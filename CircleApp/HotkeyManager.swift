import Foundation
import Carbon
import CircleKit

final class HotkeyManager {
    var onToggle: (() -> Void)?

    private var hotkeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    func register() {
        unregister()

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x4352434C) // "CRCL"
        hotKeyID.id = 1

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handler: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let userData else { return OSStatus(eventNotHandledErr) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async {
                manager.onToggle?()
            }
            return noErr
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, selfPtr, &eventHandler)

        // ⌘⌥O
        let modifiers: UInt32 = UInt32(cmdKey | optionKey)
        let keyCode: UInt32 = UInt32(kVK_ANSI_O)

        RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotkeyRef)
    }

    func unregister() {
        if let hotkeyRef {
            UnregisterEventHotKey(hotkeyRef)
        }
        hotkeyRef = nil

        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
        eventHandler = nil
    }

    deinit {
        unregister()
    }
}
