import AppKit
import SwiftUI

final class ShieldNoticeManager {
    static let shared = ShieldNoticeManager()

    private var panel: NSPanel?
    private var hosting: NSHostingView<ShieldNoticeView>?

    // Behavior
    private var firstShownAt: Date?
    private let minShowDuration: TimeInterval = 4.0
    private let showDelay: TimeInterval = 8.0
    private var showWorkItem: DispatchWorkItem?

    // User setting
    private let showKey = "showShieldBanner"
    private var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: showKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: showKey) }
    }

    private init() {}

    func start() {
        NotificationCenter.default.addObserver(self, selector: #selector(onShieldChanged(_:)), name: .shieldActiveChanged, object: nil)
        // Also check current state at startup
        scheduleShowIfNeeded(active: AccessibilityShieldWatcher.shared.isShieldActive)
    }

    @objc private func onShieldChanged(_ note: Notification) {
        let active = (note.userInfo?["active"] as? Bool) ?? AccessibilityShieldWatcher.shared.isShieldActive
        scheduleShowIfNeeded(active: active)
    }
    static func resetDontShowAgain() {
        UserDefaults.standard.set(true, forKey: "showShieldBanner")
        // Optionally show immediately if the shield is active right now
        if AccessibilityShieldWatcher.shared.isShieldActive {
            ShieldNoticeManager.shared.start()
        }
    }
    private func scheduleShowIfNeeded(active: Bool) {
        guard isEnabled else { return }

        showWorkItem?.cancel()
        if active {
            let item = DispatchWorkItem { [weak self] in
                guard AccessibilityShieldWatcher.shared.isShieldActive else { return } // cancel if it cleared
                self?.showBanner()
            }
            showWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + showDelay, execute: item)
        } else {
            // Only hide after min show duration and when AX has “settled”
            let earliestHide = (firstShownAt ?? .distantPast).addingTimeInterval(minShowDuration)
            let delay: TimeInterval = max(0, earliestHide.timeIntervalSinceNow)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self = self else { return }
                if AccessibilityShieldWatcher.shared.isEffectivelyClear {
                    self.hideBanner()
                } else {
                    // If it hasn't settled, check again shortly
                    self.scheduleShowIfNeeded(active: AccessibilityShieldWatcher.shared.isShieldActive)
                }
            }
        }
    }

    private func showBanner() {
        guard isEnabled else { return }
        guard AccessibilityShieldWatcher.shared.isShieldActive else { return }

        let rootView = ShieldNoticeView(
            onClose: { [weak self] in self?.hideBanner() },
            onNeverShowAgain: { [weak self] in
                self?.isEnabled = false
                self?.hideBanner()
            }
        )

        if hosting == nil || panel == nil {
            let host = NSHostingView(rootView: rootView)
            host.translatesAutoresizingMaskIntoConstraints = false

            let p = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = false   // we draw our own shadow in SwiftUI to avoid NSPanel shadow artifacts
            p.level = .statusBar
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            p.ignoresMouseEvents = false
            p.hidesOnDeactivate = false
            p.becomesKeyOnlyIfNeeded = true
            p.worksWhenModal = true
            p.isReleasedWhenClosed = false

            p.contentView = host
            hosting = host
            panel = p
        } else {
            hosting?.rootView = rootView
        }

        layoutAndShow()
        firstShownAt = Date()
    }

    private func layoutAndShow() {
        guard let panel = panel, let hosting = hosting else { return }

        hosting.layoutSubtreeIfNeeded()
        let fitting = hosting.fittingSize
        let targetSize = NSSize(width: max(460, fitting.width), height: max(120, fitting.height))
        panel.setContentSize(targetSize)

        let screen = activeScreen()
        let origin = CGPoint(
            x: screen.midX - targetSize.width / 2,
            y: screen.maxY - targetSize.height - 36
        )
        panel.setFrameOrigin(alignedToPixels(origin, in: screenScreen(origin)))

        if panel.isVisible == false {
            panel.orderFrontRegardless()
        }
        // No panel alpha animation (prevents blur/material artifacts). SwiftUI view animates itself on appear.
    }

    private func hideBanner() {
        guard let panel = panel, panel.isVisible else { return }
        // SwiftUI view will animate out on disappear; we can just order out after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            panel.orderOut(nil)
            self?.firstShownAt = nil
        }
    }

    // Determine the screen under the cursor, else main, and return its visible frame
    private func activeScreen() -> CGRect {
        let mouse = NSEvent.mouseLocation
        for s in NSScreen.screens {
            if s.frame.contains(mouse) {
                return s.visibleFrame
            }
        }
        return (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
    }

    // Return the NSScreen for a point
    private func screenScreen(_ point: CGPoint) -> NSScreen? {
        for s in NSScreen.screens {
            if s.frame.contains(point) { return s }
        }
        return NSScreen.main ?? NSScreen.screens.first
    }

    // Pixel-align the origin to avoid subpixel blur on Retina
    private func alignedToPixels(_ value: CGFloat, _ scale: CGFloat) -> CGFloat {
        return floor(value * scale + 0.5) / scale
    }
    private func alignedToPixels(_ point: CGPoint, in screen: NSScreen?) -> CGPoint {
        let scale = screen?.backingScaleFactor ?? 2.0
        return CGPoint(x: alignedToPixels(point.x, scale), y: alignedToPixels(point.y, scale))
    }

    func teardown() {
        NotificationCenter.default.removeObserver(self, name: .shieldActiveChanged, object: nil)
        hideBanner()
        hosting = nil
        panel = nil
    }
}
