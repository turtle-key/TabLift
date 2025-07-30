import Cocoa
import ApplicationServices
import SwiftUI

class DockClickMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // Track the number of Dock clicks for each app (by pid)
    private var appClickCounts: [pid_t: Int] = [:]
    // Remember when we last saw the app become frontmost (for alt-tab etc)
    private var lastFrontmostAppPID: pid_t?
    private var lastFrontmostAppChange: Date?

    // Main event observer for app switches (alt-tab, click, etc)
    private var workspaceObserver: NSObjectProtocol?

    init() {
        setupEventTap()
        setupFrontmostAppObserver()
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
    }

    private func setupEventTap() {
        let eventMask = (1 << CGEventType.leftMouseDown.rawValue)
        let callback: CGEventTapCallBack = { _, _, event, userInfo in
            guard let userInfo = userInfo else { return Unmanaged.passUnretained(event) }
            let monitor = Unmanaged<DockClickMonitor>.fromOpaque(userInfo).takeUnretainedValue()
            monitor.handleClick(event: event)
            return Unmanaged.passUnretained(event)
        }
        let pointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        guard let eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .tailAppendEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
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

    private func setupFrontmostAppObserver() {
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            guard let self = self,
                  let userInfo = notif.userInfo,
                  let app = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            else { return }
            let pid = app.processIdentifier
            self.lastFrontmostAppPID = pid
            self.lastFrontmostAppChange = Date()
            // Reset click count for this app, so a Dock click (if any) will be counted as the first
            self.appClickCounts[pid] = 1
        }
    }

    private func handleClick(event: CGEvent) {
        let mouseLocation = NSEvent.mouseLocation
        guard let dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return }
        let dockElement = AXUIElementCreateApplication(dockApp.processIdentifier)

        var children: AnyObject?
        if AXUIElementCopyAttributeValue(dockElement, kAXChildrenAttribute as CFString, &children) != .success { return }
        guard let dockChildren = children as? [AXUIElement], !dockChildren.isEmpty else { return }

        // Look for AXList element
        guard let axList = dockChildren.first(where: {
            (try? $0.role() == kAXListRole) ?? false
        }) else { return }

        var dockItems: AnyObject?
        if AXUIElementCopyAttributeValue(axList, kAXChildrenAttribute as CFString, &dockItems) != .success { return }
        guard let dockIcons = dockItems as? [AXUIElement] else { return }

        // Get the main screen's height (for y flip)
        let screenHeight = NSScreen.screens.first?.frame.height ?? 0

        for icon in dockIcons {
            if (try? icon.subrole()) != "AXApplicationDockItem" { continue }

            var positionValue: AnyObject?
            var sizeValue: AnyObject?
            if AXUIElementCopyAttributeValue(icon, kAXPositionAttribute as CFString, &positionValue) != .success { continue }
            if AXUIElementCopyAttributeValue(icon, kAXSizeAttribute as CFString, &sizeValue) != .success { continue }
            let position = positionValue as! AXValue
            let size = sizeValue as! AXValue

            var pos = CGPoint.zero, sz = CGSize.zero
            AXValueGetValue(position, .cgPoint, &pos)
            AXValueGetValue(size, .cgSize, &sz)

            // --- Correct the coordinate system: ---
            // AX origin is top-left, NSEvent is bottom-left, so flip y
            let correctedY = screenHeight - pos.y - sz.height
            let correctedFrame = CGRect(x: pos.x, y: correctedY, width: sz.width, height: sz.height)
            // --------------------------------------

            if correctedFrame.contains(mouseLocation) {
                var bundleURL: AnyObject?
                if AXUIElementCopyAttributeValue(icon, kAXURLAttribute as CFString, &bundleURL) == .success,
                   let url = bundleURL as? NSURL,
                   let bundle = Bundle(url: url as URL),
                   let bundleID = bundle.bundleIdentifier,
                   let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
                {
                    let pid = app.processIdentifier

                    // If the app is not frontmost, set click count to 1 (simulate first click after switch)
                    if pid != NSWorkspace.shared.frontmostApplication?.processIdentifier {
                        appClickCounts[pid] = 1
                    } else {
                        // Increment click count for this app
                        let newCount = (appClickCounts[pid] ?? 0) + 1
                        appClickCounts[pid] = newCount

                        // Only minimize if app is frontmost, with a delay, and the click count is even
                        if newCount % 2 == 0 {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                                // Use user preference for all windows or just focused
                                WindowManager.minimizeFocusedWindow(of: app)
                            }
                        }
                    }
                }
                break
            }
        }
    }
}

