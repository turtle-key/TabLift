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
                // Pass a closure to close the popover when settings is opened
                popover.contentViewController = NSHostingController(rootView: MenuBarContentView(onOpenSettings: { [weak self] in
                    self?.closePopoverAndOpenSettings()
                }))
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
        guard let button = statusItem?.button, let popover = popover else { return }

        if popover.isShown {
            popover.performClose(sender)
            removeEventMonitor()
        } else {
            // Make sure the popover becomes key and fully interactive immediately
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            if let window = popover.contentViewController?.view.window {
                window.makeKey()
                window.orderFrontRegardless()
            }
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

    // Helper to close the popover and open settings
    private func closePopoverAndOpenSettings() {
        if let popover = self.popover, popover.isShown {
            popover.performClose(nil)
            removeEventMonitor()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NSApp.sendAction(#selector(AppDelegate.showUI), to: nil, from: nil)
        }
    }

    deinit {
        removeEventMonitor()
    }
}
