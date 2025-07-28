import Foundation
import Cocoa
import AppKit

class AppMonitor {
    private var observer: NSObjectProtocol?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var lastAppSwitcherTimestamp: TimeInterval = 0
    private var isAppSwitcherActive = false
    static let timeoutThreshold: TimeInterval = 0.5

    func setupEventTap() {
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)

        let callback: CGEventTapCallBack = { proxy, type, event, userInfo in
            guard let userInfo = userInfo else { return Unmanaged.passRetained(event) }
            let mySelf = Unmanaged<AppMonitor>.fromOpaque(userInfo).takeUnretainedValue()

            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags

            switch type {
            case .keyDown:
                if flags.contains(.maskCommand) && (keyCode == 48 || keyCode == 50) {
                    mySelf.isAppSwitcherActive = true
                    print("Cmd + Tab or Cmd + ` pressed")
                }
            case .flagsChanged:
                if !flags.contains(.maskCommand), mySelf.isAppSwitcherActive {
                    mySelf.isAppSwitcherActive = false
                    mySelf.lastAppSwitcherTimestamp = Date().timeIntervalSince1970
                    print("Cmd released after App Switcher at \(mySelf.lastAppSwitcherTimestamp)")
                }
            default:
                break
            }

            return Unmanaged.passUnretained(event)
        }

        let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: selfPointer
        ) else {
            print("Failed to create event tap")
            return
        }

        self.eventTap = eventTap

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        self.runLoopSource = runLoopSource

        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    init() {
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let self = self,
                let userInfo = notification.userInfo,
                let app = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            else { return }

            let now = Date().timeIntervalSince1970
            let delta = now - self.lastAppSwitcherTimestamp

            if delta < AppMonitor.timeoutThreshold {
                print("App activated via App Switcher (Cmd+Tab or Cmd+`)")
                
                WindowManager.checkForWindows(for: app)
            }
        }
    }

    deinit {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }

        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }

        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
    }
}
