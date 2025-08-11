import Cocoa
import SwiftUI
import ApplicationServices
import UniformTypeIdentifiers

class DockIconHoverMonitor {
    private var dockPreviewDelay: Double {
        UserDefaults.standard.double(forKey: "dockPreviewSpeed")
    }
    private var mouseUpdateInterval: Double {
        max(0.016, min(UserDefaults.standard.double(forKey: "dockPreviewSpeed") * 0.45, 0.100))
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

    // Sticky behavior: lock to AXUIElement (icon) until AX changes
    private var lockedHoveredIcon: AXUIElement?
    private var lockedIconFrame: CGRect?
    private var lockedBundleIdentifier: String?
    private var showPanelTimer: Timer?

    // ANIMATION: Only update anchorX when app icon changes
    private var anchorX: CGFloat?

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
        cleanupAll()
    }

    private func cleanupAll() {
        if let observer = axObserver {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        if let clickMonitor = clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
        }
        NotificationCenter.default.removeObserver(self)
        stopMouseTimer()
        showPanelTimer?.invalidate()
        showPanelTimer = nil
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
        let callback: AXObserverCallback = { _, _, _, refcon in
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
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            self?.handleMouseAndHideIfNeeded()
        }
    }

    private func startMouseTimer() {
        stopMouseTimer()
        mouseTimer = Timer.scheduledTimer(withTimeInterval: mouseUpdateInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.previewPanel?.isVisible ?? false, self.lockedHoveredIcon != nil {
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

    private func mouseIsInsidePreview() -> Bool {
        guard let panel = previewPanel, panel.isVisible else { return false }
        return panel.frame.contains(NSEvent.mouseLocation)
    }

    private func checkMouseAndDismissIfNeeded() {
        let isInPopup = mouseIsInsidePreview()
        let isOverDockIcon = isMouseOverDockIcon()
        if !isInPopup && !isOverDockIcon {
            lastHoveredDockIcon = nil
            lastHoveredBundleIdentifier = nil
            lockedHoveredIcon = nil
            lockedIconFrame = nil
            lockedBundleIdentifier = nil
            anchorX = nil
            showPanelTimer?.invalidate()
            showPanelTimer = nil
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
        let isInPopup = mouseIsInsidePreview()
        let isOverDockIcon = isMouseOverDockIcon()
        if !isInPopup && !isOverDockIcon {
            lastHoveredDockIcon = nil
            lastHoveredBundleIdentifier = nil
            lockedHoveredIcon = nil
            lockedIconFrame = nil
            lockedBundleIdentifier = nil
            anchorX = nil
            showPanelTimer?.invalidate()
            showPanelTimer = nil
            hidePreview()
        }
    }

    func handleDockSelectionChange() {
        if !showDockPopups {
            hidePreview()
            return
        }

        // If we get a deselection because the cursor moved from the Dock to our popup,
        // ignore it and keep the preview visible.
        let isInPopup = mouseIsInsidePreview()

        guard let hoveredIcon = getCurrentlySelectedDockIcon(),
              let (iconFrame, bundleIdentifier) = getDockIconInfo(element: hoveredIcon),
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first
        else {
            // Nothing selected in the Dock.
            // Only hide if we're not hovering the popup itself.
            if !isInPopup {
                lastBundleIdentifier = nil
                hidePreview()
                lastPanelFrame = nil
                lastIconFrame = nil
                lockedHoveredIcon = nil
                lockedIconFrame = nil
                lockedBundleIdentifier = nil
                anchorX = nil
                showPanelTimer?.invalidate()
                showPanelTimer = nil
            }
            return
        }

        // If the hovered app changed, hide the current preview immediately before scheduling the new one.
        // This avoids flashing/incorrect updates and ensures the popup only switches on app changes.
        let showingBundle = lockedBundleIdentifier ?? lastBundleIdentifier
        if let current = showingBundle, current != bundleIdentifier {
            hidePreview()
        }

        // Only update if hovered icon changes (pointer comparison)
        if let locked = lockedHoveredIcon, CFEqual(hoveredIcon, locked), previewPanel != nil {
            if let (liveFrame, _) = getDockIconInfo(element: hoveredIcon) {
                lockedIconFrame = liveFrame
            }
            return
        }

        showPanelTimer?.invalidate()
        showPanelTimer = nil

        lockedHoveredIcon = hoveredIcon
        lockedBundleIdentifier = bundleIdentifier
        lockedIconFrame = iconFrame

        // Reset anchorX on app change
        if anchorX == nil || bundleIdentifier != lastBundleIdentifier {
            anchorX = iconFrame.midX
            lastBundleIdentifier = bundleIdentifier
        }

        let iconFrameCopy = iconFrame
        let hoveredIconCopy = hoveredIcon
        let bundleIdentifierCopy = bundleIdentifier
        let appCopy = app

        showPanelTimer = Timer.scheduledTimer(withTimeInterval: dockPreviewDelay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if let locked = self.lockedHoveredIcon, CFEqual(hoveredIconCopy, locked) {
                if let (liveFrame, _) = self.getDockIconInfo(element: hoveredIconCopy) {
                    self.lockedIconFrame = liveFrame
                }

                let allWindowInfos = self.filteredWindowInfos(for: appCopy)
                let infoTuples = allWindowInfos.map { ($0.title, $0.isMinimized, $0.shouldHighlight) }
                if infoTuples.isEmpty {
                    self.hidePreview()
                    self.lastPanelFrame = nil
                    self.lastIconFrame = nil
                    self.lockedHoveredIcon = nil
                    self.lockedIconFrame = nil
                    self.lockedBundleIdentifier = nil
                    self.anchorX = nil
                    return
                }

                let appDisplayName = appCopy.localizedName ?? bundleIdentifierCopy
                let appIcon = appCopy.icon ?? NSWorkspace.shared.icon(for: .application)

                let panelWidth: CGFloat = 280
                let anchorCenterX = self.anchorX ?? (self.lockedIconFrame?.midX ?? iconFrameCopy.midX)
                let anchorY = (self.lockedIconFrame?.maxY ?? iconFrameCopy.maxY) + 9
                // Initial height guess (will be corrected to fit actual content immediately after render)
                let initialHeight = CGFloat(82 + max(24, infoTuples.count * 32))
                let panelRect = CGRect(
                    x: anchorCenterX - panelWidth/2,
                    y: anchorY, // bottom anchored to Dock
                    width: panelWidth,
                    height: initialHeight
                )

                self.lastIconFrame = self.lockedIconFrame
                self.lastPanelFrame = panelRect

                let updatePopupImmediately: () -> Void = { [weak self] in
                    DispatchQueue.main.asyncAfter(deadline: .now() + max(0.01, self?.mouseUpdateInterval ?? 0.04)) {
                        self?.updateDockPreviewContent()
                    }
                }

                self.showOrUpdatePreviewPanel(
                    appBundleID: bundleIdentifierCopy,
                    appDisplayName: appDisplayName,
                    appIcon: appIcon,
                    windowInfos: infoTuples,
                    panelRect: panelRect,
                    app: appCopy,
                    onActionComplete: updatePopupImmediately
                )
            }
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
            // Measure and snap to actual content height (bottom stays anchored)
            adjustPanelHeightToFit(panel: panel, hosting: hosting, anchorY: panelRect.origin.y)
        } else {
            let hosting = NSHostingView(rootView: newContent)
            let panel = NSPanel(contentRect: panelRect,
                                styleMask: [.borderless, .nonactivatingPanel],
                                backing: .buffered, defer: false)
            panel.contentView = hosting
            panel.isFloatingPanel = true
            panel.level = .statusBar
            panel.backgroundColor = .clear
            panel.hasShadow = true
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
            // Immediately correct height to the real content (prevents cutting)
            adjustPanelHeightToFit(panel: panel, hosting: hosting, anchorY: panelRect.origin.y)
            self.startMouseTimer()
        }
    }

    // Bottom anchored height adjustment that never lets the Dock occlude the panel.
    private func adjustPanelHeightToFit(panel: NSPanel, hosting: NSHostingView<DockPreviewPanel>, anchorY: CGFloat) {
        hosting.layoutSubtreeIfNeeded()
        var targetSize = hosting.fittingSize
        if targetSize.width.isZero || targetSize.height.isZero {
            // Safety defaults during first pass
            targetSize = CGSize(width: max(panel.frame.width, 280), height: max(panel.frame.height, 120))
        }

        // Cap height to the available space above the Dock
        let screen = NSScreen.main ?? NSScreen.screens.first
        let maxTop = screen?.visibleFrame.maxY ?? (panel.frame.origin.y + 900)
        let available = max(60, maxTop - anchorY - 8) // small headroom
        let targetHeight = min(targetSize.height, available)

        let newFrame = CGRect(x: panel.frame.origin.x,
                              y: anchorY,                 // keep bottom on Dock edge
                              width: panel.frame.width,
                              height: targetHeight)       // grow/shrink only the top edge

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            panel.animator().setFrame(newFrame, display: true)
        }
        panel.setContentSize(CGSize(width: newFrame.width, height: newFrame.height))
    }

    private func updateDockPreviewContent() {
        guard let lockedIcon = lockedHoveredIcon,
              let lockedFrame = lockedIconFrame,
              let bundleIdentifier = lockedBundleIdentifier,
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first,
              let panel = previewPanel,
              let hosting = hostingView else { return }

        let windowInfos = filteredWindowInfos(for: app)
        if windowInfos.isEmpty {
            hidePreview()
            lockedHoveredIcon = nil
            lockedIconFrame = nil
            lockedBundleIdentifier = nil
            anchorX = nil
            return
        }
        let appDisplayName = app.localizedName ?? bundleIdentifier
        let appIcon = app.icon ?? NSWorkspace.shared.icon(for: .application)

        let panelWidth: CGFloat = 280
        if anchorX == nil || bundleIdentifier != lastBundleIdentifier {
            anchorX = lockedFrame.midX
            lastBundleIdentifier = bundleIdentifier
        }
        let anchorCenterX = anchorX ?? lockedFrame.midX
        let anchorY = lockedFrame.maxY + 9

        // Keep bottom anchored to Dock; we’ll correct height to content next
        let guessedHeight = CGFloat(82 + max(24, windowInfos.count * 32))
        let targetRect = CGRect(
            x: anchorCenterX - panelWidth/2,
            y: anchorY,
            width: panelWidth,
            height: guessedHeight
        )

        // Update content first
        hosting.rootView = DockPreviewPanel(
            appBundleID: bundleIdentifier,
            appDisplayName: appDisplayName,
            appIcon: appIcon,
            windowInfos: windowInfos.map { ($0.title, $0.isMinimized, $0.shouldHighlight) },
            onTitleClick: { [weak self] title in
                self?.focusWindow(of: app, withTitle: title)
            },
            onActionComplete: { [weak self] in
                guard let self = self else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + max(0.01, self.mouseUpdateInterval)) {
                    self.updateDockPreviewContent()
                }
            }
        )

        // Apply rect (to move horizontally if needed), then correct height to fit content
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.16
            panel.animator().setFrame(targetRect, display: true)
        }
        adjustPanelHeightToFit(panel: panel, hosting: hosting, anchorY: anchorY)
    }

    private func checkForWindowCountChange() {
        guard let lockedIcon = lockedHoveredIcon, let bundleIdentifier = lockedBundleIdentifier,
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first
        else {
            previousWindowCount = -1
            return
        }
        let count = filteredWindowInfos(for: app).count
        if previousWindowCount == 0 && count > 0 {
            updateDockPreviewContent()
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
        var targetWindow: AXUIElement?
        for window in windows {
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

        var minimizedValue: AnyObject?
        let gotMin = AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimizedValue) == .success
        let isMinimized = gotMin ? ((minimizedValue as? Bool) ?? false) : false
        if isMinimized {
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }

        NSApp.activate(ignoringOtherApps: true)
        usleep(50_000)
        let didActivate = app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        if !didActivate {
            let bundleID = app.bundleIdentifier ?? ""
            let script = "tell application id \"\(bundleID)\" to activate"
            if let appleScript = NSAppleScript(source: script) {
                var errorDict: NSDictionary? = nil
                appleScript.executeAndReturnError(&errorDict)
            }
        }
        waitForAppToBeFrontmost(app: app, timeout: 1.5) {
            let _ = AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
            let _ = AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
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
        lockedHoveredIcon = nil
        lockedIconFrame = nil
        lockedBundleIdentifier = nil
        anchorX = nil
        showPanelTimer?.invalidate()
        showPanelTimer = nil
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
        cleanupAll()
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
