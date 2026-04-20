import Foundation
import Carbon
import CircleKit

final class HotkeyManager {
    var onAlwaysOnToggle: (() -> Void)?
    var onEnableToggle: (() -> Void)?
    var onSizeUp: (() -> Void)?
    var onSizeDown: (() -> Void)?
    var onRotateContent: (() -> Void)?
    var onMenuBarAutoHideToggle: (() -> Void)?

    private var hotkeyRefs: [EventHotKeyRef] = []
    private var eventHandler: EventHandlerRef?

    private enum HotkeyID: UInt32 {
        case alwaysOn = 1
        case enable = 2
        case sizeUp = 3
        case sizeDown = 4
        case rotateContent = 5
        case menuBarAutoHide = 6
    }

    func register() {
        unregister()

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handler: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let userData, let event else { return OSStatus(eventNotHandledErr) }

            var hotKeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)

            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async {
                switch HotkeyID(rawValue: hotKeyID.id) {
                case .alwaysOn: manager.onAlwaysOnToggle?()
                case .enable: manager.onEnableToggle?()
                case .sizeUp: manager.onSizeUp?()
                case .sizeDown: manager.onSizeDown?()
                case .rotateContent: manager.onRotateContent?()
                case .menuBarAutoHide: manager.onMenuBarAutoHideToggle?()
                case nil: break
                }
            }
            return noErr
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, selfPtr, &eventHandler)

        let settings = SettingsManager.shared
        let signature = OSType(0x4352434C) // "CRCL"

        let hotkeys: [(HotkeyID, String)] = [
            (.alwaysOn, settings.alwaysOnHotkey),
            (.enable, settings.enableHotkey),
            (.sizeUp, settings.sizeUpHotkey),
            (.sizeDown, settings.sizeDownHotkey),
            (.rotateContent, settings.rotateContentHotkey),
            (.menuBarAutoHide, settings.menuBarAutoHideHotkey),
        ]

        for (id, hotkeyString) in hotkeys {
            var ref: EventHotKeyRef?
            var hkID = EventHotKeyID(signature: signature, id: id.rawValue)
            let (keyCode, modifiers) = parseHotkey(hotkeyString)
            RegisterEventHotKey(keyCode, modifiers, hkID, GetApplicationEventTarget(), 0, &ref)
            if let ref { hotkeyRefs.append(ref) }
        }
    }

    func unregister() {
        for ref in hotkeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotkeyRefs.removeAll()

        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
        eventHandler = nil
    }

    deinit {
        unregister()
    }

    // MARK: - Hotkey Parsing

    private func parseHotkey(_ hotkey: String) -> (UInt32, UInt32) {
        let parts = hotkey.lowercased().split(separator: "+").map(String.init)

        var modifiers: UInt32 = 0
        var keyCode: UInt32 = UInt32(kVK_ANSI_O)

        for part in parts {
            switch part {
            case "cmd": modifiers |= UInt32(cmdKey)
            case "opt": modifiers |= UInt32(optionKey)
            case "ctrl": modifiers |= UInt32(controlKey)
            case "shift": modifiers |= UInt32(shiftKey)
            default:
                if let code = keyCodeMap[part] {
                    keyCode = UInt32(code)
                }
            }
        }

        if modifiers == 0 {
            modifiers = UInt32(cmdKey | optionKey)
        }

        return (keyCode, modifiers)
    }

    private let keyCodeMap: [String: Int] = [
        "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C,
        "d": kVK_ANSI_D, "e": kVK_ANSI_E, "f": kVK_ANSI_F,
        "g": kVK_ANSI_G, "h": kVK_ANSI_H, "i": kVK_ANSI_I,
        "j": kVK_ANSI_J, "k": kVK_ANSI_K, "l": kVK_ANSI_L,
        "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O,
        "p": kVK_ANSI_P, "q": kVK_ANSI_Q, "r": kVK_ANSI_R,
        "s": kVK_ANSI_S, "t": kVK_ANSI_T, "u": kVK_ANSI_U,
        "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X,
        "y": kVK_ANSI_Y, "z": kVK_ANSI_Z,
        "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2,
        "3": kVK_ANSI_3, "4": kVK_ANSI_4, "5": kVK_ANSI_5,
        "6": kVK_ANSI_6, "7": kVK_ANSI_7, "8": kVK_ANSI_8,
        "9": kVK_ANSI_9,
        "space": kVK_Space, "return": kVK_Return,
        "tab": kVK_Tab, "delete": kVK_Delete,
        "f1": kVK_F1, "f2": kVK_F2, "f3": kVK_F3,
        "f4": kVK_F4, "f5": kVK_F5, "f6": kVK_F6,
        "f7": kVK_F7, "f8": kVK_F8, "f9": kVK_F9,
        "f10": kVK_F10, "f11": kVK_F11, "f12": kVK_F12,
        "left": kVK_LeftArrow, "right": kVK_RightArrow,
        "up": kVK_UpArrow, "down": kVK_DownArrow,
        "-": kVK_ANSI_Minus, "=": kVK_ANSI_Equal,
        "[": kVK_ANSI_LeftBracket, "]": kVK_ANSI_RightBracket,
        ";": kVK_ANSI_Semicolon, "'": kVK_ANSI_Quote,
        ",": kVK_ANSI_Comma, ".": kVK_ANSI_Period,
        "/": kVK_ANSI_Slash, "\\": kVK_ANSI_Backslash,
        "`": kVK_ANSI_Grave,
    ]
}
