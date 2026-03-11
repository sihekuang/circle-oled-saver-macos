import Foundation
import CoreGraphics

public struct BallState {
    public var x: CGFloat
    public var y: CGFloat
    public var vx: CGFloat
    public var vy: CGFloat
    public var radius: CGFloat
    public var hue: CGFloat
    public var maxSpeed: CGFloat
    public var speedMultiplier: CGFloat

    public init(
        screenWidth: CGFloat,
        screenHeight: CGFloat,
        sizeMode: BallSizeMode,
        sizeValue: Int,
        speedPercentage: Int
    ) {
        self.speedMultiplier = CGFloat(speedPercentage) / 100.0
        self.x = screenWidth / 2
        self.y = screenHeight / 2
        self.vx = 4 * speedMultiplier
        self.vy = 3 * speedMultiplier
        self.maxSpeed = 8 * speedMultiplier
        self.hue = CGFloat.random(in: 0...360)

        if sizeMode == .pixels {
            self.radius = CGFloat(sizeValue)
        } else {
            let minDim = min(screenWidth, screenHeight)
            self.radius = minDim * CGFloat(sizeValue) / 100.0
        }
    }

    public mutating func updateRadius(screenWidth: CGFloat, screenHeight: CGFloat, sizeMode: BallSizeMode, sizeValue: Int) {
        if sizeMode == .pixels {
            self.radius = CGFloat(sizeValue)
        } else {
            let minDim = min(screenWidth, screenHeight)
            self.radius = minDim * CGFloat(sizeValue) / 100.0
        }
    }

    public mutating func updateSpeed(percentage: Int) {
        self.speedMultiplier = CGFloat(percentage) / 100.0
        self.maxSpeed = 8 * speedMultiplier
    }
}

public enum EdgeAction {
    case bounce
    case wrap
}

public enum BallPhysics {

    /// Default update using theme-independent legacy bounce/wrap logic.
    public static func update(_ ball: inout BallState, bounds: CGSize, forceAction: EdgeAction? = nil) {
        ball.x += ball.vx
        ball.y += ball.vy

        let wrapChance: CGFloat = 0.3

        // Horizontal edges
        if ball.x <= 0 || ball.x >= bounds.width {
            let action = forceAction ?? (CGFloat.random(in: 0...1) < wrapChance ? .wrap : .bounce)
            if action == .wrap {
                ball.x = ball.x <= 0 ? bounds.width : 0
                ball.hue = (ball.hue + 30).truncatingRemainder(dividingBy: 360)
            } else {
                ball.vx = -ball.vx
                ball.x = ball.x <= 0 ? 0 : bounds.width
                if CGFloat.random(in: 0...1) < 0.2 {
                    ball.vy = (CGFloat.random(in: 0...1) - 0.5) * ball.maxSpeed * 1.5
                } else {
                    ball.vy += (CGFloat.random(in: 0...1) - 0.5) * 6
                }
                limitSpeed(&ball)
                ball.hue = (ball.hue + 30).truncatingRemainder(dividingBy: 360)
            }
        }

        // Vertical edges
        if ball.y <= 0 || ball.y >= bounds.height {
            let action = forceAction ?? (CGFloat.random(in: 0...1) < wrapChance ? .wrap : .bounce)
            if action == .wrap {
                ball.y = ball.y <= 0 ? bounds.height : 0
                ball.hue = (ball.hue + 30).truncatingRemainder(dividingBy: 360)
            } else {
                ball.vy = -ball.vy
                ball.y = ball.y <= 0 ? 0 : bounds.height
                if CGFloat.random(in: 0...1) < 0.2 {
                    ball.vx = (CGFloat.random(in: 0...1) - 0.5) * ball.maxSpeed * 1.5
                } else {
                    ball.vx += (CGFloat.random(in: 0...1) - 0.5) * 6
                }
                limitSpeed(&ball)
                ball.hue = (ball.hue + 30).truncatingRemainder(dividingBy: 360)
            }
        }
    }

    public static func limitSpeed(_ ball: inout BallState) {
        let currentSpeed = sqrt(ball.vx * ball.vx + ball.vy * ball.vy)
        if currentSpeed > ball.maxSpeed {
            let scale = ball.maxSpeed / currentSpeed
            ball.vx *= scale
            ball.vy *= scale
        }
    }

    /// Calculate opacity based on cursor proximity.
    public static func proximityOpacity(
        ball: BallState,
        cursorPosition: CGPoint,
        fadeRadius: CGFloat,
        fadeEnabled: Bool
    ) -> CGFloat {
        guard fadeEnabled else { return 1.0 }

        let dx = ball.x - cursorPosition.x
        let dy = ball.y - cursorPosition.y
        let distFromCenter = sqrt(dx * dx + dy * dy)
        let distFromEdge = distFromCenter - ball.radius

        if distFromEdge >= fadeRadius { return 1.0 }
        if distFromEdge <= 0 { return 0.0 }

        let linear = distFromEdge / fadeRadius
        return linear * linear  // Quadratic fade
    }
}
