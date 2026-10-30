import XCTest
@testable import CircleKit

final class ClaudeCLIUsageParserTests: XCTestCase {

    /// Output captured from `claude -p /usage` (Claude Code 2.1.314).
    private let sample = """
    You are currently using your subscription to power your Claude Code usage

    Current session: 6% used · resets Oct 30 at 12:29am (America/Los_Angeles)
    Current week (all models): 35% used · resets Nov 3 at 3:59am (America/Los_Angeles)
    Current week (Fable): 0% used · resets Nov 3 at 4am (America/Los_Angeles)

    What's contributing to your usage?
    Approximate · sessions on this machine only · shares overlap

    Last 24h · 137 requests · 7 sessions
      74%  Give simple subagents a cheaper model
    """

    func testParsesSessionAndWeek() throws {
        let now = isoDate("2026-10-29T20:00:00Z")
        let usage = try XCTUnwrap(ClaudeCLIUsageParser.parse(sample, now: now))
        XCTAssertEqual(usage.fiveHour?.utilization, 6)
        // 12:29am PDT on Oct 30 = 07:29 UTC.
        XCTAssertEqual(usage.fiveHour?.resetsAt, isoDate("2026-10-30T07:29:00Z"))
        XCTAssertEqual(usage.sevenDay?.utilization, 35)
        // Nov 3 is after the DST change, so 3:59am PST = 11:59 UTC.
        XCTAssertEqual(usage.sevenDay?.resetsAt, isoDate("2026-11-03T11:59:00Z"))
        XCTAssertNil(usage.sevenDaySonnet)
    }

    func testIgnoresRecommendationPercentages() throws {
        // "74%  Give simple subagents…" must not be read as a usage figure.
        let usage = try XCTUnwrap(ClaudeCLIUsageParser.parse(sample, now: isoDate("2026-10-29T20:00:00Z")))
        XCTAssertNotEqual(usage.fiveHour?.utilization, 74)
    }

    func testSignedOutOutputReturnsNil() {
        let output = """
        Total cost:            $0.0000
        Total duration (API):  0s
        Usage:                 0 input, 0 output, 0 cache read, 0 cache write
        """
        XCTAssertNil(ClaudeCLIUsageParser.parse(output, now: Date()))
    }

    func testLineWithoutResetKeepsPercentage() throws {
        let usage = try XCTUnwrap(ClaudeCLIUsageParser.parse("Current session: 0% used", now: Date()))
        XCTAssertEqual(usage.fiveHour?.utilization, 0)
        XCTAssertNil(usage.fiveHour?.resetsAt)
    }

    func testUnrecognizedResetPhraseKeepsPercentage() throws {
        let usage = try XCTUnwrap(ClaudeCLIUsageParser.parse("Current session: 12% used · resets soon-ish", now: Date()))
        XCTAssertEqual(usage.fiveHour?.utilization, 12)
        XCTAssertNil(usage.fiveHour?.resetsAt)
    }

    func testResetDateInJanuarySeenInDecemberRollsToNextYear() {
        let now = isoDate("2026-12-30T12:00:00Z")
        let date = ClaudeCLIUsageParser.parseResetTime("Jan 2 at 4am (UTC)", now: now)
        XCTAssertEqual(date, isoDate("2027-01-02T04:00:00Z"))
    }

    func testTimeOnlyResetIsNextOccurrence() {
        let now = isoDate("2026-10-29T20:00:00Z")
        XCTAssertEqual(ClaudeCLIUsageParser.parseResetTime("11pm (UTC)", now: now), isoDate("2026-10-29T23:00:00Z"))
        XCTAssertEqual(ClaudeCLIUsageParser.parseResetTime("4am (UTC)", now: now), isoDate("2026-10-30T04:00:00Z"))
        XCTAssertEqual(ClaudeCLIUsageParser.parseResetTime("12pm (UTC)", now: now), isoDate("2026-10-30T12:00:00Z"))
    }

    func testRelativeReset() {
        let now = isoDate("2026-10-29T20:00:00Z")
        XCTAssertEqual(ClaudeCLIUsageParser.parseResetTime("in 2h 5m", now: now), isoDate("2026-10-29T22:05:00Z"))
    }

    private func isoDate(_ s: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: s)!
    }
}

final class StatusLineUsageSnapshotTests: XCTestCase {

    func testReadsWindowsThatHaveNotReset() throws {
        let json = #"{"captured_at":1000,"rate_limits":{"five_hour":{"used_percentage":1,"resets_at":5000},"seven_day":{"used_percentage":22,"resets_at":9000}}}"#
        let usage = try XCTUnwrap(StatusLineUsageSnapshot.parse(Data(json.utf8), now: Date(timeIntervalSince1970: 2000)))
        XCTAssertEqual(usage.fiveHour, .init(utilization: 1, resetsAt: Date(timeIntervalSince1970: 5000)))
        XCTAssertEqual(usage.sevenDay?.utilization, 22)
    }

    func testDropsWindowsThatHaveReset() throws {
        let json = #"{"rate_limits":{"five_hour":{"used_percentage":80,"resets_at":5000},"seven_day":{"used_percentage":22,"resets_at":9000}}}"#
        let usage = try XCTUnwrap(StatusLineUsageSnapshot.parse(Data(json.utf8), now: Date(timeIntervalSince1970: 6000)))
        XCTAssertNil(usage.fiveHour)
        XCTAssertEqual(usage.sevenDay?.utilization, 22)
    }

    func testAllWindowsResetReturnsNil() {
        let json = #"{"rate_limits":{"five_hour":{"used_percentage":80,"resets_at":5000}}}"#
        XCTAssertNil(StatusLineUsageSnapshot.parse(Data(json.utf8), now: Date(timeIntervalSince1970: 6000)))
    }

    func testMissingFileReturnsNil() {
        XCTAssertNil(StatusLineUsageSnapshot.read(from: URL(fileURLWithPath: "/nonexistent/claude-rate-limits.json")))
    }
}

final class ClaudeCLIUsageClientTests: XCTestCase {

    private let output = "Current session: 6% used\nCurrent week (all models): 35% used\n"
    private let cli = URL(fileURLWithPath: "/usr/local/bin/claude")

    func testParsesCLIOutput() async throws {
        let client = ClaudeCLIUsageClient(locate: { self.cli }, run: { _, _ in self.output }, fallback: { nil })
        let usage = try await client.fetchUsage()
        XCTAssertEqual(usage.sevenDay?.utilization, 35)
    }

    func testPassesUsageArguments() async throws {
        var arguments: [String] = []
        let client = ClaudeCLIUsageClient(locate: { self.cli }, run: { _, args in
            arguments = args
            return self.output
        }, fallback: { nil })
        _ = try await client.fetchUsage()
        XCTAssertEqual(Array(arguments.prefix(2)), ["-p", "/usage"])
        XCTAssertTrue(arguments.contains("--no-session-persistence"))
    }

    func testReusesRecentReading() async throws {
        var runs = 0
        var now = Date(timeIntervalSince1970: 0)
        let client = ClaudeCLIUsageClient(clock: { now }, locate: { self.cli }, run: { _, _ in
            runs += 1
            return self.output
        }, fallback: { nil })
        _ = try await client.fetchUsage()
        now = now.addingTimeInterval(ClaudeCLIUsageClient.successMaxAge - 1)
        _ = try await client.fetchUsage()
        XCTAssertEqual(runs, 1)
        now = now.addingTimeInterval(2)
        _ = try await client.fetchUsage()
        XCTAssertEqual(runs, 2)
    }

    func testForceSkipsCache() async throws {
        var runs = 0
        let client = ClaudeCLIUsageClient(locate: { self.cli }, run: { _, _ in
            runs += 1
            return self.output
        }, fallback: { nil })
        _ = try await client.fetchUsage()
        _ = try await client.fetchUsage(force: true)
        XCTAssertEqual(runs, 2)
    }

    func testNotInstalled() async {
        let client = ClaudeCLIUsageClient(locate: { nil }, run: { _, _ in XCTFail("must not run"); return "" }, fallback: { nil })
        await assertThrows(client, .notInstalled)
    }

    func testSignedOutOutputIsNotSignedIn() async {
        let client = ClaudeCLIUsageClient(locate: { self.cli }, run: { _, _ in "Total cost: $0.0000" }, fallback: { nil })
        await assertThrows(client, .notSignedIn)
    }

    func testFailureIsRememberedBriefly() async {
        var runs = 0
        var now = Date(timeIntervalSince1970: 0)
        let client = ClaudeCLIUsageClient(clock: { now }, locate: { self.cli }, run: { _, _ in
            runs += 1
            throw ClaudeCLIUsageClient.ClientError.timedOut
        }, fallback: { nil })
        await assertThrows(client, .timedOut)
        await assertThrows(client, .timedOut)
        XCTAssertEqual(runs, 1)
        now = now.addingTimeInterval(ClaudeCLIUsageClient.failureMaxAge + 1)
        await assertThrows(client, .timedOut)
        XCTAssertEqual(runs, 2)
    }

    func testFallsBackToStatusLineSnapshot() async throws {
        let snapshot = AnthropicUsage(fiveHour: .init(utilization: 9, resetsAt: nil), sevenDay: nil)
        let client = ClaudeCLIUsageClient(locate: { nil }, run: { _, _ in "" }, fallback: { snapshot })
        let usage = try await client.fetchUsage()
        XCTAssertEqual(usage, snapshot)
    }

    func testCLIReadingWinsOverSnapshot() async throws {
        let snapshot = AnthropicUsage(fiveHour: .init(utilization: 9, resetsAt: nil), sevenDay: nil)
        let client = ClaudeCLIUsageClient(locate: { self.cli }, run: { _, _ in self.output }, fallback: { snapshot })
        let usage = try await client.fetchUsage()
        XCTAssertEqual(usage.fiveHour?.utilization, 6)
    }

    func testLocateFindsFirstExecutableCandidate() {
        let home = URL(fileURLWithPath: "/Users/someone")
        let found = ClaudeCLIUsageClient.locateCLI(home: home, environmentPath: "/custom/bin", isExecutable: {
            $0 == "/opt/homebrew/bin/claude" || $0 == "/custom/bin/claude"
        })
        XCTAssertEqual(found?.path, "/opt/homebrew/bin/claude")
    }

    func testLocateFallsBackToPATH() {
        let found = ClaudeCLIUsageClient.locateCLI(home: URL(fileURLWithPath: "/Users/someone"), environmentPath: "/a:/custom/bin", isExecutable: {
            $0 == "/custom/bin/claude"
        })
        XCTAssertEqual(found?.path, "/custom/bin/claude")
    }

    func testRunProcessReturnsStdout() async throws {
        let output = try await ClaudeCLIUsageClient.runProcess(URL(fileURLWithPath: "/bin/echo"), ["hello"])
        XCTAssertEqual(output, "hello\n")
    }

    private func assertThrows(_ client: ClaudeCLIUsageClient, _ expected: ClaudeCLIUsageClient.ClientError,
                              file: StaticString = #filePath, line: UInt = #line) async {
        do {
            _ = try await client.fetchUsage()
            XCTFail("expected \(expected)", file: file, line: line)
        } catch let error as ClaudeCLIUsageClient.ClientError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("unexpected \(error)", file: file, line: line)
        }
    }
}
