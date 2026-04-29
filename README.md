# Circle OLED Saver

A bouncing circle screensaver for macOS, designed for OLED displays. Ships as both a menu bar app and a native Screen Saver bundle, both powered by the same shared rendering framework.

---

## Features

- **Idle detection** — activates automatically after a configurable timeout
- **Multi-monitor** — spawns an independent overlay on every connected screen
- **Two themes** — Minimal (glowing circle) and Soft (morphing blob)
- **Proximity fade** — circle fades out as the cursor approaches it
- **Content display** — shows clock, system info (battery, etc.), and Claude Code usage inside the circle
- **Content rotation** — cycles between content providers on a configurable interval
- **Always-on mode** — keeps the overlay visible regardless of idle state
- **Global hotkey** — toggle always-on with ⌘⌥O
- **Launch at login** — optional background launch on startup

---

## Claude Code usage display

One of the built-in content providers shows your current Claude Code subscription quota (`5h` and `7d` utilization percentages plus the absolute token count) inside the circle. Here's exactly how it works, since it touches the keychain:

- **Source of the number.** The provider calls `https://api.anthropic.com/api/oauth/usage` with the `anthropic-beta: oauth-2025-04-20` header. This is the same endpoint Claude Code's own statusline uses to render the quota bar. The response shape is decoded in [`AnthropicUsageClient.swift`](CircleKit/Sources/CircleKit/Auth/AnthropicUsageClient.swift).
- **How auth works.** Claude Code stores its OAuth credential blob in the macOS Keychain under service name `Claude Code-credentials`. The provider reads the access token from that entry and includes it as a Bearer token on the API request. Token refresh is handled by Claude Code itself in the background — Circle just reads whatever access token is current at fetch time. See [`ClaudeCodeKeychain.swift`](CircleKit/Sources/CircleKit/Auth/ClaudeCodeKeychain.swift).
- **What you'll see the first time.** macOS shows the standard keychain access prompt (*"Circle wants to use your confidential information stored in 'Claude Code-credentials' in your keychain"*). Click **Always Allow** to make subsequent reads silent, or **Deny** to keep the feature off.
- **Where the token goes.** Only into the single HTTPS request to `api.anthropic.com`. The token is never logged, persisted, or sent anywhere else. The feature is gated behind an explicit Settings toggle, so the keychain is not touched until you opt in.
- **Stability caveat.** `/api/oauth/usage` is a **beta endpoint** that is not part of Anthropic's documented public API surface. Anthropic could change the response shape, tighten rate limits, or remove the endpoint without notice — in which case this provider will silently fall back to "—" until the integration is updated. There is no SLA on this endpoint; it exists for Claude Code's own UI and is being consumed by community tooling at our own risk.
- **Requires Claude Code.** If Claude Code isn't installed or you're not signed in, the keychain entry won't exist and the provider reports "Claude Code not signed in" without prompting for keychain access.

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
