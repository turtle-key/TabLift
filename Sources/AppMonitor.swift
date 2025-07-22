import Foundation
import Cocoa
import AppKit

class AppMonitor {
    private var observer: NSObjectProtocol?
    private var lastAppSwitcherTimestamp: TimeInterval = 0
    
    func setupEventTap() {
            let eventMask = (1 << CGEventType.keyDown.rawValue)
            
            let callback: CGEventTapCallBack = { proxy, type, event, userInfo in
                guard let userInfo = userInfo else { return Unmanaged.passRetained(event) }
                let mySelf = Unmanaged<AppMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                
                if type == .keyDown {
                    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                    let flags = event.flags

                    if flags.contains(.maskCommand) && (keyCode == 48 || keyCode == 50) {
                        mySelf.lastAppSwitcherTimestamp = Date().timeIntervalSince1970
                        print("Cmd + Tab or Cmd + ` detected at \(mySelf.lastAppSwitcherTimestamp)")
                    }
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

            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
    
    init(){
        observer = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { notification in guard let userInfo = notification.userInfo,let app = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            let now = Date().timeIntervalSince1970
            let delta = now - self.lastAppSwitcherTimestamp

            if delta < 0.5 {
                print("App activated via App Switcher (Cmd+Tab or Cmd+`)")
                WindowManager.restoreMinimizedWindows(for: app)
            }
            
        }
    }
    
    deinit {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
}
