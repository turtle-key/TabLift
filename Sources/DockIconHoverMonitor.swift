import Cocoa
import SwiftUI
import ApplicationServices
import UniformTypeIdentifiers

class DockIconHoverMonitor {
    private var dockPreviewDelay: Double {
        UserDefaults.standard.double(forKey: "dockPreviewSpeed")
    }
    private var axObserver: AXObserver?
    private var dockPID: pid_t = 0
    private var previewPanel: NSPanel?
    private var hostingView: NSHostingView<DockPreviewPanel>?
    private var lastBundleIdentifier: String?
    private var lastPanelFrame: CGRect?
    private var clickMonitor: Any?
    private var mouseTimer: Timer?
    private var dockFrame: CGRect = .zero
    private var lastIconFrame: CGRect?

    // Store the last hovered dock icon and bundle identifier for fallback when the mouse leaves the dock and enters the popup
    private var lastHoveredDockIcon: AXUIElement?
    private var lastHoveredBundleIdentifier: String?

    private var dockClickMonitor: DockClickMonitor? {
        (NSApplication.shared.delegate as? AppDelegate)?.dockClickMonitor
    }

    private var showDockPopups: Bool {
        UserDefaults.standard.bool(forKey: "showDockPopups")
    }

    init() {
        guard AXIsProcessTrusted() else {
            NSLog("Accessibility permissions NOT granted. Dock popups will not work.")
            return
        }
        setupDockObserver()
        updateDockFrame()
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
        if let clickMonitor = clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
        }
        NotificationCenter.default.removeObserver(self)
        stopMouseTimer()
        hidePreview()
    }

    private func setupDockObserver() {
        guard let dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return }
        dockPID = dockApp.processIdentifier
        let dockElement = AXUIElementCreateApplication(dockPID)

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

    private func setupClickOutsideMonitor() {
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            self?.handleMouseAndHideIfNeeded()
        }
    }

    private func startMouseTimer() {
        stopMouseTimer()
        mouseTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.previewPanel?.isVisible ?? false {
                self.updateDockPreviewContent()
            }
            self.checkMouseAndDismissIfNeeded()
        }
    }

    private func stopMouseTimer() {
        mouseTimer?.invalidate()
        mouseTimer = nil
    }

    private func checkMouseAndDismissIfNeeded() {
        let mouseLocation = NSEvent.mouseLocation
        let isInPopup = previewPanel?.frame.contains(mouseLocation) ?? false
        let isOverDockIcon = isMouseOverDockIcon()
        if !isInPopup && !isOverDockIcon {
            // Mouse is not over popup or dock icon; clear fallback state.
            lastHoveredDockIcon = nil
            lastHoveredBundleIdentifier = nil
            hidePreview()
        }
    }

    private func isMouseOverDockIcon() -> Bool {
        guard let dockApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return false }
        let dockElement = AXUIElementCreateApplication(dockApp.processIdentifier)
        var children: AnyObject?
        guard AXUIElementCopyAttributeValue(dockElement, kAXChildrenAttribute as CFString, &children) == .success,
              let dockChildren = children as? [AXUIElement],
              let axList = dockChildren.first(where: { $0.role() == kAXListRole }) else { return false }
        var selectedChildren: AnyObject?
        guard AXUIElementCopyAttributeValue(axList, kAXSelectedChildrenAttribute as CFString, &selectedChildren) == .success,
              let selectedList = selectedChildren as? [AXUIElement], !selectedList.isEmpty else { return false }
        return true
    }

    private func handleMouseAndHideIfNeeded() {
        let mouseLocation = NSEvent.mouseLocation
        let isInPopup = previewPanel?.frame.contains(mouseLocation) ?? false
        let isOverDockIcon = isMouseOverDockIcon()
        if !isInPopup && !isOverDockIcon {
            // Mouse is not over popup or dock icon; clear fallback state.
            lastHoveredDockIcon = nil
            lastHoveredBundleIdentifier = nil
            hidePreview()
        }
    }

    func handleDockSelectionChange() {
        if !showDockPopups {
            hidePreview()
            return
        }
        
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
        
        let windowInfos = fetchWindowInfos(for: app)
        if windowInfos.isEmpty {
            hidePreview()
            lastPanelFrame = nil
            lastIconFrame = nil
            return
        }
        
        let appName = app.localizedName ?? bundleIdentifier
        let appIcon = app.icon ?? NSWorkspace.shared.icon(for: .application)
        
        let panelWidth: CGFloat = 280
        let panelHeight = CGFloat(82 + max(24, windowInfos.count * 32))
        let anchorY = iconFrame.maxY + 10
        let panelRect = CGRect(
            x: iconFrame.midX - panelWidth/2,
            y: anchorY + CGFloat((windowInfos.count - 1 ) * 10),
            width: panelWidth,
            height: panelHeight
        )
        self.lastIconFrame = iconFrame
        self.lastPanelFrame = panelRect
        DispatchQueue.main.asyncAfter(deadline: .now() + dockPreviewDelay) {
            self.showOrUpdatePreviewPanel(
                appName: appName,
                appIcon: appIcon,
                windowInfos: windowInfos,
                panelRect: panelRect,
                app: app
            )
        }
    }

    private func showOrUpdatePreviewPanel(
        appName: String,
        appIcon: NSImage,
        windowInfos: [(title: String, isMinimized: Bool, shouldHighlight: Bool)],
        panelRect: CGRect,
        app: NSRunningApplication
    ) {
        let newContent = DockPreviewPanel(
            appName: appName,
            appIcon: appIcon,
            windowInfos: windowInfos,
            onTitleClick: { [weak self] title in
                self?.focusWindow(of: app, withTitle: title)
            }
        )
        if let panel = self.previewPanel, let hosting = self.hostingView {
            hosting.rootView = newContent
            panel.setContentSize(panelRect.size)
            panel.setFrameOrigin(panelRect.origin)
        } else {
            let hosting = NSHostingView(rootView: newContent)
            let panel = NSPanel(contentRect: panelRect,
                                styleMask: [.borderless, .nonactivatingPanel],
                                backing: .buffered, defer: false)
            panel.contentView = hosting
            panel.isFloatingPanel = true
            panel.level = .statusBar
            panel.backgroundColor = .clear
            panel.hasShadow = false
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
            self.startMouseTimer()
        }
    }

    private func updateDockPreviewContent() {
        // Fallback: use last hovered dock icon and bundle id if getCurrentlySelectedDockIcon returns nil
        var hoveredIcon = getCurrentlySelectedDockIcon()
        var bundleIdentifier: String? = nil
        var iconFrame: CGRect? = nil

        if let icon = hoveredIcon, let (frame, bundleId) = getDockIconInfo(element: icon) {
            // Remember this icon and bundle
            lastHoveredDockIcon = icon
            lastHoveredBundleIdentifier = bundleId
            bundleIdentifier = bundleId
            iconFrame = frame
        } else if let lastIcon = lastHoveredDockIcon, let lastBundleId = lastHoveredBundleIdentifier,
                  let (frame, bundleId) = getDockIconInfo(element: lastIcon) {
            // Use last icon while mouse is over popup
            hoveredIcon = lastIcon
            bundleIdentifier = bundleId
            iconFrame = frame
        } else {
            // Nowhere: clear state
            lastHoveredDockIcon = nil
            lastHoveredBundleIdentifier = nil
            return
        }

        guard let iconFrame = iconFrame,
              let bundleIdentifier = bundleIdentifier,
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first
        else {
            return
        }

        let windowInfos = fetchWindowInfos(for: app)
        let appName = app.localizedName ?? bundleIdentifier
        let appIcon = app.icon ?? NSWorkspace.shared.icon(for: .application)

        let panelWidth: CGFloat = 280
        let panelHeight = CGFloat(82 + max(24, windowInfos.count * 32))
        let anchorY = iconFrame.maxY + 10
        let panelRect = CGRect(
            x: iconFrame.midX - panelWidth/2,
            y: anchorY + CGFloat((windowInfos.count - 1 ) * 10),
            width: panelWidth,
            height: panelHeight
        )

        // Always update panel even if it's already visible
        if let panel = previewPanel, let hosting = hostingView {
            hosting.rootView = DockPreviewPanel(
                appName: appName,
                appIcon: appIcon,
                windowInfos: windowInfos,
                onTitleClick: { [weak self] title in
                    self?.focusWindow(of: app, withTitle: title)
                }
            )
            panel.setContentSize(panelRect.size)
            panel.setFrameOrigin(panelRect.origin)
            panel.orderFrontRegardless()
            panel.displayIfNeeded()
            panel.contentView?.needsLayout = true
            panel.contentView?.needsDisplay = true
            panel.contentView?.layoutSubtreeIfNeeded()

            hosting.setNeedsDisplay(hosting.bounds)
            hosting.needsLayout = true
            hosting.layoutSubtreeIfNeeded()
            if !hosting.isDescendant(of: panel.contentView!) {
                panel.contentView?.addSubview(hosting)
            }
        } else {
            let hosting = NSHostingView(rootView: DockPreviewPanel(
                appName: appName,
                appIcon: appIcon,
                windowInfos: windowInfos,
                onTitleClick: { [weak self] title in
                    self?.focusWindow(of: app, withTitle: title)
                }
            ))
            let panel = NSPanel(contentRect: panelRect,
                                styleMask: [.borderless, .nonactivatingPanel],
                                backing: .buffered, defer: false)
            panel.contentView = hosting
            panel.isFloatingPanel = true
            panel.level = .statusBar
            panel.backgroundColor = .clear
            panel.hasShadow = false
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
            self.startMouseTimer()
        }
    }

    private func hidePreview() {
        stopMouseTimer()
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

    private func fetchWindowInfos(for app: NSRunningApplication?) -> [(title: String, isMinimized: Bool, shouldHighlight: Bool)] {
        guard let app = app else { return [] }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var windowsValue: AnyObject?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let windows = windowsValue as? [AXUIElement] else { return [] }

        var focusedWindowValue: AnyObject?
        var focusedWindow: AXUIElement?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindowValue) == .success,
           let fw = focusedWindowValue {
            focusedWindow = (fw as! AXUIElement)
        }

        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let isFrontmostApp = (app.processIdentifier == frontmostPID)

        var infos: [(String, Bool, Bool)] = []

        for window in windows {
            let role = window.role() ?? "(nil)"
            let pip = isProbablyPictureInPicture(window: window)
            if role != "AXWindow" { continue }
            if pip { continue }

            var titleValue: AnyObject?
            var minimizedValue: AnyObject?
            let titleSuccess = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue) == .success
            let minSuccess = AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimizedValue) == .success
            var title = titleSuccess ? (titleValue as? String ?? "") : ""
            let minimized = minSuccess ? ((minimizedValue as? Bool) ?? false) : false
            let shouldHighlight = isFrontmostApp && (focusedWindow != nil) && CFEqual(window, focusedWindow)

            if title.isEmpty {
                var documentValue: AnyObject?
                if AXUIElementCopyAttributeValue(window, kAXDocumentAttribute as CFString, &documentValue) == .success,
                    let document = documentValue as? String, !document.isEmpty {
                    title = document
                } else {
                    title = "(Untitled)"
                }
            }
            infos.append((title, minimized, shouldHighlight))
        }
        return infos
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
                var minimizedValue: AnyObject?
                if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimizedValue) == .success,
                   let isMinimized = minimizedValue as? Bool, isMinimized
                {
                    WindowManager.restoreMinimizedWindows(for: app)
                }
                AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
                AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
                app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
                return
            }
        }
        app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    }

    func refresh() {
        if let observer = axObserver {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .commonModes)
            axObserver = nil
        }
        if let clickMonitor = clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
            self.clickMonitor = nil
        }
        NotificationCenter.default.removeObserver(self)
        stopMouseTimer()
        hidePreview()
        setupDockObserver()
        updateDockFrame()
        setupClickOutsideMonitor()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateDockFrame),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
}
