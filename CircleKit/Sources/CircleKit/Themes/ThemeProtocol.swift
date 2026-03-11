import Foundation
import QuartzCore
import AppKit

public struct ContentData {
    public let icon: String
    public let text: String

    public init(icon: String, text: String) {
        self.icon = icon
        self.text = text
    }
}

public struct MotionState {
    public var x: CGFloat
    public var y: CGFloat
    public var vx: CGFloat
    public var vy: CGFloat
    public var radius: CGFloat
    public var hue: CGFloat
    public var speedMultiplier: CGFloat

    public init(from ball: BallState) {
        self.x = ball.x
        self.y = ball.y
        self.vx = ball.vx
        self.vy = ball.vy
        self.radius = ball.radius
        self.hue = ball.hue
        self.speedMultiplier = ball.speedMultiplier
    }
}

public protocol Theme: AnyObject {
    static var themeName: String { get }
    static var themeId: ThemeID { get }

    func setup(in parentLayer: CALayer)
    func tick(deltaTime: CFTimeInterval)
    func updateMotion(state: MotionState, bounds: CGSize) -> MotionState
    func updateAppearance(position: CGPoint, size: CGFloat, hue: CGFloat, opacity: CGFloat)
    func setContent(_ content: ContentData?)
    func teardown()
}
