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
    private var previousWindowCount: Int = -1

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
            self.checkForWindowCountChange()
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
        guard let hoveredIcon = getCurrentlySelectedDockIcon(),
              let (iconFrame, bundleIdentifier) = getDockIconInfo(element: hoveredIcon),
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first
        else {
            lastBundleIdentifier = nil
            hidePreview()
            lastPanelFrame = nil
            lastIconFrame = nil
            return
        }

        let allWindowInfos = filteredWindowInfos(for: app)
        let infoTuples = allWindowInfos.map { ($0.title, $0.isMinimized, $0.shouldHighlight) }
        if infoTuples.isEmpty {
            hidePreview()
            lastPanelFrame = nil
            lastIconFrame = nil
            return
        }

        let appDisplayName = app.localizedName ?? bundleIdentifier
        let appIcon = app.icon ?? NSWorkspace.shared.icon(for: .application)

        let panelWidth: CGFloat = 280
        let panelHeight = CGFloat(82 + max(24, infoTuples.count * 32))
        let anchorY = iconFrame.maxY + 9
        let panelRect = CGRect(
            x: iconFrame.midX - panelWidth/2,
            y: anchorY + CGFloat((infoTuples.count - 1 ) * 14),
            width: panelWidth,
            height: panelHeight
        )
        self.lastIconFrame = iconFrame
        self.lastPanelFrame = panelRect

        let updatePopupImmediately: () -> Void = { [weak self] in
            _ = self?.updateDockPreviewContent()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + dockPreviewDelay) {
            self.showOrUpdatePreviewPanel(
                appBundleID: bundleIdentifier,
                appDisplayName: appDisplayName,
                appIcon: appIcon,
                windowInfos: infoTuples,
                panelRect: panelRect,
                app: app,
                onActionComplete: updatePopupImmediately
            )
        }
    }

    private func showOrUpdatePreviewPanel(
        appBundleID: String,
        appDisplayName: String,
        appIcon: NSImage,
        windowInfos: [(title: String, isMinimized: Bool, shouldHighlight: Bool)],
        panelRect: CGRect,
        app: NSRunningApplication,
        onActionComplete: @escaping () -> Void
    ) {
        let newContent = DockPreviewPanel(
            appBundleID: appBundleID,
            appDisplayName: appDisplayName,
            appIcon: appIcon,
            windowInfos: windowInfos,
            onTitleClick: { [weak self] title in
                self?.focusWindow(of: app, withTitle: title)
            },
            onActionComplete: onActionComplete
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
        var hoveredIcon = getCurrentlySelectedDockIcon()
        var bundleIdentifier: String? = nil
        var iconFrame: CGRect? = nil

        if let icon = hoveredIcon, let (frame, bundleId) = getDockIconInfo(element: icon) {
            lastHoveredDockIcon = icon
            lastHoveredBundleIdentifier = bundleId
            bundleIdentifier = bundleId
            iconFrame = frame
        } else if let lastIcon = lastHoveredDockIcon, let lastBundleId = lastHoveredBundleIdentifier,
                  let (frame, bundleId) = getDockIconInfo(element: lastIcon) {
            hoveredIcon = lastIcon
            bundleIdentifier = bundleId
            iconFrame = frame
        } else {
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

        let windowInfos = filteredWindowInfos(for: app)
        if windowInfos.isEmpty {
            hidePreview()
            return
        }
        let appDisplayName = app.localizedName ?? bundleIdentifier
        let appIcon = app.icon ?? NSWorkspace.shared.icon(for: .application)

        let panelWidth: CGFloat = 280
        let panelHeight = CGFloat(82 + max(24, windowInfos.count * 32))
        let anchorY = iconFrame.maxY + 9
        let panelRect = CGRect(
            x: iconFrame.midX - panelWidth/2,
            y: anchorY + CGFloat((windowInfos.count - 1 ) * 14),
            width: panelWidth,
            height: panelHeight
        )

        let updatePopupImmediately: () -> Void = { [weak self] in
            _ = self?.updateDockPreviewContent()
        }

        if let panel = previewPanel, let hosting = hostingView {
            hosting.rootView = DockPreviewPanel(
                appBundleID: bundleIdentifier,
                appDisplayName: appDisplayName,
                appIcon: appIcon,
                windowInfos: windowInfos.map { ($0.title, $0.isMinimized, $0.shouldHighlight) },
                onTitleClick: { [weak self] title in
                    self?.focusWindow(of: app, withTitle: title)
                },
                onActionComplete: updatePopupImmediately
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
                appBundleID: bundleIdentifier,
                appDisplayName: appDisplayName,
                appIcon: appIcon,
                windowInfos: windowInfos.map { ($0.title, $0.isMinimized, $0.shouldHighlight) },
                onTitleClick: { [weak self] title in
                    self?.focusWindow(of: app, withTitle: title)
                },
                onActionComplete: updatePopupImmediately
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

    private func checkForWindowCountChange() {
        guard let hoveredIcon = getCurrentlySelectedDockIcon(),
              let (_, bundleIdentifier) = getDockIconInfo(element: hoveredIcon),
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first
        else {
            previousWindowCount = -1
            return
        }
        let count = filteredWindowInfos(for: app).count
        if previousWindowCount == 0 && count > 0 {
            handleDockSelectionChange()
        }
        previousWindowCount = count
    }

    private func focusWindow(of app: NSRunningApplication?, withTitle title: String) {
        guard let app = app else {
            return
        }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var windowsValue: AnyObject?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue)
        guard result == .success, let windows = windowsValue as? [AXUIElement] else {
            return
        }

        // Find the window by title
        var targetWindow: AXUIElement?
        for (i, window) in windows.enumerated() {
            var titleValue: AnyObject?
            let gotTitle = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue) == .success
            let t = (titleValue as? String) ?? "(nil)"
            if gotTitle, t == title {
                targetWindow = window
                break
            }
        }
        guard let window = targetWindow else {
            return
        }

        // Unminimize if needed
        var minimizedValue: AnyObject?
        let gotMin = AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimizedValue) == .success
        let isMinimized = gotMin ? ((minimizedValue as? Bool) ?? false) : false
        if isMinimized {
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }

        // --- Most Robust Activation Sequence ---
        // 1. Try to bring your own process to the front (sometimes required)
        NSApp.activate(ignoringOtherApps: true)
        usleep(50_000) // 50ms

        // 2. Try to activate the target app
        let didActivate = app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])

        // 3. If activate failed, try AppleScript fallback
        if !didActivate {
            let bundleID = app.bundleIdentifier ?? ""
            let script = "tell application id \"\(bundleID)\" to activate"
            if let appleScript = NSAppleScript(source: script) {
                var errorDict: NSDictionary? = nil
                appleScript.executeAndReturnError(&errorDict)
            }
        }

        // 4. Wait for app to be frontmost, then set AXMain/AXFocused
        waitForAppToBeFrontmost(app: app, timeout: 1.5) {
            let mainResult = AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
            let focusedResult = AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        }
    }

    private func waitForAppToBeFrontmost(app: NSRunningApplication, timeout: TimeInterval, completion: @escaping () -> Void) {
        let deadline = Date().addingTimeInterval(timeout)
        func poll() {
            let frontmost = NSWorkspace.shared.frontmostApplication
            if frontmost == app {
                completion()
            } else if Date() < deadline {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { poll() }
            }
        }
        poll()
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

    private func filteredWindowInfos(for app: NSRunningApplication) -> [WindowInfo] {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var windowsValue: AnyObject?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let windows = windowsValue as? [AXUIElement] else { return [] }

        var focusedWindowValue: AnyObject?
        var focusedWindow: AXUIElement?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindowValue) == .success,
           focusedWindowValue != nil {
            focusedWindow = focusedWindowValue as! AXUIElement
        }

        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let isFrontmostApp = (app.processIdentifier == frontmostPID)

        let cgVisible = visibleCGWindowTitles(for: app)

        var infos: [WindowInfo] = []

        for (idx, window) in windows.enumerated() {
            let role = window.role() ?? ""
            let subrole = window.subrole() ?? ""
            if role != "AXWindow" { continue }
            if subrole != "AXStandardWindow" && subrole != "" { continue }
            if isProbablyPictureInPicture(window: window) { continue }

            var sizeValue: AnyObject?
            var skip = false
            if AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success {
                let axSize = sizeValue as! AXValue
                var sz = CGSize.zero
                AXValueGetValue(axSize, .cgSize, &sz)
                if sz.width < 80 || sz.height < 80 { skip = true }
            }
            if skip { continue }

            var t: AnyObject?
            var title = ""
            if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &t) == .success, let ti = t as? String {
                title = ti
            }
            var minimizedRaw: AnyObject?
            let isMinimized = AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimizedRaw) == .success && (minimizedRaw as? Bool ?? false)
            if title.isEmpty || title == "(Untitled)" {
                if !(isMinimized || (cgVisible.contains(title) && !title.isEmpty)) {
                    continue
                }
            }

            infos.append(WindowInfo(
                axElement: window,
                app: app,
                index: idx,
                focusedWindow: focusedWindow,
                isFrontmostApp: isFrontmostApp
            ))
        }
        return infos
    }

    private func visibleCGWindowTitles(for app: NSRunningApplication) -> Set<String> {
        var result = Set<String>()
        guard let bundleID = app.bundleIdentifier else { return result }
        let appProcs = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        let pids = Set(appProcs.map { $0.processIdentifier })

        guard let infoList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return result
        }

        for dict in infoList {
            guard
                let ownerPID = dict[kCGWindowOwnerPID as String] as? pid_t,
                pids.contains(ownerPID),
                let title = dict[kCGWindowName as String] as? String,
                !title.isEmpty
            else { continue }
            result.insert(title)
        }
        return result
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
            if sz.width < 80 || sz.height < 80 {
                let title = window.title() ?? ""
                if title.isEmpty {
                    return true
                }
            }
        }
        return false
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
