import Cocoa

class WindowManager {
    static let restoreAllKey = "restoreAllWindows"
    static let openWindowKey = "openNewWindow"
    static func restoreMinimizedWindows(for app: NSRunningApplication) {
        let restoreAll = UserDefaults.standard.bool(forKey: restoreAllKey)
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value)
        guard result == .success, let windows = value as? [AXUIElement] else { return }
        if restoreAll {
            for window in windows {
                var minimized: AnyObject?
                if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimized) == .success,
                   let isMinimized = minimized as? Bool,
                   isMinimized
                {
                    AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
                }
            }
        } else {
            for window in windows {
                var minimized: AnyObject?
                if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimized) == .success,
                   let isMinimized = minimized as? Bool,
                   isMinimized
                {
                    AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
                    break
                }
            }
        }
    }
    static func checkForWindows(for app: NSRunningApplication){
        let openNewWindow = UserDefaults.standard.bool(forKey: openWindowKey)
        if openNewWindow {
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            var value: AnyObject?
            let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value)
            guard result == .success, let windows = value as? [AXUIElement] else { return }
            if(windows.isEmpty){
                openNewWindowApp(for: app)
                return;
            }
        }
        restoreMinimizedWindows(for: app)
    }
    static func openNewWindowApp(for app: NSRunningApplication) {
        app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])

        let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x2D, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x2D, keyDown: false) 
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
