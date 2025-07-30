import Cocoa
import ApplicationServices

class WindowManager {
    static let restoreAllKey             = "restoreAllWindows"
    static let openWindowKey             = "openNewWindow"
    static let minimizePreviousWindowKey = "minimizePreviousWindow"

    static func checkForWindows(current: NSRunningApplication, previous: NSRunningApplication?) {
        let openNew   = UserDefaults.standard.bool(forKey: openWindowKey)
        let minimize  = UserDefaults.standard.bool(forKey: minimizePreviousWindowKey)
        let restoreAll = UserDefaults.standard.bool(forKey: restoreAllKey)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if openNew && !hasAnyPracticalVisibleWindow(for: current) {
                openNewWindowApp(for: current)
                return
            }

            if minimize, let prev = previous {
                minimizeFocusedWindow(of: prev)
            }

            if restoreAll {
                // If "restore all minimized windows" is enabled: always restore ALL minimized windows
                restoreMinimizedWindows(for: current)
            } else {
                // If "restore all minimized windows" is disabled:
                if areAllWindowsMinimized(for: current) {
                    restoreMinimizedWindows(for: current)
                } else {
                    focusLastUnminimizedWindow(for: current)
                }
            }
        }
    }

    static func areAllWindowsMinimized(for app: NSRunningApplication) -> Bool {
        let appEl = AXUIElementCreateApplication(app.processIdentifier)
        var raw: AnyObject?
        if AXUIElementCopyAttributeValue(appEl, kAXWindowsAttribute as CFString, &raw) != .success {
            return false
        }
        guard let windows = raw as? [AXUIElement], !windows.isEmpty else { return false }
        for window in windows {
            var minRaw: AnyObject?
            if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minRaw) == .success,
               let isMin = minRaw as? Bool, !isMin {
                return false
            }
        }
        return true
    }

    static func hasAnyPracticalVisibleWindow(for app: NSRunningApplication) -> Bool {
        if hasAXVisibleWindow(for: app) { return true }
        if hasCGVisibleWindow(for: app) { return true }
        return false
    }

    private static func hasAXVisibleWindow(for app: NSRunningApplication) -> Bool {
        let appEl = AXUIElementCreateApplication(app.processIdentifier)
        var raw: AnyObject?
        if AXUIElementCopyAttributeValue(appEl, kAXWindowsAttribute as CFString, &raw) != .success {
            return false
        }
        guard let windows = raw as? [AXUIElement] else { return false }
        for window in windows {
            var minRaw: AnyObject?
            if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minRaw) == .success,
               let isMin = minRaw as? Bool, isMin {
                continue
            }
            var posRaw: AnyObject?
            var sizeRaw: AnyObject?
            if AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRaw) == .success,
               AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRaw) == .success {
                let pos = posRaw as! AXValue
                let size = sizeRaw as! AXValue
                var position: CGPoint = .zero
                var sz: CGSize = .zero
                if AXValueGetType(pos) == .cgPoint,
                   AXValueGetType(size) == .cgSize,
                   AXValueGetValue(pos, .cgPoint, &position),
                   AXValueGetValue(size, .cgSize, &sz),
                   sz.width > 100, sz.height > 100
                {
                    return true
                }
            }
        }
        return false
    }

    private static func hasCGVisibleWindow(for app: NSRunningApplication) -> Bool {
        guard let bundleID = app.bundleIdentifier else { return false }
        let appProcs = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        let pids = Set(appProcs.map { $0.processIdentifier })

        guard let infoList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }

        for dict in infoList {
            guard
                let ownerPID = dict[kCGWindowOwnerPID as String] as? pid_t,
                pids.contains(ownerPID),
                let layer = dict[kCGWindowLayer as String] as? Int, layer == 0,
                let bounds = dict[kCGWindowBounds as String] as? [String: Any],
                let width  = bounds["Width"]  as? CGFloat, width  > 100,
                let height = bounds["Height"] as? CGFloat, height > 100,
                let alpha = dict[kCGWindowAlpha as String] as? CGFloat, alpha > 0.05
            else { continue }
            return true
        }
        return false
    }

    static func restoreMinimizedWindows(for app: NSRunningApplication) {
        let restoreAll = UserDefaults.standard.bool(forKey: restoreAllKey)
        let appEl      = AXUIElementCreateApplication(app.processIdentifier)
        var raw: AnyObject?
        guard AXUIElementCopyAttributeValue(appEl, kAXWindowsAttribute as CFString, &raw) == .success,
              let windows = raw as? [AXUIElement] else {
            return
        }
        for win in windows {
            var minRaw: AnyObject?
            guard AXUIElementCopyAttributeValue(win, kAXMinimizedAttribute as CFString, &minRaw) == .success,
                  let isMin = minRaw as? Bool, isMin else { continue }
            AXUIElementSetAttributeValue(win, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            if !restoreAll { break }
        }
    }

    // Focus only the last unminimized window (do NOT restore minimized ones)
    static func focusLastUnminimizedWindow(for app: NSRunningApplication) {
        let appEl = AXUIElementCreateApplication(app.processIdentifier)
        var raw: AnyObject?
        if AXUIElementCopyAttributeValue(appEl, kAXWindowsAttribute as CFString, &raw) != .success {
            return
        }
        guard let windows = raw as? [AXUIElement] else { return }
        // Find the last unminimized window (topmost) and focus it
        for window in windows {
            var minRaw: AnyObject?
            if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minRaw) == .success,
               let isMin = minRaw as? Bool, !isMin {
                AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
                AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
                app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
                return
            }
        }
    }

    static func minimizeFocusedWindow(of app: NSRunningApplication) {
        let restoreAll = UserDefaults.standard.bool(forKey: restoreAllKey)
        let appEl      = AXUIElementCreateApplication(app.processIdentifier)
        var raw: AnyObject?
        guard AXUIElementCopyAttributeValue(appEl, kAXWindowsAttribute as CFString, &raw) == .success,
              let windows = raw as? [AXUIElement] else {
            return
        }
        for win in windows {
            var minRaw: AnyObject?
            guard AXUIElementCopyAttributeValue(win, kAXMinimizedAttribute as CFString, &minRaw) == .success,
                  let isMin = minRaw as? Bool, !isMin else { continue }
            AXUIElementSetAttributeValue(win, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
            if !restoreAll { break }
        }
    }

    private static func openNewWindowApp(for app: NSRunningApplication) {
        app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
        let keyCode: CGKeyCode = 0x2D
        guard let src = CGEventSource(stateID: .hidSystemState) else { return }
        let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)!
        down.flags = .maskCommand
        let up   = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)!
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
