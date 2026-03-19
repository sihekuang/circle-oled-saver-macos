# Hotkey HUD Display

## Overview

Show a macOS system-style HUD (like brightness/volume) when hotkey actions are triggered.

## HUD Window

- **Class:** `HUDWindowController` managing a single borderless `NSWindow`
- **Size:** ~200x200pt rounded square
- **Style:** `NSVisualEffectView` with `.hudWindow` material, dark appearance
- **Corner radius:** ~18pt
- **Position:** Centered horizontally, lower-third vertically on main screen only
- **Window level:** `.floating`
- **Behavior:** Ignores mouse events, not in Mission Control

### Animation

- Fade in: ~0.15s
- Hold: ~1.5s
- Fade out: ~0.3s
- Re-trigger while visible: reset timer, crossfade content

## HUD Content

Vertical stack layout inside the HUD.

### Toggle Actions (Always On, Enable)

- SF Symbol icon at ~48pt
  - Always On: `moon.fill` (on) / `moon` (off)
  - Enable: `circle.fill` (on) / `circle.slash` (off)
- Text label below with action name ("Always On", "Enabled")
- State implied by icon (filled = on, slashed = off)

### Size Actions (Size Up, Size Down)

- SF Symbol icon at ~48pt (e.g., `arrow.up.left.and.arrow.down.right`)
- Horizontal progress bar below (~140pt wide, ~4pt tall, rounded)
- Bar shows current size as proportion within allowed range

### Rotate Content

- SF Symbol icon at ~48pt representing the new content type:
  - Clock: `clock.fill`
  - System Info: `cpu`
  - Stocks: `chart.line.uptrend`
- Text label below with content name

## Implementation

### New File

- `CircleApp/HUDWindowController.swift` — window, view, animation, and content logic

### Modified Files

- `CircleApp/AppDelegate.swift` — call HUD show methods from each hotkey handler
