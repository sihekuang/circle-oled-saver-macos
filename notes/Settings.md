# Settings

**File**: `CircleKit/Sources/CircleKit/SettingsManager.swift`

Singleton `SettingsManager.shared` backed by `UserDefaults(suiteName: "com.shoebillsoft.circle.shared")`. Shared between [[CircleApp]] and [[CircleSaver]].

Uses `@Published` properties with `didSet` observers that post `settingsChangedNotification`.

## Configuration Reference

### General

| Key | Default | Range/Type |
|-----|---------|------------|
| `enabled` | `true` | Bool |
| `idleTimeout` | `10` | 5-300s (5s steps) |
| `oledDisplayIDs` | all screens | Set\<String\> |
| `alwaysOnMode` | `false` | Bool |
| `launchAtLogin` | `false` | Bool |

### Ball Physics

| Key | Default | Range/Type |
|-----|---------|------------|
| `ballSizeMode` | `"percentage"` | percentage / pixels |
| `ballSize` | `10` | 1-30% or 20-500px |
| `ballOpacity` | `100` | 10-100% |
| `ballSpeed` | `100` | 25-300% |

### Rendering

| Key | Default | Range/Type |
|-----|---------|------------|
| `theme` | `"minimal"` | minimal / soft |
| `proximityFadeEnabled` | `true` | Bool |
| `proximityFadeRadius` | `150` | 50-500px |

### Hotkeys

| Key | Default | Action |
|-----|---------|--------|
| `alwaysOnHotkey` | `cmd+opt+o` | Toggle always-on mode |
| `enableHotkey` | `cmd+opt+e` | Toggle enabled |
| `sizeUpHotkey` | `cmd+opt+=` | Increase ball size |
| `sizeDownHotkey` | `cmd+opt+-` | Decrease ball size |
| `rotateContentHotkey` | `cmd+opt+r` | Next content provider |

### Content

| Key | Default | Range/Type |
|-----|---------|------------|
| `contentRotationEnabled` | `true` | Bool |
| `contentRotationInterval` | `10` | 5-60s (5s steps) |
| `clockEnabled` | `true` | Bool |
| `clockFormat24h` | `false` | Bool |
| `systemInfoEnabled` | `true` | Bool |
| `showBattery` | `true` | Bool |
| `stockEnabled` | `false` | Bool |
| `stockSymbols` | `"AAPL, GOOGL, TSLA"` | Comma-separated |
| `stockRefreshSeconds` | `300` | 60-600s (30s steps) |

## Change Propagation

```
User changes setting in Settings UI
    |
    v
SettingsManager @Published didSet
    |- Write to UserDefaults
    '- Post settingsChangedNotification
            |
            v
        CircleRenderer
            '- Swap theme / update physics
```

## See Also

- [[CircleApp#Settings UI]]
- [[Data Flow]]
