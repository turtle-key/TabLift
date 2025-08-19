import SwiftUI
import ServiceManagement
import AVKit

private final class _WindowProbe: NSView {
    var onWindow: (NSWindow) -> Void = { _ in }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let _ = window {
            DispatchQueue.main.async { [weak self] in
                if let win = self?.window { self?.onWindow(win) }
            }
        }
    }
}
private struct WindowProbe: NSViewRepresentable {
    let onWindow: (NSWindow) -> Void
    func makeNSView(context: Context) -> _WindowProbe {
        let v = _WindowProbe()
        v.onWindow = onWindow
        return v
    }
    func updateNSView(_ nsView: _WindowProbe, context: Context) {
        nsView.onWindow = onWindow
    }
}

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
    @State private var compensate = false
    @State private var topPad: CGFloat = 0
    @State private var didLoad = false
    var body: some View {
        TabView {
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
                .frame(width: 480, height: 560)
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gearshape") }
                .frame(width: 480, height: 560)
            SupportTab()
                .tabItem { Label("Support", systemImage: "lifepreserver") }
                .frame(width: 480, height: 560)
        }
        .background(
            Group {
                AboutTab().opacity(0).frame(width: 0, height: 0)
                GeneralSettingsTab().opacity(0).frame(width: 0, height: 0)
                SupportTab().opacity(0).frame(width: 0, height: 0)
            }
        )
        .padding(.top, compensate ? topPad : 0)
        .frame(width: 480, height: 560)
        .background(WindowProbe { win in
            let h = win.frame.height - win.contentLayoutRect.height
            let transparent = win.titlebarAppearsTransparent && win.styleMask.contains(.fullSizeContentView)
            
            DispatchQueue.main.async {
                let newCompensate = !transparent && h > 0
                if topPad != h || compensate != newCompensate {
                    topPad = h
                    compensate = newCompensate
                }
            }

            if #available(macOS 11, *) {
                win.titleVisibility = .hidden
                win.titlebarAppearsTransparent = false
            } else {
                win.titleVisibility = .visible
            }
        })
        .animation(didLoad ? .easeInOut(duration: 0.2) : nil, value: compensate)
        .onAppear { didLoad = true }
    }
}

class SettingsWindow: NSWindow {
    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command), let chars = event.charactersIgnoringModifiers?.lowercased() else {
            super.keyDown(with: event)
            return
        }
        switch chars {
        case "w":
            performClose(nil)
        case "m":
            performMiniaturize(nil)
        default:
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
    @AppStorage("windowSwitcher") var showWindowSwitcher: Bool = true
    @AppStorage("restoreAllOnDockClick") var restoreAllOnDockClick: Bool = false
    @AppStorage("maximizeBehavior") var maximizeBehaviorRaw: String = MaximizeBehavior.fill.rawValue
    @AppStorage("dockPopupAutoDismiss") var dockPopupAutoDismiss: Bool = true
    @AppStorage("performanceProfile") var performanceProfileRaw: String = PerformanceProfile.balanced.rawValue
    @AppStorage("dockPreviewSpeed") var dockPreviewSpeed: Double = PerformanceProfile.balanced.hoverDelay
    @AppStorage("dockPreviewFade") var dockPreviewFade: Double = PerformanceProfile.balanced.fadeOutDuration
    @State private var openNewWindow: Bool = true
    @State private var minimizePreviousWindow: Bool = false
    @State private var hoveredDemo: DemoType? = nil
    @State private var isHoveringQuit = false
    @StateObject var shortcutPref = ShortcutPreference()
    enum DemoType { case restore, opennew, minimizeprev }
    private let helpTextMaxWidth: CGFloat = 320
    private let helpTextMaxHeight: CGFloat = 5
    var selectedProfile: PerformanceProfile { PerformanceProfile(rawValue: performanceProfileRaw) ?? .balanced }
    var maximizeBehavior: MaximizeBehavior { MaximizeBehavior(rawValue: maximizeBehaviorRaw) ?? .fullscreen }

    var body: some View {
        VStack(spacing: 20) {
            Form {
                Section(header: Label("App Launch & Appearance", systemImage: "rectangle.stack").font(.headline)) {
                    Toggle("Start at login", isOn: $startAtLogin)
                    Toggle(isOn: $showMenuBarIcon) {
                        Text("Show in menu bar")
                        if !showMenuBarIcon {
                            Text("To show the settings, launch TabLift again.")
                                .foregroundColor(.secondary).font(.caption).padding(.top, 2)
                        }
                    }
                    Toggle("Show in Dock", isOn: $showDockIcon)
                }
                Section(header: Label("Dock Features", systemImage: "dock.rectangle").font(.headline)) {
                    Toggle("Show Window Previews in Dock", isOn: $showDockPopups)
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Green Button Action", selection: $maximizeBehaviorRaw) {
                            ForEach(MaximizeBehavior.allCases) { beh in
                                Text(beh.rawValue).tag(beh.rawValue)
                            }
                        }.pickerStyle(.segmented)
                        Text(maximizeBehavior.explanation)
                            .font(.caption).foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)
                            .frame(maxWidth: 340, alignment: .leading)
                    }.padding(.top, 2)
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("Dock preview speed", selection: $performanceProfileRaw) {
                            ForEach(PerformanceProfile.allCases) { profile in
                                Text(profile.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: performanceProfileRaw) { newRaw in
                            let p = PerformanceProfile(rawValue: newRaw) ?? .balanced
                            dockPreviewSpeed = p.hoverDelay
                            dockPreviewFade = p.fadeOutDuration
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Profile: \(selectedProfile.rawValue)").font(.headline)
                            Text("How quickly the Dock preview appears and fades out when you hover.\n")
                                .font(.caption).foregroundColor(.secondary)
                            HStack {
                                Text("Preview delay: \(String(format: "%.2f", selectedProfile.hoverDelay))s")
                                Text("Fade out: \(String(format: "%.2f", selectedProfile.fadeOutDuration))s")
                            }.font(.caption).foregroundColor(.secondary)
                        }
                    }.padding(.vertical, 2)
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Dock click toggles all windows", isOn: $restoreAllOnDockClick)
                        Text(
                            restoreAllOnDockClick
                            ? "Enabled: Clicking an app’s Dock icon will minimize all if visible, or restore all."
                            : "Disabled: Clicking an app’s Dock icon minimizes only current window if frontmost, restores all if all minimized."
                        )
                        .font(.caption).foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 340, alignment: .leading)
                        .padding(.top, 2)
                    }.padding(.top, 2)
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Dismiss Dock window preview after click", isOn: $dockPopupAutoDismiss)
                        Text(
                            dockPopupAutoDismiss
                            ? "The Dock window preview popup will disappear after clicking a window or its action buttons."
                            : "The Dock window preview will remain open after clicking, allowing multiple actions."
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 340, alignment: .leading)
                        .padding(.top, 2)
                    }.padding(.top, 2)
                }
                Section(header: Label("Window Switching Behavior", systemImage: "arrow.triangle.swap").font(.headline)) {
                    VStack(alignment: .leading, spacing: 24) {
                        Toggle(isOn: $showWindowSwitcher) {
                            Text("Show the window switcher pop up for the frontmost app")
                            if !showWindowSwitcher {
                                Text("When disabled, the CMD ` doesn't activate the window switching pop up")
                                    .foregroundColor(.secondary).font(.caption).padding(.top, 2)
                            }
                        }
                        if showWindowSwitcher{
                            ShortcutRecorderView(preference: shortcutPref)
                        }
                        DemoSection(
                            toggle: Toggle(isOn: $restoreAllWindows) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Restore all minimized windows on app switch")
                                    if !restoreAllWindows {
                                        Text("When disabled, only the most recently minimized window will be restored.")
                                            .foregroundColor(.secondary).font(.caption).padding(.top, 2)
                                    }
                                }
                            },
                            demoType: .restore,
                            hoveredDemo: $hoveredDemo,
                            videoName: "restoreall",
                            helpTextActive: "Enabled: Switching to an app restores all minimized windows.",
                            helpTextInactive: "Disabled: Only the last minimized window is restored.",
                            maxWidth: helpTextMaxWidth,
                            maxHeight: helpTextMaxHeight
                        )
                        DemoSection(
                            toggle: Toggle(isOn: $openNewWindow) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Automatically open a window for apps with no windows")
                                    if !openNewWindow {
                                        Text("When disabled, switching to an app without windows won't open a new window.")
                                            .foregroundColor(.secondary).font(.caption).padding(.top, 2)
                                    }
                                }
                            }
                            .onChange(of: openNewWindow) { value in
                                openNewWindowStorage = value
                                if value {
                                    minimizePreviousWindow = false
                                    minimizePreviousWindowStorage = false
                                }
                            },
                            demoType: .opennew,
                            hoveredDemo: $hoveredDemo,
                            videoName: "opennew",
                            helpTextActive: "Enabled: A new window is opened automatically.",
                            helpTextInactive: "Disabled: Switching does nothing if no windows.",
                            maxWidth: helpTextMaxWidth,
                            maxHeight: helpTextMaxHeight
                        )
                        DemoSection(
                            toggle: Toggle(isOn: $minimizePreviousWindow) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Minimize previous window on app switch")
                                    if !minimizePreviousWindow {
                                        Text("When disabled, switching to another app won't automatically minimize the previous one.")
                                            .foregroundColor(.secondary).font(.caption).padding(.top, 2)
                                    }
                                    if openNewWindow && minimizePreviousWindow {
                                        Text("Tip: Cannot enable with 'Automatically open a window'.")
                                            .foregroundColor(.red).font(.caption).padding(.top, 2)
                                    }
                                }
                            }
                            .onChange(of: minimizePreviousWindow) { value in
                                minimizePreviousWindowStorage = value
                                if value {
                                    openNewWindow = false
                                    openNewWindowStorage = false
                                }
                            },
                            demoType: .minimizeprev,
                            hoveredDemo: $hoveredDemo,
                            videoName: "minimizeprev",
                            helpTextActive: "Enabled: Previous app window minimized.",
                            helpTextInactive: "Disabled: Previous windows stay visible.",
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            openNewWindow = openNewWindowStorage
            minimizePreviousWindow = minimizePreviousWindowStorage
        }
        .onChange(of: showMenuBarIcon) { MenuBarManager.shared.showMenuBarIcon(show: $0) }
        .onChange(of: startAtLogin) { value in
            if value { try? SMAppService.mainApp.register() }
            else { try? SMAppService.mainApp.unregister() }
        }
    }
}

struct FooterView: View {
    @Binding var isHoveringQuit: Bool
    private var licenseURL: URL { URL(string: "https://github.com/turtle-key/TabLift/blob/main/LICENSE")! }
    var body: some View {
        HStack {
            Link(destination: licenseURL) {
                Text("AGPL-3.0 © Mihai-Eduard Ghețu")
                    .font(.footnote).foregroundColor(.gray)
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
            DemoVideoScreen(fileName: videoName, play: delayedPlay)
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
                            let p = AVPlayer(url: url)
                            p.actionAtItemEnd = .pause
                            player = p
                        }
                        // Only prepare, do not repeatedly seek
                        player?.pause()
                    }
                    .onChange(of: play) { playing in
                        guard let p = player else { return }
                        if playing {
                            p.seek(to: .zero)
                            p.play()
                        } else {
                            p.pause()
                        }
                    }
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
        let v = AVPlayerLayerView()
        v.player = player
        v.playerLayer.videoGravity = .resizeAspectFill
        return v
    }
    func updateNSView(_ nsView: AVPlayerLayerView, context: Context) {
        nsView.player = player
        nsView.playerLayer.videoGravity = .resizeAspectFill
    }
}

class AVPlayerLayerView: NSView {
    var player: AVPlayer? { didSet { playerLayer.player = player } }
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
    private let appIconName = "AppIcon"
    @State private var isHoveringQuit = false
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
                    .resizable().aspectRatio(contentMode: .fit)
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
                Link(destination: URL(string: "https://github.com/turtle-key/TabLift/releases/tag/\(appVersion)")!) {
                    Text(appVersion)
                        .font(.body)
                        .foregroundColor(.gray)
                        .padding(.bottom, 6)
                }
            }
            .frame(maxWidth: .infinity).padding(.bottom, 4)
            Spacer()
            VStack(spacing: 14) {
                ModernAboutLink(destination: URLs.helppage, systemImage: "info.circle", label: "Tablift Help")
                ModernAboutLink(destination: URLs.repo, systemImage: "chevron.left.slash.chevron.right", label: "Check out the source code")
                ModernAboutLink(destination: URLs.donate, systemImage: "heart", label: "Support this project")
                ModernAboutLink(destination: URLs.email, systemImage: "envelope", label: "Email me")
            }
            .frame(maxWidth: 320).padding(.vertical, 10).padding(.horizontal, 16).multilineTextAlignment(.center)
            Spacer()
            .padding(.bottom, 20)
            FooterView(isHoveringQuit: $isHoveringQuit)
        }
        .frame(width: 480, height: 560)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .animation(.easeInOut(duration: 0.14), value: hovering)
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

struct ModernQuitButton: View {
    @Binding var isHovering: Bool
    var body: some View {
        Button {
            NSApplication.shared.terminate(nil)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "power").font(.system(size: 14, weight: .semibold))
                Text("Quit").font(.footnote).fontWeight(.medium)
            }
            .foregroundColor(isHovering ? .white : .red)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovering ? Color.red : Color.clear)
            )
            .animation(.easeInOut(duration: 0.15), value: isHovering)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
}

struct TabliftCheatSheetView: View {
    // Keycap and gap sizes
    static let keycapWidth: CGFloat = 40
    static let keycapGap: CGFloat = 4
    static var threeKeyWidth: CGFloat {
        3 * keycapWidth + 2 * keycapGap + 10
    }
    @ObservedObject var shortcutPref = ShortcutPreference()
    var dividerXOffset: CGFloat {
        let keys = shortcutPref.displayKeys.isEmpty ? ["⌘", "`"] : shortcutPref.displayKeys
        let shortcutWidth = CGFloat(keys.count) * TabliftCheatSheetView.keycapWidth + CGFloat(max(keys.count - 1, 0)) * TabliftCheatSheetView.keycapGap + 10
        return max(TabliftCheatSheetView.threeKeyWidth, shortcutWidth)
    }
    var body: some View {
        VStack(spacing: 15) {
            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TabLift Cheat Sheet")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.accentColor)
                        .shadow(color: Color.accentColor.opacity(0.09), radius: 1, x: 0, y: 1)
                    Text("Essential shortcuts for smooth window switching.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            ZStack(alignment: .leading) {
                // Single vertical divider spanning the rows area, flush with right edge of widest keycap/icon
                Rectangle()
                    .fill(Color.accentColor.opacity(0.3))
                    .frame(width: 1)
                    .padding(.vertical, 0)
                    .offset(x: dividerXOffset)
                VStack(spacing: 8) {
                    CheatSheetRow(keys: ["⌘", "⇧", "M"], description: "Minimize all windows of the frontmost app", dividerXOffset: dividerXOffset)
                    CheatSheetRowMouseDock(description: "Restore or minimize windows with Dock click", dividerXOffset: dividerXOffset)
                    CheatSheetRowShortcut(dividerXOffset: dividerXOffset)
                    CheatSheetRow(keys: ["⌘", "Tab"], description: "Switch between running apps", dividerXOffset: dividerXOffset)
                }
                .padding(.top, 4)
            }
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

struct CheatSheetRowShortcut: View {
    @ObservedObject var shortcutPref = ShortcutPreference()
    var dividerXOffset: CGFloat

    var body: some View {
        let keys = shortcutPref.displayKeys.isEmpty ? ["⌘", "`"] : shortcutPref.displayKeys
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(keys, id: \.self) { KeyCap(symbol: $0) }
            }
            .frame(width: dividerXOffset, alignment: .leading)
            .padding(.trailing, 6)

            Text("Restore next window in the frontmost app")
                .font(.system(size: 14, weight: .regular, design: .default))
                .padding(.leading, 6)
                .foregroundColor(.primary)

            Spacer()
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.19))
        )
        .frame(height: 56)
    }
}


struct KeyCap: View {
    let symbol: String
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.accentColor.opacity(0.75), lineWidth: 2)
                )
                .shadow(color: Color.accentColor.opacity(0.13), radius: 3, x: 0, y: 1)
            Text(symbol)
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundColor(.accentColor)
        }
        .frame(width: 40, height: 40)
    }
}

struct CheatSheetRow: View {
    let keys: [String]
    let description: String
    let dividerXOffset: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            // Keycaps section with fixed width
            HStack(spacing: 4) {
                ForEach(keys, id: \.self) { KeyCap(symbol: $0) }
            }
            .frame(width: dividerXOffset, alignment: .leading)
            .padding(.trailing, 6)

            // Text starts immediately after divider
            Text(description)
                .font(.system(size: 14, weight: .regular, design: .default))
                .padding(.leading, 6)
                .foregroundColor(.primary)

            Spacer()
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.19))
        )
        .frame(height: 56)
    }
}

struct CheatSheetRowMouseDock: View {
    let description: String
    let dividerXOffset: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                MouseIcon()
                DockKeyCap()
            }
            .frame(width: dividerXOffset, alignment: .leading)
            .padding(.trailing, 6)

            Text(description)
                .font(.system(size: 14, weight: .regular, design: .default))
                .padding(.leading, 6)
                .foregroundColor(.primary)

            Spacer()
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.19))
        )
        .frame(height: 56)
    }
}

struct MouseIcon: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.accentColor.opacity(0.75), lineWidth: 2)
                )
                .shadow(color: Color.accentColor.opacity(0.13), radius: 3, x: 0, y: 1)
            Image(systemName: "cursorarrow")
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(.accentColor)
        }
        .frame(width: 40, height: 40)
    }
}

struct DockKeyCap: View {
    var body: some View {
        Image("FinderIcon")
            .resizable()
            .scaledToFill()
            .frame(width: 50, height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous)) // clip to rounded rect
            .shadow(color: Color.accentColor.opacity(0.09), radius: 1, x: 0, y: 1)
    }
}

struct ShieldBannerSettings: View {
    @AppStorage("showShieldBanner") private var showShieldBanner: Bool = true
    var body: some View {
        Toggle("Show accessibility shield tips", isOn: $showShieldBanner)
            .toggleStyle(.switch)
    }
}
