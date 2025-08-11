import SwiftUI
import Cocoa
import ApplicationServices

fileprivate let kAXCloseAction = "AXClose" as CFString

enum MaximizeBehavior: String, CaseIterable, Identifiable {
    case fill = "Fill"
    case fullscreen = "Fullscreen"
    var id: String { rawValue }

    var explanation: String {
        switch self {
        case .fill:
            return "Fill: Expands the window to fill the visible screen area (menu bar and Dock remain visible)."
        case .fullscreen:
            return "Fullscreen: Enters macOS native fullscreen (window becomes its own Space and menu bar/Dock are hidden)."
        }
    }

    static var current: MaximizeBehavior {
        let raw = UserDefaults.standard.string(forKey: "maximizeBehavior") ?? MaximizeBehavior.fill.rawValue
        return MaximizeBehavior(rawValue: raw) ?? .fill
    }
}


fileprivate func axPress(_ element: AXUIElement) {
    AXUIElementPerformAction(element, kAXPressAction as CFString)
}

fileprivate func axRaise(_ window: AXUIElement) {
    AXUIElementPerformAction(window, "AXRaise" as CFString)
}

fileprivate func axMinimizeButton(for window: AXUIElement) -> AXUIElement? {
    var obj: AnyObject?
    guard AXUIElementCopyAttributeValue(window, kAXMinimizeButtonAttribute as CFString, &obj) == .success else {
        return nil
    }
    return (obj as! AXUIElement)
}

fileprivate func robustMinimize(window: AXUIElement) {
    var minimized: AnyObject?
    if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimized) == .success,
       (minimized as? Bool) == true { return }

    if let btn = axMinimizeButton(for: window) {
        axRaise(window)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { axPress(btn) }
    } else {
        AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
    }
}

fileprivate func robustClose(window: AXUIElement, app: NSRunningApplication?) {
    var minimized: AnyObject?
    let gotMin = AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimized) == .success
    let isMinimized = gotMin ? ((minimized as? Bool) ?? false) : false

    if isMinimized {
        AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { performClose(window: window) }
    } else {
        performClose(window: window)
    }
}

fileprivate func performClose(window: AXUIElement) {
    var closeBtn: AnyObject?
    if AXUIElementCopyAttributeValue(window, kAXCloseButtonAttribute as CFString, &closeBtn) == .success
        {
        let btn = closeBtn as! AXUIElement
        axPress(btn)
    } else {
        AXUIElementPerformAction(window, kAXCloseAction as CFString)
    }
}

fileprivate func performMaximize(window: AXUIElement, app: NSRunningApplication?) {
    var minimized: AnyObject?
    let gotMin = AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimized) == .success
    let isMinimized = gotMin ? ((minimized as? Bool) ?? false) : false
    if isMinimized {
        AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
    }

    if let app = app {
        NSApp.activate(ignoringOtherApps: true)
        _ = app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
        switch MaximizeBehavior.current {
        case .fill:
            if let screen = screenForWindow(window) {
                let frame = screen.frame
                let visible = screen.visibleFrame
                let flipped = frame.origin.y > visible.origin.y ? false : true
                var pos: CGPoint
                if !flipped {
                    pos = visible.origin
                } else {
                    let y = frame.height - visible.origin.y - visible.height
                    pos = CGPoint(x: visible.origin.x, y: y)
                }
                var size = CGSize(width: visible.width, height: visible.height)
                if let posVal = AXValueCreate(.cgPoint, &pos), let sizeVal = AXValueCreate(.cgSize, &size) {
                    AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posVal)
                    AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeVal)
                }
            }
        case .fullscreen:
            var fsValue: AnyObject?
            if AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &fsValue) == .success,
               let isFS = fsValue as? Bool {
                AXUIElementSetAttributeValue(window, "AXFullScreen" as CFString, NSNumber(value: !isFS))
            } else {
                AXUIElementSetAttributeValue(window, "AXFullScreen" as CFString, NSNumber(value: true))
            }
        }
    }
}

fileprivate func screenForWindow(_ window: AXUIElement) -> NSScreen? {
    var posValue: AnyObject?
    var sizeValue: AnyObject?
    guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posValue) == .success,
          AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success
    else { return NSScreen.main }
    let posAX = posValue as! AXValue
    let sizeAX = sizeValue as! AXValue
    var pos = CGPoint.zero
    var size = CGSize.zero
    AXValueGetValue(posAX, .cgPoint, &pos)
    AXValueGetValue(sizeAX, .cgSize, &size)
    let frame = CGRect(origin: pos, size: size)
    let mid = CGPoint(x: frame.midX, y: frame.midY)
    return NSScreen.screens.first(where: { $0.frame.contains(mid) }) ?? NSScreen.main
}


fileprivate struct WindowRow: Identifiable, Equatable {
    let id: String
    let title: String
    let isMinimized: Bool
    let shouldHighlight: Bool
    let index: Int

    init(index: Int, tuple: (title: String, isMinimized: Bool, shouldHighlight: Bool)) {
        self.id = "\(index)-\(tuple.title)-\(tuple.isMinimized)-\(tuple.shouldHighlight)"
        self.title = tuple.title
        self.isMinimized = tuple.isMinimized
        self.shouldHighlight = tuple.shouldHighlight
        self.index = index
    }

    static func == (lhs: WindowRow, rhs: WindowRow) -> Bool { lhs.id == rhs.id }
}


struct DockPreviewPanel: View {
    let appBundleID: String
    let appDisplayName: String
    let appIcon: NSImage
    let windowInfos: [(title: String, isMinimized: Bool, shouldHighlight: Bool)]
    // Pass index + title so monitor can map reliably (duplicate titles safe)
    let onTitleClick: (Int, String) -> Void
    let onActionComplete: () -> Void

    private var windowRows: [WindowRow] {
        windowInfos.enumerated().map { WindowRow(index: $0.offset, tuple: $0.element) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(nsImage: appIcon)
                    .resizable().frame(width: 40, height: 40)
                    .cornerRadius(10)
                    .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 1)
                Text(appDisplayName)
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1).truncationMode(.tail)
                Spacer()
            }
            .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(windowRows) { row in
                    RowWithTrafficLights(
                        row: row,
                        appBundleID: appBundleID,
                        onTitleClick: onTitleClick,
                        onActionComplete: onActionComplete
                    )
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .dockStyle(cornerRadius: 18, highlightColor: nil)
        .frame(minWidth: 240, maxWidth: 320)
        .id(windowRows.map(\.id).joined(separator: "|"))
    }
}


fileprivate struct RowWithTrafficLights: View {
    let row: WindowRow
    let appBundleID: String
    let onTitleClick: (Int, String) -> Void
    let onActionComplete: () -> Void

    @State private var isRowHovering = false
    @State private var isOverlayHovered = false
    @State private var isOverlayPinned = false

    private var shouldShowOverlay: Bool { isRowHovering || isOverlayHovered || isOverlayPinned }

    private func runningApp() -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: appBundleID).first
    }

    // Mirror monitor’s filtering so index alignment is stable.
    private func visibleCGWindowTitles(for app: NSRunningApplication) -> Set<String> {
        var result = Set<String>()
        guard let bundleID = app.bundleIdentifier else { return result }
        let appProcs = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        let pids = Set(appProcs.map { $0.processIdentifier })
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return result
        }
        for dict in list {
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

    private func axFilteredWindows(for app: NSRunningApplication) -> [AXUIElement] {
        let appEl = AXUIElementCreateApplication(app.processIdentifier)
        var raw: AnyObject?
        guard AXUIElementCopyAttributeValue(appEl, kAXWindowsAttribute as CFString, &raw) == .success,
              let windows = raw as? [AXUIElement] else { return [] }

        let cgVisible = visibleCGWindowTitles(for: app)
        let bundleID = app.bundleIdentifier ?? ""

        var result: [AXUIElement] = []
        for w in windows {
            guard (w.role() ?? "") == "AXWindow" else { continue }
            let sub = w.subrole() ?? ""
            if sub == "AXPictureInPictureWindow" || sub == "AXSystemDialog" { continue }

            var minimizedRaw: AnyObject?
            let isMin = AXUIElementCopyAttributeValue(w, kAXMinimizedAttribute as CFString, &minimizedRaw) == .success && ((minimizedRaw as? Bool) ?? false)

            var sizeValue: AnyObject?
            var sizeOK = true
            if AXUIElementCopyAttributeValue(w, kAXSizeAttribute as CFString, &sizeValue) == .success {
                let ax = sizeValue as! AXValue
                var sz = CGSize.zero
                AXValueGetValue(ax, .cgSize, &sz)
                if sz.width < 80 || sz.height < 80, !isMin { sizeOK = false }
            }
            if !sizeOK { continue }

            var t: AnyObject?
            var title = ""
            if AXUIElementCopyAttributeValue(w, kAXTitleAttribute as CFString, &t) == .success {
                title = (t as? String) ?? ""
            }

            if bundleID != "com.apple.Safari" {
                if title.isEmpty || title == "(Untitled)" {
                    if !isMin {
                        if !cgVisible.contains(title) || title.isEmpty { continue }
                    }
                }
            }

            result.append(w)
        }
        return result
    }

    private func axWindowByFilteredIndex() -> AXUIElement? {
        guard let app = runningApp() else { return nil }
        let filtered = axFilteredWindows(for: app)
        if row.index >= 0 && row.index < filtered.count { return filtered[row.index] }
        // Fallback: match by title in same filtered set
        return filtered.first(where: { w in
            var t: AnyObject?
            _ = AXUIElementCopyAttributeValue(w, kAXTitleAttribute as CFString, &t)
            return (t as? String) == row.title
        })
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: {
                onTitleClick(row.index, row.title)
            }) {
                HStack {
                    MarqueeText(text: row.title.isEmpty ? "(Untitled)" : row.title, maxWidth: 185).id(row.id)
                    if row.isMinimized { MinimizedIndicator().padding(.leading, 5) }
                    Spacer()
                }
                .padding(.vertical, 7)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(row.shouldHighlight ? Color.accentColor.opacity(0.25)
                              : (shouldShowOverlay ? Color.accentColor.opacity(0.15) : Color.clear))
                        .shadow(color: row.shouldHighlight ? .black.opacity(0.12) : .clear, radius: 6, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(
                            row.shouldHighlight ? Color.white.opacity(0) :
                                (shouldShowOverlay ? Color.accentColor.opacity(0.50) : Color(nsColor: .separatorColor).opacity(0.65)),
                            lineWidth: 2.5 / max(NSScreen.main?.backingScaleFactor ?? 2.0, 1.0)
                        )
                )
                .contentShape(RoundedRectangle(cornerRadius: 10))
                .scaleEffect(row.shouldHighlight ? 1.02 : 1.0)
            }
            .buttonStyle(.plain)
            .zIndex(0)

            if shouldShowOverlay {
                TrafficLightButtons(
                    rowTitle: row.title,
                    isMinimized: row.isMinimized,
                    onClose: {
                        if let win = axWindowByFilteredIndex() { robustClose(window: win, app: runningApp()) }
                        onActionComplete()
                    },
                    onMinimize: {
                        if let win = axWindowByFilteredIndex() { robustMinimize(window: win) }
                        onActionComplete()
                    },
                    onFullscreen: {
                        if let win = axWindowByFilteredIndex(), let app = runningApp() {
                            performMaximize(window: win, app: app)
                        }
                        onActionComplete()
                    },
                    overlayHoverChanged: { hovering in
                        isOverlayHovered = hovering
                    },
                    overlayInteractionChanged: { interacting in
                        isOverlayPinned = interacting
                        if !interacting {
                            // short grace so overlay doesn’t vanish mid-click
                            isOverlayPinned = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                                if !isOverlayHovered { isOverlayPinned = false }
                            }
                        }
                    },
                    onBackplateTap: {
                        onTitleClick(row.index, row.title)
                    }
                )
                .padding(.trailing, 6)
                .padding(.top, 4)
                .zIndex(1000)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.18), value: shouldShowOverlay)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
        .onHover { hovering in
            isRowHovering = hovering
        }
    }
}


struct TrafficLightButtons: View {
    let rowTitle: String
    let isMinimized: Bool
    let onClose: () -> Void
    let onMinimize: () -> Void
    let onFullscreen: () -> Void
    let overlayHoverChanged: (Bool) -> Void
    let overlayInteractionChanged: (Bool) -> Void
    let onBackplateTap: () -> Void

    @State private var hovering = false

    // Keep overlay pinned during press without stealing Button taps
    private var pinGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in overlayInteractionChanged(true) }
            .onEnded { _ in overlayInteractionChanged(false) }
    }

    private func circle(color: Color, systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            overlayInteractionChanged(true)
            action()
            // unpin on next runloop
            DispatchQueue.main.async { overlayInteractionChanged(false) }
        }) {
            ZStack {
                Circle().fill(color).frame(width: 16, height: 16)
                Image(systemName: systemName)
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(.white.opacity(0.88))
            }
        }
        .buttonStyle(.plain)
        .contentShape(Circle().inset(by: -6))
    }

    var body: some View {
        ZStack {
            // Backplate absorbs clicks and taps-through are prevented
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(radius: 3, y: 1)
                .contentShape(RoundedRectangle(cornerRadius: 12))
                .onTapGesture { onBackplateTap() }

            HStack(spacing: 9) {
                circle(color: .red, systemName: "xmark", action: onClose).help("Close")

                if !isMinimized {
                    circle(color: .yellow, systemName: "minus", action: onMinimize).help("Minimize")
                }

                circle(color: .green, systemName: "arrow.up.left.and.arrow.down.right", action: onFullscreen).help("Maximize")
            }
            .frame(height: 28)
            .padding(.horizontal, 12)
        }
        .frame(width: isMinimized ? 58 : 85, height: 28)
        .zIndex(1000)
        .allowsHitTesting(true)
        // Important: use simultaneousGesture on the container, not on the Buttons
        .simultaneousGesture(pinGesture)
        .onHover { h in
            hovering = h
            overlayHoverChanged(h)
        }
    }
}


struct MinimizedIndicator: View {
    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            Path { path in
                let mid = size / 2
                path.move(to: CGPoint(x: mid, y: 0))
                path.addLine(to: CGPoint(x: size, y: mid))
                path.addLine(to: CGPoint(x: mid, y: size))
                path.addLine(to: CGPoint(x: 0, y: mid))
                path.closeSubpath()
            }
            .stroke(Color.secondary, lineWidth: 1.9)
        }
        .frame(width: 12, height: 12)
        .help("This window is minimized")
    }
}

struct BlurView: View { var body: some View { Rectangle().fill(.ultraThinMaterial) } }

struct DockStyleModifier: ViewModifier {
    let cornerRadius: Double
    let highlightColor: Color?
    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    BlurView()
                    if let hc = highlightColor {
                        LinearGradient(gradient: Gradient(colors: [hc, hc.opacity(0.5)]),
                                       startPoint: .top, endPoint: .bottom)
                            .opacity(0.2)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.gray.opacity(0.19), lineWidth: 1)
                        .blendMode(.plusLighter)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
                }
            }
            .padding(2)
    }
}

extension View {
    func dockStyle(cornerRadius: Double = 19, highlightColor: Color? = nil) -> some View {
        modifier(DockStyleModifier(cornerRadius: cornerRadius, highlightColor: highlightColor))
    }
}
