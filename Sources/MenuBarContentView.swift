import SwiftUI

struct MenuBarContentView: View {
    @AppStorage(WindowManager.restoreAllKey) var restoreAllWindows: Bool = true

    var body: some View {
        VStack(spacing: 16) {
            Text("TabLift")
                .font(.headline)
            Divider()
            Toggle(isOn: $restoreAllWindows) {
                Text("Restore all minimized windows")
            }
            .toggleStyle(SwitchToggleStyle())

            Button("Open Settings") {
                NSApp.sendAction(#selector(AppDelegate.showUI), to: nil, from: nil)
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
                    .foregroundColor(.red)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 18)
                }
                .buttonStyle(PlainButtonStyle())
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
