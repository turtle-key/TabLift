import SwiftUI

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var emphasized: Bool = false

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = emphasized
        view.wantsLayer = true
        view.layer?.cornerRadius = 18
        view.layer?.masksToBounds = true
        view.layer?.borderWidth = 0
        view.layer?.borderColor = nil
        view.layer?.backgroundColor = NSColor.clear.cgColor
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
        nsView.isEmphasized = emphasized
        nsView.layer?.cornerRadius = 18
        nsView.layer?.masksToBounds = true
        nsView.layer?.borderWidth = 0
        nsView.layer?.borderColor = nil
        nsView.layer?.backgroundColor = NSColor.clear.cgColor
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
        .background(
            VisualEffectView(material: .popover, blendingMode: .withinWindow)
                .shadow(color: Color.black.opacity(0.22), radius: 16, x: 0, y: 7)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .frame(minWidth: 240, maxWidth: 320)
        .animation(.snappy(duration: 0.13), value: hoveredIndex)
    }
}
