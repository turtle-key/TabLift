import Cocoa
import ApplicationServices
import SwiftUI

class DockClickMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // Track number of Dock clicks for each app (by pid)
    var appClickCounts: [pid_t: Int] = [:]
    private var lastFrontmostAppPID: pid_t?
    private var lastFrontmostAppChange: Date?
    private var lastMinimizedState: [pid_t: Bool] = [:]

    private var workspaceObserver: NSObjectProtocol?
    private var minimizedObserver: NSObjectProtocol?

    init() {
        setupEventTap()
        setupFrontmostAppObserver()
        setupMinimizedStateObserver()
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
            self.syncAppClickCountWithWindowState(pid: pid)
            self.lastMinimizedState[pid] = WindowManager.areAllWindowsMinimized(for: app)
        }
    }

    private func setupMinimizedStateObserver() {
        minimizedObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncMinimizedStatesWithRunningApps()
        }
    }

    private func syncMinimizedStatesWithRunningApps() {
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            let pid = app.processIdentifier
            syncAppClickCountWithWindowState(pid: pid)
            lastMinimizedState[pid] = WindowManager.areAllWindowsMinimized(for: app)
        }
    }

    func syncAppClickCountWithWindowState(pid: pid_t) {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return }
        if WindowManager.areAllWindowsMinimized(for: app) {
            appClickCounts[pid] = 2 // Next dock click restores
        } else {
            appClickCounts[pid] = 1 // Next dock click minimizes
        }
    }

    func setAppClickCount(_ pid: pid_t, to value: Int) {
        appClickCounts[pid] = value
    }

    private func handleClick(event: CGEvent) {
        let mouseLocation = NSEvent.mouseLocation
        guard let dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return }
        let dockElement = AXUIElementCreateApplication(dockApp.processIdentifier)

        var children: AnyObject?
        if AXUIElementCopyAttributeValue(dockElement, kAXChildrenAttribute as CFString, &children) != .success { return }
        guard let dockChildren = children as? [AXUIElement], !dockChildren.isEmpty else { return }

        guard let axList = dockChildren.first(where: {
            (try? $0.role() == kAXListRole) ?? false
        }) else { return }

        var dockItems: AnyObject?
        if AXUIElementCopyAttributeValue(axList, kAXChildrenAttribute as CFString, &dockItems) != .success { return }
        guard let dockIcons = dockItems as? [AXUIElement] else { return }

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
            let correctedY = screenHeight - pos.y - sz.height
            let correctedFrame = CGRect(x: pos.x, y: correctedY, width: sz.width, height: sz.height)
            if correctedFrame.contains(mouseLocation) {
                var bundleURL: AnyObject?
                if AXUIElementCopyAttributeValue(icon, kAXURLAttribute as CFString, &bundleURL) == .success,
                   let url = bundleURL as? NSURL,
                   let bundle = Bundle(url: url as URL),
                   let bundleID = bundle.bundleIdentifier,
                   let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
                {
                    let pid = app.processIdentifier
                    // --- Always sync before using the counter! ---
                    syncAppClickCountWithWindowState(pid: pid)
                    // If the app is not frontmost, set click count to 1 (simulate first click after switch)
                    if pid != NSWorkspace.shared.frontmostApplication?.processIdentifier {
                        appClickCounts[pid] = 1
                    } else {
                        // Increment click count for this app
                        let newCount = (appClickCounts[pid] ?? 1) + 1
                        appClickCounts[pid] = newCount

                        // Only minimize if app is frontmost, with a delay, and the click count is even
                        if newCount % 2 == 0 {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                                WindowManager.minimizeFocusedWindow(of: app)
                                self.syncAppClickCountWithWindowState(pid: pid)
                            }
                        }
                    }
                }
                break
            }
        }
    }
    func refresh() {
        //remove event tap and observers
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
        appClickCounts.removeAll()
        syncMinimizedStatesWithRunningApps()
        // Re-setup
        setupEventTap()
        setupFrontmostAppObserver()
        setupMinimizedStateObserver()
    }
}
