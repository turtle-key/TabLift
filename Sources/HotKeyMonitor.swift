import Cocoa
import ApplicationServices

class HotkeyMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init() {
        let eventMask = (1 << CGEventType.keyDown.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { _, type, event, _ in
                guard type == .keyDown else { return Unmanaged.passUnretained(event) }
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                let flags = event.flags

                // Cmd+Shift+M: keyCode 46
                if keyCode == 46 && flags.contains(.maskCommand) && flags.contains(.maskShift) {
                    HotkeyMonitor.minimizeAllWindowsOfFrontmostApp()
                    return nil // Swallow the event, or return event to pass through
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: nil
        )

        if let eventTap = eventTap {
            runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
        } else {
            print("Failed to create global event tap!")
        }
    }

    deinit {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
    }

    static func minimizeAllWindowsOfFrontmostApp() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        let appEl = AXUIElementCreateApplication(app.processIdentifier)
        var raw: AnyObject?
        guard AXUIElementCopyAttributeValue(appEl, kAXWindowsAttribute as CFString, &raw) == .success,
              let windows = raw as? [AXUIElement] else {
            return
        }
        for win in windows {
            var roleRaw: AnyObject?
            guard AXUIElementCopyAttributeValue(win, kAXRoleAttribute as CFString, &roleRaw) == .success,
                  let role = roleRaw as? String, role == "AXWindow" else { continue }
            var subroleRaw: AnyObject?
            if AXUIElementCopyAttributeValue(win, kAXSubroleAttribute as CFString, &subroleRaw) == .success,
               let subrole = subroleRaw as? String, subrole != "AXStandardWindow" { continue }
            var minRaw: AnyObject?
            guard AXUIElementCopyAttributeValue(win, kAXMinimizedAttribute as CFString, &minRaw) == .success,
                  let isMin = minRaw as? Bool, !isMin else { continue }
            // Make the window main and focused before minimizing
            AXUIElementSetAttributeValue(win, kAXMainAttribute as CFString, kCFBooleanTrue)
            AXUIElementSetAttributeValue(win, kAXFocusedAttribute as CFString, kCFBooleanTrue)
            AXUIElementSetAttributeValue(win, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
        }
    }
}
