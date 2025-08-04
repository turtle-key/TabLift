import SwiftUI

struct MenuBarContentView: View {
    @AppStorage(WindowManager.restoreAllKey) var restoreAllWindows: Bool = true

    // Add onOpenSettings closure as parameter
    var onOpenSettings: (() -> Void)? = nil

    @State private var isHoveringSettings = false
    @State private var isHoveringQuit = false

    var body: some View {
        VStack(spacing: 16) {
            Text("TabLift")
                .font(.headline)
            Divider()
            Toggle(isOn: $restoreAllWindows) {
                Text("Restore all minimized windows")
            }
            .toggleStyle(SwitchToggleStyle())

            Button(action: {
                if let onOpenSettings {
                    onOpenSettings()
                } else {
                    NSApp.sendAction(#selector(AppDelegate.showUI), to: nil, from: nil)
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15, weight: .medium))
                    Text("Open Settings")
                        .font(.body)
                        .fontWeight(.medium)
                }
                .foregroundColor(isHoveringSettings ? Color.white : Color.accentColor)
                .padding(.vertical, 7)
                .padding(.horizontal, 18)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isHoveringSettings ? Color.accentColor : Color.clear)
                        .animation(.easeInOut(duration: 0.15), value: isHoveringSettings)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { hovering in
                isHoveringSettings = hovering
            }

            WavyDivider()

            HStack {
                Spacer()
                Button(action: {
                    NSApp.terminate(nil)
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "power")
                            .font(.system(size: 13, weight: .bold))
                        Text("Quit TabLift")
                            .font(.footnote)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(isHoveringQuit ? Color.white : Color.red)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 18)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isHoveringQuit ? Color.red : Color.clear)
                            .animation(.easeInOut(duration: 0.15), value: isHoveringQuit)
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .onHover { hovering in
                    isHoveringQuit = hovering
                }
                Spacer()
            }
        }
        .padding()
        .frame(width: 300)
    }
}

struct WavyDivider: View {
    var amplitude: CGFloat = 4
    var waveLength: CGFloat = 24
    var color: Color = .secondary

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            Path { path in
                path.move(to: CGPoint(x: 0, y: height / 2))
                var x: CGFloat = 0
                while x <= width {
                    let y = height / 2 + amplitude * sin((2 * .pi / waveLength) * x)
                    path.addLine(to: CGPoint(x: x, y: y))
                    x += 1
                }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        }
        .frame(height: amplitude * 2 + 4)
        .accessibilityHidden(true)
    }
}
