# Themes

**Path**: `CircleKit/Sources/CircleKit/Themes/`

## Theme Protocol

**File**: `ThemeProtocol.swift`

```swift
protocol Theme {
    static var themeName: String
    static var themeId: ThemeID
    func setup(in parentLayer: CALayer)
    func tick(deltaTime: CFTimeInterval)
    func updateMotion(state: MotionState, bounds: CGSize) -> MotionState
    func updateAppearance(position: CGPoint, size: CGFloat, hue: CGFloat, opacity: CGFloat)
    func setContent(_ content: ContentData?)
    func teardown()
}
```

Supporting types:
- `ContentData` - icon (String) + text (String)
- `ThemeID` - `.minimal` or `.soft`
- `MotionState` - wrapper for theme-controlled physics

## MinimalTheme

**File**: `MinimalTheme.swift`

Solid glowing circle with embedded text.

**Layers**: `glowLayer` > `circleLayer` > `iconLayer` + `textLayer`

**Motion**: Smooth drift using angle-based direction. Angle randomly perturbed each frame. Wall bounces with angle reflection.

**Appearance**:
- Hue oscillation: `hue + sin(time/10) * 5`
- Glow at 1.3x circle size
- Icon at 22% radius, text at 14%

## SoftTheme

**File**: `SoftTheme.swift`

Morphing blob with pastel color palette.

**Layers**: `blobLayer` (CAShapeLayer) > `iconLayer` + `textLayer`

**Palette**: 5 pastel colors (lavender, coral, mint, gold, sky) with smooth HSL interpolation.

**Motion**: Momentum-based with random velocity adjustments. Bounce triggers "squish" deformation (`squish = 0.7`, recovers at `+= (target - squish) * 0.1`).

**Blob shape**: 6-point morphing bezier path. Morph: `sin(morphPhase + angle*2) * 0.08`. Squish alternates X/Y on even/odd control points.

## See Also

- [[CircleKit#CircleRenderer]]
- [[Content Providers]]
