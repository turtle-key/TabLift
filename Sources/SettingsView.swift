import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            AboutTab()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
            GeneralSettingsTab()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
        }
        .frame(width: 480, height: 560)
    }
}

struct AboutTab: View {
    private let appName = "TabLift"
    private let appDescription = "Minimized App Restorer"
    private let appVersion = "v" + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
    private let copyright = "MIT © Mihai-Eduard Ghețu"
    private let appIconName = "AppIcon"

    @State private var isHoveringQuit = false

    private var releaseURL: URL {
        URL(string: "https://github.com/turtle-key/TabLift/releases/tag/\(appVersion)")!
    }
    private var licenseURL: URL {
        URL(string: "https://github.com/turtle-key/TabLift/blob/main/LICENSE")!
    }

    private enum URLs {
        static var homepage: URL { URL(string: "https://tablift.mihai.sh")! }
        static var donate: URL { URL(string: "https://coff.ee/turtle.key")! }
        static var repo: URL { URL(string: "https://github.com/turtle-key/TabLift")! }
        static var email: URL { URL(string: "mailto:ghetumihaieduard@gmail.com")! }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                Spacer().frame(height: 12)
                Image(appIconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(radius: 4)
                Text(appName)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.top, 2)
                Text(appDescription)
                    .font(.title2)
                    .foregroundColor(.gray)
                Link(destination: releaseURL) {
                    Text(appVersion)
                        .font(.body)
                        .foregroundColor(.gray)
                        .padding(.bottom, 6)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 4)

            Spacer()

            VStack(spacing: 14) {
                ModernAboutLink(
                    destination: URLs.repo,
                    systemImage: "chevron.left.slash.chevron.right",
                    label: "This app is fully open source"
                )
                ModernAboutLink(
                    destination: URLs.homepage,
                    systemImage: "info.circle",
                    label: "Know more about TabLift"
                )
                ModernAboutLink(
                    destination: URLs.donate,
                    systemImage: "cup.and.saucer",
                    label: "Buy me a coffee"
                )
                ModernAboutLink(
                    destination: URLs.email,
                    systemImage: "envelope",
                    label: "Email me"
                )
            }
            .frame(maxWidth: 320)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .multilineTextAlignment(.center)

            Spacer()

            HStack {
                Link(destination: licenseURL) {
                    Text(copyright)
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                Spacer()
                ModernQuitButton(isHovering: $isHoveringQuit)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
        }
        .frame(width: 480, height: 560)
    }
}

struct ModernAboutLink: View {
    let destination: URL
    let systemImage: String
    let label: String

    @State private var hovering = false

    var body: some View {
        Link(destination: destination) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundColor(.accentColor)
                    .font(.system(size: 18, weight: .medium))
                Text(label)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(hovering ? Color.accentColor.opacity(0.14) : Color(NSColor.controlBackgroundColor))
            )
            .animation(.easeInOut(duration: 0.14), value: hovering)
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            self.hovering = hovering
        }
    }
}

struct ModernQuitButton: View {
    @Binding var isHovering: Bool

    var body: some View {
        Button(action: {
            NSApplication.shared.terminate(nil)
        }) {
            HStack(spacing: 6) {
                Image(systemName: "power")
                    .font(.system(size: 14, weight: .semibold))
                Text("Quit")
                    .font(.footnote)
                    .fontWeight(.medium)
            }
            .foregroundColor(isHovering ? Color.white : Color.red)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovering ? Color.red : Color.clear)
                    .animation(.easeInOut(duration: 0.15), value: isHovering)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            isHovering = hovering
        }
        .help("Quit TabLift")
    }
}

struct GeneralSettingsTab: View {
    var body: some View {
        Form {
            Section { }
                .modifier(SectionViewModifier())
            Section {
                CheckForUpdatesView()
            }
            .modifier(SectionViewModifier())
        }
        .modifier(FormViewModifier())
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
