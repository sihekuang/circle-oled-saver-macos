import XCTest
@testable import CircleKit

final class ClaudeUsageProviderTests: XCTestCase {

    private typealias Bucket = AnthropicUsage.Bucket
    private typealias ClientError = ClaudeCLIUsageClient.ClientError

    // MARK: - Setup problems

    func testNotInstalledShowsInstallPrompt() async {
        let provider = ClaudeUsageProvider(mode: .today, fetchUsage: { throw ClientError.notInstalled })
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\ninstall CC")
    }

    func testNotSignedInShowsSignInPrompt() async {
        let provider = ClaudeUsageProvider(mode: .today, fetchUsage: { throw ClientError.notSignedIn })
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\nsign in to CC")
    }

    func testSetupFailureBacksOff() async {
        var calls = 0
        var now = isoDate("2026-04-28T12:00:00Z")
        let provider = ClaudeUsageProvider(clock: { now }, mode: .today, fetchUsage: {
            calls += 1
            throw ClientError.notSignedIn
        })
        await provider.fetchData()
        now = now.addingTimeInterval(ClaudeUsageProvider.setupFailureBackoff - 1)
        await provider.fetchData()
        XCTAssertEqual(calls, 1)
        now = now.addingTimeInterval(2)
        await provider.fetchData()
        XCTAssertEqual(calls, 2)
    }

    // MARK: - Today (5h session)

    func testTodayShowsSessionPercentage() async {
        let usage = AnthropicUsage(
            fiveHour: Bucket(utilization: 33, resetsAt: isoDate("2026-04-28T18:00:00Z")),
            sevenDay: Bucket(utilization: 48, resetsAt: isoDate("2026-04-30T00:00:00Z"))
        )
        let now = isoDate("2026-04-28T12:00:00Z")
        let provider = ClaudeUsageProvider(clock: { now }, mode: .today, fetchUsage: { usage })
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\n33% session\n6h left")
    }

    func testWeekShowsWeekPercentage() async {
        let usage = AnthropicUsage(
            fiveHour: nil,
            sevenDay: Bucket(utilization: 48, resetsAt: isoDate("2026-04-28T03:00:00Z"))
        )
        let now = isoDate("2026-04-28T00:00:00Z")
        let provider = ClaudeUsageProvider(clock: { now }, mode: .week, fetchUsage: { usage })
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\n48% week\n3h left")
    }

    func testMissingBucketShowsNoData() async {
        let usage = AnthropicUsage(
            fiveHour: nil,
            sevenDay: Bucket(utilization: 48, resetsAt: isoDate("2026-04-29T00:00:00Z"))
        )
        let provider = ClaudeUsageProvider(mode: .today, fetchUsage: { usage })
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\nno data")
    }

    func testBucketWithoutResetsAtSkipsCountdown() async {
        let usage = AnthropicUsage(fiveHour: Bucket(utilization: 15, resetsAt: nil), sevenDay: nil)
        let provider = ClaudeUsageProvider(mode: .today, fetchUsage: { usage })
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\n15% session")
    }

    // MARK: - Transient errors

    func testTransientErrorShowsUnavailableWhenNoCachedData() async {
        let provider = ClaudeUsageProvider(mode: .today, fetchUsage: { throw ClientError.timedOut })
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\nunavailable")
    }

    func testTransientErrorKeepsLastKnownData() async {
        var callCount = 0
        var now = isoDate("2026-04-28T12:00:00Z")
        let provider = ClaudeUsageProvider(clock: { now }, mode: .today, fetchUsage: {
            callCount += 1
            if callCount == 1 {
                return AnthropicUsage(fiveHour: Bucket(utilization: 42, resetsAt: nil), sevenDay: nil)
            }
            throw ClientError.timedOut
        })
        await provider.fetchData()
        now = now.addingTimeInterval(1)
        await provider.fetchData()
        XCTAssertEqual(callCount, 2)
        XCTAssertEqual(provider.cachedData?.text, "Claude\n42% session")
    }

    func testSuccessClearsBackoff() async {
        var callCount = 0
        var now = isoDate("2026-04-28T12:00:00Z")
        let provider = ClaudeUsageProvider(clock: { now }, mode: .today, fetchUsage: {
            callCount += 1
            if callCount == 1 { throw ClientError.timedOut }
            return AnthropicUsage(fiveHour: Bucket(utilization: 12, resetsAt: nil), sevenDay: nil)
        })
        await provider.fetchData()
        now = now.addingTimeInterval(ClaudeUsageProvider.transientFailureBackoff + 1)
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\n12% session")
        await provider.fetchData()
        XCTAssertEqual(callCount, 3)
    }

    // MARK: - Token aggregation (JSONL)

    func testAppendsTokensToTodayDisplayWhenAvailable() async {
        let usage = AnthropicUsage(
            fiveHour: Bucket(utilization: 33, resetsAt: isoDate("2026-04-28T18:00:00Z")),
            sevenDay: nil
        )
        let now = isoDate("2026-04-28T12:00:00Z")
        // resets_at 18:00, window = 5h → window start = 13:00.
        var capturedSince: Date?
        let provider = ClaudeUsageProvider(
            clock: { now },
            mode: .today,
            fetchUsage: { usage },
            tokensSince: { since in
                capturedSince = since
                return 1_234_567
            }
        )
        await provider.fetchData()
        XCTAssertEqual(capturedSince, isoDate("2026-04-28T13:00:00Z"))
        XCTAssertEqual(provider.cachedData?.text, "Claude\n33% session \u{00B7} 1.2M used\n6h left")
    }

    func testAppendsTokensToWeekDisplayWithSevenDayWindow() async {
        let usage = AnthropicUsage(
            fiveHour: nil,
            sevenDay: Bucket(utilization: 48, resetsAt: isoDate("2026-04-30T00:00:00Z"))
        )
        let now = isoDate("2026-04-29T00:00:00Z")
        var capturedSince: Date?
        let provider = ClaudeUsageProvider(
            clock: { now },
            mode: .week,
            fetchUsage: { usage },
            tokensSince: { since in
                capturedSince = since
                return 12_500_000
            }
        )
        await provider.fetchData()
        // resets_at 2026-04-30T00:00, window = 7d → window start = 2026-04-23T00:00.
        XCTAssertEqual(capturedSince, isoDate("2026-04-23T00:00:00Z"))
        XCTAssertEqual(provider.cachedData?.text, "Claude\n48% week \u{00B7} 13M used\n24h left")
    }

    func testZeroTokensOmitsTokenSegment() async {
        let usage = AnthropicUsage(
            fiveHour: Bucket(utilization: 33, resetsAt: isoDate("2026-04-28T18:00:00Z")),
            sevenDay: nil
        )
        let now = isoDate("2026-04-28T12:00:00Z")
        let provider = ClaudeUsageProvider(clock: { now }, mode: .today, fetchUsage: { usage }, tokensSince: { _ in 0 })
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\n33% session\n6h left")
    }

    func testTokensNotAppendedWhenResetsAtMissing() async {
        let usage = AnthropicUsage(fiveHour: Bucket(utilization: 15, resetsAt: nil), sevenDay: nil)
        var called = false
        let provider = ClaudeUsageProvider(
            mode: .today,
            fetchUsage: { usage },
            tokensSince: { _ in called = true; return 999_999 }
        )
        await provider.fetchData()
        XCTAssertFalse(called, "no resets_at = no window start = no JSONL read")
        XCTAssertEqual(provider.cachedData?.text, "Claude\n15% session")
    }

    func testFormatTokensSubMillion() {
        XCTAssertEqual(ClaudeUsageProvider.formatTokens(0), "0.0M")
        XCTAssertEqual(ClaudeUsageProvider.formatTokens(123_456), "0.1M")
        XCTAssertEqual(ClaudeUsageProvider.formatTokens(1_500_000), "1.5M")
        XCTAssertEqual(ClaudeUsageProvider.formatTokens(9_949_000), "9.9M")
    }

    func testFormatTokensTenMillionPlus() {
        XCTAssertEqual(ClaudeUsageProvider.formatTokens(10_000_000), "10M")
        XCTAssertEqual(ClaudeUsageProvider.formatTokens(12_400_000), "12M")
        XCTAssertEqual(ClaudeUsageProvider.formatTokens(12_600_000), "13M")
    }

    // MARK: - Helpers

    private func isoDate(_ s: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: s)!
    }
}
