# Circle OLED Saver

A bouncing circle screensaver for macOS, designed for OLED displays. Ships as both a **menu bar app** and a **native Screen Saver bundle**, powered by a shared rendering framework.

## Architecture

```
         +---------------------------+
         |    CircleKit (Framework)   |
         |  Rendering & Animation    |
         +------+------------+-------+
                |            |
        +-------+--+   +----+--------+
        | CircleApp |   | CircleSaver |
        | Menu Bar  |   | .saver      |
        +-----------+   +-------------+
```

- [[CircleKit]] - Shared Swift Package with rendering, physics, themes, content
- [[CircleApp]] - Menu bar application (AppKit + SwiftUI)
- [[CircleSaver]] - macOS Screen Saver bundle

## Key Features

| Feature | Notes |
|---------|-------|
| Bouncing animation | CVDisplayLink-driven at display refresh rate |
| [[Themes]] | Minimal (glowing circle) and Soft (morphing blob) |
| [[Content Providers]] | Clock, System Info, Stocks - rotating display |
| [[Idle Detection]] | CGEventSource polling triggers overlay |
| [[Hotkey System]] | Carbon Event Manager for global hotkeys |
| Multi-monitor | Per-screen overlay windows, configurable per display |
| [[Proximity Fade]] | Ball fades as cursor approaches |
| [[Settings]] | Shared UserDefaults between app and saver |

## Build System

- **XcodeGen** generates `.xcodeproj` from `project.yml`
- **Swift Package Manager** for CircleKit
- **Deployment target**: macOS 14.0+
- **Swift**: 5.9

## External Dependencies

| Dependency | Purpose |
|------------|---------|
| MacHUD | On-screen HUD notifications |

## Design Patterns

- Protocol-oriented design ([[Themes]], [[Content Providers]])
- Singleton (`SettingsManager.shared`, `HUDController.shared`)
- Observer (NotificationCenter for settings changes)
- Callback (IdleMonitor, HotkeyManager)
- Value types for state (`BallState`, `MotionState`)
