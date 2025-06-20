import Foundation
import AppKit

class AppMonitor {
    private var observer: NSObjectProtocol?
    
    init(){
        observer = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { notification in guard let userInfo = notification.userInfo,let app = userInfo[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            WindowManager.restoreMinimsizedWindows(for: app)
        }
    }
    
    deinit {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
}
