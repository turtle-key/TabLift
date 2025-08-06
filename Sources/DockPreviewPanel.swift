import SwiftUI

struct BlurView: View {
    var body: some View {
        Rectangle().fill(.ultraThinMaterial)
    }
}

// Helper struct for robust identity and equatability
fileprivate struct WindowRow: Identifiable, Equatable {
    let id: String
    let title: String
    let isMinimized: Bool
    let shouldHighlight: Bool
    let index: Int

    init(index: Int, tuple: (title: String, isMinimized: Bool, shouldHighlight: Bool)) {
        // Composite ID for stability; ideal would be a window pointer or identifier
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

struct DockPreviewPanel: View {
    let appName: String
    let appIcon: NSImage
    let windowInfos: [(title: String, isMinimized: Bool, shouldHighlight: Bool)]
    let onTitleClick: (String) -> Void
    @State private var hoveredID: String? = nil

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
                Text(appName)
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundColor(Color.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
            }
            .padding(.bottom, 4)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(windowRows) { row in
                    Button(action: {
                        onTitleClick(row.title)
                    }) {
                        HStack {
                            MarqueeText(text: row.title.isEmpty ? "(Untitled)" : row.title, maxWidth: 185)
                                .id(row.id)
                            if row.isMinimized {
                                MinimizedIndicator()
                                    .padding(.leading, 5)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 7)
                        .padding(.horizontal, 10)
                        .background(
                            ZStack {
                                if row.shouldHighlight {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.accentColor.opacity(0.25))
                                        .shadow(color: .black.opacity(0.12), radius: 6, x: 0, y: 2)
                                } else if hoveredID == row.id {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.accentColor.opacity(0.15))
                                }
                            }
                        )
                        .scaleEffect(row.shouldHighlight ? 1.02 : 1.0)
                        .animation(.easeOut(duration: 0.15), value: row.shouldHighlight)
                        .padding(.bottom, 6)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        hoveredID = hovering ? row.id : nil
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .dockStyle(cornerRadius: 18, highlightColor: nil)
        .frame(minWidth: 240, maxWidth: 320)
        .animation(.snappy(duration: 0.13), value: hoveredID)
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
