import os.log
import SwiftUI
import Combine

struct AccessibilityPermissionView: View {
    private static let log = OSLog(subsystem: Bundle.main.bundleIdentifier!, category: "AccessibilityPermissionView")
    weak var window:  AccessibilityPermissionWindow?
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 15) {
                Image("AccessibilityIcon")

                Text("TabLift needs Accessibility permission")
                    .font(.headline)
            }
            .padding(.horizontal)

            Text(
                "You need to grant Accessibility permission in System Settings > Security & Privacy > Accessibility."
            )
            .padding(.horizontal)

            HyperLink(URL(string: "https://tablift.mihai.sh/faq")!) {
                Text("Get more help")
            }
            .padding(.horizontal)

            Spacer()

            HStack {
                Button("Open Accessibility") {
                    openAccessibility()
                }
            }
        }
        .padding()
        .frame(width: 450, height: 200)
    }

    func openAccessibility() {
        AccessibilityPermission.prompt()
        window?.moveAside()
    }
}
struct PingingCircle: View {
    var color: Color

    @State private var animate = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            Circle()
                .stroke(color.opacity(0.5))
                .frame(width: 16, height: 16)
                .scaleEffect(animate ? 1.5 : 1)
                .opacity(animate ? 0 : 0.6)
                .animation(Animation.easeOut(duration: 1).repeatForever(autoreverses: false), value: animate)
        }
        .onAppear {
            animate = true
        }
    }
}
struct AccesibilityPermissionCheckView: View {
    @State private var isAccessibilityEnabled = AccessibilityPermission.enabled
    
    var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Permissions")
                    .font(.headline)
                HStack(spacing: 8) {
                    PingingCircle(color: isAccessibilityEnabled ? .green : .red)

                    Text(isAccessibilityEnabled ?
                         "Accessibility permissions are enabled" :
                         "Accessibility permissions are not enabled")
                    .foregroundColor(.secondary)

                    Spacer()
                    Button("Enable Access") {
                        AccessibilityPermissionWindow.show()
                    }
                    .disabled(isAccessibilityEnabled)
                    .help("Bring up the permission request window to allow Tablift to control windows.")
                }
            }
            .padding()
            .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
                isAccessibilityEnabled = AccessibilityPermission.enabled
            }
        }
}
struct AccessibilityPermissionView_Previews: PreviewProvider {
    static var previews: some View {
        AccessibilityPermissionView()
    }
}
