import SwiftUI
import Carbon
import CircleKit

struct HotkeyRecorderView: View {
    @ObservedObject private var settings = SettingsManager.shared
    @State private var isRecording = false

    var body: some View {
        HStack(spacing: 12) {
            Text("Hotkey")
                .frame(width: 90, alignment: .leading)

            Button(action: { isRecording.toggle() }) {
                Text(isRecording ? "Press keys..." : displayString(for: settings.alwaysOnHotkey))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isRecording ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
            .background(
                Group {
                    if isRecording {
                        HotkeyListener { hotkey in
                            settings.alwaysOnHotkey = hotkey
                            isRecording = false
                        }
                    }
                }
            )
        }
    }

    private func displayString(for hotkey: String) -> String {
        hotkey.split(separator: "+").map { part in
            switch part.lowercased() {
            case "cmd": return "\u{2318}"
            case "opt": return "\u{2325}"
            case "ctrl": return "\u{2303}"
            case "shift": return "\u{21E7}"
            default: return part.uppercased()
            }
        }.joined()
    }
}

// MARK: - NSView-based key listener

private struct HotkeyListener: NSViewRepresentable {
    let onRecord: (String) -> Void

    func makeNSView(context: Context) -> KeyListenerView {
        let view = KeyListenerView()
        view.onRecord = onRecord
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return view
    }

    func updateNSView(_ nsView: KeyListenerView, context: Context) {
        nsView.onRecord = onRecord
    }
}

class KeyListenerView: NSView {
    var onRecord: ((String) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Require at least one modifier
        guard !flags.isEmpty else { return }
        // Escape cancels
        if event.keyCode == UInt16(kVK_Escape) { return }

        var parts: [String] = []
        if flags.contains(.control) { parts.append("ctrl") }
        if flags.contains(.option) { parts.append("opt") }
        if flags.contains(.shift) { parts.append("shift") }
        if flags.contains(.command) { parts.append("cmd") }

        if let key = keyString(for: event.keyCode) {
            parts.append(key)
        }

        // Need at least one modifier + one key
        let modCount = parts.count - (parts.last.map { isModifier($0) ? 0 : 1 } ?? 0)
        guard modCount >= 1 && parts.count > modCount else { return }

        onRecord?(parts.joined(separator: "+"))
    }

    private func isModifier(_ s: String) -> Bool {
        ["cmd", "opt", "ctrl", "shift"].contains(s)
    }

    private func keyString(for keyCode: UInt16) -> String? {
        let mapping: [UInt16: String] = [
            UInt16(kVK_ANSI_A): "a", UInt16(kVK_ANSI_B): "b", UInt16(kVK_ANSI_C): "c",
            UInt16(kVK_ANSI_D): "d", UInt16(kVK_ANSI_E): "e", UInt16(kVK_ANSI_F): "f",
            UInt16(kVK_ANSI_G): "g", UInt16(kVK_ANSI_H): "h", UInt16(kVK_ANSI_I): "i",
            UInt16(kVK_ANSI_J): "j", UInt16(kVK_ANSI_K): "k", UInt16(kVK_ANSI_L): "l",
            UInt16(kVK_ANSI_M): "m", UInt16(kVK_ANSI_N): "n", UInt16(kVK_ANSI_O): "o",
            UInt16(kVK_ANSI_P): "p", UInt16(kVK_ANSI_Q): "q", UInt16(kVK_ANSI_R): "r",
            UInt16(kVK_ANSI_S): "s", UInt16(kVK_ANSI_T): "t", UInt16(kVK_ANSI_U): "u",
            UInt16(kVK_ANSI_V): "v", UInt16(kVK_ANSI_W): "w", UInt16(kVK_ANSI_X): "x",
            UInt16(kVK_ANSI_Y): "y", UInt16(kVK_ANSI_Z): "z",
            UInt16(kVK_ANSI_0): "0", UInt16(kVK_ANSI_1): "1", UInt16(kVK_ANSI_2): "2",
            UInt16(kVK_ANSI_3): "3", UInt16(kVK_ANSI_4): "4", UInt16(kVK_ANSI_5): "5",
            UInt16(kVK_ANSI_6): "6", UInt16(kVK_ANSI_7): "7", UInt16(kVK_ANSI_8): "8",
            UInt16(kVK_ANSI_9): "9",
            UInt16(kVK_Space): "space", UInt16(kVK_Return): "return",
            UInt16(kVK_Tab): "tab", UInt16(kVK_Delete): "delete",
            UInt16(kVK_F1): "f1", UInt16(kVK_F2): "f2", UInt16(kVK_F3): "f3",
            UInt16(kVK_F4): "f4", UInt16(kVK_F5): "f5", UInt16(kVK_F6): "f6",
            UInt16(kVK_F7): "f7", UInt16(kVK_F8): "f8", UInt16(kVK_F9): "f9",
            UInt16(kVK_F10): "f10", UInt16(kVK_F11): "f11", UInt16(kVK_F12): "f12",
            UInt16(kVK_LeftArrow): "left", UInt16(kVK_RightArrow): "right",
            UInt16(kVK_UpArrow): "up", UInt16(kVK_DownArrow): "down",
            UInt16(kVK_ANSI_Minus): "-", UInt16(kVK_ANSI_Equal): "=",
            UInt16(kVK_ANSI_LeftBracket): "[", UInt16(kVK_ANSI_RightBracket): "]",
            UInt16(kVK_ANSI_Semicolon): ";", UInt16(kVK_ANSI_Quote): "'",
            UInt16(kVK_ANSI_Comma): ",", UInt16(kVK_ANSI_Period): ".",
            UInt16(kVK_ANSI_Slash): "/", UInt16(kVK_ANSI_Backslash): "\\",
            UInt16(kVK_ANSI_Grave): "`",
        ]
        return mapping[keyCode]
    }
}
