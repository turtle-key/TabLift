import Cocoa
import SwiftUI

/// Main controller for the Dock window title preview
class DockWindowTitlePreviewManager {
    static let shared = DockWindowTitlePreviewManager()
    
    private var panel: NSPanel?
    private var hostingView: NSHostingView<WindowTitlesPreviewPanel>?
    private var monitor: Any?
    private var currentAppBundleID: String?
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    func startMonitoring() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseMoved(event)
        }
    }
    
    func stopMonitoring() {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        hidePanel()
    }
    
    private func handleMouseMoved(_ event: NSEvent) {
        let mousePoint = NSEvent.mouseLocation
        print("Mouse moved to: \(mousePoint)") // DEBUG

        let icons = DockIconHelper.getDockAppIcons()
        if icons.isEmpty {
            print("No dock icons found.") // DEBUG
        }
        guard let icon = icons.first(where: { $0.frame.contains(mousePoint) }) else {
            // DEBUG: Not hovering a dock icon
            print("Not hovering a dock icon")
            hidePanel()
            currentAppBundleID = nil
            return
        }
        print("Hovering dock icon for bundleID: \(icon.bundleIdentifier)") // DEBUG
        if icon.bundleIdentifier == currentAppBundleID {
            // Already showing
            return
        }
        currentAppBundleID = icon.bundleIdentifier
        // Get app name
        let app = NSRunningApplication.runningApplications(withBundleIdentifier: icon.bundleIdentifier).first
        let appName = app?.localizedName ?? icon.bundleIdentifier
        // Get window titles
        let titles = DockWindowTitlePreviewManager.fetchWindowTitles(for: app)
        print("Window titles for \(appName): \(titles)") // DEBUG
        showPanel(appName: appName, titles: titles, above: icon.frame)
    }
    
    private static func fetchWindowTitles(for app: NSRunningApplication?) -> [String] {
        guard let app = app else { return [] }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var windowsValue: AnyObject?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let windows = windowsValue as? [AXUIElement] else { return [] }
        var titles: [String] = []
        for window in windows {
            var titleValue: AnyObject?
            if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue) == .success,
               let title = titleValue as? String {
                titles.append(title)
            }
        }
        return titles
    }
    
    private func showPanel(appName: String, titles: [String], above frame: CGRect) {
        print("Showing preview panel for \(appName) at frame \(frame)")
        // Remove any existing panel
        hidePanel()
        let content = WindowTitlesPreviewPanel(appName: appName, windowTitles: titles)
        let hosting = NSHostingView(rootView: content)
        let panel = NSPanel(contentRect: CGRect(x: frame.midX - 90, y: frame.maxY + 8, width: 180, height: CGFloat(60 + max(20, titles.count * 24))),
                            styleMask: [.borderless],
                            backing: .buffered, defer: false)
        panel.contentView = hosting
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // Position panel above the Dock icon
        panel.setFrameTopLeftPoint(NSPoint(x: frame.midX - 90, y: frame.maxY + 8 + CGFloat(60 + max(20, titles.count * 24))))
        panel.orderFrontRegardless()
        self.panel = panel
        self.hostingView = hosting
    }
    
    private func hidePanel() {
        panel?.orderOut(nil)
        panel = nil
        hostingView = nil
        currentAppBundleID = nil
    }
}
