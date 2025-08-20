import SwiftUI
import Combine
import Carbon.HIToolbox

class ShortcutPreference: ObservableObject {
    @AppStorage("shortcutKeyCode") private var keyCodeRaw: Int = 50
    @AppStorage("shortcutKeyString") private var keyStringRaw: String = "`"
    @AppStorage("shortcutModifiers") private var modifiersRaw: Int = Int(NSEvent.ModifierFlags.command.rawValue)

    var keyCode: UInt16 {
        get { UInt16(max(0, keyCodeRaw)) } // Ensure not negative
        set { keyCodeRaw = Int(newValue) }
    }
    var keyString: String {
        get { keyStringRaw }
        set { keyStringRaw = newValue }
    }
    var modifiers: NSEvent.ModifierFlags {
        get { NSEvent.ModifierFlags(rawValue: UInt(modifiersRaw)) }
        set { modifiersRaw = Int(newValue.rawValue) }
    }
    // Only treat both as zero for "no shortcut"
    var hasShortcut: Bool { !(keyCodeRaw == 0 && modifiersRaw == 0) }
    var displayKeys: [String] {
        var keys = [String]()
        if modifiers.contains(.command) { keys.append("⌘") }
        if modifiers.contains(.option) { keys.append("⌥") }
        if modifiers.contains(.control) { keys.append("⌃") }
        if modifiers.contains(.shift) { keys.append("⇧") }
        if hasShortcut && !keyString.isEmpty {
            keys.append(keyString.uppercased())
        }
        return keys
    }
    var fullString: String {
        displayKeys.joined(separator: " ")
    }
    func clear() {
        keyCodeRaw = 0
        keyStringRaw = ""
        modifiersRaw = 0
    }
}

private let forbiddenKeyStrings: Set<String> = [
    "1", "2", "3", "4", "5", "6", "7", "8", "9", "0"
]
private let forbiddenKeyCodes: Set<UInt16> = [
    56, 60 // Shift (left and right)
]

struct ShortcutRecorderView: View {
    @ObservedObject var preference: ShortcutPreference
    @State private var listening = false
    @State private var showTimeout = false
    @State private var timeoutWorkItem: DispatchWorkItem?
    @FocusState private var isFocused: Bool

    @State private var keyMonitor: Any?

    var onBeginRecording: (() -> Void)? = nil
    var onEndRecording: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Spacer()
                ZStack {
                    if listening {
                        Capsule()
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(height: 44)
                            .overlay(
                                HStack(spacing: 18) {
                                    ProgressView()
                                        .scaleEffect(0.85)
                                        .frame(width: 18, height: 18)
                                    Text(showTimeout ? "Timed out" : "Press shortcut…")
                                        .foregroundColor(showTimeout ? .red : .accentColor)
                                        .font(.system(.body, design: .monospaced).weight(.medium))
                                }
                            )
                            .frame(minWidth: 200)
                            .onAppear { setupEventMonitor() }
                            .onDisappear { removeEventMonitor() }
                    } else if preference.hasShortcut {
                        Capsule()
                            .fill(Color.accentColor.opacity(0.12))
                            .frame(height: 44)
                            .overlay(
                                HStack(spacing: 18) {
                                    Text("Shortcut:")
                                        .font(.system(size: 16, weight: .medium, design: .rounded))
                                        .foregroundColor(.accentColor)
                                    ForEach(preference.displayKeys, id: \.self) { key in
                                        Text(key)
                                            .font(.system(size: 19, weight: .medium, design: .rounded))
                                            .foregroundColor(.primary)
                                            .frame(minWidth: 28)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 3)
                                            .background(
                                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                    .fill(Color(NSColor.controlBackgroundColor))
                                            )
                                            .shadow(color: Color.accentColor.opacity(0.11), radius: 1, x: 0, y: 1)
                                    }
                                }
                            )
                            .frame(minWidth: 200)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .strokeBorder(Color.accentColor.opacity(0.16), lineWidth: 1.2)
                            )
                            .onTapGesture {
                                beginListening()
                            }
                            .help("Click to change shortcut")
                    } else {
                        Button(action: {
                            beginListening()
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "keyboard")
                                    .font(.title2)
                                Text("Set Shortcut")
                                    .font(.system(.body, design: .monospaced).weight(.semibold))
                            }
                            .frame(minWidth: 200, minHeight: 44)
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 10)
                            .background(
                                Capsule()
                                    .fill(Color.accentColor.opacity(0.16))
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.accentColor.opacity(0.18), lineWidth: 1.2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 6)
                Spacer()
            }

            Text("Default shortcut: ⌘ + ` (command + backtick)")
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.top, 2)
            Text("You can modify the shortcut here. Numbers (0-9) and Shift are reserved for window switching and cannot be used as the main shortcut.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .onDisappear {
            cancelTimeout()
            removeEventMonitor()
        }
    }

    private func beginListening() {
        listening = true
        showTimeout = false
        isFocused = true
        startTimeout()
        NSApp.mainWindow?.makeFirstResponder(nil)
        onBeginRecording?()
    }

    private func stopListening() {
        listening = false
        cancelTimeout()
        onEndRecording?()
        removeEventMonitor()
    }

    private func setupEventMonitor() {
        removeEventMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard listening else { return event }
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let requiredMods = mods.intersection([.command, .option, .control])
            let keyString = event.charactersIgnoringModifiers ?? ""
            let keyCode = event.keyCode

            // Fix: allow keyCode==0 (A key) as valid!
            // Only treat no shortcut if both keyCode==0 and modifier==0
            if requiredMods.isEmpty ||
                forbiddenKeyStrings.contains(keyString) ||
                forbiddenKeyCodes.contains(keyCode) ||
                mods.contains(.shift) ||
                keyString.isEmpty {
                NSSound.beep()
                return nil
            }

            preference.keyCode = keyCode
            preference.keyString = keyString
            preference.modifiers = mods
            stopListening()
            return nil
        }
    }

    private func removeEventMonitor() {
        if let keyMonitor = keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private func startTimeout() {
        cancelTimeout()
        let workItem = DispatchWorkItem {
            if listening {
                showTimeout = true
                stopListening()
            }
        }
        timeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: workItem)
    }

    private func cancelTimeout() {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        showTimeout = false
    }
}
