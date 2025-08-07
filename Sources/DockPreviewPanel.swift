import SwiftUI
import Cocoa

fileprivate let kAXCloseAction = "AXClose" as CFString

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
        // Fallback: try sending kAXCloseAction directly to window
        AXUIElementPerformAction(window, kAXCloseAction as CFString)
    }
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
                        if !row.isMinimized { // Only allow minimize if not already minimized
                            robustMinimize(window: win)
                        }
                        onActionComplete()
                    },
                    onFullscreen: {
                        guard let win = findWindowAXElement() else { onActionComplete(); return }
                        var fsValue: AnyObject?
                        if AXUIElementCopyAttributeValue(win, "AXFullScreen" as CFString, &fsValue) == .success,
                           let isFS = fsValue as? Bool {
                            AXUIElementSetAttributeValue(win, "AXFullScreen" as CFString, NSNumber(value: !isFS))
                        }
                        onActionComplete()
                    },
                    isMinimized: row.isMinimized // Pass minimized state for button filtering
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

// Modified: Hide Minimize if minimized
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
                .help("Toggle Fullscreen")
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
