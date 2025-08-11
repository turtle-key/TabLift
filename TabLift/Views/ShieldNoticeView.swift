import SwiftUI

// Crisp blur/vibrancy background that clips to rounded corners
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    var blending: NSVisualEffectView.BlendingMode = .withinWindow
    var emphasized: Bool = false
    var cornerRadius: CGFloat = 12

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blending
        v.state = .active
        v.isEmphasized = emphasized
        v.wantsLayer = true
        v.layer?.cornerRadius = cornerRadius
        v.layer?.masksToBounds = true
        return v
    }
    func updateNSView(_ v: NSVisualEffectView, context: Context) {
        v.material = material
        v.blendingMode = blending
        v.isEmphasized = emphasized
        v.layer?.cornerRadius = cornerRadius
        v.state = .active
    }
}

// Little “keycap” badge for shortcuts
struct Keycap: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.22))
            )
    }
}

struct ShieldNoticeView: View {
    var onClose: () -> Void
    var onNeverShowAgain: () -> Void

    @State private var appear = false

    private var appIcon: NSImage {
        // Fallback to system app icon if needed
    private let appIcon: NSImage

    init(
        onClose: @escaping () -> Void,
        onNeverShowAgain: @escaping () -> Void
    ) {
        self.onClose = onClose
        self.onNeverShowAgain = onNeverShowAgain
        // Fallback to system app icon if needed
        self.appIcon = NSApplication.shared.applicationIconImage
            ?? (NSImage(named: NSImage.applicationIconName) ?? NSImage())
    }

    private var appName: String {
        let display = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
        return display ?? name ?? "This app"
    }

    var body: some View {
        ZStack {
            // Background blur with rounded corners and a subtle border
            VisualEffectView(material: .popover, blending: .withinWindow, emphasized: true, cornerRadius: 12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    // App icon for better integration
                    Image(nsImage: appIcon)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 36, height: 36)
                        .cornerRadius(7)
                        .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
                        .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Waiting for macOS Accessibility")
                            .font(.system(size: 15, weight: .semibold))

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text("Try:")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Keycap(text: "⌃")
                                Keycap(text: "⌘")
                                Keycap(text: "Q")
                                Text("to lock, then")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Keycap(text: "Esc")
                                Text("to dismiss.")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            Text("This clears a temporary macOS shield that blocks Accessibility for a few seconds. \(appName) will resume automatically.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        HStack(spacing: 10) {
                            Button("Got it") { onClose() }
                                .buttonStyle(.bordered)
                            Button("Don’t show again") { onNeverShowAgain() }
                                .buttonStyle(.link)
                        }
                        .padding(.top, 2)
                    }
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .shadow(color: Color.black.opacity(0.22), radius: 14, x: 0, y: 10)
            .opacity(appear ? 1.0 : 0.0)
            .scaleEffect(appear ? 1.0 : 0.985)
            .animation(.spring(response: 0.32, dampingFraction: 0.92, blendDuration: 0.2), value: appear)
            .onAppear { appear = true }
            .onDisappear { appear = false }
        }
        .frame(width: 460, alignment: .leading)
        .padding(1) // small inset to avoid edge clipping
    }
}
