import XCTest
@testable import CircleKit

final class ContentSettingsSnapshotTests: XCTestCase {

    func testIdenticalSettingsProduceEqualSnapshots() {
        let a = makeSnapshot()
        let b = makeSnapshot()
        XCTAssertEqual(a, b)
    }

    func testClockToggleChangesSnapshot() {
        let a = makeSnapshot(clockEnabled: true)
        let b = makeSnapshot(clockEnabled: false)
        XCTAssertNotEqual(a, b)
    }

    func testClaudeUsageToggleChangesSnapshot() {
        let a = makeSnapshot(claudeUsageEnabled: false)
        let b = makeSnapshot(claudeUsageEnabled: true)
        XCTAssertNotEqual(a, b)
    }

    func testStockSymbolsChangeChangesSnapshot() {
        let a = makeSnapshot(stockSymbols: "AAPL")
        let b = makeSnapshot(stockSymbols: "AAPL, GOOGL")
        XCTAssertNotEqual(a, b)
    }

    func testRotationIntervalChangeChangesSnapshot() {
        let a = makeSnapshot(rotationInterval: 10)
        let b = makeSnapshot(rotationInterval: 30)
        XCTAssertNotEqual(a, b)
    }

    func testClaudeUsageModeChangeChangesSnapshot() {
        let a = makeSnapshot(claudeUsageMode: .today)
        let b = makeSnapshot(claudeUsageMode: .week)
        XCTAssertNotEqual(a, b)
    }

    private func makeSnapshot(
        clockEnabled: Bool = true,
        clockFormat24h: Bool = false,
        systemInfoEnabled: Bool = true,
        showBattery: Bool = true,
        stockEnabled: Bool = false,
        stockSymbols: String = "AAPL",
        stockRefreshSeconds: Int = 300,
        claudeUsageEnabled: Bool = false,
        claudeUsageMode: ClaudeUsageMode = .today,
        rotationInterval: Int = 10
    ) -> ContentSettingsSnapshot {
        ContentSettingsSnapshot(
            clockEnabled: clockEnabled,
            clockFormat24h: clockFormat24h,
            systemInfoEnabled: systemInfoEnabled,
            showBattery: showBattery,
            stockEnabled: stockEnabled,
            stockSymbols: stockSymbols,
            stockRefreshSeconds: stockRefreshSeconds,
            claudeUsageEnabled: claudeUsageEnabled,
            claudeUsageMode: claudeUsageMode,
            rotationInterval: rotationInterval
        )
    }
}
