import Cocoa
import ApplicationServices
import SwiftUI

class DockClickMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private var lastAction: [pid_t: DockAction] = [:]
    private var workspaceObserver: NSObjectProtocol?
    private var minimizedObserver: NSObjectProtocol?

    enum DockAction {
        case minimize
        case restore
    }

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
            self.syncDockActionForApp(pid: pid)
        }
    }

    private func setupMinimizedStateObserver() {
        minimizedObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncAllDockActions()
        }
    }

    private func syncDockActionForApp(pid: pid_t) {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return }
        // Always get the real window state
        let allMinimized = WindowManager.areAllWindowsMinimized(for: app)
        lastAction[pid] = allMinimized ? .restore : .minimize
    }

    private func syncAllDockActions() {
        for app in NSWorkspace.shared.runningApplications {
            syncDockActionForApp(pid: app.processIdentifier)
        }
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
                    // Always sync before acting (fix window close/minimize bugs)
                    syncDockActionForApp(pid: pid)
                    let action = lastAction[pid] ?? .minimize

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                        // Recheck state right before acting
                        let allMinimized = WindowManager.areAllWindowsMinimized(for: app)
                        if action == .minimize && !allMinimized {
                            WindowManager.minimizeFocusedWindow(of: app)
                        } else if action == .restore && allMinimized {
                            WindowManager.restoreMinimizedWindows(for: app)
                        }
                        // Sync after acting
                        self.syncDockActionForApp(pid: pid)
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
        lastAction.removeAll()
        syncAllDockActions()
        setupEventTap()
        setupFrontmostAppObserver()
        setupMinimizedStateObserver()
    }
}
