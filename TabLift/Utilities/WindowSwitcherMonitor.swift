import Cocoa
import SwiftUI
import ApplicationServices
import Combine

final class WindowSwitcherMonitor {
    private let panelWidth: CGFloat = 420
    private let rowHeight: CGFloat = 32
    private let edgePadding: CGFloat = 14
    private let cornerRadius: CGFloat = 18
    private let maxVisibleRows: Int = 12
    private let refreshInterval: TimeInterval = 0.10
    private let autoHideAfterKeyPress: TimeInterval = 1.1
    private let fadeDuration: TimeInterval = 0.10

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var canInterceptEvents = false // we will not intercept; only listen

    private var refreshTimer: Timer?
    private var autoHideTimer: Timer?

    private var panel: NSPanel?
    private var containerView: PassthroughContainerView?
    private var effectView: NSVisualEffectView?
    private var hosting: NSHostingView<WindowSwitcherPanel>?
    private var lastShownAppPID: pid_t?
    private var commandIsHeld: Bool = false

    // SwiftUI view model for stable updates (prevents marquee glitches)
    private let model = WindowSwitcherViewModel()

    // Mapping from stable window id -> AXUIElement
    private var idToWindow: [String: AXUIElement] = [:]

    init() {
        startKeyEventTap()
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(frontAppChanged),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    deinit {
        stopKeyEventTap()
        stopRefreshTimer()
        stopAutoHideTimer()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        hidePanel(animated: false)
    }


    private func startKeyEventTap() {
        // Always listen-only so the system handles Cmd+` switching.
        _ = createEventTap(options: .listenOnly)
        canInterceptEvents = false
    }

    private func createEventTap(options: CGEventTapOptions) -> Bool {
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: options,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, cgEvent, refcon in
                guard let refcon = refcon else { return Unmanaged.passUnretained(cgEvent) }
                let monitor = Unmanaged<WindowSwitcherMonitor>.fromOpaque(refcon).takeUnretainedValue()
                return monitor.handleEvent(type: type, event: cgEvent)
            },
            userInfo: UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        ) else {
            NSLog("WindowSwitcherMonitor: Failed to create key event tap with options \(options). Check permissions.")
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            return true
        }
        return false
    }

    private func stopKeyEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    // Return value: non-nil to pass event through; nil to suppress.
    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch type {
        case .keyDown:
            let keycode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags
            let isCmd = flags.contains(.maskCommand)
            if isCmd && keycode == 50 /* kVK_ANSI_Grave */ {
                // Let macOS switch windows; we only show/update the popup.
                commandIsHeld = true

                // Give the system a moment to apply the new focused window, then update UI.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
                    self?.showOrUpdateForFrontmostApp()
                    self?.restartAutoHideTimer()
                }

                // Always pass the event through so the system cycles windows.
                return Unmanaged.passUnretained(event)
            }
        case .flagsChanged:
            let flags = event.flags
            let nowCmd = flags.contains(.maskCommand)
            if commandIsHeld && !nowCmd {
                commandIsHeld = false
                DispatchQueue.main.async { [weak self] in
                    self?.hidePanel(animated: true)
                }
            } else if nowCmd {
                commandIsHeld = true
            }
        default:
            break
        }
        return Unmanaged.passUnretained(event)
    }


    @objc
    private func frontAppChanged(_ note: Notification) {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            hidePanel(animated: true)
            return
        }
        if let lastPID = lastShownAppPID, app.processIdentifier != lastPID {
            hidePanel(animated: true)
        }
    }

    private enum CycleDirection { case forward, backward }

    private func performCycle(direction: CycleDirection) {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let list = fetchWindowList(for: app)
        guard list.windows.count > 0 else { return }

        var currentIndex = list.focusedIndex ?? 0
        if direction == .forward {
            currentIndex = (currentIndex + 1) % list.windows.count
        } else {
            currentIndex = (currentIndex - 1 + list.windows.count) % list.windows.count
        }

        let target = list.windows[currentIndex]
        focus(window: target, in: app)
    }

    private func focus(window: AXUIElement, in app: NSRunningApplication) {
        // Unminimize if needed
        var minimizedValue: AnyObject?
        if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimizedValue) == .success,
           let isMin = minimizedValue as? Bool, isMin {
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }

        // Raise and focus
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)

        let appEl = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetAttributeValue(appEl, kAXFocusedWindowAttribute as CFString, window)

        // Helps bring some apps forward
        app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    }


    private func showOrUpdateForFrontmostApp() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        lastShownAppPID = app.processIdentifier

        let list = fetchWindowList(for: app)
        if list.infos.isEmpty { hidePanel(animated: true); return }

        // Update model (stable, prevents marquee reset)
        let appName = app.localizedName ?? app.bundleIdentifier ?? "App"
        let appIcon: NSImage = {
            if let icon = app.icon { return icon }
            if let url = app.bundleURL {
                return NSWorkspace.shared.icon(forFile: url.path)
            }
            return NSImage(size: NSSize(width: 64, height: 64))
        }()

        // Keep mapping for click selection
        idToWindow = list.idToWindow

        model.update(appName: appName, appIcon: appIcon, windowInfos: list.infos)

        let requiredHeight = panelHeight(for: list.infos.count)
        let panelFrame = centeredPanelFrame(width: panelWidth, height: requiredHeight)

        if let panel = panel, let container = containerView {
            panel.setFrame(panelFrame, display: false)
            if !panel.isVisible {
                showPanel(panel)
            }
            container.cornerRadius = cornerRadius // keep in sync
            effectView?.layer?.cornerRadius = cornerRadius
        } else {
            createPanel(frame: panelFrame)
            if let panel = panel {
                showPanel(panel)
            }
        }

        startRefreshTimer()
    }

    private func createPanel(frame: CGRect) {
        // Panel
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true // shadow drawn by SwiftUI if desired
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.level = .statusBar
        panel.ignoresMouseEvents = false // allow clicking rows

        // Container that only accepts clicks inside rounded rect
        let container = PassthroughContainerView(frame: NSRect(origin: .zero, size: frame.size), cornerRadius: cornerRadius)
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor

        // Visual effect background, clipped to radius
        let effect = NSVisualEffectView(frame: container.bounds)
        effect.autoresizingMask = [.width, .height]
        effect.material = .hudWindow // subtle and neutral; change to .popover or .menu if preferred
        effect.blendingMode = .withinWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = cornerRadius
        effect.layer?.masksToBounds = true

        // Hosting SwiftUI contents
        let rootView = WindowSwitcherPanel(
            model: model,
            cornerRadius: cornerRadius,
            onSelect: { [weak self] id in self?.selectWindow(by: id) }
        )

        let hosting = NSHostingView(rootView: rootView)
        hosting.frame = container.bounds
        hosting.autoresizingMask = [.width, .height]
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor

        container.addSubview(effect, positioned: .below, relativeTo: nil)
        container.addSubview(hosting)

        panel.contentView = container

        self.panel = panel
        self.containerView = container
        self.effectView = effect
        self.hosting = hosting
    }

    private func showPanel(_ panel: NSPanel) {
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = fadeDuration
            panel.animator().alphaValue = 1
        }
    }

    private func hidePanel(animated: Bool) {
        stopRefreshTimer()
        stopAutoHideTimer()
        guard let panel = panel else { return }
        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = fadeDuration
                panel.animator().alphaValue = 0
            } completionHandler: {
                panel.orderOut(nil)
            }
        } else {
            panel.orderOut(nil)
        }
    }

    private func restartAutoHideTimer() {
        stopAutoHideTimer()
        autoHideTimer = Timer.scheduledTimer(withTimeInterval: autoHideAfterKeyPress, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if !self.commandIsHeld {
                self.hidePanel(animated: true)
            }
        }
    }

    private func stopAutoHideTimer() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
    }

    private func startRefreshTimer() {
        if refreshTimer != nil { return }
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.refreshIfNeeded()
        }
    }

    private func stopRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func refreshIfNeeded() {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier == lastShownAppPID,
              panel?.isVisible == true
        else {
            hidePanel(animated: true)
            return
        }
        let list = fetchWindowList(for: app)
        if list.infos.isEmpty {
            hidePanel(animated: true)
            return
        }
        // Update model and mapping, no rootView replacement
        idToWindow = list.idToWindow
        model.update(appName: app.localizedName ?? app.bundleIdentifier ?? "App",
                     appIcon: app.icon ?? NSImage(size: NSSize(width: 64, height: 64)),
                     windowInfos: list.infos)

        let newHeight = panelHeight(for: list.infos.count)
        let newFrame = centeredPanelFrame(width: panelWidth, height: newHeight)
        panel?.setFrame(newFrame, display: false)
        containerView?.cornerRadius = cornerRadius
        effectView?.layer?.cornerRadius = cornerRadius
    }

    private func selectWindow(by id: String) {
        guard let app = NSWorkspace.shared.frontmostApplication,
              let ax = idToWindow[id] else { return }
        focus(window: ax, in: app)
        hidePanel(animated: true)
    }


    // Prefer AXWindowNumber (stable across refreshes); fallback to AXUIElement pointer.
    struct WinInfo: Identifiable, Hashable {
        let id: String // "w:<AXWindowNumber>" or "p:<pointer>"
        let title: String
        let isMinimized: Bool
        let isFocused: Bool
    }

    private struct WindowList {
        let windows: [AXUIElement]
        let infos: [WinInfo]
        let focusedIndex: Int?
        let idToWindow: [String: AXUIElement]
    }

    // Helper: Z-ordered visible window numbers (front to back) for a PID.
    private func cgOrderedWindowNumbers(forPID pid: pid_t) -> [Int] {
        guard let list = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return []
        }
        
        var nums: [Int] = []
        
        for item in list {
            guard
                let ownerPID = item[kCGWindowOwnerPID as String] as? pid_t,
                ownerPID == pid,
                let layer = item[kCGWindowLayer as String] as? Int, layer == 0,
                let num = item[kCGWindowNumber as String] as? Int
            else { continue }
            
            nums.append(num)
        }
        
        return nums
    }

    private func fetchWindowList(for app: NSRunningApplication) -> WindowList {
        let pid = app.processIdentifier
        let appEl = AXUIElementCreateApplication(pid)

        // AX windows for the app
        var windowsValue: AnyObject?
        guard AXUIElementCopyAttributeValue(appEl, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let axWindows = windowsValue as? [AXUIElement], !axWindows.isEmpty else {
            return WindowList(windows: [], infos: [], focusedIndex: nil, idToWindow: [:])
        }

        // Focused window (AX)
        var focusedValue: AnyObject?
        var focusedWin: AXUIElement?
        if AXUIElementCopyAttributeValue(appEl, kAXFocusedWindowAttribute as CFString, &focusedValue) == .success,
           let fw = focusedValue {
            focusedWin = (fw as! AXUIElement)
        }
        let focusedNum = focusedWin?.tlAXWindowNumber()

        // Build AX maps and filter to actual top-level windows
        var axByNumber: [Int: AXUIElement] = [:]
        var restAX: [AXUIElement] = []

        func isEligible(_ w: AXUIElement) -> Bool {
            let role = w.tlAXRole() ?? ""
            if role != "AXWindow" { return false }
            if isProbablyPictureInPicture(window: w) { return false }
            return true
        }

        for w in axWindows {
            guard isEligible(w) else { continue }
            if let num = w.tlAXWindowNumber() {
                axByNumber[num] = w
            } else {
                restAX.append(w) // no window number; append later
            }
        }

        // Z-ordered CG window numbers for this PID (visible, layer 0)
        let orderedNums = cgOrderedWindowNumbers(forPID: pid)

        // Build final ordered AX windows: first those visible on screen by CG order,
        // then append remaining AX windows (minimized/off-screen/unnumbered).
        var orderedAX: [AXUIElement] = []
        var seen = Set<String>() // track by stable ID string

        func stableID(for w: AXUIElement) -> String {
            if let num = w.tlAXWindowNumber() { return "w:\(num)" }
            return "p:\(Unmanaged.passUnretained(w).toOpaque())"
        }

        for num in orderedNums {
            if let w = axByNumber[num] {
                let sid = stableID(for: w)
                if !seen.contains(sid) {
                    orderedAX.append(w)
                    seen.insert(sid)
                }
            }
        }

        // Append remaining AX windows that weren't visible (e.g., minimized/off-screen)
        for w in axWindows {
            guard isEligible(w) else { continue }
            let sid = stableID(for: w)
            if !seen.contains(sid) {
                orderedAX.append(w)
                seen.insert(sid)
            }
        }
        // Finally append those without window number (if any left)
        for w in restAX {
            let sid = stableID(for: w)
            if !seen.contains(sid) {
                orderedAX.append(w)
                seen.insert(sid)
            }
        }
        orderedAX.reverse()
        if let fw = focusedWin {
            if let index = orderedAX.firstIndex(where: { CFEqual($0, fw) }) {
                let focusedElement = orderedAX.remove(at: index)
                orderedAX.insert(focusedElement, at: 0)
            }
        }
        if orderedAX.isEmpty {
            return WindowList(windows: [], infos: [], focusedIndex: nil, idToWindow: [:])
        }

        // Build infos and locate focused index
        var infos: [WinInfo] = []
        var idToWindow: [String: AXUIElement] = [:]
        var focusedIndex: Int?

        for (idx, w) in orderedAX.enumerated() {
            // Title
            var titleRaw: AnyObject?
            var title = ""
            if AXUIElementCopyAttributeValue(w, kAXTitleAttribute as CFString, &titleRaw) == .success {
                title = (titleRaw as? String) ?? ""
            }
            if title.isEmpty {
                var docRaw: AnyObject?
                if AXUIElementCopyAttributeValue(w, kAXDocumentAttribute as CFString, &docRaw) == .success,
                   let docPath = docRaw as? String, !docPath.isEmpty {
                    title = (docPath as NSString).lastPathComponent
                }
            }
            if title.isEmpty { title = "(Untitled)" }

            // Minimized
            var minimizedRaw: AnyObject?
            let minimized = AXUIElementCopyAttributeValue(w, kAXMinimizedAttribute as CFString, &minimizedRaw) == .success
                ? ((minimizedRaw as? Bool) ?? false) : false

            // Stable ID and focus
            let id: String
            if let num = w.tlAXWindowNumber() {
                id = "w:\(num)"
            } else {
                id = "p:\(Unmanaged.passUnretained(w).toOpaque())"
            }

            var isFocused = false
            if let fnum = focusedNum, let num = w.tlAXWindowNumber() {
                isFocused = (fnum == num)
            } else if let fw = focusedWin {
                isFocused = CFEqual(w, fw)
            }
            if isFocused { focusedIndex = idx }

            infos.append(WinInfo(id: id, title: title, isMinimized: minimized, isFocused: isFocused))
            idToWindow[id] = w
        }

        return WindowList(windows: orderedAX, infos: infos, focusedIndex: focusedIndex, idToWindow: idToWindow)
    }

    // Heuristic: filter out tiny Picture-in-Picture / overlay windows or non-standard dialogs.
    private func isProbablyPictureInPicture(window: AXUIElement) -> Bool {
        if let subrole = window.tlAXSubrole(), subrole == "AXSystemDialog" || subrole == "AXPictureInPictureWindow" {
            return true
        }
        if let title = window.tlAXTitle(), title.lowercased().contains("picture in picture") {
            return true
        }
        // Filter by very small size
        var sizeRaw: AnyObject?
        if AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRaw) == .success,
           let anyObj = sizeRaw, CFGetTypeID(anyObj) == AXValueGetTypeID() {
            let axValue = anyObj as! AXValue
            var sz = CGSize.zero
            if AXValueGetValue(axValue, .cgSize, &sz) {
                if sz.width <= 180 || sz.height <= 120 {
                    return true
                }
            }
        }
        return false
    }


    private func panelHeight(for count: Int) -> CGFloat {
        let rows = min(count, maxVisibleRows)
        let contentHeight = CGFloat(rows) * rowHeight
        // Header height ~ 56 + paddings
        let headerHeight: CGFloat = 56 + 8
        return contentHeight + edgePadding * 2 + headerHeight
    }

    private func centeredPanelFrame(width: CGFloat, height: CGFloat) -> CGRect {
        let screen = NSScreen.main?.visibleFrame ?? NSScreen.screens.first?.visibleFrame ?? CGRect(x: 0, y: 0, width: 800, height: 600)
        return CGRect(
            x: screen.midX - width / 2,
            y: screen.midY - height / 2,
            width: width,
            height: height
        )
    }
}


final class WindowSwitcherViewModel: ObservableObject {
    @Published var appName: String = ""
    @Published var appIcon: NSImage = NSImage(size: NSSize(width: 64, height: 64))
    @Published var windowInfos: [WindowSwitcherMonitor.WinInfo] = []

    func update(appName: String, appIcon: NSImage, windowInfos: [WindowSwitcherMonitor.WinInfo]) {
        // Assign directly; SwiftUI diffing is fine and avoids image equality issues.
        self.appName = appName
        self.appIcon = appIcon
        self.windowInfos = windowInfos
    }
}


private struct WindowSwitcherPanel: View {
    @ObservedObject var model: WindowSwitcherViewModel
    let cornerRadius: CGFloat
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 10) {
            // Header with app icon + name
            HStack(spacing: 10) {
                Image(nsImage: model.appIcon)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                Text(model.appName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            // List of windows
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(model.windowInfos, id: \.id) { info in
                        RowView(info: info) {
                            onSelect(info.id)
                        }
                        .frame(height: 32)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.bottom, 10)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .frame(width: 420)
        .transition(.opacity)
    }

    private struct RowView: View {
        let info: WindowSwitcherMonitor.WinInfo
        var onTap: () -> Void
        @State private var isHovering = false

        var body: some View {
            Button(action: { onTap() }) {
                HStack(spacing: 10) {
                    // Minimization dot
                    Circle()
                        .fill(info.isMinimized ? Color.primary.opacity(0.35) : Color.clear)
                        .frame(width: 6, height: 6)
                        .opacity(info.isMinimized ? 1 : 0)

                    FlexibleMarqueeText(text: info.title)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.primary)
                        .padding(.vertical, 6)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .background(
                    Group {
                        if info.isFocused {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.accentColor.opacity(0.26))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(Color.accentColor.opacity(0.40), lineWidth: 0.6)
                                )
                                .blendMode(.normal)
                        } else if isHovering {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.primary.opacity(0.06))
                                .blendMode(.normal)
                        } else {
                            Color.clear
                        }
                    }
                )
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .onHover { hov in
                isHovering = hov
            }
        }
    }
}


private struct FlexibleMarqueeText: View {
    let text: String

    var body: some View {
        GeometryReader { proxy in
            let w = max(0, proxy.size.width)
            MarqueeText(text: text, maxWidth: w)
                .frame(width: w, alignment: .leading)
                .clipped() // ensure the marquee does not draw outside its lane
                .allowsHitTesting(false)
        }
        .frame(height: 18) // approx text height to keep row bounds tight
    }
}


private final class PassthroughContainerView: NSView {
    var cornerRadius: CGFloat {
        didSet { needsDisplay = true }
    }

    init(frame frameRect: NSRect, cornerRadius: CGFloat) {
        self.cornerRadius = cornerRadius
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = false // we clip subviews individually where needed
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        self.cornerRadius = 16
        super.init(coder: coder)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let roundedPath = NSBezierPath(roundedRect: bounds, xRadius: cornerRadius, yRadius: cornerRadius)
        if roundedPath.contains(point) {
            return super.hitTest(point)
        } else {
            // Allow clicks outside rounded shape to pass to underlying windows
            return nil
        }
    }
}


private extension AXUIElement {
    func tlAXRole() -> String? {
        var v: AnyObject?
        guard AXUIElementCopyAttributeValue(self, kAXRoleAttribute as CFString, &v) == .success else { return nil }
        return v as? String
    }

    func tlAXSubrole() -> String? {
        var v: AnyObject?
        guard AXUIElementCopyAttributeValue(self, kAXSubroleAttribute as CFString, &v) == .success else { return nil }
        return v as? String
    }

    func tlAXTitle() -> String? {
        var v: AnyObject?
        guard AXUIElementCopyAttributeValue(self, kAXTitleAttribute as CFString, &v) == .success else { return nil }
        return v as? String
    }

    func tlAXWindowNumber() -> Int? {
        var v: AnyObject?
        guard AXUIElementCopyAttributeValue(self, "AXWindowNumber" as CFString, &v) == .success else { return nil }
        return v as? Int
    }

    func tlAXBoolAttribute(_ attr: CFString) -> Bool? {
        var v: AnyObject?
        guard AXUIElementCopyAttributeValue(self, attr, &v) == .success else { return nil }
        return v as? Bool
    }
}
