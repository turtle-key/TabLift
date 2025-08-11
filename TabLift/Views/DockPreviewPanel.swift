import SwiftUI
import Cocoa

fileprivate let kAXCloseAction = "AXClose" as CFString


enum MaximizeBehavior: String, CaseIterable, Identifiable {
    case fill = "Fill"
    case fullscreen = "Fullscreen"

    var id: String { rawValue }

    var explanation: String {
        switch self {
        case .fill: return "Fill: Expands the window to fill the entire screen area (excluding the menu bar and Dock), leaving no space around."
        case .fullscreen: return "Fullscreen: Native macOS fullscreen mode (window becomes its own space, hides menu bar and Dock)."
        }
    }

    static var current: MaximizeBehavior {
        let raw = UserDefaults.standard.string(forKey: "maximizeBehavior") ?? MaximizeBehavior.fill.rawValue
        return MaximizeBehavior(rawValue: raw) ?? .fill
    }
}


fileprivate func robustMinimize(window: AXUIElement) {
    var minimized: AnyObject?
    if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimized) == .success,
       let isMin = minimized as? Bool, !isMin {
        AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
    } else {
    }
}

fileprivate func robustClose(window: AXUIElement, app: NSRunningApplication?) {
    var minimized: AnyObject?
    let gotMin = AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimized) == .success
    let isMinimized = gotMin ? ((minimized as? Bool) ?? false) : false

    if isMinimized {
        AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            performClose(window: window)
        }
    } else {
        performClose(window: window)
    }
}

fileprivate func performClose(window: AXUIElement) {
    var closeBtn: AnyObject?
    if AXUIElementCopyAttributeValue(window, kAXCloseButtonAttribute as CFString, &closeBtn) == .success {
        AXUIElementPerformAction(closeBtn as! AXUIElement, kAXPressAction as CFString)
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
                let posVal = AXValueCreate(.cgPoint, &pos)
                let sizeVal = AXValueCreate(.cgSize, &size)
                if let posVal, let sizeVal {
                    AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posVal)
                    AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeVal)
                }
            } else {
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
    guard
        AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posValue) == .success,
        AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success
    else { return NSScreen.main }
    let posAX = posValue as! AXValue
    let sizeAX = sizeValue as! AXValue
    var pos = CGPoint.zero
    var size = CGSize.zero
    AXValueGetValue(posAX, .cgPoint, &pos)
    AXValueGetValue(sizeAX, .cgSize, &size)
    let frame = CGRect(origin: pos, size: size)
    let windowCenter = CGPoint(x: frame.midX, y: frame.midY)
    for screen in NSScreen.screens {
        if screen.frame.contains(windowCenter) {
            return screen
        }
    }
    return NSScreen.main
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

    static func == (lhs: WindowRow, rhs: WindowRow) -> Bool {
        lhs.id == rhs.id
    }
}

enum TrafficLightAction {
    case close, minimize, fullscreen
}


struct DockPreviewPanel: View {
    let appBundleID: String
    let appDisplayName: String
    let appIcon: NSImage
    let windowInfos: [(title: String, isMinimized: Bool, shouldHighlight: Bool)]
    let onTitleClick: (String) -> Void
    let onActionComplete: () -> Void

    private var windowRows: [WindowRow] {
        windowInfos.enumerated().map { WindowRow(index: $0.offset, tuple: $0.element) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 40, height: 40)
                    .cornerRadius(10)
                    .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 1)
                Text(appDisplayName)
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
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
    let onTitleClick: (String) -> Void
    let onActionComplete: () -> Void

    @State private var isRowHovering: Bool = false
    @State private var isOverlayHovered: Bool = false
    @State private var isOverlayPinned: Bool = false

    private var shouldShowOverlay: Bool {
        isRowHovering || isOverlayHovered || isOverlayPinned
    }

    // Prefer selecting by AX windows index to disambiguate same-titled windows
    private func axWindowByIndex() -> AXUIElement? {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: appBundleID).first else { return nil }
        let appEl = AXUIElementCreateApplication(app.processIdentifier)
        var raw: AnyObject?
        guard AXUIElementCopyAttributeValue(appEl, kAXWindowsAttribute as CFString, &raw) == .success,
              let windows = raw as? [AXUIElement] else { return nil }

        var filtered: [AXUIElement] = []
        for w in windows {
            if w.role() == "AXWindow" {
                filtered.append(w)
            }
        }
        if row.index >= 0 && row.index < filtered.count {
            return filtered[row.index]
        }

        // Fallback: match by title
        for w in filtered {
            var t: AnyObject?
            if AXUIElementCopyAttributeValue(w, kAXTitleAttribute as CFString, &t) == .success,
               let t = t as? String, t == row.title {
                return w
            }
        }
        return nil
    }

    private func findApp() -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: appBundleID).first
    }

    @State private var backingScale: CGFloat = NSScreen.main?.backingScaleFactor ?? 2.0
    private var hairlineWidth: CGFloat { 2.5 / max(backingScale, 1.0) }
    private var borderColor: Color {
        if row.shouldHighlight { return Color.white.opacity(0) }
        if shouldShowOverlay { return Color.accentColor.opacity(0.50) }
        return Color(nsColor: .separatorColor).opacity(0.65)
    }

    private var mouseLogger: some Gesture {
        DragGesture(minimumDistance: 0)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Underlay title button. Leave hit-testing enabled; overlay intercepts within its own bounds.
            Button(action: {
                onTitleClick(row.title)
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
                        .inset(by: hairlineWidth / 2)
                        .stroke(borderColor, lineWidth: hairlineWidth)
                )
                .contentShape(RoundedRectangle(cornerRadius: 10))
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
                    backingScale = NSScreen.main?.backingScaleFactor ?? backingScale
                }
                .scaleEffect(row.shouldHighlight ? 1.02 : 1.0)
            }
            .buttonStyle(.plain)
            .simultaneousGesture(mouseLogger)
            .zIndex(0)

            // Overlay traffic lights, with pinning and hover reporting. Backplate tap => activate row.
            if shouldShowOverlay {
                TrafficLightButtons(
                    rowTitle: row.title,
                    isMinimized: row.isMinimized,
                    onClose: {
                        if let win = axWindowByIndex() {
                            robustClose(window: win, app: findApp())
                        } else {
                        }
                        onActionComplete()
                    },
                    onMinimize: {
                        if let win = axWindowByIndex() {
                            robustMinimize(window: win)
                        } else {
                        }
                        onActionComplete()
                    },
                    onFullscreen: {
                        if let win = axWindowByIndex(), let app = findApp() {
                            performMaximize(window: win, app: app)
                        } else {
                        }
                        onActionComplete()
                    },
                    overlayHoverChanged: { hovering in
                        isOverlayHovered = hovering
                    },
                    overlayInteractionChanged: { interacting in
                        isOverlayPinned = interacting
                    },
                    onBackplateTap: {
                        onTitleClick(row.title)
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
        .simultaneousGesture(mouseLogger)
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

    private var overlayMouseLogger: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                overlayInteractionChanged(true)
            }
            .onEnded { _ in
                overlayInteractionChanged(false)
            }
    }

    var body: some View {
        ZStack {
            // Backplate blocks pass-through and now triggers the row click if you click the background.
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .frame(width: isMinimized ? 58 : 85, height: 28)
                .shadow(radius: 3, y: 1)
                .contentShape(RoundedRectangle(cornerRadius: 12))
                .onTapGesture {
                    onBackplateTap()
                }

            HStack(spacing: 9) {
                Button(action: {
                    onClose()
                }) {
                    ZStack {
                        Circle().fill(Color.red).frame(width: 16, height: 16)
                            .shadow(color: Color.red.opacity(0.13), radius: 1, x: 0, y: 0)
                        Image(systemName: "xmark")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(.white.opacity(0.88))
                    }
                }
                .buttonStyle(.plain)
                .contentShape(Circle().inset(by: -6))
                .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in
                    overlayInteractionChanged(true)
                }.onEnded { _ in
                    overlayInteractionChanged(false)
                })
                .help("Close")

                if !isMinimized {
                    Button(action: {
                        onMinimize()
                    }) {
                        ZStack {
                            Circle().fill(Color.yellow).frame(width: 16, height: 16)
                                .shadow(color: Color.yellow.opacity(0.13), radius: 1, x: 0, y: 0)
                            Image(systemName: "minus")
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundColor(.white.opacity(0.88))
                        }
                    }
                    .buttonStyle(.plain)
                    .contentShape(Circle().inset(by: -6))
                    .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in
                        overlayInteractionChanged(true)
                    }.onEnded { _ in
                        overlayInteractionChanged(false)
                    })
                    .help("Minimize")
                }

                Button(action: {
                    onFullscreen()
                }) {
                    ZStack {
                        Circle().fill(Color.green).frame(width: 16, height: 16)
                            .shadow(color: Color.green.opacity(0.13), radius: 1, x: 0, y: 0)
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(.white.opacity(0.88))
                    }
                }
                .buttonStyle(.plain)
                .contentShape(Circle().inset(by: -6))
                .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in
                    overlayInteractionChanged(true)
                }.onEnded { _ in
                    overlayInteractionChanged(false)
                })
                .help("Maximize")
            }
            .frame(height: 28)
        }
        .frame(width: isMinimized ? 58 : 85, height: 28)
        .zIndex(1000)
        .allowsHitTesting(true)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .simultaneousGesture(overlayMouseLogger)
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

struct BlurView: View {
    var body: some View {
        Rectangle().fill(.ultraThinMaterial)
    }
}

struct DockStyleModifier: ViewModifier {
    let cornerRadius: Double
    let highlightColor: Color?
    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    BlurView()
                    if let hc = highlightColor {
                        LinearGradient(gradient: Gradient(colors: [hc, hc.opacity(0.5)]), startPoint: .top, endPoint: .bottom)
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
