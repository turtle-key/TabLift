import Cocoa

class WindowManager {
    static func restoreMinimsizedWindows(for app: NSRunningApplication) {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value)
        guard result == .success, let windows = value as? [AXUIElement] else {return}
        for window in windows {
            var minimized: AnyObject?
            if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimized) == .success,
                let isMinimsized = minimized as? Bool,
               isMinimsized
            {
                AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            }
        }
    }
}
