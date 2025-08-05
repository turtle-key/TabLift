import SwiftUI
import ServiceManagement
import AVKit

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
            SupportTab()
                .tabItem {
                    Label("Support", systemImage: "lifepreserver")
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

// --- Make sure all footers are the same height and aligned ---
let footerHeight: CGFloat = 20

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

    // Hover state for demo videos & help text
    @State private var hoveredDemo: DemoType? = nil

    enum DemoType { case restore, opennew, minimizeprev }

    private let copyright = "AGPL-3.0 © Mihai-Eduard Ghețu"
    private var licenseURL: URL {
        URL(string: "https://github.com/turtle-key/TabLift/blob/main/LICENSE")!
    }

    // Maximum length of help texts (measured, can be tweaked)
    private let helpTextMaxWidth: CGFloat = 320
    private let helpTextMaxHeight: CGFloat = 46 // ~2 lines at caption font

    var body: some View {
        VStack(spacing: 20) {
            Form {
                Section(header: Label("App Launch & Appearance", systemImage: "rectangle.stack").font(.headline)) {
                    Toggle(isOn: $startAtLogin) {
                        Text("Start at login")
                            .font(.body)
                    }
                    .help("Launch TabLift automatically when you log in to your Mac.")

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

                    Toggle(isOn: $showDockIcon) {
                        Text("Show in Dock")
                            .font(.body)
                    }
                    .help("Display the icon of the app in the Dock. Works just like a normal app.")
                }
                
                Section(header: Label("Dock Features", systemImage: "dock.rectangle").font(.headline)) {
                    Toggle(isOn: $showDockPopups) {
                        Text("Show Window Previews in Dock")
                            .font(.body)
                    }
                    .help("Show a popup with app windows when hovering over icons in the Dock.")
                }
                
                Section(header: Label("Window Switching Behavior", systemImage: "arrow.triangle.swap").font(.headline)) {
                    VStack(alignment: .leading, spacing: 24) {
                        // Restore All Windows Demo
                        DemoSection(
                            toggle: Toggle(isOn: $restoreAllWindows) {
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
                            .help("If enabled, switching to an app will restore all its minimized windows. If disabled, only the last minimized window will be restored."),
                            demoType: .restore,
                            hoveredDemo: $hoveredDemo,
                            videoName: "restoreall",
                            helpTextActive: "Enabled: When you switch to an app, all of its minimized windows are instantly restored. The video above shows this effect when the toggle is ON.",
                            helpTextInactive: "Disabled: Only the last minimized window is restored when switching apps. The video preview demonstrates the result when enabled.",
                            maxWidth: helpTextMaxWidth,
                            maxHeight: helpTextMaxHeight
                        )

                        // Open New Window Demo
                        DemoSection(
                            toggle: Toggle(isOn: $openNewWindow) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Automatically open a window for apps with no windows")
                                        .font(.body)
                                    if !openNewWindow {
                                        Text("When disabled, switching to an app without windows won't open a new window.")
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
                            .help("If enabled, a new window will be opened when switching to an app that has no visible windows."),
                            demoType: .opennew,
                            hoveredDemo: $hoveredDemo,
                            videoName: "opennew",
                            helpTextActive: "Enabled: TabLift automatically opens a new window for an app that doesn't have any open windows. See the video above for how it works when ON.",
                            helpTextInactive: "Disabled: If you switch to an app with no windows, nothing opens. The video preview illustrates the result when enabled.",
                            maxWidth: helpTextMaxWidth,
                            maxHeight: helpTextMaxHeight
                        )

                        // Minimize Previous Window Demo
                        DemoSection(
                            toggle: Toggle(isOn: $minimizePreviousWindow) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Minimize previous window on app switch")
                                        .font(.body)
                                    if !minimizePreviousWindow {
                                        Text("When disabled, switching to another app won't automatically minimize the previous one's window(s).")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                            .padding(.top, 2)
                                    }
                                    if openNewWindow && minimizePreviousWindow {
                                        Text("Tip: 'Automatically open a window' and 'Minimize previous window' cannot be enabled at the same time.")
                                            .foregroundColor(.red)
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
                            .help("When enabled, the currently focused window is minimized when switching apps using Cmd+Tab. This helps keep the workspace clean by showing only one active window at a time."),
                            demoType: .minimizeprev,
                            hoveredDemo: $hoveredDemo,
                            videoName: "minimizeprev",
                            helpTextActive: "Enabled: The previous window is minimized automatically whenever you switch apps. The video above shows the result when ON.",
                            helpTextInactive: "Disabled: Previous windows are left open when switching apps. The video preview shows what happens when enabled.",
                            maxWidth: helpTextMaxWidth,
                            maxHeight: helpTextMaxHeight
                        )
                    }
                }

            }
            .modifier(FormViewModifier())
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            FooterView(isHoveringQuit: $isHoveringQuit)
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

// Shared Footer component for alignment
struct FooterView: View {
    @Binding var isHoveringQuit: Bool
    private let copyright = "AGPL-3.0 © Mihai-Eduard Ghețu"
    private var licenseURL: URL {
        URL(string: "https://github.com/turtle-key/TabLift/blob/main/LICENSE")!
    }

    var body: some View {
        HStack {
            Link(destination: licenseURL) {
                Text(copyright)
                    .font(.footnote)
                    .foregroundColor(.gray)
            }
            Spacer()
            ModernQuitButton(isHovering: $isHoveringQuit)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
        .frame(height: footerHeight+5)
        .frame(maxWidth: .infinity)
    }
}

// --- DemoSection: toggle, video, and help text together, with delayed animation ---
struct DemoSection<ToggleView: View>: View {
    let toggle: ToggleView
    let demoType: GeneralSettingsTab.DemoType
    @Binding var hoveredDemo: GeneralSettingsTab.DemoType?
    let videoName: String
    let helpTextActive: String
    let helpTextInactive: String
    let maxWidth: CGFloat
    let maxHeight: CGFloat

    @State private var delayedPlay = false
    @State private var delayedText = false

    var body: some View {
        VStack(spacing: 6) {
            toggle
            DemoVideoScreen(
                fileName: videoName,
                play: delayedPlay
            )
            .onHover { hovering in
                if hovering {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
                        hoveredDemo = demoType
                        delayedPlay = true
                        delayedText = true
                    }
                } else {
                    hoveredDemo = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.13) {
                        delayedPlay = false
                        delayedText = false
                    }
                }
            }
            DemoHelpText(
                text: delayedText ? helpTextActive : helpTextInactive,
                maxWidth: maxWidth,
                maxHeight: maxHeight
            )
            .animation(.easeInOut(duration: 0.22), value: delayedText)
        }
    }
}

// --- Demo macOS screen for video animation: NO controls, aspect fill, rounded, PREVIEW AT STARTUP ---
struct DemoVideoScreen: View {
    let fileName: String
    let play: Bool
    @State private var player: AVPlayer? = nil

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.13), radius: 13, x: 0, y: 2)
            if let url = Bundle.main.url(forResource: fileName, withExtension: "m4v") {
                VideoFill(player: player ?? AVPlayer(url: url))
                    .frame(width: 320, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .onAppear {
                        if player == nil {
                            let newPlayer = AVPlayer(url: url)
                            newPlayer.actionAtItemEnd = .pause
                            player = newPlayer
                        }
                        player?.seek(to: CMTime(seconds: 0.0, preferredTimescale: 600))
                        player?.pause()
                    }
                    .onChange(of: play) { playing in
                        guard let player = player else { return }
                        if playing {
                            player.seek(to: CMTime(seconds: 0.0, preferredTimescale: 600))
                            player.play()
                        } else {
                            player.pause()
                            player.seek(to: CMTime(seconds: 0.0, preferredTimescale: 600))
                        }
                    }
                    .animation(.easeInOut(duration: 0.22), value: play)
            } else {
                Text("Video missing")
                    .foregroundColor(.red)
                    .frame(width: 320, height: 180)
            }
        }
        .frame(width: 320, height: 180)
        .cornerRadius(13)
        .shadow(radius: 13)
        .padding(.top, 8)
    }
}

// --- VideoFill: NSViewRepresentable for macOS, aspect fill, NO controls ---
struct VideoFill: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerLayerView {
        let view = AVPlayerLayerView()
        view.player = player
        view.playerLayer.videoGravity = .resizeAspectFill // Zoom in a bit, crop, no bars
        return view
    }
    func updateNSView(_ nsView: AVPlayerLayerView, context: Context) {
        nsView.player = player
        nsView.playerLayer.videoGravity = .resizeAspectFill
    }
}

// --- AVPlayerLayerView for macOS ---
class AVPlayerLayerView: NSView {
    var player: AVPlayer? {
        didSet { playerLayer.player = player }
    }
    let playerLayer = AVPlayerLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.addSublayer(playerLayer)
        playerLayer.videoGravity = .resizeAspectFill
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.addSublayer(playerLayer)
        playerLayer.videoGravity = .resizeAspectFill
    }
    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }
}

// --- Help Text Placement ---
struct DemoHelpText: View {
    let text: String
    let maxWidth: CGFloat
    let maxHeight: CGFloat
    var body: some View {
        // Fix the help text size so the scroll/height never changes
        Text(text)
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(width: maxWidth, height: maxHeight, alignment: .topLeading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 8)
    }
}

// --- AboutTab, ModernAboutLink, ModernQuitButton, SupportTab unchanged ---
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
        static var helppage: URL { URL(string: "https://tablift.dev/faq")! }
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
                    destination: URLs.helppage,
                    systemImage: "info.circle",
                    label: "Tablift Help"
                )
                ModernAboutLink(
                    destination: URLs.repo,
                    systemImage: "chevron.left.slash.chevron.right",
                    label: "Check out the source code"
                )
                ModernAboutLink(
                    destination: URLs.donate,
                    systemImage: "heart",
                    label: "Support this project"
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

struct SupportTab: View {
    @State private var isHoveringQuit = false
    private let copyright = "AGPL-3.0 © Mihai-Eduard Ghețu"
    private var licenseURL: URL {
        URL(string: "https://github.com/turtle-key/TabLift/blob/main/LICENSE")!
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section {
                    AccessibilityPermissionCheckView()
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
    }
}
