import SwiftUI
import ServiceManagement

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
class SettingsWindow: NSWindow {
    override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "w" {
            self.performClose(nil)
        } else {
            super.keyDown(with: event)
        }
    }
}
struct GeneralSettingsTab: View {
    @AppStorage(WindowManager.restoreAllKey) var restoreAllWindows: Bool = false
    @AppStorage(WindowManager.openWindowKey) private var openNewWindowStorage: Bool = true
    @AppStorage(WindowManager.minimizePreviousWindowKey) private var minimizePreviousWindowStorage: Bool = false
    @AppStorage("showMenuBarIcon") var showMenuBarIcon: Bool = true
    @AppStorage("showDockPopups") var showDockPopups: Bool = true
    @AppStorage("startAtLogin") var startAtLogin: Bool = true
    @AppStorage("showDockIcon") var showDockIcon: Bool = true
    @State private var isHoveringQuit = false

    // Local state for mutual exclusion
    @State private var openNewWindow: Bool = true
    @State private var minimizePreviousWindow: Bool = false

    private let copyright = "AGPL-3.0 © Mihai-Eduard Ghețu"
    private var licenseURL: URL {
        URL(string: "https://github.com/turtle-key/TabLift/blob/main/LICENSE")!
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    Toggle(isOn: $showMenuBarIcon) {
                        Text("Show in menu bar")
                            .font(.body)
                        if !showMenuBarIcon {
                            Text("To show the settings, launch TabLift again.")
                                .foregroundColor(.secondary)
                                .font(.caption)
                                .padding(.top, 2)
                        }
                    }
                    .help("Show or hide the TabLift icon in your menu bar for quick access.")
                    Toggle(isOn: $startAtLogin) {
                        Text("Start at login")
                            .font(.body)
                    }
                    .help("Launch TabLift automatically when you log in to your Mac.")
                    Toggle(isOn: $showDockIcon) {
                        Text("Show in Dock")
                            .font(.body)
                    }
                    .help("Display the icon of the app in the Dock. Works just like a normal app.")
                }
                Section {
                    AccessibilityPermissionCheckView()
                }
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Behaviour")
                            .font(.headline)
                        Toggle(isOn: $restoreAllWindows) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Restore all minimized windows on app switch")
                                    .font(.body)
                                if !restoreAllWindows {
                                    Text("When disabled, only the most recently minimized window will be restored.")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                        .padding(.top, 2)
                                }
                            }
                        }
                        .help("If enabled, switching to an app will restore all its minimized windows. If disabled, only the last minimized window will be restored.")
                        Toggle(isOn: $openNewWindow) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Automatically open a window when switching to apps without windows")
                                    .font(.body)
                                if !openNewWindow {
                                    Text("When disabled, switching to an app without windows won't open a new window")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                        .padding(.top, 2)
                                }
                            }
                        }
                        .onChange(of: openNewWindow) { value in
                            openNewWindowStorage = value
                            if value {
                                minimizePreviousWindow = false
                                minimizePreviousWindowStorage = false
                            }
                        }
                        .help("If enabled, a new window will be opened when switching to an app that has no visible windows")
                        Toggle(isOn: $minimizePreviousWindow) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Minimize previous window on app switch")
                                    .font(.body)
                                if !minimizePreviousWindow {
                                    Text("When disabled, switching to another app won't automatically minimize the previous one's window(s)")
                                        .foregroundColor(.secondary)
                                        .font(.caption)
                                        .padding(.top, 2)
                                }
                            }
                        }
                        .onChange(of: minimizePreviousWindow) { value in
                            minimizePreviousWindowStorage = value
                            if value {
                                openNewWindow = false
                                openNewWindowStorage = false
                            }
                        }
                        .help("When enabled, the currently focused window is minimized when switching apps using Cmd+Tab. This helps keep the workspace clean by showing only one active window at a time.")
                        Toggle(isOn: $showDockPopups) {
                            Text("Show Window Previews in Dock")
                                .font(.body)
                        }
                        .help("Show popup with app windows when hovering icons in the Dock.")
                    }
                    .padding()
                }
                Section {
                    CheckForUpdatesView()
                }
                .modifier(SectionViewModifier())
            }
            .modifier(FormViewModifier())
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                Link(destination: licenseURL) {
                    Text(copyright)
                        .font(.footnote)
                        .foregroundColor(.gray)
                }
                Spacer()
                ModernQuitButton(isHovering: $isHoveringQuit)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
        }
        .onAppear {
            openNewWindow = openNewWindowStorage
            minimizePreviousWindow = minimizePreviousWindowStorage
        }
        .onChange(of: showMenuBarIcon) { value in
            MenuBarManager.shared.showMenuBarIcon(show: value)
        }
        .onChange(of: startAtLogin) { value in
            if value {
                try? SMAppService.mainApp.register()
            } else {
                try? SMAppService.mainApp.unregister()
            }
        }
    }
}

// ...AboutTab, ModernAboutLink, ModernQuitButton unchanged...

struct AboutTab: View {
    private let appName = "TabLift"
    private let appDescription = "Minimized App Restorer"
    private let appVersion = "v" + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
    private let copyright = "AGPL-3.0 © Mihai-Eduard Ghețu"
    private let appIconName = "AppIcon"

    @State private var isHoveringQuit = false

    private var releaseURL: URL {
        URL(string: "https://github.com/turtle-key/TabLift/releases/tag/\(appVersion)")!
    }
    private var licenseURL: URL {
        URL(string: "https://github.com/turtle-key/TabLift/blob/main/LICENSE")!
    }

    private enum URLs {
        static var homepage: URL { URL(string: "https://tablift.dev")! }
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
            .padding(.vertical, 8)
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
