import SwiftUI
import ServiceManagement
import AVKit

enum PerformanceProfile: String, CaseIterable, Identifiable {
    case detailed = "Relaxed"
    case balanced = "Default"
    case fast = "Speedy"
    var id: String { rawValue }

    var hoverDelay: Double {
        switch self {
        case .detailed: return 0.40
        case .balanced: return 0.20
        case .fast: return 0.08
        }
    }
    var fadeOutDuration: Double {
        switch self {
        case .detailed: return 0.40
        case .balanced: return 0.25
        case .fast: return 0.10
        }
    }
}

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

let footerHeight: CGFloat = 20

struct GeneralSettingsTab: View {
    @AppStorage(WindowManager.restoreAllKey) var restoreAllWindows: Bool = false
    @AppStorage(WindowManager.openWindowKey) private var openNewWindowStorage: Bool = true
    @AppStorage(WindowManager.minimizePreviousWindowKey) private var minimizePreviousWindowStorage: Bool = false
    @AppStorage("showMenuBarIcon") var showMenuBarIcon: Bool = true
    @AppStorage("showDockPopups") var showDockPopups: Bool = true
    @AppStorage("startAtLogin") var startAtLogin: Bool = true
    @AppStorage("showDockIcon") var showDockIcon: Bool = false

    // NEW: Dock click behavior toggle (used by DockClickMonitor)
    // When true: Dock click toggles all windows for that app (minimize all / restore all).
    // When false: Dock click minimizes only the current window; if all windows are minimized it restores them all.
    @AppStorage("restoreAllOnDockClick") var restoreAllOnDockClick: Bool = false

    @State private var isHoveringQuit = false
    @AppStorage("maximizeBehavior") var maximizeBehaviorRaw: String = MaximizeBehavior.fill.rawValue

    var maximizeBehavior: MaximizeBehavior {
        MaximizeBehavior(rawValue: maximizeBehaviorRaw) ?? .fullscreen
    }

    @State private var openNewWindow: Bool = true
    @State private var minimizePreviousWindow: Bool = false
    @State private var hoveredDemo: DemoType? = nil

    enum DemoType { case restore, opennew, minimizeprev }

    private let copyright = "AGPL-3.0 © Mihai-Eduard Ghețu"
    private var licenseURL: URL {
        URL(string: "https://github.com/turtle-key/TabLift/blob/main/LICENSE")!
    }

    @AppStorage("performanceProfile") var performanceProfileRaw: String = PerformanceProfile.balanced.rawValue
    @AppStorage("dockPreviewSpeed") var dockPreviewSpeed: Double = PerformanceProfile.balanced.hoverDelay
    @AppStorage("dockPreviewFade") var dockPreviewFade: Double = PerformanceProfile.balanced.fadeOutDuration

    var selectedProfile: PerformanceProfile {
        PerformanceProfile(rawValue: performanceProfileRaw) ?? .balanced
    }

    private let helpTextMaxWidth: CGFloat = 320
    private let helpTextMaxHeight: CGFloat = 46

    var body: some View {
        VStack(spacing: 20) {
            Form {
                Section(header: Label("App Launch & Appearance", systemImage: "rectangle.stack").font(.headline)) {
                    Toggle(isOn: $startAtLogin) {
                        Text("Start at login").font(.body)
                    }
                    .help("Launch TabLift automatically when you log in to your Mac.")

                    Toggle(isOn: $showMenuBarIcon) {
                        Text("Show in menu bar").font(.body)
                        if !showMenuBarIcon {
                            Text("To show the settings, launch TabLift again.")
                                .foregroundColor(.secondary)
                                .font(.caption)
                                .padding(.top, 2)
                        }
                    }
                    .help("Show or hide the TabLift icon in your menu bar for quick access.")

                    Toggle(isOn: $showDockIcon) {
                        Text("Show in Dock").font(.body)
                    }
                    .help("Display the icon of the app in the Dock. Works just like a normal app.")
                }
                
                Section(header: Label("Dock Features", systemImage: "dock.rectangle").font(.headline)) {
                    Toggle(isOn: $showDockPopups) {
                        Text("Show Window Previews in Dock").font(.body)
                    }
                    .help("Show a popup with app windows when hovering over icons in the Dock.")

                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Green Button Action", selection: $maximizeBehaviorRaw) {
                            ForEach(MaximizeBehavior.allCases) { beh in
                                Text(beh.rawValue).tag(beh.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .help("Choose what happens when you click the green maximize button in window previews.")

                        Text(maximizeBehavior.explanation)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)
                            .frame(maxWidth: 340, alignment: .leading)
                    }
                    .padding(.top, 2)

                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Dock preview speed", selection: $performanceProfileRaw) {
                            ForEach(PerformanceProfile.allCases) { profile in
                                Text(profile.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: performanceProfileRaw) { newRaw in
                            let newProfile = PerformanceProfile(rawValue: newRaw) ?? .balanced
                            dockPreviewSpeed = newProfile.hoverDelay
                            dockPreviewFade = newProfile.fadeOutDuration
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Profile: \(selectedProfile.rawValue)").font(.headline)
                            Text("How quickly the Dock preview appears and fades out when you hover.\n")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            HStack {
                                Text("Preview delay: \(String(format: "%.2f", selectedProfile.hoverDelay))s")
                                Text("Fade out: \(String(format: "%.2f", selectedProfile.fadeOutDuration))s")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 2)

                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(isOn: $restoreAllOnDockClick) {
                            Text("Dock click toggles all windows").font(.body)
                        }
                        .help("When enabled: Clicking an app’s Dock icon minimizes all its windows if any are visible, or restores all if they are all minimized. When disabled: Clicking the Dock icon minimizes only the current window when the app is frontmost; if all windows are minimized, it restores them all.")

                        Text(
                            restoreAllOnDockClick
                            ? "Enabled: Clicking an app’s Dock icon will minimize all of its windows if any are visible, or restore all if they’re all minimized."
                            : "Disabled: Clicking an app’s Dock icon will minimize only the current window when the app is frontmost. If all windows are minimized, it restores them all."
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 340, alignment: .leading)
                        .padding(.top, 2)
                    }
                    .padding(.top, 2)
                }
               
                Section(header: Label("Window Switching Behavior", systemImage: "arrow.triangle.swap").font(.headline)) {
                    VStack(alignment: .leading, spacing: 24) {
                        DemoSection(
                            toggle: Toggle(isOn: $restoreAllWindows) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Restore all minimized windows on app switch").font(.body)
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
                        DemoSection(
                            toggle: Toggle(isOn: $openNewWindow) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Automatically open a window for apps with no windows").font(.body)
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
                        DemoSection(
                            toggle: Toggle(isOn: $minimizePreviousWindow) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Minimize previous window on app switch").font(.body)
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
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    TabliftCheatSheetView()
                        .padding(.top, 14)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: 420)
                    Form {
                        Section {
                            AccessibilityPermissionCheckView()
                            ShieldBannerSettings()
                        }
                        Section {
                            CheckForUpdatesView()
                        }
                        .modifier(SectionViewModifier())
                    }
                    .modifier(FormViewModifier())
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.bottom, 20)
            FooterView(isHoveringQuit: $isHoveringQuit)
        }
    }
}

struct TabliftCheatSheetView: View {
    var body: some View {
        VStack(spacing: 15) {
            HStack(alignment: .center, spacing: 18) {
                KeyboardFaceView()
                VStack(alignment: .leading, spacing: 2) {
                    Text("TabLift Cheat Sheet")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(Color.accentColor)
                        .shadow(color: Color.accentColor.opacity(0.09), radius: 1, x: 0, y: 1)
                    Text("Essential shortcuts for smooth window switching.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            VStack(spacing: 8) {
                CheatSheetRow(
                    keys: ["⌘", "⇧", "M"],
                    description: "Minimize all windows of the frontmost app"
                )
                CheatSheetRowMouseDock(
                    description: "Restore or minimize windows by clicking the Dock icon"
                )
                CheatSheetRow(
                    keys: ["⌘", "`"],
                    description: "Restore next minimized window in the frontmost app"
                )
                CheatSheetRow(
                    keys: ["⌘", "Tab"],
                    description: "Switch between running apps"
                )
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.85))
                .shadow(color: Color.accentColor.opacity(0.10), radius: 7, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(Color.accentColor.opacity(0.19), lineWidth: 1)
        )
    }
}

struct KeyboardFaceView: View {
    var body: some View {
        HStack(spacing: 7) {
            KeyCap(symbol: "⌘")
            KeyCapKeyboardFace()
        }
    }
}

struct KeyCap: View {
    let symbol: String
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(gradient: Gradient(colors: [
                        Color.white,
                        Color(NSColor.systemGray).opacity(0.18)
                    ]), startPoint: .top, endPoint: .bottom)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.accentColor.opacity(0.75), lineWidth: 2)
                )
                .shadow(color: Color.accentColor.opacity(0.13), radius: 3, x: 0, y: 1)
            Text(symbol)
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundColor(Color.accentColor)
        }
        .frame(width: 40, height: 40)
    }
}

struct KeyCapKeyboardFace: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(gradient: Gradient(colors: [
                        Color.white,
                        Color(NSColor.systemGray).opacity(0.18)
                    ]), startPoint: .top, endPoint: .bottom)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.accentColor.opacity(0.75), lineWidth: 2)
                )
                .shadow(color: Color.accentColor.opacity(0.13), radius: 3, x: 0, y: 1)
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.accentColor.opacity(0.85))
                        .frame(width: 5, height: 5)
                    Circle()
                        .fill(Color.accentColor.opacity(0.85))
                        .frame(width: 5, height: 5)
                }
                .padding(.top, 8)
                SmileShape()
                    .stroke(Color.accentColor.opacity(0.8), lineWidth: 2)
                    .frame(width: 18, height: 10)
                    .offset(y: -2)
            }
        }
        .frame(width: 40, height: 40)
    }
}

struct SmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addArc(center: CGPoint(x: rect.midX, y: rect.minY + 4),
                    radius: rect.width * 0.33,
                    startAngle: .degrees(33),
                    endAngle: .degrees(147),
                    clockwise: false)
        return path
    }
}

struct CheatSheetRow: View {
    let keys: [String]
    let description: String

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: 0) {
                HStack(spacing: 4) {
                    ForEach(keys, id: \.self) { key in
                        KeyCap(symbol: key)
                    }
                }
                Text(description)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                    .frame(width: geometry.size.width - 40 * CGFloat(keys.count) - 12, alignment: .leading)
                    .padding(.leading, 12)
            }
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.19))
            )
        }
        .frame(height: 56)
    }
}

struct CheatSheetRowMouseDock: View {
    let description: String
    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: 0) {
                HStack(spacing: 4) {
                    MouseIcon()
                    DockKeyCap()
                }
                Text(description)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                    .frame(width: geometry.size.width - 40 * 2 - 12, alignment: .leading)
                    .padding(.leading, 12)
            }
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.19))
            )
        }
        .frame(height: 56)
    }
}

struct MouseIcon: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.systemGray))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor.opacity(0.4), lineWidth: 1)
                )
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.accentColor.opacity(0.85))
                    .frame(width: 4, height: 12)
                    .cornerRadius(2)
                    .offset(y:-8)
            }
        }
        .frame(width: 40, height: 40)
    }
}

struct DockKeyCap: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(
                LinearGradient(gradient: Gradient(colors: [
                    Color.white,
                    Color(NSColor.systemGray).opacity(0.18)
                ]), startPoint: .top, endPoint: .bottom)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1.2)
            )
            .shadow(color: Color.accentColor.opacity(0.09), radius: 1, x: 0, y: 1)
            .frame(width: 40, height: 40)
    }
}

struct ShieldBannerSettings: View {
    @AppStorage("showShieldBanner") private var showShieldBanner: Bool = true

    var body: some View {
        Toggle("Show accessibility shield tips", isOn: $showShieldBanner)
            .toggleStyle(.switch)
            .help("Show a brief tip when macOS temporarily blocks Accessibility after unlock/wake.")
    }
}
