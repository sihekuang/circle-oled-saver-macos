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

    // MARK: - Helpers

    private func isoDate(_ s: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: s)!
    }
}
