import Cocoa

class CmdBacktickMonitor {
    private var eventTap: CFMachPort?
    private let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
    private var runLoopSource: CFRunLoopSource?

    init() {
        createTap()
    }

    private func createTap() {
        let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { (proxy, type, event, refcon) in
                if type == .keyDown {
                    let flags = event.flags
                    let keycode = event.getIntegerValueField(.keyboardEventKeycode)
                    if flags.contains(.maskCommand) && keycode == 50 {
                        CmdBacktickMonitor.unminimizeNextMinimizedWindow()
                    }
                }
                return Unmanaged.passUnretained(event)
            },
            userInfo: nil
        )
        self.eventTap = eventTap

        if let eventTap = eventTap {
            runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
    }

    func refresh() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
        createTap()
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
    static func unminimizeNextMinimizedWindow() {
        DispatchQueue.main.async {
            guard let app = NSWorkspace.shared.frontmostApplication else { return }
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            var value: AnyObject?
            let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value)
            guard result == .success, let windows = value as? [AXUIElement] else { return }

            for window in windows {
                var minimized: AnyObject?
                if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimized) == .success,
                   let isMinimized = minimized as? Bool,
                   isMinimized
                {
                    AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
                    AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
                    AXUIElementSetAttributeValue(window, kAXFocusedAttribute as CFString, kCFBooleanTrue)
                    break
                }
            }
        }
    }
}
