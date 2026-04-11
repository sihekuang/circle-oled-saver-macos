# Hotkey System

**File**: `CircleApp/HotkeyManager.swift`

Uses the **Carbon Event Manager** (`kEventHotKeyPressed`) for global hotkey registration.

## Registered Hotkeys

| ID | Default | Action |
|----|---------|--------|
| 1 | `Cmd+Opt+O` | Toggle always-on mode |
| 2 | `Cmd+Opt+E` | Toggle enabled |
| 3 | `Cmd+Opt+=` | Increase ball size |
| 4 | `Cmd+Opt+-` | Decrease ball size |
| 5 | `Cmd+Opt+R` | Rotate content |

All hotkeys are configurable via [[Settings]] and the Settings UI's `HotkeyRecorderView`.

## Implementation

- **Signature**: `"CRCL"` (FourCharCode)
- Hotkey strings parsed by splitting on `+` delimiter
- Modifiers: `cmd`, `opt`, `ctrl`, `shift`
- Key codes mapped to `kVK_*` constants (full ASCII + special keys)
- Callbacks dispatched to main thread
- Uses `Unmanaged.fromOpaque()` to retrieve manager instance in C callback

## Interaction with Idle Detection

When a hotkey fires, [[Idle Detection]] suppression is triggered to prevent the keypress from being treated as user activity that would dismiss the overlay.

## See Also

- [[CircleApp#AppDelegate]]
- [[Settings#Hotkeys]]
