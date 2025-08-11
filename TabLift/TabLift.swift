import Foundation

enum TabLift {
    static var appBundleIdentifier: String {
        Bundle.main.infoDictionary?[kCFBundleIdentifierKey as String] as? String ?? "com.TabLift"
    }

    static var appName: String {
        Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String ?? "(unknown)"
    }

    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "(unknown)"
    }
}
