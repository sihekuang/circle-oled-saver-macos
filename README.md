# Circle OLED Saver

A bouncing circle screensaver for macOS, designed for OLED displays. Ships as both a menu bar app and a native Screen Saver bundle, both powered by the same shared rendering framework.

---

## Features

- **Idle detection** — activates automatically after a configurable timeout
- **Multi-monitor** — spawns an independent overlay on every connected screen
- **Two themes** — Minimal (glowing circle) and Soft (morphing blob)
- **Proximity fade** — circle fades out as the cursor approaches it
- **Content display** — shows clock and system info (battery, etc.) inside the circle
- **Content rotation** — cycles between clock and system info on a configurable interval
- **Always-on mode** — keeps the overlay visible regardless of idle state
- **Global hotkey** — toggle always-on with ⌘⌥O
- **Launch at login** — optional background launch on startup

---

## Getting Started

### Requirements

- macOS 14.0+
- Xcode 15.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

### Build & Run

```bash
git clone https://github.com/sihekuang/oled-saver-macos.git
cd oled-saver-macos
xcodegen generate
open CircleOLEDSaver.xcodeproj
```

Select the **CircleApp** scheme and run. The app appears in the menu bar (no dock icon).

### Install the Screen Saver

Build the **CircleSaver** scheme, then double-click the `.saver` bundle in `DerivedData` to install it into System Settings > Screen Saver.

### Running Tests

```bash
cd CircleKit && swift test
```

---

## Architecture

The project is split into three targets. `CircleKit` is the shared Swift Package that contains all rendering logic. Both `CircleApp` and `CircleSaver` are thin shells that hand off to `CircleKit`.

```
┌─────────────────────────────────┐
│         CircleKit               │
│      (Swift Package)            │
│                                 │
│  CircleRenderer                 │
│  BallPhysics / BallState        │
│  Theme protocol                 │
│  ├─ MinimalTheme                │
│  └─ SoftTheme                   │
│  ContentProvider protocol       │
│  ├─ ClockProvider               │
│  └─ SystemInfoProvider          │
│  ContentRotator                 │
│  SettingsManager                │
└────────────┬────────────────────┘
             │
     ┌───────┴────────┐
     ▼                ▼
┌─────────────┐  ┌──────────────┐
│  CircleApp  │  │ CircleSaver  │
│ (menu bar)  │  │ (screen saver│
│             │  │  bundle)     │
└─────────────┘  └──────────────┘
```

**CircleApp** is a menu bar app (`NSStatusItem`) that manages idle detection, a global hotkey, and per-screen overlay windows. It is the primary distribution target.

**CircleSaver** is a standard macOS Screen Saver bundle (`ScreenSaverView`) for users who prefer the system screensaver flow. It has no settings UI of its own — it reads from the same shared `UserDefaults` suite as `CircleApp`.

---

## Module Breakdown

### `CircleRenderer`
The main animation controller. Owns a `CVDisplayLink` that drives a tick loop at display refresh rate. Each tick it advances physics, computes opacity, and calls the active theme to update visuals and content.

### `BallPhysics` / `BallState`
`BallState` is a value type holding position, velocity, radius, hue, and speed. `BallPhysics` is a stateless utility with static methods for edge bouncing/wrapping, speed clamping, and proximity-based opacity calculation (quadratic falloff).

### `Theme` protocol
Defines the contract all themes implement: `setup`, `tick`, `updateMotion`, `updateAppearance`, `setContent`, and `teardown`. Each theme owns its own `CALayer` tree and is responsible for both movement logic and visual rendering.

- **MinimalTheme** — a solid circle `CALayer` with a soft glow layer and embedded `CATextLayer`s for icon and text.
- **SoftTheme** — a `CAShapeLayer` that builds a smooth morphing blob path each frame using bezier curves, with squish on bounce.

### `ContentProvider` / `ContentRotator`
`ContentProvider` is a protocol for anything that produces a `ContentData` (icon + text string). `BaseContentProvider` handles the timer loop. `ClockProvider` and `SystemInfoProvider` are the built-in implementations. `ContentRotator` owns a list of providers and exposes the currently active one, rotating on a configurable interval.

### `SettingsManager`
A singleton `ObservableObject` backed by a shared `UserDefaults` suite (`com.shoebillsoft.circle.shared`). All settings are `@Published` and post a `settingsChangedNotification` on change so both `CircleApp` and `CircleRenderer` can react without tight coupling.

---

## Frame Lifecycle

Each display frame follows this path:

1. **CVDisplayLink fires** — `CircleRenderer.frame()` is called on the main thread
2. **Tick** — the active theme's `tick(deltaTime:)` advances any time-based animation state (morphing, color shift)
3. **Motion update** — `BallState` is wrapped in a `MotionState` and passed to `theme.updateMotion(state:bounds:)`, which returns updated position and velocity; the result is written back to `BallState`
4. **Opacity** — `BallPhysics.proximityOpacity` computes a 0–1 fade factor based on cursor distance; multiplied with the base opacity setting to get `finalOpacity`
5. **Appearance** — `theme.updateAppearance(position:size:hue:opacity:)` repositions and recolors all `CALayer`s (animations disabled via `CATransaction`)
6. **Content** — `theme.setContent(_:)` pushes the latest `ContentData` from the active provider into the text layers

---

## Distribution

Releases are built and published automatically by [`.github/workflows/release.yml`](.github/workflows/release.yml) on every `v*` tag, and attached as `Circle.zip` to the corresponding [GitHub Release](https://github.com/sihekuang/circle-oled-saver-macos/releases). The build is **ad-hoc signed** (no Apple Developer cert), so first launch requires right-click → **Open** to bypass Gatekeeper. See [docs/distribution.md](docs/distribution.md) for details.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and guidelines.

## License

[MIT](LICENSE)
