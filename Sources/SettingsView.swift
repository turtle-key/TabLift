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

// ABOUT TAB
struct AboutTab: View {
    private let appName = "TabLift"
    private let appDescription = "Minimized App Restorer"
    private let appVersion = "v" + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
    private let copyright = "MIT © Mihai-Eduard Ghețu"
    private let appIconName = "AppIcon"

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
            // Header (no background, no shadow)
            VStack(spacing: 16) {
                Spacer().frame(height: 12)
                Image(appIconName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 96, height: 96)
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

            // Main content and footer separated
            VStack {
                Form {
                    Section {
                        HyperLink(URLs.homepage) {
                            HStack(alignment: .firstTextBaseline, spacing: 5) {
                                Image(systemName: "info.circle")
                                    .symbolRenderingMode(.hierarchical)
                                Text("Know more about TabLift")
                            }
                        }
                        HyperLink(URLs.donate) {
                            HStack(alignment: .firstTextBaseline, spacing: 5) {
                                Image(systemName: "cup.and.saucer")
                                    .symbolRenderingMode(.hierarchical)
                                Text("Buy me a coffee")
                            }
                        }
                        HyperLink(URLs.repo) {
                            HStack(alignment: .firstTextBaseline, spacing: 5) {
                                Image(systemName: "chevron.left.slash.chevron.right")
                                    .symbolRenderingMode(.hierarchical)
                                Text("This app is fully open source")
                            }
                        }
                        HyperLink(URLs.email) {
                            HStack(alignment: .firstTextBaseline, spacing: 5) {
                                Image(systemName: "envelope")
                                    .symbolRenderingMode(.hierarchical)
                                Text("Email me")
                            }
                        }
                    }
                    .modifier(SectionViewModifier())
                    .frame(minHeight: 22)
                }
                .modifier(FormViewModifier())
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Footer at the bottom
                HStack {
                    Link(destination: licenseURL) {
                        Text(copyright)
                            .font(.footnote)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Button(action: {
                        NSApplication.shared.terminate(nil)
                    }) {
                        Text("Quit")
                            .font(.footnote)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 3)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 480, height: 560)
    }
}

// GENERAL SETTINGS TAB (includes Updates)
struct GeneralSettingsTab: View {
    var body: some View {
        VStack {
            Form {
                Section {
                    // Add your general settings toggles here, for example:
                    // Toggle("Some setting", isOn: $someState)
                }
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
}
