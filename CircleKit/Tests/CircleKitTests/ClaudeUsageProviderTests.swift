import XCTest
@testable import CircleKit

final class ClaudeUsageProviderTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("circle-tests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Failure modes

    func testProjectsDirMissing() async {
        let missing = tempDir.appendingPathComponent("does-not-exist")
        let provider = ClaudeUsageProvider(
            projectsDir: missing,
            clock: fixedClock("2026-04-26"),
            mode: .today,
            weeklyGoalTokens: 0
        )
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "0\ntoday")
    }

    func testNoJSONLFiles() async throws {
        try makeProject("empty")
        let provider = makeProvider(date: "2026-04-26", mode: .today)
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "0\ntoday")
    }

    func testIgnoresMalformedLines() async throws {
        try writeSession("p1", "session1", lines: [
            "this is not json",
            assistantLine(timestamp: "2026-04-26T10:00:00Z", input: 100, output: 200, cacheRead: 300, cacheCreate: 400),
            "",
            "{ broken: json",
        ])
        let provider = makeProvider(date: "2026-04-26", mode: .today)
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "1K\ntoday")
    }

    // MARK: - Today aggregation

    func testSumsTodayTokensFromOneSession() async throws {
        try writeSession("p1", "session1", lines: [
            assistantLine(timestamp: "2026-04-26T10:00:00Z", input: 1_000, output: 2_000, cacheRead: 500_000, cacheCreate: 1_000),
        ])
        let provider = makeProvider(date: "2026-04-26", mode: .today)
        await provider.fetchData()
        // total = 1000 + 2000 + 500000 + 1000 = 504000 -> "504K today"
        XCTAssertEqual(provider.cachedData?.text, "504K\ntoday")
    }

    func testSumsAcrossProjectsAndFiles() async throws {
        try writeSession("p1", "session1", lines: [
            assistantLine(timestamp: "2026-04-26T08:00:00Z", input: 0, output: 0, cacheRead: 1_500_000, cacheCreate: 0),
        ])
        try writeSession("p1", "session2", lines: [
            assistantLine(timestamp: "2026-04-26T09:00:00Z", input: 0, output: 0, cacheRead: 2_000_000, cacheCreate: 0),
        ])
        try writeSession("p2", "session1", lines: [
            assistantLine(timestamp: "2026-04-26T10:00:00Z", input: 0, output: 0, cacheRead: 1_500_000, cacheCreate: 0),
        ])
        let provider = makeProvider(date: "2026-04-26", mode: .today)
        await provider.fetchData()
        // 1.5M + 2M + 1.5M = 5M -> "5.0M today"
        XCTAssertEqual(provider.cachedData?.text, "5.0M\ntoday")
    }

    func testIgnoresOtherDates() async throws {
        try writeSession("p1", "session1", lines: [
            assistantLine(timestamp: "2026-04-25T23:59:59Z", input: 0, output: 0, cacheRead: 999_999_999, cacheCreate: 0),
            assistantLine(timestamp: "2026-04-27T00:00:00Z", input: 0, output: 0, cacheRead: 999_999_999, cacheCreate: 0),
        ])
        let provider = makeProvider(date: "2026-04-26", mode: .today)
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "0\ntoday")
    }

    func testIgnoresNonAssistantEntries() async throws {
        try writeSession("p1", "session1", lines: [
            #"{"type":"user","timestamp":"2026-04-26T10:00:00Z","message":{"usage":{"input_tokens":999999}}}"#,
            #"{"type":"system","timestamp":"2026-04-26T10:00:00Z"}"#,
            assistantLine(timestamp: "2026-04-26T10:00:00Z", input: 0, output: 1_000, cacheRead: 0, cacheCreate: 0),
        ])
        let provider = makeProvider(date: "2026-04-26", mode: .today)
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "1K\ntoday")
    }

    // MARK: - Week aggregation

    func testWeekSumsLast7Days() async throws {
        // 1M today, 1M each for 6 prior days, 1M for day 8 (out of window)
        try writeSession("p1", "today", lines: [
            assistantLine(timestamp: "2026-04-26T12:00:00Z", input: 0, output: 0, cacheRead: 1_000_000, cacheCreate: 0),
        ])
        try writeSession("p1", "yesterday", lines: [
            assistantLine(timestamp: "2026-04-25T12:00:00Z", input: 0, output: 0, cacheRead: 1_000_000, cacheCreate: 0),
        ])
        try writeSession("p1", "sixDaysAgo", lines: [
            assistantLine(timestamp: "2026-04-20T12:00:00Z", input: 0, output: 0, cacheRead: 1_000_000, cacheCreate: 0),
        ])
        try writeSession("p1", "eightDaysAgo", lines: [
            assistantLine(timestamp: "2026-04-18T12:00:00Z", input: 0, output: 0, cacheRead: 999_999_999, cacheCreate: 0),
        ])
        let provider = makeProvider(date: "2026-04-26", mode: .week)
        await provider.fetchData()
        // 1M (today) + 1M (yesterday) + 1M (six days ago) = 3M -> "3.0M week"
        XCTAssertEqual(provider.cachedData?.text, "3.0M\nweek")
    }

    // MARK: - Percentage of weekly goal

    func testPercentOfGoalBelowGoal() async throws {
        try writeSession("p1", "session1", lines: [
            assistantLine(timestamp: "2026-04-26T12:00:00Z", input: 0, output: 0, cacheRead: 250_000_000, cacheCreate: 0),
        ])
        // Goal: 1B tokens. Used: 250M. -> 25%
        let provider = ClaudeUsageProvider(
            projectsDir: tempDir,
            clock: fixedClock("2026-04-26"),
            mode: .percentOfWeekly,
            weeklyGoalTokens: 1_000_000_000
        )
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "25%\nweek")
    }

    func testPercentOfGoalOver100() async throws {
        try writeSession("p1", "session1", lines: [
            assistantLine(timestamp: "2026-04-26T12:00:00Z", input: 0, output: 0, cacheRead: 1_500_000_000, cacheCreate: 0),
        ])
        let provider = ClaudeUsageProvider(
            projectsDir: tempDir,
            clock: fixedClock("2026-04-26"),
            mode: .percentOfWeekly,
            weeklyGoalTokens: 1_000_000_000
        )
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "150%\nweek")
    }

    func testPercentWithoutGoalShowsHint() async throws {
        try writeSession("p1", "session1", lines: [
            assistantLine(timestamp: "2026-04-26T12:00:00Z", input: 0, output: 0, cacheRead: 1_000_000, cacheCreate: 0),
        ])
        let provider = ClaudeUsageProvider(
            projectsDir: tempDir,
            clock: fixedClock("2026-04-26"),
            mode: .percentOfWeekly,
            weeklyGoalTokens: 0
        )
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Set goal\nin Settings")
    }

    // MARK: - Formatting

    func testFormatsSmallNumbers() async throws {
        try writeSession("p1", "session1", lines: [
            assistantLine(timestamp: "2026-04-26T12:00:00Z", input: 0, output: 999, cacheRead: 0, cacheCreate: 0),
        ])
        let provider = makeProvider(date: "2026-04-26", mode: .today)
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "999\ntoday")
    }

    func testFormatsBillionsAsM() async throws {
        try writeSession("p1", "session1", lines: [
            assistantLine(timestamp: "2026-04-26T12:00:00Z", input: 0, output: 0, cacheRead: 3_400_000_000, cacheCreate: 0),
        ])
        let provider = makeProvider(date: "2026-04-26", mode: .today)
        await provider.fetchData()
        // 3.4B is shown as 3400.0M -> we want compact: "3.4B today"
        XCTAssertEqual(provider.cachedData?.text, "3.4B\ntoday")
    }

    // MARK: - Helpers

    private func makeProject(_ name: String) throws {
        try FileManager.default.createDirectory(
            at: tempDir.appendingPathComponent(name),
            withIntermediateDirectories: true
        )
    }

    private func writeSession(_ project: String, _ session: String, lines: [String]) throws {
        let projectDir = tempDir.appendingPathComponent(project)
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
        let file = projectDir.appendingPathComponent("\(session).jsonl")
        try lines.joined(separator: "\n").write(to: file, atomically: true, encoding: .utf8)
    }

    private func assistantLine(timestamp: String, input: Int, output: Int, cacheRead: Int, cacheCreate: Int) -> String {
        #"{"type":"assistant","timestamp":"\#(timestamp)","message":{"usage":{"input_tokens":\#(input),"output_tokens":\#(output),"cache_read_input_tokens":\#(cacheRead),"cache_creation_input_tokens":\#(cacheCreate)}}}"#
    }

    private func makeProvider(date: String, mode: ClaudeUsageMode) -> ClaudeUsageProvider {
        ClaudeUsageProvider(
            projectsDir: tempDir,
            clock: fixedClock(date),
            mode: mode,
            weeklyGoalTokens: 0
        )
    }

    private func fixedClock(_ ymd: String) -> () -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        let date = formatter.date(from: ymd)!
        return { date }
    }
}
