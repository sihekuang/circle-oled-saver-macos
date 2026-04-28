import XCTest
@testable import CircleKit

final class CircleTextLayoutTests: XCTestCase {

    // MARK: - Line counting

    func testLineCountSingleLine() {
        XCTAssertEqual(CircleTextLayout.lineCount(of: "Claude"), 1)
    }

    func testLineCountMultiLine() {
        XCTAssertEqual(CircleTextLayout.lineCount(of: "Claude\n33% session\n6h left"), 3)
    }

    func testLineCountEmptyStringIsOne() {
        XCTAssertEqual(CircleTextLayout.lineCount(of: ""), 1)
    }

    func testLineCountTrailingNewlineCounts() {
        XCTAssertEqual(CircleTextLayout.lineCount(of: "Claude\n"), 2)
    }

    // MARK: - Group is centered around ball center

    func testSingleLineGroupCenteredAroundBallCenter() {
        let size: CGFloat = 100
        let layout = CircleTextLayout.compute(size: size, lineCount: 1)
        let groupTop = layout.iconFrame.maxY
        let groupBottom = layout.textFrame.minY
        let groupCenter = (groupTop + groupBottom) / 2
        XCTAssertEqual(groupCenter, size, accuracy: 0.01)
    }

    func testThreeLineGroupCenteredAroundBallCenter() {
        let size: CGFloat = 100
        let layout = CircleTextLayout.compute(size: size, lineCount: 3)
        let groupTop = layout.iconFrame.maxY
        let groupBottom = layout.textFrame.minY
        let groupCenter = (groupTop + groupBottom) / 2
        XCTAssertEqual(groupCenter, size, accuracy: 0.01)
    }

    // MARK: - Icon stays above text

    func testIconAlwaysAboveText() {
        let size: CGFloat = 100
        for lines in 1...5 {
            let layout = CircleTextLayout.compute(size: size, lineCount: lines)
            XCTAssertGreaterThan(
                layout.iconFrame.minY, layout.textFrame.maxY,
                "icon should be above text for \(lines) lines"
            )
        }
    }

    // MARK: - Text height grows with line count

    func testTextHeightIncreasesWithLineCount() {
        let size: CGFloat = 100
        let h1 = CircleTextLayout.compute(size: size, lineCount: 1).textFrame.height
        let h2 = CircleTextLayout.compute(size: size, lineCount: 2).textFrame.height
        let h3 = CircleTextLayout.compute(size: size, lineCount: 3).textFrame.height
        XCTAssertLessThan(h1, h2)
        XCTAssertLessThan(h2, h3)
    }

    // MARK: - Frame widths span the diameter

    func testIconAndTextFramesSpanFullDiameter() {
        let size: CGFloat = 100
        let layout = CircleTextLayout.compute(size: size, lineCount: 2)
        XCTAssertEqual(layout.iconFrame.width, size * 2)
        XCTAssertEqual(layout.textFrame.width, size * 2)
        XCTAssertEqual(layout.iconFrame.minX, 0)
        XCTAssertEqual(layout.textFrame.minX, 0)
    }

    // MARK: - Font sizes scale with ball size

    func testFontSizesScaleWithSize() {
        let small = CircleTextLayout.compute(size: 50, lineCount: 1)
        let big = CircleTextLayout.compute(size: 200, lineCount: 1)
        XCTAssertEqual(big.iconFontSize / small.iconFontSize, 4.0, accuracy: 0.01)
        XCTAssertEqual(big.textFontSize / small.textFontSize, 4.0, accuracy: 0.01)
    }

    // MARK: - Content fits within ball at moderate sizes

    func testThreeLineContentFitsWithinBallDiameter() {
        let size: CGFloat = 100  // ball diameter = 200
        let layout = CircleTextLayout.compute(size: size, lineCount: 3)
        // Group should fit within [0, 2*size]
        XCTAssertGreaterThanOrEqual(layout.textFrame.minY, 0)
        XCTAssertLessThanOrEqual(layout.iconFrame.maxY, 2 * size)
    }
}
