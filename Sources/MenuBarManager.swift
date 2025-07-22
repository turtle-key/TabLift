import AppKit
import SwiftUI

class MenuBarManager: NSObject {
    static let shared = MenuBarManager()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var eventMonitor: Any?

    @AppStorage(WindowManager.restoreAllKey) var restoreAllWindows: Bool = true

    func showMenuBarIcon(show: Bool) {
        if show {
            if statusItem == nil {
                statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
                if let button = statusItem?.button {
                    button.image = NSImage(named: "MenuIcon")
                    button.action = #selector(togglePopover(_:))
                    button.target = self
                }

                let popover = NSPopover()
                popover.contentSize = NSSize(width: 320, height: 180)
                popover.behavior = .transient
                popover.animates = false
                popover.contentViewController = NSHostingController(rootView: MenuBarContentView())
                self.popover = popover
            }
        } else {
            if let statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
                self.statusItem = nil
            }
            self.popover = nil
            removeEventMonitor()
        }
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button, let popover else { return }

        if popover.isShown {
            popover.performClose(sender)
            removeEventMonitor()
        } else {
            NSApp.activate(ignoringOtherApps: true) // 🧠 Ensure app is frontmost
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            
            // 🧠 Critical to make popover's window key so transient works
            popover.contentViewController?.view.window?.makeKey()

            startEventMonitor()
        }
    }

    private func startEventMonitor() {
        guard eventMonitor == nil else { return }

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, let popover = self.popover, popover.isShown else { return }
            popover.performClose(nil)
            self.removeEventMonitor()
        }
    }

    private func removeEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }

    deinit {
        removeEventMonitor()
    }
}
