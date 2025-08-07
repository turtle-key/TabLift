import Foundation
import Cocoa
import AppKit

class AppMonitor {
    private var observer: NSObjectProtocol?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var lastAppSwitcherTimestamp: TimeInterval = 0
    private var isAppSwitcherActive = false
    private var previousApp: NSRunningApplication?

    static let timeoutThreshold: TimeInterval = 0.5

    func setupEventTap() {
        let eventMask = (1 << CGEventType.keyDown.rawValue)
                      | (1 << CGEventType.flagsChanged.rawValue)

        let callback: CGEventTapCallBack = { proxy, type, event, userInfo in
            guard let ptr = userInfo else {
                return Unmanaged.passRetained(event)
            }
            let monitor = Unmanaged<AppMonitor>.fromOpaque(ptr).takeUnretainedValue()
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags

            switch type {
            case .keyDown:
                if flags.contains(.maskCommand) && (keyCode == 48 || keyCode == 50),
                   let frontApp = NSWorkspace.shared.frontmostApplication {
                    monitor.isAppSwitcherActive = true
                    monitor.previousApp = frontApp
                }
            case .flagsChanged:
                if !flags.contains(.maskCommand), monitor.isAppSwitcherActive {
                    monitor.isAppSwitcherActive = false
                    monitor.lastAppSwitcherTimestamp = Date().timeIntervalSince1970
                }
            default: break
            }
            return Unmanaged.passUnretained(event)
        }

        let pointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: pointer
        ) else {
            print("Failed to create event tap")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    init() {
        setupEventTap()
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let info = notification.userInfo,
                  let newApp = info[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            else { return }
            let now = Date().timeIntervalSince1970
            let delta = now - self.lastAppSwitcherTimestamp
            if delta < AppMonitor.timeoutThreshold {
                WindowManager.checkForWindows(
                    current: newApp,
                    previous: self.previousApp
                )
            }
        }
    }

    deinit {
        if let obs = observer {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, .commonModes)
        }
    }

    func refresh() {
        if let obs = observer {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            observer = nil
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            eventTap = nil
        }
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src, .commonModes)
            runLoopSource = nil
        }
        setupEventTap()
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let info = notification.userInfo,
                  let newApp = info[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            else { return }
            let now = Date().timeIntervalSince1970
            let delta = now - self.lastAppSwitcherTimestamp
            if delta < AppMonitor.timeoutThreshold {
                WindowManager.checkForWindows(
                    current: newApp,
                    previous: self.previousApp
                )
            }
        }
    }
}
