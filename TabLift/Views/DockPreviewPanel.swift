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
    }
}

fileprivate func robustClose(window: AXUIElement, app: NSRunningApplication?) {
    var minimized: AnyObject?
    let gotMin = AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimized) == .success
    let isMinimized = gotMin ? ((minimized as? Bool) ?? false) : false

    // Unminimize first if minimized, then close
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
    // Find the screen that contains the center of the window
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

    @State private var isHovered: Bool = false

    private func findWindowAXElement() -> AXUIElement? {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: appBundleID).first else {
            return nil
        }
        let appEl = AXUIElementCreateApplication(app.processIdentifier)
        var raw: AnyObject?
        guard AXUIElementCopyAttributeValue(appEl, kAXWindowsAttribute as CFString, &raw) == .success,
              let windows = raw as? [AXUIElement] else { return nil }
        for window in windows {
            var t: AnyObject?
            if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &t) == .success,
               let t = t as? String,
               t == row.title {
                return window
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
        // Subtle by default, brighter when hovered/highlighted
        if row.shouldHighlight { return Color.white.opacity(0) }
        if isHovered { return Color.accentColor.opacity(0.50) }
        return Color(nsColor: .separatorColor).opacity(0.65)
    }
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: { onTitleClick(row.title) }) {
                HStack {
                    MarqueeText(text: row.title.isEmpty ? "(Untitled)" : row.title, maxWidth: 185).id(row.id)
                    if row.isMinimized {
                        MinimizedIndicator()
                            .padding(.leading, 5)
                    }
                    Spacer()
                }
                .padding(.vertical, 7)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(row.shouldHighlight ? Color.accentColor.opacity(0.25)
                              : (isHovered ? Color.accentColor.opacity(0.15) : Color.clear))
                        .shadow(color: row.shouldHighlight ? .black.opacity(0.12) : .clear, radius: 6, x: 0, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .inset(by: hairlineWidth / 2) // keeps stroke fully inside the clip
                        .stroke(borderColor, lineWidth: hairlineWidth)
                )
                .onAppear { backingScale = NSScreen.main?.backingScaleFactor ?? backingScale }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
                    backingScale = NSScreen.main?.backingScaleFactor ?? backingScale
                }
                .scaleEffect(row.shouldHighlight ? 1.02 : 1.0)
            }
            .buttonStyle(.plain)

            if isHovered {
                TrafficLightButtons(
                    onClose: {
                        guard let win = findWindowAXElement() else { onActionComplete(); return }
                        robustClose(window: win, app: findApp())
                        onActionComplete()
                    },
                    onMinimize: {
                        guard let win = findWindowAXElement() else { onActionComplete(); return }
                        if !row.isMinimized { robustMinimize(window: win) }
                        onActionComplete()
                    },
                    onFullscreen: {
                        guard let win = findWindowAXElement(), let app = findApp() else { onActionComplete(); return }
                        performMaximize(window: win, app: app)
                        onActionComplete()
                    },
                    isMinimized: row.isMinimized
                )
                .padding(.trailing, 6)
                .padding(.top, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.18), value: isHovered)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onHover { hovering in isHovered = hovering }
    }
}

struct TrafficLightButtons: View {
    let onClose: () -> Void
    let onMinimize: () -> Void
    let onFullscreen: () -> Void
    let isMinimized: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .frame(width: isMinimized ? 58 : 85, height: 28)
                .shadow(radius: 3, y: 1)

            HStack(spacing: 9) {
                Button(action: { onClose() }) {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 16, height: 16)
                            .shadow(color: Color.red.opacity(0.13), radius: 1, x: 0, y: 0)
                        Image(systemName: "xmark")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(.white.opacity(0.88))
                    }
                }
                .buttonStyle(.plain)
                .contentShape(Circle().inset(by: -6))
                .padding(2)
                .help("Close")

                if !isMinimized {
                    Button(action: { onMinimize() }) {
                        ZStack {
                            Circle()
                                .fill(Color.yellow)
                                .frame(width: 16, height: 16)
                                .shadow(color: Color.yellow.opacity(0.13), radius: 1, x: 0, y: 0)
                            Image(systemName: "minus")
                                .font(.system(size: 8.5, weight: .bold))
                                .foregroundColor(.white.opacity(0.88))
                        }
                    }
                    .buttonStyle(.plain)
                    .contentShape(Circle().inset(by: -6))
                    .padding(2)
                    .help("Minimize")
                }

                Button(action: { onFullscreen() }) {
                    ZStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 16, height: 16)
                            .shadow(color: Color.green.opacity(0.13), radius: 1, x: 0, y: 0)
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 8.5, weight: .bold))
                            .foregroundColor(.white.opacity(0.88))
                    }
                }
                .buttonStyle(.plain)
                .contentShape(Circle().inset(by: -6))
                .padding(2)
                .help("Maximize")
            }
            .frame(height: 28)
            .contentShape(Rectangle())
        }
        .frame(width: isMinimized ? 58 : 85, height: 28)
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
