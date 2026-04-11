# CircleApp

Menu bar application (AppKit + SwiftUI hybrid). No dock icon (`LSUIElement: true`).

**Path**: `CircleApp/`
**Bundle ID**: `com.danielkurin.circle`

## Entry Point

`main.swift` - creates `NSApplication` and sets `AppDelegate`.

## AppDelegate

**File**: `AppDelegate.swift`

Initialization sequence:
1. Prevent duplicate instances
2. Default all screens to OLED on first launch
3. Setup [[TrayManager]]
4. Setup [[Idle Detection|IdleMonitor]] with callbacks
5. Register [[Hotkey System|hotkeys]] with callbacks
6. Restore always-on state
7. Setup login item management
8. Register for settings & display change notifications

### Overlay Management

- `showOverlays()` - creates `OverlayWindowController` for each OLED screen
- `dismissOverlays()` - cleans up windows and views
- `toggleAlwaysOn()` - enter/exit always-on mode

## OverlayWindowController

**File**: `OverlayWindowController.swift`

Creates borderless overlay windows per OLED display:
- Window level: `.screenSaver`
- Ignores mouse events
- Joins all spaces, stationary, fullscreen auxiliary
- Filters screens via `settings.isOLEDScreen(displayID:)`

## CircleOverlayView

**File**: `CircleOverlayView.swift`

`NSView` subclass hosting a `CALayer` for [[CircleKit#CircleRenderer|CircleRenderer]].

- Registers global mouse movement monitor for [[Proximity Fade]]
- Manages animation lifecycle (start/stop)

## HUD Controller

**File**: `HUDWindowController.swift`

Uses **MacHUD** library for on-screen feedback:
- Always-on toggle (moon icon)
- Enable toggle (circle icon)
- Size change (progress bar, 16 segments)
- Content rotation (context-based icon)

## Settings UI

**Path**: `CircleApp/Settings/`

SwiftUI views hosted in an `NSWindow` via `SettingsWindowController`.

| Tab | Content |
|-----|---------|
| General | Enable, idle timeout, display selection, always-on, launch at login, hotkeys |
| Appearance | Theme, size, opacity, speed, proximity fade |
| Content | Rotation, clock, system info, stocks |
| About | App info |

See [[Settings]] for full configuration details.

## See Also

- [[Idle Detection]]
- [[Hotkey System]]
- [[TrayManager]]
- [[Data Flow]]
