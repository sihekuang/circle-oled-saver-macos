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

    func testClaudeUsageWeeklyGoalChangeChangesSnapshot() {
        let a = makeSnapshot(claudeUsageWeeklyGoalMTokens: 100)
        let b = makeSnapshot(claudeUsageWeeklyGoalMTokens: 500)
        XCTAssertNotEqual(a, b)
    }

    func testNonContentSettingsAreNotInSnapshot() {
        // Snapshot should ignore ball physics, theme, hotkeys, etc. The
        // exhaustive list of fields lives in the struct definition; this test
        // just guards against accidentally adding e.g. ballSize to the snapshot.
        let a = ContentSettingsSnapshot(
            clockEnabled: true, clockFormat24h: false,
            systemInfoEnabled: true, showBattery: true,
            stockEnabled: false, stockSymbols: "", stockRefreshSeconds: 300,
            claudeUsageEnabled: false,
            claudeUsageMode: .today,
            claudeUsageAuthMode: .local,
            claudeUsageWeeklyGoalMTokens: 1000,
            rotationInterval: 10
        )
        let b = ContentSettingsSnapshot(
            clockEnabled: true, clockFormat24h: false,
            systemInfoEnabled: true, showBattery: true,
            stockEnabled: false, stockSymbols: "", stockRefreshSeconds: 300,
            claudeUsageEnabled: false,
            claudeUsageMode: .today,
            claudeUsageAuthMode: .local,
            claudeUsageWeeklyGoalMTokens: 1000,
            rotationInterval: 10
        )
        XCTAssertEqual(a, b)
    }

    // MARK: - Helpers

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
        claudeUsageAuthMode: ClaudeUsageAuthMode = .local,
        claudeUsageWeeklyGoalMTokens: Int = 1000,
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
            claudeUsageAuthMode: claudeUsageAuthMode,
            claudeUsageWeeklyGoalMTokens: claudeUsageWeeklyGoalMTokens,
            rotationInterval: rotationInterval
        )
    }
}
