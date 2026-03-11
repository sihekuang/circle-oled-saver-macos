import XCTest
@testable import CircleKit

final class ContentRotatorTests: XCTestCase {

    func testRotatesProviders() {
        let clock = ClockProvider()
        let system = SystemInfoProvider()
        let rotator = ContentRotator(providers: [clock, system], intervalSeconds: 10)

        XCTAssertTrue(rotator.currentProvider === clock)
        rotator.next()
        XCTAssertTrue(rotator.currentProvider === system)
        rotator.next()
        XCTAssertTrue(rotator.currentProvider === clock)  // Wraps around
    }

    func testEmptyProviders() {
        let rotator = ContentRotator(providers: [], intervalSeconds: 10)
        XCTAssertNil(rotator.currentProvider)
    }
}
