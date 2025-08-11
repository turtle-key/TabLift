import SwiftUI
import Cocoa
import ServiceManagement

@main
struct TabLiftApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var appMonitor: AppMonitor?
    var cmdBacktickMonitor: CmdBacktickMonitor?
    var window: NSWindow?
    private let autoUpdateManager = AutoUpdateManager.shared
    private var globalHotkeyMonitor: HotkeyMonitor?
    var windowSwitcherMonitor: WindowSwitcherMonitor?
    var dockClickMonitor: DockClickMonitor?
    var dockIconHoverMonitor: DockIconHoverMonitor?
    private var wakeObserver: NSObjectProtocol?
    private var screenRecordingObserver: NSObjectProtocol?
    private var displayConfigObserver: NSObjectProtocol?
    private var accessibilityObserver: NSObjectProtocol?

    @objc func showHelp(_ sender: Any?) {
        if let url = URL(string: "https://tablift.dev/faq") {
            NSWorkspace.shared.open(url)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        ShieldNoticeManager.shared.start()
        PFMoveToApplicationsFolderIfNecessary()
        guard AccessibilityPermission.enabled else {
            AccessibilityPermissionWindow.show()
            return
        }
        UserDefaults.standard.register(defaults: [
            "restoreAllWindows": true,
            "openNewWindow": true,
            "minimizePreviousWindow": false,
            "showDockPopups": true,
            "showMenuBarIcon": true,
            "showDockIcon": false,
            "startAtLogin": true,
            "showShieldBanner": true,
            "restoreAllOnDockClick": false
        ])
        applyAllSettings()
        NotificationCenter.default.addObserver(self, selector: #selector(userDefaultsDidChange(_:)), name: UserDefaults.didChangeNotification, object: nil)
        updateDockIconPolicy()
        windowSwitcherMonitor = WindowSwitcherMonitor()
        cmdBacktickMonitor = CmdBacktickMonitor()
        appMonitor = AppMonitor()
        appMonitor?.setupEventTap()
        registerLoginItemIfNeeded()
        dockClickMonitor = DockClickMonitor()
        dockIconHoverMonitor = DockIconHoverMonitor()
        let showMenuBar = UserDefaults.standard.bool(forKey: "showMenuBarIcon")
        MenuBarManager.shared.showMenuBarIcon(show: showMenuBar)
        globalHotkeyMonitor = HotkeyMonitor()
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in self?.handleGlobalRefresh() }
        screenRecordingObserver = DistributedNotificationCenter.default().addObserver(forName: NSNotification.Name("com.apple.screencapture.interactive"), object: nil, queue: .main) { [weak self] _ in self?.handleGlobalRefresh() }
        displayConfigObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in self?.handleGlobalRefresh() }
        accessibilityObserver = DistributedNotificationCenter.default().addObserver(forName: NSNotification.Name("com.apple.accessibility.api"), object: nil, queue: .main) { [weak self] _ in self?.handleGlobalRefresh() }
        DispatchQueue.main.async { self.showUI() }
    }

    func handleGlobalRefresh() {
        let watcher = AccessibilityShieldWatcher.shared
        if !watcher.isEffectivelyClear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.handleGlobalRefresh() }
            return
        }
        appMonitor?.refresh()
        cmdBacktickMonitor?.refresh()
        dockClickMonitor?.refresh()
        dockIconHoverMonitor?.refresh()
        globalHotkeyMonitor?.refresh()
        if !AccessibilityPermission.enabled { AccessibilityPermissionWindow.show() }
    }

    func applyAllSettings() {
        let showMenuBar = UserDefaults.standard.bool(forKey: "showMenuBarIcon")
        let showDockIcon = UserDefaults.standard.bool(forKey: "showDockIcon")
        let startAtLogin = UserDefaults.standard.bool(forKey: "startAtLogin")
        MenuBarManager.shared.showMenuBarIcon(show: showMenuBar)
        updateDockIconPolicy(showDockIcon)
        registerLoginItemIfNeeded(startAtLogin)
        appMonitor?.refresh()
        dockClickMonitor?.refresh()
        cmdBacktickMonitor?.refresh()
        dockIconHoverMonitor?.refresh()
    }

    func updateDockIconPolicy(_ showDockIcon: Bool) {
        let policy: NSApplication.ActivationPolicy = showDockIcon ? .regular : .accessory
        NSApp.setActivationPolicy(policy)
    }

    func registerLoginItemIfNeeded(_ startAtLogin: Bool) {
        if startAtLogin { try? SMAppService.mainApp.register() } else { try? SMAppService.mainApp.unregister() }
    }

    deinit {
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
        if let screenRecordingObserver { DistributedNotificationCenter.default().removeObserver(screenRecordingObserver) }
        if let displayConfigObserver { NSWorkspace.shared.notificationCenter.removeObserver(displayConfigObserver) }
        if let accessibilityObserver { DistributedNotificationCenter.default().removeObserver(accessibilityObserver) }
    }

    func registerLoginItemIfNeeded() {
        let startAtLogin = UserDefaults.standard.bool(forKey: "startAtLogin")
        if startAtLogin { try? SMAppService.mainApp.register() } else { try? SMAppService.mainApp.unregister() }
    }

    @objc private func userDefaultsDidChange(_ notification: Notification) {
        updateDockIconPolicy()
    }

    private func updateDockIconPolicy() {
        let showDockIcon = UserDefaults.standard.bool(forKey: "showDockIcon")
        let policy: NSApplication.ActivationPolicy = showDockIcon ? .regular : .accessory
        NSApp.setActivationPolicy(policy)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showUI()
        return true
    }

    @objc func showUI() {
        if window == nil {
            let settingsView = SettingsView()
            window = SettingsWindow(
                contentRect: NSMakeRect(0, 0, 500, 450),
                styleMask: [.titled, .closable, .miniaturizable, .unifiedTitleAndToolbar, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            if let w = window {
                w.title = "TabLift Settings"
                w.titleVisibility = .hidden
                w.titlebarAppearsTransparent = true
                w.center()
                w.contentView = NSHostingView(rootView: settingsView)
                w.isReleasedWhenClosed = false
                w.makeFirstResponder(w.contentView)
                w.delegate = self
            }
        }
        if UserDefaults.standard.bool(forKey: "showDockIcon") { NSApp.setActivationPolicy(.regular) }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        if !UserDefaults.standard.bool(forKey: "showDockIcon") { NSApp.setActivationPolicy(.accessory) }
    }
}
