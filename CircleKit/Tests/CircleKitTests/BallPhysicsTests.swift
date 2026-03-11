import XCTest
@testable import CircleKit

final class BallPhysicsTests: XCTestCase {

    func testInitialPosition() {
        let ball = BallState(screenWidth: 1920, screenHeight: 1080, sizeMode: .percentage, sizeValue: 10, speedPercentage: 100)
        XCTAssertEqual(ball.x, 960, accuracy: 1)
        XCTAssertEqual(ball.y, 540, accuracy: 1)
    }

    func testRadiusPercentageMode() {
        let ball = BallState(screenWidth: 1920, screenHeight: 1080, sizeMode: .percentage, sizeValue: 10, speedPercentage: 100)
        XCTAssertEqual(ball.radius, 108, accuracy: 1)
    }

    func testRadiusPixelMode() {
        let ball = BallState(screenWidth: 1920, screenHeight: 1080, sizeMode: .pixels, sizeValue: 50, speedPercentage: 100)
        XCTAssertEqual(ball.radius, 50, accuracy: 1)
    }

    func testBounceChangesDirection() {
        var ball = BallState(screenWidth: 100, screenHeight: 100, sizeMode: .pixels, sizeValue: 10, speedPercentage: 100)
        ball.x = 100
        ball.vx = 4
        ball.vy = 3
        let oldHue = ball.hue
        BallPhysics.update(&ball, bounds: CGSize(width: 100, height: 100), forceAction: .bounce)
        XCTAssertLessThan(ball.vx, 0)
        XCTAssertNotEqual(ball.hue, oldHue)
    }

    func testProximityOpacityFullWhenFar() {
        let ball = BallState(screenWidth: 1000, screenHeight: 1000, sizeMode: .pixels, sizeValue: 50, speedPercentage: 100)
        let opacity = BallPhysics.proximityOpacity(ball: ball, cursorPosition: CGPoint(x: -1000, y: -1000), fadeRadius: 150, fadeEnabled: true)
        XCTAssertEqual(opacity, 1.0, accuracy: 0.01)
    }

    func testProximityOpacityZeroWhenInside() {
        var ball = BallState(screenWidth: 1000, screenHeight: 1000, sizeMode: .pixels, sizeValue: 50, speedPercentage: 100)
        ball.x = 500; ball.y = 500
        let opacity = BallPhysics.proximityOpacity(ball: ball, cursorPosition: CGPoint(x: 500, y: 500), fadeRadius: 150, fadeEnabled: true)
        XCTAssertEqual(opacity, 0.0, accuracy: 0.01)
    }

    func testProximityOpacityDisabled() {
        var ball = BallState(screenWidth: 1000, screenHeight: 1000, sizeMode: .pixels, sizeValue: 50, speedPercentage: 100)
        ball.x = 500; ball.y = 500
        let opacity = BallPhysics.proximityOpacity(ball: ball, cursorPosition: CGPoint(x: 500, y: 500), fadeRadius: 150, fadeEnabled: false)
        XCTAssertEqual(opacity, 1.0, accuracy: 0.01)
    }
}
