import Cocoa
import Combine

final class PermissionsService: ObservableObject {
    //request accesibility permissions
    static func acquireAccessibilityPrivileges() {
        let options: NSDictionary = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ]
        let isTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        if isTrusted == true {
            print("Obtained Accesibility Privileges")
        }else{
            print("Didn't obtain accesibility privileges")
        }
    }
    
    
}
