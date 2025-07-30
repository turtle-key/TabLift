import Cocoa

extension AXUIElement {
    func role() -> String? {
        var value: AnyObject?
        if AXUIElementCopyAttributeValue(self, kAXRoleAttribute as CFString, &value) == .success {
            return value as? String
        }
        return nil
    }
    func subrole() -> String? {
        var value: AnyObject?
        if AXUIElementCopyAttributeValue(self, kAXSubroleAttribute as CFString, &value) == .success {
            return value as? String
        }
        return nil
    }
    func title() -> String? {
        var value: AnyObject?
        if AXUIElementCopyAttributeValue(self, kAXTitleAttribute as CFString, &value) == .success {
            return value as? String
        }
        return nil
    }
}
