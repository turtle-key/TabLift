import SwiftUI
import Combine
import Carbon.HIToolbox

class ShortcutPreference: ObservableObject {
    @AppStorage("shortcutKeyCode") private var keyCodeRaw: Int = 0
    @AppStorage("shortcutModifiers") private var modifiersRaw: Int = 0

    var keyCode: UInt16 {
        get { UInt16(keyCodeRaw) }
        set { keyCodeRaw = Int(newValue) }
    }
    var modifiers: NSEvent.ModifierFlags {
        get { NSEvent.ModifierFlags(rawValue: UInt(modifiersRaw)) }
        set { modifiersRaw = Int(newValue.rawValue) }
    }
    var hasShortcut: Bool { keyCodeRaw != 0 && modifiersRaw != 0 }
    var displayKeys: [String] {
        var keys = [String]()
        if modifiers.contains(.command) { keys.append("⌘") }
        if modifiers.contains(.option) { keys.append("⌥") }
        if modifiers.contains(.control) { keys.append("⌃") }
        if modifiers.contains(.shift) { keys.append("⇧") }
        if hasShortcut, let kstr = keyCodeToString(keyCode) { keys.append(kstr.uppercased()) }
        return keys
    }
    var fullString: String {
        displayKeys.joined(separator: " ")
    }
    private func keyCodeToString(_ keyCode: UInt16) -> String? {
        if let special = specialKeyString(for: keyCode) { return special }
        let source = TISCopyCurrentKeyboardLayoutInputSource().takeUnretainedValue()
        let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        guard let data = layoutData else { return nil }
        let keyboardLayout = unsafeBitCast(data, to: CFData.self)
        guard let ptr = CFDataGetBytePtr(keyboardLayout) else { return nil }
        var keysDown: UInt32 = 0
        var chars: [UniChar] = [0, 0, 0, 0]
        var realLength: Int = 0
        let res = UCKeyTranslate(
            UnsafePointer(ptr).withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1, { $0 }),
            keyCode,
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            0,
            &keysDown,
            chars.count,
            &realLength,
            &chars
        )
        guard res == noErr, realLength > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: realLength)
    }
    private func specialKeyString(for keyCode: UInt16) -> String? {
        switch keyCode {
        case UInt16(kVK_Tab): return "Tab"
        case UInt16(kVK_Return): return "↩"
        case UInt16(kVK_Escape): return "⎋"
        case UInt16(kVK_Delete): return "⌫"
        case UInt16(kVK_Space): return "Space"
        case UInt16(kVK_ForwardDelete): return "⌦"
        case UInt16(kVK_LeftArrow): return "←"
        case UInt16(kVK_RightArrow): return "→"
        case UInt16(kVK_UpArrow): return "↑"
        case UInt16(kVK_DownArrow): return "↓"
        case UInt16(kVK_Help): return "Help"
        default: return nil
        }
    }
    func clear() {
        keyCodeRaw = 0
        modifiersRaw = 0
    }
}

struct ShortcutRecorderView: View {
    @ObservedObject var preference: ShortcutPreference
    @State private var listening = false
    @State private var showTimeout = false
    @State private var timeoutWorkItem: DispatchWorkItem?
    @FocusState private var isFocused: Bool

    var body: some View {
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
                } else if preference.hasShortcut {
                    // Show the shortcut as a capsule, click to change
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
                                                .fill(Color.white.opacity(0.90))
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
                            listening = true
                            showTimeout = false
                            isFocused = true
                            startTimeout()
                            NSApp.mainWindow?.makeFirstResponder(nil)
                        }
                        .help("Click to change shortcut")
                } else {
                    // Show the 'Set Shortcut' button
                    Button(action: {
                        listening = true
                        showTimeout = false
                        isFocused = true
                        startTimeout()
                        NSApp.mainWindow?.makeFirstResponder(nil)
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
        .onDisappear { cancelTimeout() }
    }

    private func setupEventMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard listening else { return event }
            // Accept all shortcuts with at least one modifier (cmd, opt, ctrl, shift)
            let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            if !mods.intersection([.command, .option, .control, .shift]).isEmpty {
                preference.keyCode = event.keyCode
                preference.modifiers = mods
                stopListening()
                return nil // Consume event
            }
            // If no modifier, ignore
            return event
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

    private func stopListening() {
        listening = false
        cancelTimeout()
    }
}
