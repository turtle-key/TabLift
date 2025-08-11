import Cocoa
import ApplicationServices
import SwiftUI

final class DockClickMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var workspaceObserver: NSObjectProtocol?
    private var minimizedObserver: NSObjectProtocol?

    // User preference (General > Dock Features > “Dock click toggles all windows”)
    private var restoreAllOnDockClick: Bool {
        UserDefaults.standard.object(forKey: "restoreAllOnDockClick") as? Bool ?? false
    }

    init() {
        setupEventTap()
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { _ in }
        minimizedObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in }
    }

    deinit {
        if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: false); CFMachPortInvalidate(eventTap) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes) }
        if let observer = workspaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        if let observer = minimizedObserver { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    }

    // MARK: Event Tap

    private func setupEventTap() {
        let mask = (1 << CGEventType.leftMouseDown.rawValue)
        let pointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        guard let eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .tailAppendEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, _, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<DockClickMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                monitor.handleClick(event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: pointer
        ) else {
            print("Failed to create DockClickMonitor event tap")
            return
        }
        self.eventTap = eventTap
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        self.runLoopSource = src
        CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    // MARK: AX helpers / identity (no titles)

    private let kAXWindowNumberAttributeStr = "AXWindowNumber" as CFString

    @inline(__always)
    private func axString(_ el: AXUIElement, _ attr: CFString) -> String? {
        var v: AnyObject?
        guard AXUIElementCopyAttributeValue(el, attr, &v) == .success else { return nil }
        return v as? String
    }

    @inline(__always)
    private func role(of el: AXUIElement) -> String? {
        axString(el, kAXRoleAttribute as CFString)
    }

    @inline(__always)
    private func subrole(of el: AXUIElement) -> String? {
        axString(el, kAXSubroleAttribute as CFString)
    }

    private func windowNumber(of el: AXUIElement) -> Int? {
        var any: AnyObject?
        guard AXUIElementCopyAttributeValue(el, kAXWindowNumberAttributeStr, &any) == .success else { return nil }
        if let n = any as? NSNumber { return n.intValue }
        if let cf = any as CFTypeRef?, CFGetTypeID(cf) == CFNumberGetTypeID() {
            var val: Int32 = 0
            if CFNumberGetValue(cf as! CFNumber, .sInt32Type, &val) { return Int(val) }
        }
        return nil
    }

    private func isProbablyPictureInPicture(window: AXUIElement) -> Bool {
        let sub = subrole(of: window) ?? ""
        if sub == "AXPictureInPictureWindow" ||
            sub == "AXFloatingWindow" ||
            sub == "AXPanel" ||
            sub == "AXSystemDialog" {
            return true
        }
        // Heuristic: very tiny utility / overlay
        var sizeValue: AnyObject?
        if AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success {
            let axSize = sizeValue as! AXValue
            var sz = CGSize.zero
            AXValueGetValue(axSize, .cgSize, &sz)
            if sz.width < 80 || sz.height < 80 { return true }
        }
        return false
    }

    private func appWindows(for app: NSRunningApplication) -> [AXUIElement] {
        let appEl = AXUIElementCreateApplication(app.processIdentifier)
        var raw: AnyObject?
        guard AXUIElementCopyAttributeValue(appEl, kAXWindowsAttribute as CFString, &raw) == .success,
              let windows = raw as? [AXUIElement], !windows.isEmpty else { return [] }
        return windows.filter {
            (role(of: $0) ?? "") == "AXWindow" && !isProbablyPictureInPicture(window: $0)
        }
    }

    private func focusedWindow(for app: NSRunningApplication) -> AXUIElement? {
        let appEl = AXUIElementCreateApplication(app.processIdentifier)
        var v: AnyObject?
        guard AXUIElementCopyAttributeValue(appEl, kAXFocusedWindowAttribute as CFString, &v) == .success else { return nil }
        return v as! AXUIElement
    }

    private func visibleWindows(of app: NSRunningApplication) -> [AXUIElement] {
        appWindows(for: app).filter { win in
            var minRaw: AnyObject?
            let ok = AXUIElementCopyAttributeValue(win, kAXMinimizedAttribute as CFString, &minRaw) == .success
            return ok && ((minRaw as? Bool) == false)
        }
    }

    private func counts(for app: NSRunningApplication) -> (total: Int, minimized: Int, visible: Int) {
        let all = appWindows(for: app)
        var minimizedCount = 0
        for win in all {
            var minRaw: AnyObject?
            if AXUIElementCopyAttributeValue(win, kAXMinimizedAttribute as CFString, &minRaw) == .success,
               let isMin = minRaw as? Bool, isMin {
                minimizedCount += 1
            }
        }
        return (total: all.count, minimized: minimizedCount, visible: all.count - minimizedCount)
    }

    @inline(__always)
    private func isMinimized(_ window: AXUIElement) -> Bool {
        var minRaw: AnyObject?
        if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minRaw) == .success,
           let isMin = minRaw as? Bool { return isMin }
        return false
    }

    // MARK: Minimize / Restore helpers

    private func minimizeWindow(_ window: AXUIElement) {
        var btnAny: AnyObject?
        if AXUIElementCopyAttributeValue(window, kAXMinimizeButtonAttribute as CFString, &btnAny) == .success {
            let cf = btnAny as CFTypeRef
            if CFGetTypeID(cf) == AXUIElementGetTypeID() {
                let btn = cf as! AXUIElement
                AXUIElementPerformAction(window, "AXRaise" as CFString)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                    AXUIElementPerformAction(btn, kAXPressAction as CFString)
                }
                return
            }
        }
        AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
    }

    private func restoreWindow(_ window: AXUIElement) {
        AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
    }

    private func restoreAllMinimizedWindows(for app: NSRunningApplication) {
        let all = appWindows(for: app)
        var didRestore = false
        for w in all where isMinimized(w) {
            restoreWindow(w)
            didRestore = true
        }
        if didRestore {
            NSApp.activate(ignoringOtherApps: true)
            _ = app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        }
    }

    private func minimizeAllVisibleWindows(for app: NSRunningApplication) {
        for w in visibleWindows(of: app) { minimizeWindow(w) }
    }

    private func minimizeFocusedOrTopVisibleWindow(for app: NSRunningApplication) {
        if let focused = focusedWindow(for: app), !isMinimized(focused) {
            minimizeWindow(focused)
            return
        }
        if let first = visibleWindows(of: app).first {
            minimizeWindow(first)
        }
    }


    private func handleClick(event: CGEvent) {
        let mouseLocation = NSEvent.mouseLocation
        guard let dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return }
        let dockElement = AXUIElementCreateApplication(dockApp.processIdentifier)

        var children: AnyObject?
        guard AXUIElementCopyAttributeValue(dockElement, kAXChildrenAttribute as CFString, &children) == .success,
              let dockChildren = children as? [AXUIElement], !dockChildren.isEmpty else { return }
        guard let axList = dockChildren.first(where: { (role(of: $0) ?? "") == kAXListRole }) else { return }

        var dockItems: AnyObject?
        guard AXUIElementCopyAttributeValue(axList, kAXChildrenAttribute as CFString, &dockItems) == .success,
              let dockIcons = dockItems as? [AXUIElement] else { return }

        let screenHeight = NSScreen.screens.first?.frame.height ?? 0

        for icon in dockIcons {
            guard (subrole(of: icon) ?? "") == "AXApplicationDockItem" else { continue }

            var positionValue: AnyObject?
            var sizeValue: AnyObject?
            guard AXUIElementCopyAttributeValue(icon, kAXPositionAttribute as CFString, &positionValue) == .success,
                  AXUIElementCopyAttributeValue(icon, kAXSizeAttribute as CFString, &sizeValue) == .success else { continue }

            var pos = CGPoint.zero, sz = CGSize.zero
            AXValueGetValue(positionValue as! AXValue, .cgPoint, &pos)
            AXValueGetValue(sizeValue as! AXValue, .cgSize, &sz)
            let correctedY = screenHeight - pos.y - sz.height
            let correctedFrame = CGRect(x: pos.x, y: correctedY, width: sz.width, height: sz.height)

            if correctedFrame.contains(mouseLocation) {
                var bundleURL: AnyObject?
                guard AXUIElementCopyAttributeValue(icon, kAXURLAttribute as CFString, &bundleURL) == .success,
                      let url = bundleURL as? NSURL,
                      let bundle = Bundle(url: url as URL),
                      let bundleID = bundle.bundleIdentifier,
                      let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else { return }

                let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
                let pid = app.processIdentifier
                let isFrontmost = (pid == frontmostPID)

                let c = counts(for: app)

                if restoreAllOnDockClick {
                    // Toggle mode but only minimize if frontmost
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                        if isFrontmost {
                            if c.visible > 0 {
                                self.minimizeAllVisibleWindows(for: app)
                            } else if c.total > 0 && c.minimized == c.total {
                                self.restoreAllMinimizedWindows(for: app)
                            } else {
                                // No windows? Just activate (should already be frontmost).
                                _ = app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
                            }
                        } else {
                            // Not frontmost: never minimize, only restore all if everything minimized, else activate.
                            if c.total > 0 && c.minimized == c.total {
                                self.restoreAllMinimizedWindows(for: app)
                            } else {
                                _ = app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
                            }
                        }
                    }
                } else {
                    // Single-window minimize mode
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                        if c.total > 0 && c.minimized == c.total {
                            // All minimized -> restore all
                            self.restoreAllMinimizedWindows(for: app)
                        } else if isFrontmost {
                            // Only minimize the focused (or first visible) when already frontmost
                            self.minimizeFocusedOrTopVisibleWindow(for: app)
                        } else {
                            // Bring to front (do not minimize if not already frontmost)
                            _ = app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
                        }
                    }
                }
                break
            }
        }
    }

    // MARK: Refresh

    func refresh() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            workspaceObserver = nil
        }
        if let observer = minimizedObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            minimizedObserver = nil
        }
        setupEventTap()
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { _ in }
        minimizedObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in }
    }
}
