import SwiftUI
import Cocoa
import ServiceManagement

@main
struct TabLiftApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var appMonitor: AppMonitor?
    var cmdBacktickMonitor: CmdBacktickMonitor?
    var window: NSWindow?
    private let autoUpdateManager = AutoUpdateManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [
            "showMenuBarIcon": true,
            "startAtLogin": true
        ])
        guard AccessibilityPermission.enabled else {
            AccessibilityPermissionWindow.show()
            return
        }
        cmdBacktickMonitor = CmdBacktickMonitor()
        appMonitor = AppMonitor()
        registerLoginItemIfNeeded()
        let showMenuBar = UserDefaults.standard.bool(forKey: "showMenuBarIcon")
        MenuBarManager.shared.showMenuBarIcon(show: showMenuBar)
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
                backing: .buffered, defer: false)
            window?.center()
            window?.contentView = NSHostingView(rootView: settingsView)
            window?.isReleasedWhenClosed = false
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
