import SwiftUI
import Cocoa
import ServiceManagement

@main
struct TabLiftApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            // Show new settings view with tabs
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var appMonitor: AppMonitor?
    var window: NSWindow?
    private let autoUpdateManager = AutoUpdateManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard AccessibilityPermission.enabled else {
            AccessibilityPermissionWindow.show()
            return
        }
        appMonitor = AppMonitor()
        registerLoginItem()
    }
    
    func registerLoginItem() {
        do {
            try SMAppService.mainApp.register()
            print("Registered login item")
        } catch {
            print("Failed to register login item: \(error)")
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        print("applicationShouldHandleReopen")
        showUI()
        return true
    }

    func showUI() {
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
