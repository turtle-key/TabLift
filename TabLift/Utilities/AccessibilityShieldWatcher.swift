import AppKit
import CoreGraphics

extension Notification.Name {
    static let shieldActiveChanged = Notification.Name("AccessibilityShieldWatcher.shieldActiveChanged")
}

final class AccessibilityShieldWatcher {
    static let shared = AccessibilityShieldWatcher()

    private(set) var isShieldActive: Bool = false {
        didSet {
            if oldValue != isShieldActive {
                lastChangeAt = Date()
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: .shieldActiveChanged,
                        object: self,
                        userInfo: ["active": self.isShieldActive]
                    )
                }
                if debugLog {
                    print("ShieldActiveChanged -> \(isShieldActive)")
                }
            }
        }
    }

    private let queue = DispatchQueue(label: "ShieldWatcher.queue")
    private var timer: DispatchSourceTimer?
    private var lastChangeAt: Date = .distantPast

    // Tunables
    private let pollInterval: TimeInterval = 0.25
    /// The minimum fraction of the screen that must be covered by very-high-layer windows
    /// to consider the shield active. Set to 0.70 (70%) based on empirical observation of
    /// typical shield overlays, balancing sensitivity and false positives.
    private let coverageThreshold: CGFloat = 0.70
    /// If the window owner appears to be a shield, a lower coverage threshold is used.
    /// Set to 0.45 (45%) to allow for partial overlays that still block user interaction,
    /// based on observed behavior of some shield implementations.
    private let ownerCoverageThreshold: CGFloat = 0.45
    /// The grace period (in seconds) after the shield is cleared before considering the
    /// screen effectively clear. Set to 0.60s to avoid flicker and allow for UI transitions.
    private let graceAfterClear: TimeInterval = 0.60
    /// The minimum window layer value to consider a window as "very high" (i.e., likely
    /// to be a shield overlay). Set to 1200 as a conservative lower bound, since shield
    /// overlays are typically at layer 2000 or higher, but some may use lower values.
    private let shieldLayerThreshold: Int = 1200

    // Debug toggle via defaults: defaults write dev.tablift ShieldDebugLog -bool YES
    private var debugLog: Bool {
        UserDefaults.standard.bool(forKey: "ShieldDebugLog")
    }

    private init() {
        start()
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(onWake),
            name: NSWorkspace.didWakeNotification, object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(onSessionActive),
            name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil
        )
    }

    deinit {
        stop()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    var isEffectivelyClear: Bool {
        if isShieldActive { return false }
        return Date().timeIntervalSince(lastChangeAt) > graceAfterClear
    }

    @objc private func onWake() { bumpPolling() }
    @objc private func onSessionActive() { bumpPolling() }

    private func bumpPolling() {
        queue.async {
            self.stop()
            self.start(interval: 0.12)
            self.queue.asyncAfter(deadline: .now() + 2.0) {
                self.stop()
                self.start(interval: self.pollInterval)
            }
        }
    }

    func start(interval: TimeInterval? = nil) {
        stop()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: interval ?? pollInterval)
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        timer = t
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func tick() {
        let active = detectShield()
        if debugLog, active {
            dumpTopWindows()
        }
        isShieldActive = active
    }

    private func detectShield() -> Bool {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return false
        }

        // Use CoreGraphics display bounds to stay in the same global coordinate space as window bounds.
        var displays = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        CGGetActiveDisplayList(UInt32(displays.count), &displays, &count)
        displays = Array(displays.prefix(Int(count)))
        if displays.isEmpty { return false }
        let displayRects = displays.map { CGDisplayBounds($0) }

        // Coverage per display
        var coveredAreas = Array(repeating: 0.0 as CGFloat, count: displayRects.count)
        var ownerBoostTriggered = false

        let probableShieldOwners: Set<String> = ["loginwindow", "Window Server", "SecurityAgent"]

        for info in list {
            // Skip fully transparent windows
            if let alpha = info[kCGWindowAlpha as String] as? CGFloat, alpha <= 0.01 { continue }

            // High layer heuristic
            let layer = (info[kCGWindowLayer as String] as? Int) ?? 0
            if layer < shieldLayerThreshold { continue }

            guard
                let b = info[kCGWindowBounds as String] as? [String: CGFloat],
                let x = b["X"], let y = b["Y"], let w = b["Width"], let h = b["Height"]
            else { continue }
            let rect = CGRect(x: x, y: y, width: w, height: h)
            if rect.isEmpty { continue }

            let owner = (info[kCGWindowOwnerName as String] as? String) ?? ""
            if probableShieldOwners.contains(owner) { ownerBoostTriggered = true }

            // Accumulate coverage across displays using CG (same) coordinates
            for (i, dRect) in displayRects.enumerated() {
                let inter = dRect.intersection(rect)
                if !inter.isNull, inter.width > 0, inter.height > 0 {
                    coveredAreas[i] += inter.width * inter.height
                }
            }
        }

        // Decide using thresholds
        for (i, dRect) in displayRects.enumerated() {
            let area = dRect.width * dRect.height
            guard area > 0 else { continue }
            let coverage = coveredAreas[i] / area
            if ownerBoostTriggered {
                if coverage >= ownerCoverageThreshold { return true }
            } else {
                if coverage >= coverageThreshold { return true }
            }
        }
        return false
    }

    private func dumpTopWindows() {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else { return }
        let sorted = list.sorted { (a, b) -> Bool in
            let la = (a[kCGWindowLayer as String] as? Int) ?? 0
            let lb = (b[kCGWindowLayer as String] as? Int) ?? 0
            return la > lb
        }
        print("Top windows by layer:")
        for info in sorted.prefix(8) {
            let layer = (info[kCGWindowLayer as String] as? Int) ?? 0
            let owner = (info[kCGWindowOwnerName as String] as? String) ?? ""
            let name = (info[kCGWindowName as String] as? String) ?? ""
            let b = (info[kCGWindowBounds as String] as? [String: CGFloat]) ?? [:]
            print(String(format: "  layer=%4d owner=%@ name=%@ bounds=%@", layer, owner, name, NSStringFromRect(NSRectFromCGRect(CGRect(x: b["X"] ?? 0, y: b["Y"] ?? 0, width: b["Width"] ?? 0, height: b["Height"] ?? 0)))))
        }
    }

    // Optional blocking wait (use on background queues if you need it)
    func waitUntilClear(timeout: TimeInterval = 8.0, poll: TimeInterval = 0.10) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if isEffectivelyClear { return true }
            Thread.sleep(forTimeInterval: poll)
        }
        return isEffectivelyClear
    }
}
