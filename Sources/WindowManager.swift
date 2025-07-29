import Cocoa

class WindowManager {
    static let restoreAllKey = "restoreAllWindows"
    static let openWindowKey = "openNewWindow"
    static let minimizePreviousWindowKey = "minimizePreviousWindow"

    static func restoreMinimizedWindows(for app: NSRunningApplication) {
        let restoreAll = UserDefaults.standard.bool(forKey: restoreAllKey)
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return }

        if restoreAll {
            for window in windows {
                var minimized: AnyObject?
                if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimized) == .success,
                   let isMinimized = minimized as? Bool,
                   isMinimized {
                    AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
                }
            }
        } else {
            for window in windows {
                var minimized: AnyObject?
                if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimized) == .success,
                   let isMinimized = minimized as? Bool,
                   isMinimized {
                    AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
                    break
                }
            }
        }
    }

    static func minimizeFocusedWindow(of app: NSRunningApplication) {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        let restoreAll = UserDefaults.standard.bool(forKey: restoreAllKey)
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return }
        if restoreAll {
            for window in windows {
                var minimized: AnyObject?
                if AXUIElementCopyAttributeValue(window, kAXFocusedAttribute as CFString, &minimized) == .success,
                   let isMinimized = minimized as? Bool,
                   !isMinimized {
                    AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
                }
            }
        }else{
            for window in windows {
                var minimized: AnyObject?
                if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimized) == .success,
                   let isMinimized = minimized as? Bool,
                   !isMinimized {
                    AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
                    break
                }
            }
        }
    }

    static func checkForWindows(current: NSRunningApplication, previous: NSRunningApplication?){
        let openNewWindow = UserDefaults.standard.bool(forKey: openWindowKey)
        let minimizePreviousWindow = UserDefaults.standard.bool(forKey: minimizePreviousWindowKey)
        if openNewWindow {
            let appElement = AXUIElementCreateApplication(current.processIdentifier)
            var value: AnyObject?
            if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
               let windows = value as? [AXUIElement],
               windows.isEmpty {
                openNewWindowApp(for: current)
                return
            }
        }
        if minimizePreviousWindow, let previous = previous {
            minimizeFocusedWindow(of: previous)
        }
        restoreMinimizedWindows(for: current)
    }

    private static func openNewWindowApp(for app: NSRunningApplication) {
        app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x2D, keyDown: true)
        keyDown?.flags = .maskCommand
        let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x2D, keyDown: false)
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
