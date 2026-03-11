import Foundation
import QuartzCore
import AppKit

public final class MinimalTheme: Theme {
    public static let themeName = "Minimal"
    public static let themeId = ThemeID.minimal

    private var circleLayer = CALayer()
    private var glowLayer = CALayer()
    private var iconLayer = CATextLayer()
    private var textLayer = CATextLayer()
    private var time: CFTimeInterval = 0
    private var angle: CGFloat = CGFloat.random(in: 0...(2 * .pi))

    public init() {}

    public func setup(in parentLayer: CALayer) {
        // Glow layer (behind circle)
        glowLayer.shadowColor = NSColor.white.cgColor
        glowLayer.shadowOpacity = 0.3
        glowLayer.shadowRadius = 20
        glowLayer.shadowOffset = .zero
        parentLayer.addSublayer(glowLayer)

        // Main circle
        circleLayer.masksToBounds = true
        parentLayer.addSublayer(circleLayer)

        // Icon text layer
        iconLayer.alignmentMode = .center
        iconLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        iconLayer.isWrapped = false
        iconLayer.truncationMode = .none
        circleLayer.addSublayer(iconLayer)

        // Text layer
        textLayer.alignmentMode = .center
        textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        textLayer.isWrapped = true
        textLayer.truncationMode = .none
        circleLayer.addSublayer(textLayer)
    }

    public func tick(deltaTime: CFTimeInterval) {
        time += deltaTime
    }

    public func updateMotion(state: MotionState, bounds: CGSize) -> MotionState {
        var s = state
        let baseSpeed: CGFloat = 3
        let speed = baseSpeed * s.speedMultiplier

        // Smooth drift — gradual angle changes
        angle += CGFloat.random(in: -0.01...0.01)

        s.vx = cos(angle) * speed
        s.vy = sin(angle) * speed
        s.x += s.vx
        s.y += s.vy

        // Continuous slow hue shift
        s.hue = (s.hue + 0.1).truncatingRemainder(dividingBy: 360)

        // Bounce when center hits edge
        if s.x < 0 {
            angle = .pi - angle + CGFloat.random(in: -0.25...0.25)
            s.x = 0
            s.hue = (s.hue + 20).truncatingRemainder(dividingBy: 360)
        } else if s.x > bounds.width {
            angle = .pi - angle + CGFloat.random(in: -0.25...0.25)
            s.x = bounds.width
            s.hue = (s.hue + 20).truncatingRemainder(dividingBy: 360)
        }

        if s.y < 0 {
            angle = -angle + CGFloat.random(in: -0.25...0.25)
            s.y = 0
            s.hue = (s.hue + 20).truncatingRemainder(dividingBy: 360)
        } else if s.y > bounds.height {
            angle = -angle + CGFloat.random(in: -0.25...0.25)
            s.y = bounds.height
            s.hue = (s.hue + 20).truncatingRemainder(dividingBy: 360)
        }

        return s
    }

    public func updateAppearance(position: CGPoint, size: CGFloat, hue: CGFloat, opacity: CGFloat) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        // Gentle hue oscillation
        let shift = sin(time / 10.0) * 5
        let h = ((hue + shift).truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 360.0
        let color = NSColor(hue: h, saturation: 0.3, brightness: 0.6, alpha: opacity)

        let frame = CGRect(
            x: position.x - size,
            y: position.y - size,
            width: size * 2,
            height: size * 2
        )

        // Circle
        circleLayer.frame = frame
        circleLayer.cornerRadius = size
        circleLayer.backgroundColor = color.cgColor

        // Glow
        let glowSize = size * 1.3
        glowLayer.frame = CGRect(
            x: position.x - glowSize,
            y: position.y - glowSize,
            width: glowSize * 2,
            height: glowSize * 2
        )
        glowLayer.cornerRadius = glowSize
        glowLayer.backgroundColor = color.withAlphaComponent(opacity * 0.15).cgColor
        glowLayer.shadowColor = color.cgColor
        glowLayer.shadowOpacity = Float(opacity * 0.3)
        glowLayer.shadowRadius = size * 0.3

        // Layout text layers relative to circle bounds (CA coordinates: origin bottom-left)
        let iconSize = size * 0.22
        let textSize = size * 0.14

        iconLayer.fontSize = iconSize
        iconLayer.frame = CGRect(
            x: 0,
            y: size * 1.05,
            width: size * 2,
            height: iconSize * 1.5
        )

        textLayer.fontSize = textSize
        textLayer.frame = CGRect(
            x: 0,
            y: size * 0.35,
            width: size * 2,
            height: size * 0.7
        )

        CATransaction.commit()
    }

    public func setContent(_ content: ContentData?) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        if let content {
            iconLayer.string = content.icon
            iconLayer.foregroundColor = NSColor.white.cgColor

            let attributed = NSMutableAttributedString(string: content.text)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            paragraphStyle.lineSpacing = textLayer.fontSize * 0.5
            attributed.addAttributes([
                .foregroundColor: NSColor.white,
                .font: NSFont.boldSystemFont(ofSize: textLayer.fontSize),
                .paragraphStyle: paragraphStyle
            ], range: NSRange(location: 0, length: attributed.length))
            textLayer.string = attributed
        } else {
            iconLayer.string = nil
            textLayer.string = nil
        }

        CATransaction.commit()
    }

    public func teardown() {
        glowLayer.removeFromSuperlayer()
        circleLayer.removeFromSuperlayer()
    }
}
