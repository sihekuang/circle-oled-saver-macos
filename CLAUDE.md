# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Generate Xcode project (required after changing project.yml or Package.swift)
xcodegen generate

# Build targets
xcodebuild -scheme CircleApp -configuration Debug build
xcodebuild -scheme CircleSaver -configuration Debug build

# Run CircleKit tests
cd CircleKit && swift test

# Run a single test
cd CircleKit && swift test --filter BallPhysicsTests/testBounceChangesDirection
```

## Architecture

Circle OLED Saver is a bouncing circle screensaver for macOS OLED displays, distributed as both a menu bar app and a native `.saver` bundle. The key architectural decision is a **three-tier design** where both frontends share a single rendering framework:

```
CircleKit (Swift Package — shared rendering, physics, themes, content, settings)
    ├── CircleApp (AppKit + SwiftUI — menu bar app with idle detection, hotkeys, settings UI)
    └── CircleSaver (ScreenSaver framework — thin adapter, no UI of its own)
```

**CircleKit** (`CircleKit/Sources/CircleKit/`) is the core. `CircleRenderer` drives animation via `CVDisplayLink`, delegating visuals to a `Theme` protocol (MinimalTheme = glowing circle, SoftTheme = morphing blob). `ContentProvider` protocol + `ContentRotator` cycle through data sources (clock, system info, stocks) displayed inside the ball. `SettingsManager` is a singleton backed by a shared `UserDefaults` suite so both app and saver read the same config.

**CircleApp** (`CircleApp/`) is an `LSUIElement` (no dock icon). `AppDelegate` wires together `IdleMonitor` (CGEventSource polling), `HotkeyManager` (Carbon events), `TrayManager` (NSStatusItem), and `OverlayWindowController` (borderless `.screenSaver`-level windows per OLED display). Settings UI is SwiftUI hosted in an NSWindow.

**CircleSaver** (`CircleSaver/`) is just `CircleSaverView: ScreenSaverView` that creates a `CircleRenderer` on start and tears it down on stop.

## Key Patterns

- Settings changes propagate via `NotificationCenter` (`settingsChangedNotification`), not bindings
- `CVDisplayLink` callback dispatches to main thread — all `CALayer` work is main-thread only
- Hotkey presses trigger `IdleMonitor.suppressDismissal()` to prevent the keypress itself from dismissing the overlay
- Both targets share UserDefaults suite `com.danielkurin.circle.shared`

## Build System

- **XcodeGen** (`project.yml`) generates `CircleOLEDSaver.xcodeproj` — run `xcodegen generate` after structural changes
- **Swift Package Manager** for CircleKit (local package dependency)
- macOS 14.0+ / Swift 5.9 / Xcode 15.0
- Tests use a mix of Swift Testing and XCTest frameworks
