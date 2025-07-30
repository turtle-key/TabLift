import Cocoa
import SwiftUI
import ApplicationServices

class DockIconHoverMonitor {
    private var axObserver: AXObserver?
    private var dockPID: pid_t = 0
    private var previewPanel: NSPanel?
    private var hostingView: NSHostingView<DockPreviewPanel>?
    private var lastBundleIdentifier: String?
    private var lastPanelFrame: CGRect?
    private var mouseMonitor: Any?
    private var clickMonitor: Any?
    private var dockFrame: CGRect = .zero
    private var lastIconFrame: CGRect?

    init() {
        guard AXIsProcessTrusted() else {
            NSLog("Accessibility permissions NOT granted. Dock popups will not work.")
            return
        }
        setupDockObserver()
        updateDockFrame()
        setupMouseTracking()
        setupClickOutsideMonitor()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateDockFrame),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    deinit {
        if let observer = axObserver {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        if let mouseMonitor = mouseMonitor {
            NSEvent.removeMonitor(mouseMonitor)
        }
        if let clickMonitor = clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
        }
        NotificationCenter.default.removeObserver(self)
        hidePreview()
    }

    private func setupDockObserver() {
        guard let dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return }
        dockPID = dockApp.processIdentifier
        let dockElement = AXUIElementCreateApplication(dockPID)

        // Find AXList child
        var children: AnyObject?
        guard AXUIElementCopyAttributeValue(dockElement, kAXChildrenAttribute as CFString, &children) == .success,
              let dockChildren = children as? [AXUIElement],
              let axList = dockChildren.first(where: { $0.role() == kAXListRole }) else { return }

        var observer: AXObserver?
        let callback: AXObserverCallback = { observer, element, notification, refcon in
            guard let refcon = refcon else { return }
            let monitor = Unmanaged<DockIconHoverMonitor>.fromOpaque(refcon).takeUnretainedValue()
            DispatchQueue.main.async {
                monitor.handleDockSelectionChange()
            }
        }

        if AXObserverCreate(dockPID, callback, &observer) == .success, let observer = observer {
            axObserver = observer
            let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
            AXObserverAddNotification(observer, axList, kAXSelectedChildrenChangedNotification as CFString, refcon)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
    }

    @objc
    private func updateDockFrame() {
        guard let dockInfoList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return }
        for info in dockInfoList {
            if let ownerName = info[kCGWindowOwnerName as String] as? String,
               ownerName == "Dock",
               let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
               let x = bounds["X"], let y = bounds["Y"], let w = bounds["Width"], let h = bounds["Height"] {
                dockFrame = CGRect(x: x, y: y, width: w, height: h)
                return
            }
        }
        // Fallback: old approximation
        if let screen = NSScreen.screens.first {
            let height: CGFloat = 80
            let visibleFrame = screen.visibleFrame
            let fullFrame = screen.frame
            let dockHeight = fullFrame.height - visibleFrame.height
            if dockHeight > 0 {
                dockFrame = CGRect(x: visibleFrame.origin.x, y: visibleFrame.origin.y + visibleFrame.height, width: visibleFrame.width, height: dockHeight)
            } else {
                dockFrame = CGRect(x: visibleFrame.origin.x, y: visibleFrame.origin.y, width: visibleFrame.width, height: height)
            }
        }
    }

    private func setupMouseTracking() {
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            self?.handleMouseAndHideIfNeeded()
        }
        // Add a local monitor so we can track mouse exit from popup more responsively
        NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseAndHideIfNeeded()
            return event
        }
    }

    private func setupClickOutsideMonitor() {
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            self?.handleMouseAndHideIfNeeded()
        }
    }

    private func handleMouseAndHideIfNeeded() {
        let mouseLocation = NSEvent.mouseLocation
        if !isPointInsideDockOrPopup(mouseLocation) {
            hidePreview()
        }
    }

    private func isPointInsideDockOrPopup(_ point: CGPoint) -> Bool {
        if dockFrame.contains(point) { return true }
        if let panel = previewPanel, panel.isVisible {
            if panel.frame.contains(point) { return true }
        }
        return false
    }

    func handleDockSelectionChange() {
        guard let hoveredIcon = getCurrentlySelectedDockIcon() else {
            lastBundleIdentifier = nil
            hidePreview()
            lastPanelFrame = nil
            lastIconFrame = nil
            return
        }
        guard let (iconFrame, bundleIdentifier) = getDockIconInfo(element: hoveredIcon) else {
            lastBundleIdentifier = nil
            hidePreview()
            lastPanelFrame = nil
            lastIconFrame = nil
            return
        }
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first else {
            hidePreview()
            lastPanelFrame = nil
            lastIconFrame = nil
            return
        }

        // Only show if app has windows (disable "new window" for active with no windows)
        let windowTitles = fetchWindowTitles(for: app)
        if windowTitles.isEmpty {
            hidePreview()
            lastPanelFrame = nil
            lastIconFrame = nil
            return
        }

        let appName = app.localizedName ?? bundleIdentifier
        let appIcon = app.icon ?? NSWorkspace.shared.icon(forFileType: NSFileTypeForHFSTypeCode(OSType(kGenericApplicationIcon)))

        // Dynamically update panel content and frame, but don't move up/down if content changes
        let newContent = DockPreviewPanel(
            appName: appName,
            appIcon: appIcon,
            windowTitles: windowTitles,
            onTitleClick: { [weak self] title in
                self?.focusWindow(of: app, withTitle: title)
            }
        )
        let panelWidth: CGFloat = 280
        let panelHeight = CGFloat(82 + max(24, windowTitles.count * 32))
        let panelRect: CGRect
        if let lastIconFrame = lastIconFrame, let lastPanelFrame = lastPanelFrame {
            if iconFrame.equalTo(lastIconFrame) {
                panelRect = lastPanelFrame
            } else {
                panelRect = CGRect(x: iconFrame.midX - panelWidth/2, y: iconFrame.maxY + 10, width: panelWidth, height: panelHeight)
                self.lastIconFrame = iconFrame
                self.lastPanelFrame = panelRect
            }
        } else {
            panelRect = CGRect(x: iconFrame.midX - panelWidth/2, y: iconFrame.maxY + 10, width: panelWidth, height: panelHeight)
            self.lastIconFrame = iconFrame
            self.lastPanelFrame = panelRect
        }

        if let panel = previewPanel, let hosting = hostingView {
            hosting.rootView = newContent
            panel.setContentSize(panelRect.size)
        } else {
            let hosting = NSHostingView(rootView: newContent)
            let panel = NSPanel(contentRect: panelRect,
                                styleMask: [.borderless, .nonactivatingPanel],
                                backing: .buffered, defer: false)
            panel.contentView = hosting
            panel.isFloatingPanel = true
            panel.level = .statusBar
            panel.backgroundColor = .clear
            panel.hasShadow = false // Use SwiftUI shadow, not AppKit
            panel.ignoresMouseEvents = false
            panel.hidesOnDeactivate = false
            panel.becomesKeyOnlyIfNeeded = true
            panel.worksWhenModal = true
            panel.isReleasedWhenClosed = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.setFrameOrigin(panelRect.origin)
            panel.setContentSize(panelRect.size)
            panel.orderFrontRegardless()
            self.previewPanel = panel
            self.hostingView = hosting
        }
    }

    private func hidePreview() {
        if let panel = previewPanel {
            panel.orderOut(nil)
        }
        previewPanel = nil
        hostingView = nil
        lastPanelFrame = nil
        lastIconFrame = nil
    }

    private func getCurrentlySelectedDockIcon() -> AXUIElement? {
        guard let dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return nil }
        let dockElement = AXUIElementCreateApplication(dockApp.processIdentifier)
        var children: AnyObject?
        guard AXUIElementCopyAttributeValue(dockElement, kAXChildrenAttribute as CFString, &children) == .success,
              let dockChildren = children as? [AXUIElement],
              let axList = dockChildren.first(where: { $0.role() == kAXListRole }) else { return nil }
        var selectedChildren: AnyObject?
        guard AXUIElementCopyAttributeValue(axList, kAXSelectedChildrenAttribute as CFString, &selectedChildren) == .success,
              let selectedList = selectedChildren as? [AXUIElement], !selectedList.isEmpty else { return nil }
        let hoveredDockIcon = selectedList.first
        if hoveredDockIcon?.subrole() == "AXApplicationDockItem" {
            return hoveredDockIcon
        }
        return nil
    }

    private func getDockIconInfo(element: AXUIElement) -> (CGRect, String)? {
        var positionValue: AnyObject?
        var sizeValue: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success else { return nil }
        var pos = CGPoint.zero, sz = CGSize.zero
        AXValueGetValue(positionValue as! AXValue, .cgPoint, &pos)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &sz)
        let screenHeight = NSScreen.screens.first?.frame.height ?? 0
        let correctedY = screenHeight - pos.y - sz.height
        let frame = CGRect(x: pos.x, y: correctedY, width: sz.width, height: sz.height)

        var bundleURL: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXURLAttribute as CFString, &bundleURL) == .success,
              let url = bundleURL as? NSURL,
              let bundle = Bundle(url: url as URL),
              let bundleID = bundle.bundleIdentifier
        else { return nil }
        return (frame, bundleID)
    }

    private func fetchWindowTitles(for app: NSRunningApplication?) -> [String] {
        guard let app = app else { return [] }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var windowsValue: AnyObject?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let windows = windowsValue as? [AXUIElement] else { return [] }
        var titles: [String] = []
        for window in windows {
            var titleValue: AnyObject?
            if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue) == .success,
               let title = titleValue as? String {
                titles.append(title)
            }
        }
        return titles
    }

    private func focusWindow(of app: NSRunningApplication?, withTitle title: String) {
        guard let app = app else { return }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var windowsValue: AnyObject?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let windows = windowsValue as? [AXUIElement] else { return }
        for window in windows {
            var titleValue: AnyObject?
            if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue) == .success,
               let t = titleValue as? String, t == title {
                AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
                AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
                app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
                return
            }
        }
        app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    }
}
