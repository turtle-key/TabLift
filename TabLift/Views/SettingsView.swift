import SwiftUI
import ServiceManagement
import AVKit

private final class _WindowProbe: NSView {
    var onWindow: (NSWindow) -> Void = { _ in }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let w = window {
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
    var localizedName: String {
        switch self {
        case .detailed: return loc(.profileRelaxed)
        case .balanced: return loc(.profileDefault)
        case .fast: return loc(.profileSpeedy)
        }
    }
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
    @ObservedObject private var locManager = LocalizationManager.shared
    var body: some View {
        TabView {
            AboutTab()
                .tabItem { Label(loc(.tabAbout), systemImage: "info.circle") }
            GeneralSettingsTab()
                .tabItem { Label(loc(.tabGeneral), systemImage: "gearshape") }
            SupportTab()
                .tabItem { Label(loc(.tabSupport), systemImage: "lifepreserver") }
        }
        .padding(.top, compensate ? topPad : 0)
        .frame(width: 480, height: 560)
        .background(WindowProbe { win in
            let h = win.frame.height - win.contentLayoutRect.height
            let transparent = win.titlebarAppearsTransparent && win.styleMask.contains(.fullSizeContentView)
            if #available(macOS 11, *) {
                win.titleVisibility = .hidden
                win.titlebarAppearsTransparent = false
            } else {
                win.titleVisibility = .visible
            }
            if !transparent && h > 0 {
                topPad = h
                compensate = true
            } else {
                compensate = false
            }
        })
        .animation(.easeInOut(duration: 0.2), value: compensate)
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
    @AppStorage("silentLaunch") var silentLaunch: Bool = false
    @State private var openNewWindow: Bool = true
    @State private var minimizePreviousWindow: Bool = false
    @State private var hoveredDemo: DemoType? = nil
    @State private var isHoveringQuit = false
    @ObservedObject private var locManager = LocalizationManager.shared
    enum DemoType { case restore, opennew, minimizeprev }
    private let helpTextMaxWidth: CGFloat = 320
    private let helpTextMaxHeight: CGFloat = 5
    var selectedProfile: PerformanceProfile { PerformanceProfile(rawValue: performanceProfileRaw) ?? .balanced }
    var maximizeBehavior: MaximizeBehavior { MaximizeBehavior(rawValue: maximizeBehaviorRaw) ?? .fullscreen }

    var body: some View {
        VStack(spacing: 20) {
            Form {
                Section(header: Label(loc(.appLaunchAppearance), systemImage: "rectangle.stack").font(.headline)) {
                    Toggle(loc(.startAtLogin), isOn: $startAtLogin)
                    Toggle(isOn: $showMenuBarIcon) {
                        Text(loc(.showInMenuBar))
                        if !showMenuBarIcon {
                            Text(loc(.showMenuBarHint))
                                .foregroundColor(.secondary).font(.caption).padding(.top, 2)
                        }
                    }
                    Toggle(loc(.showInDock), isOn: $showDockIcon)

                    VStack(alignment: .leading, spacing: 6) {
                        Picker(loc(.language), selection: Binding(
                            get: { locManager.currentLanguage },
                            set: { locManager.setLanguage($0) }
                        )) {
                            ForEach(AppLanguage.allCases) { lang in
                                Text(lang.displayName).tag(lang)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 200)
                    }
                    .padding(.vertical, 4)
                    Toggle(isOn: $silentLaunch) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(loc(.silentLaunch))
                            Text(loc(.silentLaunchEnabled))
                                .foregroundColor(.secondary).font(.caption).padding(.top, 2)
                        }
                    }
                }
                Section(header: Label(loc(.dockFeatures), systemImage: "dock.rectangle").font(.headline)) {
                    Toggle(loc(.showWindowPreviews), isOn: $showDockPopups)
                    VStack(alignment: .leading, spacing: 8) {
                        Picker(loc(.greenButtonAction), selection: $maximizeBehaviorRaw) {
                            ForEach(MaximizeBehavior.allCases) { beh in
                                Text(beh.localizedName).tag(beh.rawValue)
                            }
                        }.pickerStyle(.segmented)
                        Text(maximizeBehavior.explanation)
                            .font(.caption).foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)
                            .frame(maxWidth: 340, alignment: .leading)
                    }.padding(.top, 2)
                    VStack(alignment: .leading, spacing: 10) {
                        Picker(loc(.dockPreviewSpeed), selection: $performanceProfileRaw) {
                            ForEach(PerformanceProfile.allCases) { profile in
                                Text(profile.localizedName)
                            }
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: performanceProfileRaw) { newRaw in
                            let p = PerformanceProfile(rawValue: newRaw) ?? .balanced
                            dockPreviewSpeed = p.hoverDelay
                            dockPreviewFade = p.fadeOutDuration
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(loc(.profileLabel, selectedProfile.localizedName)).font(.headline)
                            Text(loc(.profileDescription))
                                .font(.caption).foregroundColor(.secondary)
                            HStack {
                                Text(loc(.previewDelay, String(format: "%.2f", selectedProfile.hoverDelay)))
                                Text(loc(.fadeOut, String(format: "%.2f", selectedProfile.fadeOutDuration)))
                            }.font(.caption).foregroundColor(.secondary)
                        }
                    }.padding(.vertical, 2)
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(loc(.dockClickTogglesAll), isOn: $restoreAllOnDockClick)
                        Text(
                            restoreAllOnDockClick
                            ? loc(.dockClickEnabled)
                            : loc(.dockClickDisabled)
                        )
                        .font(.caption).foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 340, alignment: .leading)
                        .padding(.top, 2)
                    }.padding(.top, 2)
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle(loc(.dockDismissAfterClick), isOn: $dockPopupAutoDismiss)
                        Text(
                            dockPopupAutoDismiss
                            ? loc(.dockDismissEnabled)
                            : loc(.dockDismissDisabled)
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 340, alignment: .leading)
                        .padding(.top, 2)
                    }.padding(.top, 2)
                }
                Section(header: Label(loc(.windowSwitchingBehavior), systemImage: "arrow.triangle.swap").font(.headline)) {
                    VStack(alignment: .leading, spacing: 24) {
                        Toggle(isOn: $showWindowSwitcher) {
                            Text(loc(.showWindowSwitcher))
                            if !showWindowSwitcher {
                                Text(loc(.windowSwitcherDisabled))
                                    .foregroundColor(.secondary).font(.caption).padding(.top, 2)
                            }
                        }
                        DemoSection(
                            toggle: Toggle(isOn: $restoreAllWindows) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(loc(.restoreAllOnSwitch))
                                    if !restoreAllWindows {
                                        Text(loc(.restoreAllDisabled))
                                            .foregroundColor(.secondary).font(.caption).padding(.top, 2)
                                    }
                                }
                            },
                            demoType: .restore,
                            hoveredDemo: $hoveredDemo,
                            videoName: "restoreall",
                            helpTextActive: loc(.restoreHelpEnabled),
                            helpTextInactive: loc(.restoreHelpDisabled),
                            maxWidth: helpTextMaxWidth,
                            maxHeight: helpTextMaxHeight
                        )
                        DemoSection(
                            toggle: Toggle(isOn: $openNewWindow) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(loc(.autoOpenWindow))
                                    if !openNewWindow {
                                        Text(loc(.autoOpenDisabled))
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
                            helpTextActive: loc(.autoOpenHelpEnabled),
                            helpTextInactive: loc(.autoOpenHelpDisabled),
                            maxWidth: helpTextMaxWidth,
                            maxHeight: helpTextMaxHeight
                        )
                        DemoSection(
                            toggle: Toggle(isOn: $minimizePreviousWindow) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(loc(.minimizePrevious))
                                    if !minimizePreviousWindow {
                                        Text(loc(.minimizePreviousDisabled))
                                            .foregroundColor(.secondary).font(.caption).padding(.top, 2)
                                    }
                                    if openNewWindow && minimizePreviousWindow {
                                        Text(loc(.tipCannotEnable))
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
                            helpTextActive: loc(.minimizePrevHelpEnabled),
                            helpTextInactive: loc(.minimizePrevHelpDisabled),
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
        .onChange(of: showMenuBarIcon) { MenuBarManager.shared.showMenuBarIcon(show: $0) }
        .onChange(of: startAtLogin) { value in
            if value { try? SMAppService.mainApp.register() }
            else { try? SMAppService.mainApp.unregister() }
        }
        .environmentObject(locManager)
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
                        player?.seek(to: .zero)
                        player?.pause()
                    }
                    .onChange(of: play) { playing in
                        guard let p = player else { return }
                        if playing {
                            p.seek(to: .zero)
                            p.play()
                        } else {
                            p.pause()
                            p.seek(to: .zero)
                        }
                    }
                    .animation(.easeInOut(duration: 0.22), value: play)
            } else {
                Text(loc(.videoMissing)).foregroundColor(.red)
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
    @ObservedObject private var locManager = LocalizationManager.shared
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
                Text(loc(.appDescription))
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
                ModernAboutLink(destination: URLs.helppage, systemImage: "info.circle", label: loc(.tabliftHelp))
                ModernAboutLink(destination: URLs.repo, systemImage: "chevron.left.slash.chevron.right", label: loc(.checkSourceCode))
                ModernAboutLink(destination: URLs.donate, systemImage: "heart", label: loc(.supportProject))
                ModernAboutLink(destination: URLs.email, systemImage: "envelope", label: loc(.emailMe))
            }
            .frame(maxWidth: 320).padding(.vertical, 10).padding(.horizontal, 16).multilineTextAlignment(.center)
            Spacer()
            HStack {
                Link(destination: URL(string: "https://github.com/turtle-key/TabLift/blob/main/LICENSE")!) {
                    Text("AGPL-3.0 \u{a9} Mihai-Eduard Ghe\u{21B}u")
                        .font(.footnote).foregroundColor(.gray)
                }
                Spacer()
                ModernQuitButton(isHovering: $isHoveringQuit)
            }
            .padding(.vertical, 8).padding(.horizontal, 16)
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
                Text(loc(.quit)).font(.footnote).fontWeight(.medium)
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
        .help(loc(.quitTabLift))
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
                    Text(loc(.cheatSheetTitle))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.accentColor)
                        .shadow(color: Color.accentColor.opacity(0.09), radius: 1, x: 0, y: 1)
                    Text(loc(.cheatSheetDesc))
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            VStack(spacing: 8) {
                CheatSheetRow(keys: ["\u{2318}", "\u{21E7}", "M"], description: loc(.cheatMinimizeAll))
                CheatSheetRowMouseDock(description: loc(.cheatDockClick))
                CheatSheetRow(keys: ["\u{2318}", "`"], description: loc(.cheatRestoreNext))
                CheatSheetRow(keys: ["\u{2318}", "Tab"], description: loc(.cheatSwitchApps))
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
                .foregroundColor(.accentColor)
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
                    Circle().fill(Color.accentColor.opacity(0.85)).frame(width: 5, height: 5)
                    Circle().fill(Color.accentColor.opacity(0.85)).frame(width: 5, height: 5)
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
                    ForEach(keys, id: \.self) { KeyCap(symbol: $0) }
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
        Toggle(loc(.showShieldBanner), isOn: $showShieldBanner)
            .toggleStyle(.switch)
    }
}
