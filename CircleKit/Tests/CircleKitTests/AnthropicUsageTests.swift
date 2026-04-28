import XCTest
@testable import CircleKit

final class AnthropicUsageTests: XCTestCase {

    // MARK: - Token type detection

    func testDetectsOAuthPrefix() {
        XCTAssertEqual(AnthropicTokenType(rawToken: "sk-ant-oat01-abc123"), .oauth)
    }

    func testDetectsAdminPrefix() {
        XCTAssertEqual(AnthropicTokenType(rawToken: "sk-ant-admin01-abc123"), .admin)
    }

    func testTrimsWhitespaceBeforeDetection() {
        XCTAssertEqual(AnthropicTokenType(rawToken: "  sk-ant-oat01-abc\n"), .oauth)
    }

    func testRejectsRegularApiKey() {
        XCTAssertEqual(AnthropicTokenType(rawToken: "sk-ant-api03-abc123"), .unknown)
    }

    func testRejectsEmpty() {
        XCTAssertEqual(AnthropicTokenType(rawToken: ""), .unknown)
    }

    // MARK: - OAuth response decoding

    func testDecodesFullOAuthResponse() throws {
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
        let json = #"""
        { "five_hour": {"utilization": 50.0, "resets_at": "2026-04-28T01:00:00+00:00"} }
        """#
        let usage = try AnthropicUsage.decode(Data(json.utf8))
        XCTAssertNotNil(usage.fiveHour)
        XCTAssertNil(usage.sevenDay)
        XCTAssertNil(usage.sevenDaySonnet)
    }

    // MARK: - Cost report decoding

    func testDecodesCostReport() throws {
        let json = #"""
        {
          "data": [
            {
              "starting_at": "2026-04-28T00:00:00Z",
              "ending_at": "2026-04-29T00:00:00Z",
              "results": [
                {"amount": "1234.56", "currency": "USD"},
                {"amount": "1000.00", "currency": "USD"}
              ]
            }
          ],
          "has_more": false,
          "next_page": null
        }
        """#
        let report = try AnthropicCostReport.decode(Data(json.utf8))
        XCTAssertEqual(report.data.count, 1)
        XCTAssertEqual(report.data[0].results.count, 2)
        XCTAssertFalse(report.hasMore)
        XCTAssertNil(report.nextPage)
        // 1234.56 + 1000.00 = 2234.56 cents → $22.3456
        XCTAssertEqual(report.totalUSD, 22.3456, accuracy: 0.0001)
    }

    func testCostReportEmptyData() throws {
        let json = #"""
        {"data": [], "has_more": false, "next_page": null}
        """#
        let report = try AnthropicCostReport.decode(Data(json.utf8))
        XCTAssertEqual(report.totalUSD, 0)
    }

    func testCostReportSumsAcrossBuckets() throws {
        let json = #"""
        {
          "data": [
            {"starting_at":"2026-04-22T00:00:00Z","ending_at":"2026-04-23T00:00:00Z","results":[{"amount":"100.00","currency":"USD"}]},
            {"starting_at":"2026-04-23T00:00:00Z","ending_at":"2026-04-24T00:00:00Z","results":[{"amount":"200.00","currency":"USD"}]},
            {"starting_at":"2026-04-24T00:00:00Z","ending_at":"2026-04-25T00:00:00Z","results":[{"amount":"50.00","currency":"USD"}]}
          ],
          "has_more": false,
          "next_page": null
        }
        """#
        let report = try AnthropicCostReport.decode(Data(json.utf8))
        // 350 cents = $3.50
        XCTAssertEqual(report.totalUSD, 3.50, accuracy: 0.0001)
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
}
