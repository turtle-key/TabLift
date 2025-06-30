import Cocoa

class WindowManager {
    static let restoreAllKey = "restoreAllWindows"

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
}
