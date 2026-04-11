# Proximity Fade

The ball fades out as the mouse cursor approaches, preventing OLED burn-in from a stationary cursor near the ball.

## Implementation

### Cursor Tracking

**File**: `CircleApp/CircleOverlayView.swift`

Registers `NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved)` and converts screen coordinates to window-relative position, updating `renderer.cursorPosition`.

### Opacity Calculation

**File**: `CircleKit/Sources/CircleKit/BallPhysics.swift`

`proximityOpacity(ball:cursorPosition:fadeRadius:fadeEnabled:)`:
- Returns `1.0` if fade is disabled
- Calculates distance from cursor to ball center
- If distance > `fadeRadius`: full opacity
- If distance < ball radius: zero opacity
- In between: **quadratic falloff** `(ratio * ratio)` where `ratio = (distance - radius) / (fadeRadius - radius)`

## Configuration

Via [[Settings]]:
- `proximityFadeEnabled` (default: `true`)
- `proximityFadeRadius` (default: `150px`, range: 50-500px)

## See Also

- [[CircleKit#BallPhysics]]
- [[CircleApp#CircleOverlayView]]
