# CircleSaver

macOS Screen Saver bundle (`.saver`), using the system ScreenSaver framework.

**Path**: `CircleSaver/`
**Bundle ID**: `com.shoebillsoft.circle.saver`
**Principal Class**: `CircleSaver.CircleSaverView`

## CircleSaverView

**File**: `CircleSaverView.swift`

Subclass of `ScreenSaverView`. Thin adapter around [[CircleKit#CircleRenderer|CircleRenderer]].

- `startAnimation()` - creates renderer, sets black background, starts animation
- `stopAnimation()` - stops renderer, cleans up
- `hasConfigureSheet` returns `false` (no config UI in System Preferences)

## Settings Sharing

Reads from the same `UserDefaults` suite (`com.shoebillsoft.circle.shared`) as [[CircleApp]]. Configuration is done entirely through the CircleApp's [[Settings]] UI.

## See Also

- [[CircleKit]]
- [[Settings]]
