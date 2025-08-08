import Cocoa
import ApplicationServices

struct WindowInfo: Identifiable, Equatable {
    let id: String
    let title: String
    let isMinimized: Bool
    let shouldHighlight: Bool
    let axElement: AXUIElement
    let app: NSRunningApplication

    init(axElement: AXUIElement, app: NSRunningApplication, index: Int, focusedWindow: AXUIElement?, isFrontmostApp: Bool) {
        self.axElement = axElement
        self.app = app

        var t: AnyObject?
        if AXUIElementCopyAttributeValue(axElement, kAXTitleAttribute as CFString, &t) == .success, let ti = t as? String {
            self.title = ti
        } else {
            var doc: AnyObject?
            if AXUIElementCopyAttributeValue(axElement, kAXDocumentAttribute as CFString, &doc) == .success, let docstr = doc as? String, !docstr.isEmpty {
                self.title = docstr
            } else {
                self.title = "(Untitled)"
            }
        }

        var minRaw: AnyObject?
        if AXUIElementCopyAttributeValue(axElement, kAXMinimizedAttribute as CFString, &minRaw) == .success, let isMin = minRaw as? Bool {
            self.isMinimized = isMin
        } else {
            self.isMinimized = false
        }

        self.shouldHighlight = isFrontmostApp && (focusedWindow != nil) && (CFEqual(axElement, focusedWindow))
        self.id = "\(app.processIdentifier)-\(Unmanaged.passUnretained(axElement).toOpaque())-\(index)"
    }

    static func == (lhs: WindowInfo, rhs: WindowInfo) -> Bool {
        return lhs.id == rhs.id
    }
}

class WindowManager {
    static let restoreAllKey             = "restoreAllWindows"
    static let openWindowKey             = "openNewWindow"
    static let minimizePreviousWindowKey = "minimizePreviousWindow"

    static func checkForWindows(current: NSRunningApplication, previous: NSRunningApplication?) {
        let openNew   = UserDefaults.standard.bool(forKey: openWindowKey)
        let minimize  = UserDefaults.standard.bool(forKey: minimizePreviousWindowKey)
        let restoreAll = UserDefaults.standard.bool(forKey: restoreAllKey)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if minimize, let prev = previous {
                minimizeFocusedWindow(of: prev)
            }
            if restoreAll {
                restoreMinimizedWindows(for: current)
            } else {
                if areAllWindowsMinimized(for: current) {
                    restoreMinimizedWindows(for: current)
                } else {
                    focusLastUnminimizedWindow(for: current)
                }
            }
            if openNew && !hasAnyPracticalVisibleWindow(for: current) {
                openNewWindowApp(for: current)
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

    static func focusLastUnminimizedWindow(for app: NSRunningApplication) {
        let appEl = AXUIElementCreateApplication(app.processIdentifier)
        var raw: AnyObject?
        if AXUIElementCopyAttributeValue(appEl, kAXWindowsAttribute as CFString, &raw) != .success {
            return
        }
        guard let windows = raw as? [AXUIElement] else { return }
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

    static func windowInfos(for app: NSRunningApplication) -> [WindowInfo] {
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var windowsValue: AnyObject?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let windows = windowsValue as? [AXUIElement] else { return [] }

        var focusedWindowValue: AnyObject?
        var focusedWindow: AXUIElement?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindowValue) == .success,
           focusedWindowValue != nil {
            focusedWindow = focusedWindowValue as! AXUIElement
        }

        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let isFrontmostApp = (app.processIdentifier == frontmostPID)

        var infos: [WindowInfo] = []

        for (idx, window) in windows.enumerated() {
            let role = window.role() ?? "(nil)"
            if role != "AXWindow" { continue }
            if isProbablyPictureInPicture(window: window) { continue }
            infos.append(WindowInfo(axElement: window, app: app, index: idx, focusedWindow: focusedWindow, isFrontmostApp: isFrontmostApp))
        }
        return infos
    }

    private static func isProbablyPictureInPicture(window: AXUIElement) -> Bool {
        let subrole = window.subrole() ?? ""
        if subrole == "AXPictureInPictureWindow" ||
           subrole == "AXFloatingWindow" ||
           subrole == "AXPanel" ||
           subrole == "AXSystemDialog"
        {
            return true
        }
        var sizeValue: AnyObject?
        if AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success {
            let axSize = sizeValue as! AXValue
            var sz = CGSize.zero
            AXValueGetValue(axSize, .cgSize, &sz)
            if sz.width < 220 || sz.height < 220 {
                let title = window.title() ?? ""
                if title.isEmpty {
                    return true
                }
            }
        }
        return false
    }
}
