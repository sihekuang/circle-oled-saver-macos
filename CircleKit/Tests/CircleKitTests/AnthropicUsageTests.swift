import XCTest
@testable import CircleKit

final class AnthropicUsageTests: XCTestCase {

    func testDecodesFullResponse() throws {
        let json = #"""
        {
          "five_hour":          {"utilization": 35.0, "resets_at": "2026-04-28T01:20:00.339018+00:00"},
          "seven_day":          {"utilization": 48.0, "resets_at": "2026-04-28T12:00:00+00:00"},
          "seven_day_sonnet":   {"utilization": 12.0, "resets_at": "2026-04-28T12:00:00+00:00"},
          "seven_day_oauth_apps": null,
          "seven_day_opus": null,
          "seven_day_omelette": {"utilization": 0.0, "resets_at": null},
          "extra_usage": {"is_enabled": true, "monthly_limit": 5000, "used_credits": 923.0, "utilization": 18.46, "currency": "USD"}
        }
        """#
        let usage = try AnthropicUsage.decode(Data(json.utf8))
        XCTAssertEqual(usage.fiveHour?.utilization, 35.0)
        XCTAssertEqual(usage.sevenDay?.utilization, 48.0)
        XCTAssertEqual(usage.sevenDaySonnet?.utilization, 12.0)
        XCTAssertNotNil(usage.fiveHour?.resetsAt)
        XCTAssertNotNil(usage.sevenDay?.resetsAt)
    }

    func testDecodesNullResetsAt() throws {
        let json = #"""
        {
          "five_hour": {"utilization": 0.0, "resets_at": null}
        }
        """#
        let usage = try AnthropicUsage.decode(Data(json.utf8))
        XCTAssertEqual(usage.fiveHour?.utilization, 0.0)
        XCTAssertNil(usage.fiveHour?.resetsAt)
    }

    func testDecodesMissingBuckets() throws {
        // API may omit buckets the user doesn't have access to
        let json = #"""
        { "five_hour": {"utilization": 50.0, "resets_at": "2026-04-28T01:00:00+00:00"} }
        """#
        let usage = try AnthropicUsage.decode(Data(json.utf8))
        XCTAssertNotNil(usage.fiveHour)
        XCTAssertNil(usage.sevenDay)
        XCTAssertNil(usage.sevenDaySonnet)
    }

    // MARK: - Time formatting

    func testFormatTimeRemainingHoursAndMinutes() {
        XCTAssertEqual(ClaudeUsageProvider.formatTimeRemaining(seconds: 9 * 3600 + 30 * 60), "9h 30m")
    }

    func testFormatTimeRemainingHoursOnly() {
        XCTAssertEqual(ClaudeUsageProvider.formatTimeRemaining(seconds: 5 * 3600), "5h")
    }

    func testFormatTimeRemainingMinutesOnly() {
        XCTAssertEqual(ClaudeUsageProvider.formatTimeRemaining(seconds: 30 * 60), "30m")
    }

    func testFormatTimeRemainingSecondsCeilToMinute() {
        XCTAssertEqual(ClaudeUsageProvider.formatTimeRemaining(seconds: 30), "1m")
    }

    // MARK: - Provider in Anthropic mode (no token)

    func testAnthropicModeWithoutTokenShowsPasteHint() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("circle-anthropic-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let stubClient = AnthropicUsageClient(tokenProvider: { nil })
        let provider = ClaudeUsageProvider(
            projectsDir: tempDir,
            mode: .today,
            authMode: .anthropic,
            usageClient: stubClient
        )
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\npaste token")
    }
}
