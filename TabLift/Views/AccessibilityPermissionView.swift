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

                Text(loc(.accessibilityNeeded))
                    .font(.headline)
            }
            .padding(.horizontal)

            Text(loc(.accessibilityDescription))
            .padding(.horizontal)

            HyperLink(URL(string: "https://tablift.dev/faq")!) {
                Text(loc(.getMoreHelp))
            }
            .padding(.horizontal)

            Spacer()

            HStack {
                Button(loc(.openAccessibility)) {
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
struct AccessibilityPermissionCheckView: View {
    @State private var isAccessibilityEnabled = AccessibilityPermission.enabled
    
    var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(loc(.permissions))
                    .font(.headline)
                HStack(spacing: 8) {
                    PingingCircle(color: isAccessibilityEnabled ? .green : .red)

                    Text(isAccessibilityEnabled ?
                         loc(.permissionsEnabled) :
                         loc(.permissionsNotEnabled))
                    .foregroundColor(.secondary)

                    Spacer()
                    Button(loc(.enableAccess)) {
                        AccessibilityPermissionWindow.show()
                    }
                    .disabled(isAccessibilityEnabled)
                    .help(loc(.enableAccessHelp))
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
