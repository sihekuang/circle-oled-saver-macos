import Foundation
import QuartzCore
import AppKit

public final class SoftTheme: Theme {
    public static let themeName = "Soft"
    public static let themeId = ThemeID.soft

    private var blobLayer = CAShapeLayer()
    private var iconLayer = CATextLayer()
    private var textLayer = CATextLayer()
    private var time: CFTimeInterval = 0
    private var morphPhase: CGFloat = CGFloat.random(in: 0...(2 * .pi))
    private var squish: CGFloat = 1
    private var squishTarget: CGFloat = 1

    // Pastel palette
    private let palette: [(h: CGFloat, s: CGFloat, l: CGFloat)] = [
        (270, 0.40, 0.75),  // Lavender
        (15,  0.45, 0.80),  // Soft coral
        (150, 0.35, 0.75),  // Mint
        (45,  0.40, 0.80),  // Pale gold
        (200, 0.40, 0.78),  // Sky blue
    ]
    private var colorIndex = 0
    private var colorTransition: CGFloat = 0

    public init() {}

    public func setup(in parentLayer: CALayer) {
        blobLayer.fillColor = NSColor.white.cgColor
        blobLayer.strokeColor = nil
        parentLayer.addSublayer(blobLayer)

        iconLayer.alignmentMode = .center
        iconLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        iconLayer.isWrapped = false
        iconLayer.truncationMode = .none
        blobLayer.addSublayer(iconLayer)

        textLayer.alignmentMode = .center
        textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
        textLayer.isWrapped = true
        textLayer.truncationMode = .none
        blobLayer.addSublayer(textLayer)
    }

    public func tick(deltaTime: CFTimeInterval) {
        time += deltaTime
        morphPhase += 0.02
    }

    private func currentColor(opacity: CGFloat) -> NSColor {
        colorTransition += 0.0002
        if colorTransition >= 1 {
            colorTransition = 0
            colorIndex = (colorIndex + 1) % palette.count
        }

        let current = palette[colorIndex]
        let next = palette[(colorIndex + 1) % palette.count]
        let t = colorTransition

        let h = (current.h + (next.h - current.h) * t) / 360.0
        let s = current.s + (next.s - current.s) * t
        let b = current.l + (next.l - current.l) * t

        return NSColor(hue: h, saturation: s, brightness: b, alpha: opacity)
    }

    public func updateMotion(state: MotionState, bounds: CGSize) -> MotionState {
        var s = state
        let baseSpeed: CGFloat = 3
        let speed = baseSpeed * s.speedMultiplier

        // Add slight momentum variation
        s.vx += CGFloat.random(in: -0.05...0.05)
        s.vy += CGFloat.random(in: -0.05...0.05)

        // Limit speed
        let currentSpeed = sqrt(s.vx * s.vx + s.vy * s.vy)
        if currentSpeed > speed {
            s.vx = (s.vx / currentSpeed) * speed
            s.vy = (s.vy / currentSpeed) * speed
        }
        if currentSpeed < speed * 0.5 {
            s.vx = (s.vx / currentSpeed) * speed * 0.5
            s.vy = (s.vy / currentSpeed) * speed * 0.5
        }

        s.x += s.vx
        s.y += s.vy

        // Bounce from center point
        if s.x < 0 || s.x > bounds.width {
            s.vx = -s.vx
            s.vy += CGFloat.random(in: -0.25...0.25)
            squishTarget = 0.7
            s.x = max(0, min(bounds.width, s.x))
            s.hue = (s.hue + 20).truncatingRemainder(dividingBy: 360)
        }

        if s.y < 0 || s.y > bounds.height {
            s.vy = -s.vy
            s.vx += CGFloat.random(in: -0.25...0.25)
            squishTarget = 0.7
            s.y = max(0, min(bounds.height, s.y))
            s.hue = (s.hue + 20).truncatingRemainder(dividingBy: 360)
        }

        // Recover from squish
        squish += (squishTarget - squish) * 0.1
        squishTarget += (1 - squishTarget) * 0.05

        return s
    }

    public func updateAppearance(position: CGPoint, size: CGFloat, hue: CGFloat, opacity: CGFloat) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)

        let color = currentColor(opacity: opacity)

        // Build blob path in absolute coordinates
        let path = CGMutablePath()
        let points = 6

        for i in 0...points {
            let angle = CGFloat(i) / CGFloat(points) * 2 * .pi
            let morphAmount = sin(morphPhase + angle * 2) * 0.08
            let squishX = i % 2 == 0 ? squish : 1
            let squishY = i % 2 == 0 ? 1 : squish
            let r = size * (1 + morphAmount) * ((squishX + squishY) / 2)

            let px = position.x + cos(angle) * r * squishX
            let py = position.y + sin(angle) * r * squishY

            if i == 0 {
                path.move(to: CGPoint(x: px, y: py))
            } else {
                let prevAngle = CGFloat(i - 1) / CGFloat(points) * 2 * .pi
                let cpRadius = r * 0.55
                let cp1 = CGPoint(
                    x: position.x + cos(prevAngle + .pi / CGFloat(points)) * cpRadius,
                    y: position.y + sin(prevAngle + .pi / CGFloat(points)) * cpRadius
                )
                let cp2 = CGPoint(
                    x: position.x + cos(angle - .pi / CGFloat(points)) * cpRadius,
                    y: position.y + sin(angle - .pi / CGFloat(points)) * cpRadius
                )
                path.addCurve(to: CGPoint(x: px, y: py), control1: cp1, control2: cp2)
            }
        }
        path.closeSubpath()

        // Set blob shape — use the bounding box as the frame
        let blobBounds = path.boundingBox
        blobLayer.frame = blobBounds

        // Translate path to local coordinates
        var transform = CGAffineTransform(translationX: -blobBounds.origin.x, y: -blobBounds.origin.y)
        if let localPath = path.copy(using: &transform) {
            blobLayer.path = localPath
        }
        blobLayer.fillColor = color.cgColor

        // Text positioning (relative to blob layer)
        let localCenterX = position.x - blobBounds.origin.x
        let localCenterY = position.y - blobBounds.origin.y
        let iconSize = size * 0.25
        let textSize = size * 0.15

        iconLayer.fontSize = iconSize
        iconLayer.frame = CGRect(
            x: localCenterX - size,
            y: localCenterY - size * 0.1,
            width: size * 2,
            height: iconSize * 1.4
        )

        textLayer.fontSize = textSize
        textLayer.frame = CGRect(
            x: localCenterX - size,
            y: localCenterY - size * 0.6,
            width: size * 2,
            height: size * 0.9
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
            paragraphStyle.lineSpacing = 2
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
        blobLayer.removeFromSuperlayer()
    }
}
