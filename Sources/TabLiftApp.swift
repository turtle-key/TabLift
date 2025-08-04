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
    
    var dockClickMonitor: DockClickMonitor?
    var dockIconHoverMonitor: DockIconHoverMonitor?
    
    private var wakeObserver: NSObjectProtocol?
    @objc func showHelp(_ sender: Any?) {
        if let url = URL(string: "https://tablift.dev/faq") {
            NSWorkspace.shared.open(url)
        }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [
            "showMenuBarIcon": true,
            "startAtLogin": true,
            "showDockIcon": false,
        ])

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDefaultsDidChange(_:)),
            name: UserDefaults.didChangeNotification,
            object: nil
        )

        guard AccessibilityPermission.enabled else {
            AccessibilityPermissionWindow.show()
            return
        }

        updateDockIconPolicy()

        cmdBacktickMonitor = CmdBacktickMonitor()
        appMonitor = AppMonitor()
        appMonitor?.setupEventTap()
        registerLoginItemIfNeeded()
        
        dockClickMonitor = DockClickMonitor()
        dockIconHoverMonitor = DockIconHoverMonitor()
        
        let showMenuBar = UserDefaults.standard.bool(forKey: "showMenuBarIcon")
        MenuBarManager.shared.showMenuBarIcon(show: showMenuBar)
        
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
                    forName: NSWorkspace.didWakeNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    self?.handleWakeFromSleep()
                }
    }
    func handleWakeFromSleep() {
        print("Mac woke from sleep — refreshing TabLift state")
        appMonitor?.refresh()
        cmdBacktickMonitor?.refresh()
        dockClickMonitor?.refresh()
        dockIconHoverMonitor?.refresh()
        if !AccessibilityPermission.enabled {
            AccessibilityPermissionWindow.show()
        }
    }
    
    deinit {
        if let wakeObserver = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
    }
    
    func registerLoginItemIfNeeded() {
        let startAtLogin = UserDefaults.standard.bool(forKey: "startAtLogin")
        if startAtLogin {
            do {
                try SMAppService.mainApp.register()
            } catch {
                print("Failed to register login item: \(error)")
            }
        } else {
            do {
                try SMAppService.mainApp.unregister()
            } catch {
                print("Failed to unregister login item: \(error)")
            }
        }
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
            window = NSWindow(
                contentRect: NSMakeRect(0, 0, 500, 450),
                styleMask: [.titled, .closable, .unifiedTitleAndToolbar],
                backing: .buffered,
                defer: false
            )
            window?.center()
            window?.contentView = NSHostingView(rootView: settingsView)
            window?.isReleasedWhenClosed = false

            window?.delegate = self
        }

        if UserDefaults.standard.bool(forKey: "showDockIcon") {
            NSApp.setActivationPolicy(.regular)
        }

        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
