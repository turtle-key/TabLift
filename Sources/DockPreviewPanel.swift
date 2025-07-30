import SwiftUI

// Use this for the popup's background and gray lightning border, exactly as DockDoor does.
struct BlurView: View {
    var body: some View {
        Rectangle().fill(.ultraThinMaterial)
    }
}

struct DockPreviewPanel: View {
    let appName: String
    let appIcon: NSImage
    let windowTitles: [String]
    let onTitleClick: (String) -> Void

    @State private var hoveredIndex: Int? = nil

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
                ForEach(Array(windowTitles.enumerated()), id: \.offset) { idxTitle in
                    let index = idxTitle.offset
                    let title = idxTitle.element
                    Button(action: {
                        onTitleClick(title)
                    }) {
                        HStack {
                            Text(title.isEmpty ? "(Untitled)" : title)
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundColor(Color.primary)
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.vertical, 7)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(hoveredIndex == index ? Color.accentColor.opacity(0.18) : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        hoveredIndex = hovering ? index : nil
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .dockStyle(cornerRadius: 18, highlightColor: nil) // <- the DockDoor look!
        .frame(minWidth: 240, maxWidth: 320)
        .animation(.snappy(duration: 0.13), value: hoveredIndex)
    }
}

// --- DockDoor's border, shadow, and blur modifier ("lightning border") ---
struct DockStyleModifier: ViewModifier {
    let cornerRadius: Double
    let highlightColor: Color?

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    BlurView()
                    if let hc = highlightColor {
                        // Optional highlight gradient, usually not used for basic popup
                        LinearGradient(gradient: Gradient(colors: [hc, hc.opacity(0.5)]), startPoint: .top, endPoint: .bottom)
                            .opacity(0.2)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    // Lightning gray border
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
