import Cocoa
import SwiftUI
import ApplicationServices
import UniformTypeIdentifiers

class DockIconHoverMonitor {

    // Use an Equatable snapshot type so we can compare arrays safely (fast diff to avoid unnecessary re-renders)
    private struct WindowSnapshot: Equatable {
        let title: String
        let isMinimized: Bool
        let shouldHighlight: Bool
    }

    private var dockPreviewDelay: Double {
        UserDefaults.standard.double(forKey: "dockPreviewSpeed")
    }

    // Run the update loop at ~60 Hz for snappy movement
    private var mouseUpdateInterval: Double { 0.016 }

    private var axObserver: AXObserver?
    private var dockPID: pid_t = 0
    private var previewPanel: NSPanel?
    private var hostingView: NSHostingView<DockPreviewPanel>?
    private var lastBundleIdentifier: String?
    private var lastPanelFrame: CGRect?
    private var clickMonitor: Any?
    private var localClickMonitorDown: Any?
    private var localClickMonitorUp: Any?
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

    // Anchor used to place the panel; updated on app change
    private var anchorX: CGFloat?

    // Interaction guard: avoid swapping content while the user is pressing a button
    private var isInteractingInsidePanel = false

    // Snapshot of what is currently rendered to avoid unnecessary re-renders
    private var lastRenderedSnapshot: [WindowSnapshot] = []

    private var dockClickMonitor: DockClickMonitor? {
        (NSApplication.shared.delegate as? AppDelegate)?.dockClickMonitor
    }

    private var showDockPopups: Bool {
        UserDefaults.standard.bool(forKey: "showDockPopups")
    }

    // Behavior flags for faster lateral movement (like DockDoor)
    private var lateralMovementEnabled: Bool {
        UserDefaults.standard.bool(forKey: "lateralMovement")
    }
    private let artifactTimeThreshold: TimeInterval = 0.05
    private var lastNotificationTime: TimeInterval = 0
    private var lastNotificationId: String = ""

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
        if let m = localClickMonitorDown {
            NSEvent.removeMonitor(m)
        }
        if let m = localClickMonitorUp {
            NSEvent.removeMonitor(m)
        }
        localClickMonitorDown = nil
        localClickMonitorUp = nil
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

        // Ignore Dock deselection caused by moving from Dock to our popup.
        let isInPopup = mouseIsInsidePreview()

        guard let hoveredIcon = getCurrentlySelectedDockIcon(),
              let (iconFrame, bundleIdentifier) = getDockIconInfo(element: hoveredIcon),
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first
        else {
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

        // Suppress duplicate/rapid notifications for the same app (prevents thrash)
        let now = ProcessInfo.processInfo.systemUptime
        if lastNotificationId == bundleIdentifier, (now - lastNotificationTime) < artifactTimeThreshold {
            return
        }
        lastNotificationId = bundleIdentifier
        lastNotificationTime = now

        // If app changed, hide the old preview first to prevent stale interactions
        let showingBundle = lockedBundleIdentifier ?? lastBundleIdentifier
        if let current = showingBundle, current != bundleIdentifier {
            hidePreview()
        }

        // Only update lock if hovered icon actually changed
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

        // If we already have a preview shown or lateral movement is enabled, bypass delay
        let shouldBypassDelay = (previewPanel != nil) || lateralMovementEnabled
        let delay = shouldBypassDelay ? 0.0 : dockPreviewDelay
        let capturedMouse = NSEvent.mouseLocation

        showPanelTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self else { return }

            // If mouse moved far from where we scheduled, drop this show (stale)
            if capturedMouse.distance(to: NSEvent.mouseLocation) > 100 { return }

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
                let initialHeight = CGFloat(82 + max(24, infoTuples.count * 32))
                let panelRect = CGRect(
                    x: anchorCenterX - panelWidth/2,
                    y: anchorY,
                    width: panelWidth,
                    height: initialHeight
                )

                self.lastIconFrame = self.lockedIconFrame
                self.lastPanelFrame = panelRect

                let updateNow: () -> Void = { [weak self] in
                    self?.updateDockPreviewContent()
                }

                self.showOrUpdatePreviewPanel(
                    appBundleID: bundleIdentifierCopy,
                    appDisplayName: appDisplayName,
                    appIcon: appIcon,
                    windowInfos: infoTuples,
                    panelRect: panelRect,
                    app: appCopy,
                    onActionComplete: updateNow
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
                self?.focusWindowPreferMinimized(of: app, withTitle: title)
            },
            onActionComplete: { [weak self] in
                guard let self = self else { return }
                // Refresh immediately after an action (e.g., minimize/restore) and one extra pass for async state
                self.updateDockPreviewContent()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.updateDockPreviewContent()
                }
                onActionComplete()
            }
        )

        if let panel = self.previewPanel, let hosting = self.hostingView {
            // Only re-render SwiftUI content if data actually changed OR if we have no snapshot
            let incomingSnapshot: [WindowSnapshot] = windowInfos.map {
                WindowSnapshot(title: $0.title, isMinimized: $0.isMinimized, shouldHighlight: $0.shouldHighlight)
            }
            if lastRenderedSnapshot != incomingSnapshot {
                if !isInteractingInsidePanel {
                    hosting.rootView = newContent
                    lastRenderedSnapshot = incomingSnapshot
                }
            }
            // Snap to actual content height (no animation), and reposition immediately
            adjustPanelHeightToFit(panel: panel, hosting: hosting, anchorY: panelRect.origin.y)
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
            panel.hasShadow = true
            panel.ignoresMouseEvents = false // Capture clicks; background clicks won't pass through
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
            lastRenderedSnapshot = windowInfos.map {
                WindowSnapshot(title: $0.title, isMinimized: $0.isMinimized, shouldHighlight: $0.shouldHighlight)
            }
            // Correct height to the real content (no animation)
            adjustPanelHeightToFit(panel: panel, hosting: hosting, anchorY: panelRect.origin.y)
            self.installLocalInteractionMonitors()
            self.startMouseTimer()
        }
    }

    // No animation: bottom anchored height adjustment that never lets the Dock occlude the panel.
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

        panel.setFrame(newFrame, display: true)
        panel.setContentSize(CGSize(width: newFrame.width, height: newFrame.height))
    }

    private func updateDockPreviewContent() {
        guard let lockedFrame = lockedIconFrame,
              let bundleIdentifier = lockedBundleIdentifier,
              let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first,
              let panel = previewPanel,
              let hosting = hostingView else { return }

        let windowInfosFull = filteredWindowInfos(for: app)
        if windowInfosFull.isEmpty {
            hidePreview()
            lockedHoveredIcon = nil
            lockedIconFrame = nil
            lockedBundleIdentifier = nil
            anchorX = nil
            lastRenderedSnapshot = []
            return
        }

        // Make an Equatable snapshot for change detection
        let snapshot: [WindowSnapshot] = windowInfosFull.map {
            WindowSnapshot(title: $0.title, isMinimized: $0.isMinimized, shouldHighlight: $0.shouldHighlight)
        }

        // Update position immediately
        let panelWidth: CGFloat = 280
        if anchorX == nil || bundleIdentifier != lastBundleIdentifier {
            anchorX = lockedFrame.midX
            lastBundleIdentifier = bundleIdentifier
        }
        let anchorCenterX = anchorX ?? lockedFrame.midX
        let anchorY = lockedFrame.maxY + 9
        let guessedHeight = CGFloat(82 + max(24, snapshot.count * 32))
        let targetRect = CGRect(
            x: anchorCenterX - panelWidth/2,
            y: anchorY,
            width: panelWidth,
            height: guessedHeight
        )
        panel.setFrame(targetRect, display: true)

        // Only replace SwiftUI content if it actually changed and we are not in the middle of a click
        if !isInteractingInsidePanel && snapshot != lastRenderedSnapshot {
            let appDisplayName = app.localizedName ?? bundleIdentifier
            let appIcon = app.icon ?? NSWorkspace.shared.icon(for: .application)
            hosting.rootView = DockPreviewPanel(
                appBundleID: bundleIdentifier,
                appDisplayName: appDisplayName,
                appIcon: appIcon,
                windowInfos: snapshot.map { ($0.title, $0.isMinimized, $0.shouldHighlight) },
                onTitleClick: { [weak self] title in
                    self?.focusWindowPreferMinimized(of: app, withTitle: title)
                },
                onActionComplete: { [weak self] in
                    guard let self = self else { return }
                    self.updateDockPreviewContent()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        self.updateDockPreviewContent()
                    }
                }
            )
            lastRenderedSnapshot = snapshot
        }

        // Always correct height to the new content size (no animation)
        adjustPanelHeightToFit(panel: panel, hosting: hosting, anchorY: anchorY)
    }

    private func checkForWindowCountChange() {
        guard let bundleIdentifier = lockedBundleIdentifier,
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

    // Prefer a minimized window when multiple windows share a title, so each click restores one instance
    private func focusWindowPreferMinimized(of app: NSRunningApplication?, withTitle title: String) {
        guard let app = app else { return }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        var windowsValue: AnyObject?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let windows = windowsValue as? [AXUIElement] else { return }

        var candidates: [(element: AXUIElement, isMin: Bool)] = []
        for w in windows {
            guard w.role() == "AXWindow" else { continue }
            var t: AnyObject?
            if AXUIElementCopyAttributeValue(w, kAXTitleAttribute as CFString, &t) != .success { continue }
            let wt = (t as? String) ?? ""
            if wt != title { continue }
            var minRaw: AnyObject?
            let isMin = AXUIElementCopyAttributeValue(w, kAXMinimizedAttribute as CFString, &minRaw) == .success && (minRaw as? Bool ?? false)
            candidates.append((w, isMin))
        }

        // Pick a minimized one first; otherwise fallback to first matching
        let target = candidates.first(where: { $0.isMin })?.element ?? candidates.first?.element
        guard let window = target else { return }

        // If minimized, restore it; otherwise just focus it
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
            // Refresh quickly to reflect the new state
            self.updateDockPreviewContent()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.updateDockPreviewContent()
            }
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
        lastRenderedSnapshot = []
        showPanelTimer?.invalidate()
        showPanelTimer = nil

        if let m = localClickMonitorDown { NSEvent.removeMonitor(m) }
        if let m = localClickMonitorUp { NSEvent.removeMonitor(m) }
        localClickMonitorDown = nil
        localClickMonitorUp = nil
        isInteractingInsidePanel = false
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

    // Install a local event monitor so clicks inside the panel don't get disrupted by live updates.
    // We don't swallow events; we only mark interaction spans to pause content replacement.
    private func installLocalInteractionMonitors() {
        // Clean old ones (if any)
        if let m = localClickMonitorDown { NSEvent.removeMonitor(m) }
        if let m = localClickMonitorUp { NSEvent.removeMonitor(m) }
        localClickMonitorDown = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            guard let self = self, let panel = self.previewPanel else { return event }
            if event.window === panel {
                self.isInteractingInsidePanel = true
            }
            return event
        }
        localClickMonitorUp = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp, .rightMouseUp, .otherMouseUp]) { [weak self] event in
            guard let self = self, let panel = self.previewPanel else { return event }
            if event.window === panel {
                // Let SwiftUI finish handling, then resume live updates
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                    self.isInteractingInsidePanel = false
                    self.updateDockPreviewContent()
                }
            }
            return event
        }
    }
}

// MARK: - Utilities

private extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        let dx = x - other.x
        let dy = y - other.y
        return sqrt(dx * dx + dy * dy)
    }
}
