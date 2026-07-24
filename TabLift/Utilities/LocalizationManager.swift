import Combine
import SwiftUI

// MARK: - Language Enum

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case chinese = "zh-Hans"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .chinese: return "中文"
        }
    }

    var locale: Locale {
        switch self {
        case .english: return Locale(identifier: "en_US")
        case .chinese: return Locale(identifier: "zh_Hans")
        }
    }
}

// MARK: - Localization Manager

class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()

    @AppStorage("appLanguage") var languageRaw: String = AppLanguage.english.rawValue {
        didSet { objectWillChange.send() }
    }

    var currentLanguage: AppLanguage {
        AppLanguage(rawValue: languageRaw) ?? .english
    }

    func setLanguage(_ lang: AppLanguage) {
        languageRaw = lang.rawValue
        objectWillChange.send()
    }

    /// Convenience: returns the localized string for a key
    func localized(_ key: L10nKey) -> String {
        key.string(for: currentLanguage)
    }
}

// MARK: - Localization Keys & Strings

enum L10nKey: String {
    // Menu bar
    case menuBarTitle
    case restoreAllMinimizedWindows
    case openSettings
    case quitTabLift

    // Accessibility permission
    case accessibilityNeeded
    case accessibilityDescription
    case getMoreHelp
    case openAccessibility
    case permissions
    case permissionsEnabled
    case permissionsNotEnabled
    case enableAccess
    case enableAccessHelp

    // Shield notice
    case waitingForAccessibility
    case tryText
    case toLockThen
    case toDismiss
    case shieldExplanation
    case gotIt
    case dontShowAgain

    // Settings - About tab
    case appDescription
    case tabliftHelp
    case checkSourceCode
    case supportProject
    case emailMe
    case quit

    // Settings - General tab labels
    case appLaunchAppearance
    case startAtLogin
    case showInMenuBar
    case showMenuBarHint
    case showInDock

    case dockFeatures
    case showWindowPreviews
    case greenButtonAction
    case dockPreviewSpeed
    case dockClickTogglesAll
    case dockClickEnabled
    case dockClickDisabled
    case dockDismissAfterClick
    case dockDismissEnabled
    case dockDismissDisabled

    case windowSwitchingBehavior
    case showWindowSwitcher
    case windowSwitcherDisabled
    case restoreAllOnSwitch
    case restoreAllDisabled
    case autoOpenWindow
    case autoOpenDisabled
    case minimizePrevious
    case minimizePreviousDisabled
    case tipCannotEnable

    // Settings - performance
    case profileRelaxed
    case profileDefault
    case profileSpeedy
    case profileLabel
    case profileDescription
    case previewDelay
    case fadeOut

    // Settings - support tab
    case version
    case checkUpdatesAuto
    case updateInterval
    case daily
    case weekly
    case monthly
    case checkForUpdatesButton

    // Settings - demo help
    case restoreHelpEnabled
    case restoreHelpDisabled
    case autoOpenHelpEnabled
    case autoOpenHelpDisabled
    case minimizePrevHelpEnabled
    case minimizePrevHelpDisabled

    // Settings - cheat sheet
    case cheatSheetTitle
    case cheatSheetDesc
    case cheatMinimizeAll
    case cheatDockClick
    case cheatRestoreNext
    case cheatSwitchApps

    // Settings - other
    case videoMissing
    case showShieldBanner

    // Maximize behavior
    case maximizeFill
    case maximizeFullscreen
    case fillExplanation
    case fullscreenExplanation

    // Dock preview panel
    case minimizedIndicatorHelp

    // Language
    case language

    // Tab labels
    case tabAbout
    case tabGeneral
    case tabSupport
    case settingsWindowTitle

    // MARK: - String lookup

    func string(for lang: AppLanguage) -> String {
        switch lang {
        case .english: return Self.en[self] ?? rawValue
        case .chinese: return Self.zh[self] ?? Self.en[self] ?? rawValue
        }
    }

    // MARK: - English Strings

    private static let en: [L10nKey: String] = [
        .menuBarTitle: "TabLift",
        .restoreAllMinimizedWindows: "Restore all minimized windows",
        .openSettings: "Open Settings",
        .quitTabLift: "Quit TabLift",

        .accessibilityNeeded: "TabLift needs Accessibility permission",
        .accessibilityDescription: "You need to grant Accessibility permission in System Settings > Security & Privacy > Accessibility.",
        .getMoreHelp: "Get more help",
        .openAccessibility: "Open Accessibility",
        .permissions: "Permissions",
        .permissionsEnabled: "Accessibility permissions are enabled",
        .permissionsNotEnabled: "Accessibility permissions are not enabled",
        .enableAccess: "Enable Access",
        .enableAccessHelp: "Bring up the permission request window to allow Tablift to control windows.",

        .waitingForAccessibility: "Waiting for macOS Accessibility",
        .tryText: "Try:",
        .toLockThen: "to lock, then",
        .toDismiss: "to dismiss.",
        .shieldExplanation: "This clears a temporary macOS shield that blocks Accessibility for a few seconds. %@ will resume automatically.",
        .gotIt: "Got it",
        .dontShowAgain: "Don't show again",

        .appDescription: "Minimized App Restorer",
        .tabliftHelp: "Tablift Help",
        .checkSourceCode: "Check out the source code",
        .supportProject: "Support this project",
        .emailMe: "Email me",
        .quit: "Quit",

        .appLaunchAppearance: "App Launch & Appearance",
        .startAtLogin: "Start at login",
        .showInMenuBar: "Show in menu bar",
        .showMenuBarHint: "To show the settings, launch TabLift again.",
        .showInDock: "Show in Dock",

        .dockFeatures: "Dock Features",
        .showWindowPreviews: "Show Window Previews in Dock",
        .greenButtonAction: "Green Button Action",
        .dockPreviewSpeed: "Dock preview speed",
        .dockClickTogglesAll: "Dock click toggles all windows",
        .dockClickEnabled: "Enabled: Clicking an app's Dock icon will minimize all if visible, or restore all.",
        .dockClickDisabled: "Disabled: Clicking an app's Dock icon minimizes only current window if frontmost, restores all if all minimized.",
        .dockDismissAfterClick: "Dismiss Dock window preview after click",
        .dockDismissEnabled: "The Dock window preview popup will disappear after clicking a window or its action buttons.",
        .dockDismissDisabled: "The Dock window preview will remain open after clicking, allowing multiple actions.",

        .windowSwitchingBehavior: "Window Switching Behavior",
        .showWindowSwitcher: "Show the window switcher pop up for the frontmost app",
        .windowSwitcherDisabled: "When disabled, the CMD ` doesn't activate the window switching pop up",
        .restoreAllOnSwitch: "Restore all minimized windows on app switch",
        .restoreAllDisabled: "When disabled, only the most recently minimized window will be restored.",
        .autoOpenWindow: "Automatically open a window for apps with no windows",
        .autoOpenDisabled: "When disabled, switching to an app without windows won't open a new window.",
        .minimizePrevious: "Minimize previous window on app switch",
        .minimizePreviousDisabled: "When disabled, switching to another app won't automatically minimize the previous one.",
        .tipCannotEnable: "Tip: Cannot enable with 'Automatically open a window'.",

        .profileRelaxed: "Relaxed",
        .profileDefault: "Default",
        .profileSpeedy: "Speedy",
        .profileLabel: "Profile: %@",
        .profileDescription: "How quickly the Dock preview appears and fades out when you hover.\n",
        .previewDelay: "Preview delay: %@s",
        .fadeOut: "Fade out: %@s",

        .version: "Version: %@",
        .checkUpdatesAuto: "Check for updates automatically",
        .updateInterval: "Update check interval",
        .daily: "Daily",
        .weekly: "Weekly",
        .monthly: "Monthly",
        .checkForUpdatesButton: "Check for Updates…",

        .restoreHelpEnabled: "Enabled: Switching to an app restores all minimized windows.",
        .restoreHelpDisabled: "Disabled: Only the last minimized window is restored.",
        .autoOpenHelpEnabled: "Enabled: A new window is opened automatically.",
        .autoOpenHelpDisabled: "Disabled: Switching does nothing if no windows.",
        .minimizePrevHelpEnabled: "Enabled: Previous app window minimized.",
        .minimizePrevHelpDisabled: "Disabled: Previous windows stay visible.",

        .cheatSheetTitle: "TabLift Cheat Sheet",
        .cheatSheetDesc: "Essential shortcuts for smooth window switching.",
        .cheatMinimizeAll: "Minimize all windows of the frontmost app",
        .cheatDockClick: "Restore or minimize windows by clicking the Dock icon",
        .cheatRestoreNext: "Restore next window in the frontmost app & show the Windows Preview",
        .cheatSwitchApps: "Switch between running apps",

        .videoMissing: "Video missing",
        .showShieldBanner: "Show accessibility shield tips",

        .maximizeFill: "Fill",
        .maximizeFullscreen: "Fullscreen",
        .fillExplanation: "Fill: Expands the window to fill the visible screen area (menu bar and Dock remain visible).",
        .fullscreenExplanation: "Fullscreen: Enters macOS native fullscreen (window becomes its own Space and menu bar/Dock are hidden).",

        .minimizedIndicatorHelp: "This window is minimized",

        .language: "Language",

        .tabAbout: "About",
        .tabGeneral: "General",
        .tabSupport: "Support",
        .settingsWindowTitle: "TabLift Settings",
    ]

    // MARK: - Chinese Strings

    private static let zh: [L10nKey: String] = [
        .menuBarTitle: "TabLift",
        .restoreAllMinimizedWindows: "恢复所有最小化窗口",
        .openSettings: "打开设置",
        .quitTabLift: "退出 TabLift",

        .accessibilityNeeded: "TabLift 需要辅助功能权限",
        .accessibilityDescription: "请在 系统设置 > 隐私与安全性 > 辅助功能 中授予辅助功能权限。",
        .getMoreHelp: "获取更多帮助",
        .openAccessibility: "打开辅助功能设置",
        .permissions: "权限",
        .permissionsEnabled: "辅助功能权限已启用",
        .permissionsNotEnabled: "辅助功能权限未启用",
        .enableAccess: "启用权限",
        .enableAccessHelp: "打开权限请求窗口，允许 Tablift 控制窗口。",

        .waitingForAccessibility: "等待 macOS 辅助功能就绪",
        .tryText: "请尝试：",
        .toLockThen: "锁定屏幕，然后",
        .toDismiss: "取消锁定。",
        .shieldExplanation: "这将清除一个临时的 macOS 屏蔽层，该屏蔽层会短暂阻断辅助功能。%@ 将自动恢复运行。",
        .gotIt: "知道了",
        .dontShowAgain: "不再提示",

        .appDescription: "最小化应用恢复工具",
        .tabliftHelp: "Tablift 帮助",
        .checkSourceCode: "查看源代码",
        .supportProject: "支持此项目",
        .emailMe: "发送邮件",
        .quit: "退出",

        .appLaunchAppearance: "启动与外观",
        .startAtLogin: "开机自启动",
        .showInMenuBar: "在菜单栏显示",
        .showMenuBarHint: "如需显示设置，请再次启动 TabLift。",
        .showInDock: "在 Dock 中显示",

        .dockFeatures: "Dock 功能",
        .showWindowPreviews: "在 Dock 中显示窗口预览",
        .greenButtonAction: "绿色按钮行为",
        .dockPreviewSpeed: "Dock 预览速度",
        .dockClickTogglesAll: "Dock 点击切换所有窗口",
        .dockClickEnabled: "已启用：点击应用 Dock 图标将最小化所有可见窗口或恢复所有窗口。",
        .dockClickDisabled: "已禁用：点击应用 Dock 图标仅最小化当前窗口（如在前台），或全部最小化时恢复全部。",
        .dockDismissAfterClick: "点击后关闭 Dock 窗口预览",
        .dockDismissEnabled: "Dock 窗口预览在点击窗口或操作按钮后将自动消失。",
        .dockDismissDisabled: "Dock 窗口预览在点击后保持显示，允许执行多个操作。",

        .windowSwitchingBehavior: "窗口切换行为",
        .showWindowSwitcher: "为前台应用显示窗口切换器弹窗",
        .windowSwitcherDisabled: "禁用后，CMD ` 将不会激活窗口切换弹窗",
        .restoreAllOnSwitch: "切换应用时恢复所有最小化窗口",
        .restoreAllDisabled: "禁用后，仅恢复最近最小化的窗口。",
        .autoOpenWindow: "为无窗口应用自动打开新窗口",
        .autoOpenDisabled: "禁用后，切换到无窗口的应用时不会打开新窗口。",
        .minimizePrevious: "切换应用时最小化上一个窗口",
        .minimizePreviousDisabled: "禁用后，切换到其他应用时不会自动最小化上一个窗口。",
        .tipCannotEnable: "提示：无法与「自动打开窗口」同时启用。",

        .profileRelaxed: "宽松",
        .profileDefault: "默认",
        .profileSpeedy: "快速",
        .profileLabel: "模式：%@",
        .profileDescription: "悬停时 Dock 预览出现和淡出的速度。\n",
        .previewDelay: "预览延迟：%@ 秒",
        .fadeOut: "淡出时间：%@ 秒",

        .version: "版本：%@",
        .checkUpdatesAuto: "自动检查更新",
        .updateInterval: "更新检查频率",
        .daily: "每天",
        .weekly: "每周",
        .monthly: "每月",
        .checkForUpdatesButton: "检查更新…",

        .restoreHelpEnabled: "已启用：切换应用时恢复所有最小化窗口。",
        .restoreHelpDisabled: "已禁用：仅恢复最近最小化的窗口。",
        .autoOpenHelpEnabled: "已启用：无窗口时自动打开新窗口。",
        .autoOpenHelpDisabled: "已禁用：无窗口时不做任何操作。",
        .minimizePrevHelpEnabled: "已启用：自动最小化上一个应用窗口。",
        .minimizePrevHelpDisabled: "已禁用：上一个窗口保持可见。",

        .cheatSheetTitle: "TabLift 快捷键速查",
        .cheatSheetDesc: "流畅切换窗口的必备快捷键。",
        .cheatMinimizeAll: "最小化前台应用的所有窗口",
        .cheatDockClick: "点击 Dock 图标恢复或最小化窗口",
        .cheatRestoreNext: "恢复前台应用的下一个窗口并显示窗口预览",
        .cheatSwitchApps: "在运行的应用之间切换",

        .videoMissing: "视频缺失",
        .showShieldBanner: "显示辅助功能屏蔽提示",

        .maximizeFill: "填充",
        .maximizeFullscreen: "全屏",
        .fillExplanation: "填充：将窗口扩展至可见屏幕区域（菜单栏和 Dock 保持可见）。",
        .fullscreenExplanation: "全屏：进入 macOS 原生全屏模式（窗口成为独立桌面空间，菜单栏和 Dock 隐藏）。",

        .minimizedIndicatorHelp: "此窗口已最小化",

        .language: "语言",

        .tabAbout: "关于",
        .tabGeneral: "通用",
        .tabSupport: "支持",
        .settingsWindowTitle: "TabLift 设置",
    ]
}

// MARK: - Convenience View Extension

extension View {
    /// Shorthand to get a localized string
    func loc(_ key: L10nKey) -> String {
        LocalizationManager.shared.localized(key)
    }

    /// Shorthand with format arguments
    func loc(_ key: L10nKey, _ args: CVarArg...) -> String {
        let fmt = LocalizationManager.shared.localized(key)
        return String(format: fmt, arguments: args)
    }
}

// MARK: - Global Helper

/// Global convenience for non-View contexts
func loc(_ key: L10nKey) -> String {
    LocalizationManager.shared.localized(key)
}

func loc(_ key: L10nKey, _ args: CVarArg...) -> String {
    let fmt = LocalizationManager.shared.localized(key)
    return String(format: fmt, arguments: args)
}
