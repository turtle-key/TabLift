import Cocoa
import ApplicationServices
import SwiftUI

class DockClickMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var workspaceObserver: NSObjectProtocol?
    private var minimizedObserver: NSObjectProtocol?

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
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        if let observer = minimizedObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    private func setupEventTap() {
        let eventMask = (1 << CGEventType.leftMouseDown.rawValue)
        let pointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        guard let eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .tailAppendEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { _, _, event, userInfo in
                guard let userInfo = userInfo else { return Unmanaged.passUnretained(event) }
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
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        self.runLoopSource = runLoopSource
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    private func isProbablyPictureInPicture(window: AXUIElement) -> Bool {
        let subrole = window.subrole() ?? ""
        if subrole == "AXPictureInPictureWindow" ||
           subrole == "AXFloatingWindow" ||
           subrole == "AXPanel" ||
           subrole == "AXSystemDialog"
        {
            return true
        }
        var sizeValue: AnyObject?
        if AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success {
            let axSize = sizeValue as! AXValue
            var sz = CGSize.zero
            AXValueGetValue(axSize, .cgSize, &sz)
            if sz.width < 220 || sz.height < 220 {
                let title = window.title() ?? ""
                if title.isEmpty {
                    return true
                }
            }
        }
        return false
    }

    private func visibleWindows(of app: NSRunningApplication) -> [AXUIElement] {
        let appEl = AXUIElementCreateApplication(app.processIdentifier)
        var raw: AnyObject?
        guard AXUIElementCopyAttributeValue(appEl, kAXWindowsAttribute as CFString, &raw) == .success,
              let windows = raw as? [AXUIElement], !windows.isEmpty else { return [] }
        return windows.filter {
            let role = $0.role() ?? ""
            if role != "AXWindow" { return false }
            if isProbablyPictureInPicture(window: $0) { return false }
            var minRaw: AnyObject?
            if AXUIElementCopyAttributeValue($0, kAXMinimizedAttribute as CFString, &minRaw) == .success,
               let isMin = minRaw as? Bool {
                return !isMin
            }
            return false
        }
    }

    private func areAllVisibleWindowsMinimized(for app: NSRunningApplication) -> Bool {
        let appEl = AXUIElementCreateApplication(app.processIdentifier)
        var raw: AnyObject?
        guard AXUIElementCopyAttributeValue(appEl, kAXWindowsAttribute as CFString, &raw) == .success,
              let windows = raw as? [AXUIElement], !windows.isEmpty else { return false }
        for window in windows {
            let role = window.role() ?? ""
            if role != "AXWindow" { continue }
            if isProbablyPictureInPicture(window: window) { continue }
            var minRaw: AnyObject?
            if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minRaw) == .success,
               let isMin = minRaw as? Bool, !isMin {
                return false
            }
        }
        return true
    }

    private func handleClick(event: CGEvent) {
        let mouseLocation = NSEvent.mouseLocation
        guard let dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return }
        let dockElement = AXUIElementCreateApplication(dockApp.processIdentifier)
        var children: AnyObject?
        guard AXUIElementCopyAttributeValue(dockElement, kAXChildrenAttribute as CFString, &children) == .success,
              let dockChildren = children as? [AXUIElement], !dockChildren.isEmpty else { return }
        guard let axList = dockChildren.first(where: { $0.role() == kAXListRole }) else { return }
        var dockItems: AnyObject?
        guard AXUIElementCopyAttributeValue(axList, kAXChildrenAttribute as CFString, &dockItems) == .success,
              let dockIcons = dockItems as? [AXUIElement] else { return }
        let screenHeight = NSScreen.screens.first?.frame.height ?? 0

        for icon in dockIcons {
            guard icon.subrole() == "AXApplicationDockItem" else { continue }
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

                let pid = app.processIdentifier
                let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
                let restoreAll = UserDefaults.standard.bool(forKey: WindowManager.restoreAllKey)
                let minimized = areAllVisibleWindowsMinimized(for: app)
                let visWindows = visibleWindows(of: app)

                if minimized {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                        WindowManager.restoreMinimizedWindows(for: app)
                        app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
                    }
                } else if pid == frontmostPID {
                    if restoreAll {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                            for win in visWindows {
                                AXUIElementSetAttributeValue(win, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
                            }
                        }
                    } else if let focused = visWindows.first {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                            AXUIElementSetAttributeValue(focused, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
                        }
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                            app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
                        }
                    }
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                        app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
                    }
                }
                break
            }
        }
    }

    func refresh() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
        if let runLoopSource = runLoopSource {
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
