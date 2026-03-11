# Circle OLED Saver — Native macOS Design

## Overview

Native macOS port of the Circle OLED screensaver (originally Electron). Menu bar app + `.saver` screen saver plugin. Prevents OLED burn-in by displaying a bouncing animated circle with rotating content.

## Technology

- **Swift**, macOS 14+ (Sonoma)
- **AppKit** for menu bar app, overlay windows, `.saver` bundle
- **SwiftUI** for settings UI
- **Core Animation** for circle rendering
- **Local Swift Package** for shared rendering code between app and `.saver`

## Architecture

```
CircleOLEDSaver.xcodeproj
├── CircleKit/ (local Swift package — shared rendering)
│   ├── BallPhysics.swift
│   ├── ThemeProtocol.swift
│   ├── MinimalTheme.swift
│   ├── SoftTheme.swift
│   ├── ContentProvider.swift
│   ├── ClockProvider.swift
│   ├── SystemInfoProvider.swift
│   ├── ContentRotator.swift
│   └── CircleRenderer.swift      — Hosts CA layers, drives animation
│
├── CircleApp/ (menu bar app target)
│   ├── CircleApp.swift            — @main, NSApplicationDelegate, menu bar
│   ├── IdleMonitor.swift          — CGEventSource idle polling
│   ├── HotkeyManager.swift       — Global hotkey (⌘⌥O) for always-on
│   ├── OverlayWindowController.swift — Transparent click-through windows
│   ├── CircleView.swift           — NSView hosting CircleRenderer
│   ├── ProximityFade.swift        — Mouse tracking + distance fade
│   ├── TrayManager.swift          — NSStatusItem + menu
│   ├── SettingsManager.swift      — UserDefaults wrapper, @Published
│   ├── Settings/ (SwiftUI)
│   │   ├── SettingsView.swift
│   │   ├── GeneralSettingsView.swift
│   │   └── ContentSettingsView.swift
│   └── Resources/
│       ├── Assets.xcassets
│       └── Info.plist             — LSUIElement=true
│
└── CircleSaver/ (.saver target)
    ├── CircleSaverView.swift      — ScreenSaverView subclass
    └── Info.plist
```

## Shared Rendering (CircleKit)

Local Swift package linked by both the menu bar app and `.saver` targets. Contains:

- Ball physics (bounce/wrap, speed, hue shift)
- Theme protocol + Minimal and Soft themes
- Content providers (Clock, System Info) + rotator
- `CircleRenderer` class that manages CA layers and animation

## Menu Bar App

### Window Behavior
- `NSWindow`: borderless, transparent, `isOpaque = false`
- `NSWindow.Level`: `.screenSaver`
- `ignoresMouseEvents = true` (click-through)
- `collectionBehavior`: `.canJoinAllSpaces, .stationary`
- One window per display, repositioned on `didChangeScreenParametersNotification`
- No rounded corners — fully transparent, only the circle is visible

### Idle Monitoring
- `CGEventSource.secondsSinceLastEventType(.combinedSessionState, .any)`
- Polled every 1 second
- Configurable threshold (5-300 seconds)
- Skipped in always-on mode

### Always-On Mode
- Global hotkey via Carbon hotkey API (default ⌘⌥O)
- Bypasses idle detection, keeps overlay visible
- Toggled from menu bar or hotkey
- Brief notification on toggle

### Proximity Fade
- `NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved)`
- Quadratic fade curve based on distance from circle edge
- Configurable radius (50-500px)
- Applied to layer opacity

### Menu Bar
- `NSStatusItem` with template image
- Menu: Enable/Disable, Always On (⌘⌥O), Settings..., Quit
- Launch at login via `SMAppService.mainApp`

### Settings (SwiftUI)
- Opened via `NSHostingController` in standard `NSWindow`
- **General tab**: enable, idle timeout, ball size/opacity/speed, theme picker, proximity fade, always-on + hotkey, launch at login
- **Content tab**: provider toggles, rotation interval, clock format, battery toggle
- Persisted via `UserDefaults` with App Group suite
- Changes observed immediately via `@AppStorage` / `NotificationCenter`

## Screen Saver Plugin (.saver)

- `ScreenSaverView` subclass hosting CircleKit's `CircleRenderer`
- macOS handles idle detection and activation
- Reads settings from shared App Group `UserDefaults`
- No proximity fade or always-on (handled by menu bar app only)
- Installed to `~/Library/Screen Savers/`

## Themes

### MinimalTheme
- `CAGradientLayer` radial gradient for circle fill
- `CALayer.shadowPath` for glow
- HSL hue cycling on bounce
- `CATextLayer` for content text

### SoftTheme
- `CAShapeLayer` with morphing blob path (sinusoidal radius offsets)
- Pastel color palette
- `CABasicAnimation` on path property
- Same `CATextLayer` for content

### ThemeProtocol
- `func setup(in layer: CALayer)`
- `func update(position: CGPoint, size: CGFloat, hue: CGFloat, opacity: CGFloat)`
- `func setContent(icon: String, text: String)`

## Content Providers

- `ContentProvider` protocol: `func fetch() async -> ContentData`, `refreshInterval: TimeInterval`
- `ClockProvider`: DateFormatter, 12/24h, refreshes 1s
- `SystemInfoProvider`: CPU via `host_processor_info()`, memory via `host_statistics64()`, battery via `IOPSCopyPowerSourcesInfo()`, refreshes 2s
- `ContentRotator`: timer-based cycling, configurable interval

## Settings Schema (UserDefaults)

| Key | Type | Default |
|-----|------|---------|
| enabled | Bool | true |
| idleTimeout | Int | 10 |
| ballSizeMode | String | "percentage" |
| ballSize | Int | 15 |
| ballOpacity | Int | 100 |
| ballSpeed | Int | 100 |
| theme | String | "minimal" |
| proximityFadeEnabled | Bool | true |
| proximityFadeRadius | Int | 150 |
| alwaysOnMode | Bool | false |
| alwaysOnHotkey | String | "⌘⌥O" |
| launchAtLogin | Bool | false |
| contentRotationEnabled | Bool | true |
| contentRotationInterval | Int | 10 |
| clockEnabled | Bool | true |
| clockFormat24h | Bool | false |
| systemInfoEnabled | Bool | true |
| showBattery | Bool | true |

## Out of Scope (Future)

- Stock ticker content provider
- Glassy and Abstract themes
- Caret tracking (Accessibility API)
- Proximity fade for text caret
