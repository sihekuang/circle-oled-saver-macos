# CircleKit

Shared Swift Package containing all rendering, physics, theme, and content logic. Used by both [[CircleApp]] and [[CircleSaver]].

**Path**: `CircleKit/`

## Structure

```
CircleKit/
  Package.swift
  Sources/CircleKit/
    CircleKit.swift
    CircleRenderer.swift
    BallPhysics.swift
    SettingsManager.swift
    Themes/
      ThemeProtocol.swift
      MinimalTheme.swift
      SoftTheme.swift
    Providers/
      ContentProvider.swift
      ContentRotator.swift
      ClockProvider.swift
      SystemInfoProvider.swift
      StockProvider.swift
  Tests/CircleKitTests/
    CircleKitTests.swift
    BallPhysicsTests.swift
    ContentRotatorTests.swift
```

## Core Components

### CircleRenderer

**File**: `CircleRenderer.swift`

The main animation driver. Owns a `CVDisplayLink` that fires at the display's refresh rate.

**Frame lifecycle** (each tick):
1. Calculate delta time
2. `theme.tick(deltaTime:)` - time-based animation
3. `theme.updateMotion(state:bounds:)` - physics/movement
4. `BallPhysics.proximityOpacity()` - cursor fade
5. `theme.updateAppearance(...)` - visual update
6. `theme.setContent(...)` - text/icon update

Reacts to `settingsChangedNotification` to swap themes or update physics parameters.

### BallPhysics

**File**: `BallPhysics.swift`

- `BallState` - value type: position, velocity, radius, hue, speed
- `EdgeAction` - `.bounce` or `.wrap` (30% wrap chance on collision)
- `proximityOpacity()` - quadratic falloff as cursor nears ball
- Max speed: `8 * speedMultiplier`
- Bounce randomness: `+/-0.5 * maxSpeed * 1.5`

### SettingsManager

**File**: `SettingsManager.swift`
See [[Settings]] for full details.

## See Also

- [[Themes]]
- [[Content Providers]]
- [[Data Flow]]
