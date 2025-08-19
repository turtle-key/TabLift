import Cocoa
import SwiftUI
import ApplicationServices
import Combine

final class WindowSwitcherMonitor {
    private let panelWidth: CGFloat = 420
    private let rowHeight: CGFloat = 32
    private let edgePadding: CGFloat = 14
    private let cornerRadius: CGFloat = 18
    private let maxVisibleRows: Int = 8
    private let refreshInterval: TimeInterval = 0.10

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private var refreshTimer: Timer?
    private var panel: NSPanel?
    private var containerView: PassthroughContainerView?
    private var effectView: NSVisualEffectView?
    private var hosting: NSHostingView<WindowSwitcherPanel>?
    private var lastShownAppPID: pid_t?
    private let model = WindowSwitcherViewModel()

    @AppStorage("windowSwitcher") private var showWindowSwitcher: Bool = true
    @AppStorage("shortcutKeyCode") private var keyCodeRaw: Int = 50
    @AppStorage("shortcutModifiers") private var modifiersRaw: Int = Int(NSEvent.ModifierFlags.command.rawValue)

    private var shortcutModifiers: CGEventFlags { CGEventFlags(rawValue: UInt64(modifiersRaw)) }
    private var shortcutKeyCode: UInt16 { UInt16(keyCodeRaw) }

    private let deviceIndependentFlags: CGEventFlags = [
        .maskShift, .maskControl, .maskAlternate, .maskCommand, .maskHelp, .maskSecondaryFn
    ]
    private var modifierIsHeld = false
    private var triggerIsHeld = false
    private var switcherActive = false
    private var cyclingWindowList: [AXUIElement] = []
    private var currentCycleIndex = 0
    private var idToWindow: [String: AXUIElement] = [:]
    private var tabliftHasGrab: Bool = false
    private var mouseClickedDuringSwitch = false
    private var mouseMonitor: Any?
    private var panelHiding = false

    init() {
        startKeyEventTap()
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(frontAppChanged),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            guard let self = self, self.switcherActive else { return }
            self.mouseClickedDuringSwitch = true
            self.hidePanelIfNeeded()
            self.cleanupSwitcherState()
        }
    }

    deinit {
        stopKeyEventTap()
        stopRefreshTimer()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        hidePanel()
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func startKeyEventTap() {
        _ = createEventTap(options: .defaultTap)
    }

    private func createEventTap(options: CGEventTapOptions) -> Bool {
        let mask = (1 << CGEventType.keyDown.rawValue) |
                   (1 << CGEventType.flagsChanged.rawValue) |
                   (1 << CGEventType.keyUp.rawValue)
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

    private func shouldBlockEvent(_ event: CGEvent) -> Bool {
        if tabliftHasGrab {
            let type = event.type
            if type == .flagsChanged { return false }
            let keycode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let allowedKeycodes: Set<UInt16> = [shortcutKeyCode, 18, 19, 20, 21, 23, 22, 26, 28, 25, 29]
            if allowedKeycodes.contains(keycode) { return false }
            return true
        }
        return false
    }

    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if !showWindowSwitcher { return Unmanaged.passUnretained(event) }
        let keycode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags.intersection(deviceIndependentFlags)
        let modifiersNowActive = flags.containsAllFlags(shortcutModifiers)
        let shiftPressed = flags.contains(.maskShift)

        let numberKeyToIndex: [UInt16: Int] = [
            18: 0, 19: 1, 20: 2, 21: 3, 23: 4, 22: 5, 26: 6, 28: 7, 25: 8, 29: 8
        ]

        if shouldBlockEvent(event) {
            return nil
        }

        switch type {
        case .flagsChanged:
            if modifiersNowActive && !modifierIsHeld {
                modifierIsHeld = true
            } else if !modifiersNowActive && modifierIsHeld {
                modifierIsHeld = false
                triggerIsHeld = false
                if switcherActive {
                    if !mouseClickedDuringSwitch, cyclingWindowList.indices.contains(currentCycleIndex), let app = NSWorkspace.shared.frontmostApplication {
                        focus(window: cyclingWindowList[currentCycleIndex], in: app)
                    }
                    hidePanelIfNeeded()
                    cleanupSwitcherState()
                }
            }
        case .keyDown:
            if modifierIsHeld && keycode == shortcutKeyCode && !triggerIsHeld {
                triggerIsHeld = true
                tabliftHasGrab = true
                if !switcherActive {
                    guard let app = NSWorkspace.shared.frontmostApplication else { break }
                    let winList = fetchWindowList(for: app).windows
                    cyclingWindowList = winList
                    currentCycleIndex = winList.count > 1 ? 1 : 0
                    if !winList.isEmpty { showOrUpdateForFrontmostApp() }
                    switcherActive = true
                    panelHiding = false
                    mouseClickedDuringSwitch = false
                } else {
                    let count = cyclingWindowList.count
                    if count > 0 {
                        currentCycleIndex = shiftPressed
                            ? (currentCycleIndex - 1 + count) % count
                            : (currentCycleIndex + 1) % count
                        showOrUpdateForFrontmostApp()
                    }
                }
                return nil
            }
            if switcherActive {
                if let index = numberKeyToIndex[keycode], cyclingWindowList.indices.contains(index) {
                    if let app = NSWorkspace.shared.frontmostApplication {
                        focus(window: cyclingWindowList[index], in: app)
                    }
                    hidePanelIfNeeded()
                    cleanupSwitcherState()
                    return nil
                }
            }
        case .keyUp:
            if keycode == shortcutKeyCode && triggerIsHeld {
                triggerIsHeld = false
            }
        default:
            break
        }
        return Unmanaged.passUnretained(event)
    }

    @objc
    private func frontAppChanged(_ note: Notification) {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            hidePanelIfNeeded()
            cleanupSwitcherState()
            return
        }
        if let lastPID = lastShownAppPID, app.processIdentifier != lastPID {
            hidePanelIfNeeded()
            cleanupSwitcherState()
        }
    }

    private func cleanupSwitcherState() {
        switcherActive = false
        cyclingWindowList = []
        tabliftHasGrab = false
        panelHiding = false
        mouseClickedDuringSwitch = false
        modifierIsHeld = false
        triggerIsHeld = false
    }

    private func hidePanelIfNeeded() {
        if panelHiding { return }
        panelHiding = true
        hidePanel()
    }

    private func focus(window: AXUIElement, in app: NSRunningApplication) {
        var minimizedValue: AnyObject?
        if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimizedValue) == .success,
           let isMin = minimizedValue as? Bool, isMin {
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        let appEl = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetAttributeValue(appEl, kAXFocusedWindowAttribute as CFString, window)
        app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    }

    private func showOrUpdateForFrontmostApp() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        lastShownAppPID = app.processIdentifier

        let list = fetchWindowList(for: app)
        if list.infos.isEmpty { hidePanelIfNeeded(); return }

        idToWindow = list.idToWindow

        model.update(appName: app.localizedName ?? app.bundleIdentifier ?? "App",
                     appIcon: app.icon ?? NSImage(size: NSSize(width: 64, height: 64)),
                     windowInfos: list.infos.enumerated().map { idx, info in
                        var info = info
                        info.isFocused = (idx == currentCycleIndex)
                        info.displayNumber = idx + 1
                        return info
                     })

        let requiredHeight = panelHeight(for: list.infos.count)
        let panelFrame = centeredPanelFrame(width: panelWidth, height: requiredHeight)

        if let panel = panel, let container = containerView {
            panel.setFrame(panelFrame, display: false)
            if !panel.isVisible {
                showPanel(panel)
            }
            container.cornerRadius = cornerRadius
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
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.level = .statusBar
        panel.ignoresMouseEvents = false

        let container = PassthroughContainerView(frame: NSRect(origin: .zero, size: frame.size), cornerRadius: cornerRadius)
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor

        let effect = NSVisualEffectView(frame: container.bounds)
        effect.autoresizingMask = [.width, .height]
        effect.material = .hudWindow
        effect.blendingMode = .withinWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = cornerRadius
        effect.layer?.masksToBounds = true

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
        panel.alphaValue = 1 // show instantly, for speed
        panel.orderFrontRegardless()
    }

    private func hidePanel() {
        stopRefreshTimer()
        guard let panel = panel else { return }
        panel.alphaValue = 0
        panel.orderOut(nil)
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
            hidePanelIfNeeded()
            return
        }
        let list = fetchWindowList(for: app)
        if list.infos.isEmpty {
            hidePanelIfNeeded()
            return
        }
        idToWindow = list.idToWindow
        model.update(appName: app.localizedName ?? app.bundleIdentifier ?? "App",
                     appIcon: app.icon ?? NSImage(size: NSSize(width: 64, height: 64)),
                     windowInfos: list.infos.enumerated().map { idx, info in
                        var info = info
                        info.isFocused = (idx == currentCycleIndex)
                        info.displayNumber = idx + 1
                        return info
                     })

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
        hidePanelIfNeeded()
        cleanupSwitcherState()
    }

    struct WinInfo: Identifiable, Hashable {
        let id: String
        let title: String
        let isMinimized: Bool
        var isFocused: Bool
        var displayNumber: Int = 0 // 1-based, for UI
    }

    private struct WindowList {
        let windows: [AXUIElement]
        let infos: [WinInfo]
        let focusedIndex: Int?
        let idToWindow: [String: AXUIElement]
    }

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

        var windowsValue: AnyObject?
        guard AXUIElementCopyAttributeValue(appEl, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let axWindows = windowsValue as? [AXUIElement], !axWindows.isEmpty else {
            return WindowList(windows: [], infos: [], focusedIndex: nil, idToWindow: [:])
        }

        var focusedValue: AnyObject?
        var focusedWin: AXUIElement?
        if AXUIElementCopyAttributeValue(appEl, kAXFocusedWindowAttribute as CFString, &focusedValue) == .success,
           let fw = focusedValue {
            focusedWin = (fw as! AXUIElement)
        }
        let focusedNum = focusedWin?.tlAXWindowNumber()

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
                restAX.append(w)
            }
        }

        let orderedNums = cgOrderedWindowNumbers(forPID: pid)

        var orderedAX: [AXUIElement] = []
        var seen = Set<String>()

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
        for w in axWindows {
            guard isEligible(w) else { continue }
            let sid = stableID(for: w)
            if !seen.contains(sid) {
                orderedAX.append(w)
                seen.insert(sid)
            }
        }
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

        var infos: [WinInfo] = []
        var idToWindow: [String: AXUIElement] = [:]
        var focusedIndex: Int?

        for (idx, w) in orderedAX.enumerated() {
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

            var minimizedRaw: AnyObject?
            let minimized = AXUIElementCopyAttributeValue(w, kAXMinimizedAttribute as CFString, &minimizedRaw) == .success
                ? ((minimizedRaw as? Bool) ?? false) : false

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

            infos.append(WinInfo(id: id, title: title, isMinimized: minimized, isFocused: isFocused, displayNumber: idx + 1))
            idToWindow[id] = w
        }

        return WindowList(windows: orderedAX, infos: infos, focusedIndex: focusedIndex, idToWindow: idToWindow)
    }

    private func isProbablyPictureInPicture(window: AXUIElement) -> Bool {
        if let subrole = window.tlAXSubrole(), subrole == "AXSystemDialog" || subrole == "AXPictureInPictureWindow" {
            return true
        }
        if let title = window.tlAXTitle(), title.lowercased().contains("picture in picture") {
            return true
        }
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

private extension CGEventFlags {
    func containsAllFlags(_ other: CGEventFlags) -> Bool {
        rawValue & other.rawValue == other.rawValue
    }
}

final class WindowSwitcherViewModel: ObservableObject {
    @Published var appName: String = ""
    @Published var appIcon: NSImage = NSImage(size: NSSize(width: 64, height: 64))
    @Published var windowInfos: [WindowSwitcherMonitor.WinInfo] = []

    func update(appName: String, appIcon: NSImage, windowInfos: [WindowSwitcherMonitor.WinInfo]) {
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

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(model.windowInfos, id: \.id) { info in
                            RowView(info: info) {
                                onSelect(info.id)
                            }
                            .frame(height: 32)
                            .id(info.id)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
                .frame(maxWidth: .infinity)
                .onAppear {
                    scrollToFocused(proxy: proxy)
                }
                .onChange(of: focusedId) { _ in
                    scrollToFocused(proxy: proxy)
                }
            }
        }
        .padding(.bottom, 10)
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .frame(width: 420)
        .transition(.opacity)
    }

    private var focusedId: String? {
        model.windowInfos.first(where: { $0.isFocused })?.id
    }

    private func scrollToFocused(proxy: ScrollViewProxy) {
        guard let id = focusedId else { return }
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.07)) {
                proxy.scrollTo(id, anchor: .center)
            }
        }
    }

    private struct RowView: View {
        let info: WindowSwitcherMonitor.WinInfo
        var onTap: () -> Void
        @State private var isHovering = false

        var body: some View {
            Button(action: { onTap() }) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(info.isMinimized ? Color.primary.opacity(0.35) : Color.clear)
                        .frame(width: 6, height: 6)
                        .opacity(info.isMinimized ? 1 : 0)
                    FlexibleMarqueeText(text: info.title)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.primary)
                        .padding(.vertical, 6)
                    Spacer(minLength: 0)
                    if info.displayNumber > 0 && info.displayNumber <= 9 {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.accentColor.opacity(info.isFocused ? 0.58 : 0.16))
                                .frame(width: 24, height: 24)
                            Text("\(info.displayNumber)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(info.isFocused ? Color.white : Color.accentColor)
                        }
                        .padding(.trailing, 4)
                    }
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
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(
                            info.isFocused ? Color.white.opacity(0) :
                                (isHovering ? Color.accentColor.opacity(0.50) : Color(nsColor: .separatorColor).opacity(0.65)),
                            lineWidth: 2.5 / max(NSScreen.main?.backingScaleFactor ?? 2.0, 1.0)
                        )
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
        GeometryReader { _ in
            Text(text)
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .lineLimit(1)
        }
        .frame(height: 18)
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
        layer?.masksToBounds = false
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
