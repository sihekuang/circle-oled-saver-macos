import XCTest
@testable import CircleKit

final class ClaudeUsageProviderTests: XCTestCase {
    private var tempDir: URL!

    /// Goal of 7000 tokens → daily share = 1000 tokens. Gives clean percentages
    /// in tests (e.g., 250 used = 25%, 1000 = 100%).
    private let testWeeklyGoal = 7000

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
            weeklyGoalTokens: testWeeklyGoal
        )
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\n0% today\n24h left")
    }

    func testNoJSONLFiles() async throws {
        try makeProject("empty")
        let provider = makeProvider(date: "2026-04-26", mode: .today)
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\n0% today\n24h left")
    }

    func testIgnoresMalformedLines() async throws {
        try writeSession("p1", "session1", lines: [
            "this is not json",
            assistantLine(timestamp: "2026-04-26T10:00:00Z", input: 100, output: 100, cacheRead: 999, cacheCreate: 50),
            "",
            "{ broken: json",
        ])
        // Active = 100 + 100 + 50 = 250 (cacheRead excluded). Daily share = 1000. -> 25%
        let provider = makeProvider(date: "2026-04-26", mode: .today)
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\n25% today\n24h left")
    }

    func testTodayWithoutGoalShowsHint() async throws {
        try writeSession("p1", "session1", lines: [
            assistantLine(timestamp: "2026-04-26T12:00:00Z", input: 0, output: 1000, cacheRead: 0, cacheCreate: 0),
        ])
        let provider = ClaudeUsageProvider(
            projectsDir: tempDir,
            clock: fixedClock("2026-04-26"),
            mode: .today,
            weeklyGoalTokens: 0
        )
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\nset goal")
    }

    func testWeekWithoutGoalShowsHint() async throws {
        try writeSession("p1", "session1", lines: [
            assistantLine(timestamp: "2026-04-26T12:00:00Z", input: 0, output: 1000, cacheRead: 0, cacheCreate: 0),
        ])
        let provider = ClaudeUsageProvider(
            projectsDir: tempDir,
            clock: fixedClock("2026-04-26"),
            mode: .week,
            weeklyGoalTokens: 0
        )
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\nset goal")
    }

    // MARK: - Today percentage

    func testTodayBelow100() async throws {
        try writeSession("p1", "session1", lines: [
            assistantLine(timestamp: "2026-04-26T10:00:00Z", input: 100, output: 100, cacheRead: 0, cacheCreate: 50),
        ])
        // 250 / 1000 = 25%
        let provider = makeProvider(date: "2026-04-26", mode: .today)
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\n25% today\n24h left")
    }

    func testTodayExactly100() async throws {
        try writeSession("p1", "session1", lines: [
            assistantLine(timestamp: "2026-04-26T10:00:00Z", input: 0, output: 1000, cacheRead: 0, cacheCreate: 0),
        ])
        // 1000 / 1000 = 100%
        let provider = makeProvider(date: "2026-04-26", mode: .today)
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\n100% today\n24h left")
    }

    func testTodayAbove100() async throws {
        try writeSession("p1", "session1", lines: [
            assistantLine(timestamp: "2026-04-26T10:00:00Z", input: 0, output: 2500, cacheRead: 0, cacheCreate: 0),
        ])
        // 2500 / 1000 = 250%
        let provider = makeProvider(date: "2026-04-26", mode: .today)
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\n250% today\n24h left")
    }

    func testTodaySumsAcrossProjectsAndFiles() async throws {
        try writeSession("p1", "s1", lines: [
            assistantLine(timestamp: "2026-04-26T08:00:00Z", input: 0, output: 200, cacheRead: 0, cacheCreate: 0),
        ])
        try writeSession("p1", "s2", lines: [
            assistantLine(timestamp: "2026-04-26T09:00:00Z", input: 0, output: 300, cacheRead: 0, cacheCreate: 0),
        ])
        try writeSession("p2", "s1", lines: [
            assistantLine(timestamp: "2026-04-26T10:00:00Z", input: 0, output: 500, cacheRead: 0, cacheCreate: 0),
        ])
        // 200 + 300 + 500 = 1000 -> 100%
        let provider = makeProvider(date: "2026-04-26", mode: .today)
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\n100% today\n24h left")
    }

    func testCacheReadsAreExcluded() async throws {
        // Cache reads inflate the raw count without representing real usage.
        // Verify they're dropped from the active total.
        try writeSession("p1", "session1", lines: [
            assistantLine(timestamp: "2026-04-26T10:00:00Z", input: 0, output: 250, cacheRead: 999_999_999, cacheCreate: 0),
        ])
        // 250 / 1000 = 25% (cacheRead ignored)
        let provider = makeProvider(date: "2026-04-26", mode: .today)
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\n25% today\n24h left")
    }

    func testTodayIgnoresOtherDates() async throws {
        try writeSession("p1", "session1", lines: [
            assistantLine(timestamp: "2026-04-25T23:59:59Z", input: 0, output: 0, cacheRead: 999_999, cacheCreate: 0),
            assistantLine(timestamp: "2026-04-27T00:00:00Z", input: 0, output: 0, cacheRead: 999_999, cacheCreate: 0),
        ])
        let provider = makeProvider(date: "2026-04-26", mode: .today)
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\n0% today\n24h left")
    }

    func testTodayIgnoresNonAssistantEntries() async throws {
        try writeSession("p1", "session1", lines: [
            #"{"type":"user","timestamp":"2026-04-26T10:00:00Z","message":{"usage":{"input_tokens":999999}}}"#,
            #"{"type":"system","timestamp":"2026-04-26T10:00:00Z"}"#,
            assistantLine(timestamp: "2026-04-26T10:00:00Z", input: 0, output: 250, cacheRead: 0, cacheCreate: 0),
        ])
        // Only the assistant line counts: 250 / 1000 = 25%
        let provider = makeProvider(date: "2026-04-26", mode: .today)
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\n25% today\n24h left")
    }

    // MARK: - Week percentage

    func testWeekBelow100() async throws {
        try writeSession("p1", "session1", lines: [
            assistantLine(timestamp: "2026-04-26T12:00:00Z", input: 0, output: 1750, cacheRead: 0, cacheCreate: 0),
        ])
        // 1750 / 7000 = 25%
        let provider = makeProvider(date: "2026-04-26", mode: .week)
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\n25% week")
    }

    func testWeekAbove100() async throws {
        try writeSession("p1", "session1", lines: [
            assistantLine(timestamp: "2026-04-26T12:00:00Z", input: 0, output: 10_500, cacheRead: 0, cacheCreate: 0),
        ])
        // 10500 / 7000 = 150%
        let provider = makeProvider(date: "2026-04-26", mode: .week)
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\n150% week")
    }

    func testWeekSumsLast7Days() async throws {
        // 1000 today, 1000 yesterday, 1000 six days ago, 999_999 eight days ago (out of window)
        try writeSession("p1", "today", lines: [
            assistantLine(timestamp: "2026-04-26T12:00:00Z", input: 0, output: 1000, cacheRead: 0, cacheCreate: 0),
        ])
        try writeSession("p1", "yesterday", lines: [
            assistantLine(timestamp: "2026-04-25T12:00:00Z", input: 0, output: 1000, cacheRead: 0, cacheCreate: 0),
        ])
        try writeSession("p1", "sixDaysAgo", lines: [
            assistantLine(timestamp: "2026-04-20T12:00:00Z", input: 0, output: 1000, cacheRead: 0, cacheCreate: 0),
        ])
        try writeSession("p1", "eightDaysAgo", lines: [
            assistantLine(timestamp: "2026-04-18T12:00:00Z", input: 0, output: 999_999, cacheRead: 0, cacheCreate: 0),
        ])
        // 3000 / 7000 = 42% (truncates from 42.85%)
        let provider = makeProvider(date: "2026-04-26", mode: .week)
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\n42% week")
    }

    // MARK: - Icon

    func testUsesSparkleIcon() async throws {
        try writeSession("p1", "session1", lines: [
            assistantLine(timestamp: "2026-04-26T10:00:00Z", input: 0, output: 1, cacheRead: 0, cacheCreate: 0),
        ])
        let provider = makeProvider(date: "2026-04-26", mode: .today)
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.icon, "\u{2728}")
    }

    // MARK: - Time-until-midnight formatting

    private func untilMidnight(_ date: Date) -> String {
        ClaudeUsageProvider.formatTimeRemaining(seconds: ClaudeUsageProvider.secondsUntilMidnight(from: date))
    }

    func testFormatTimeUntilMidnightHoursAndMinutes() {
        // 14:30 local → 9h 30m to midnight
        let date = makeDate("2026-04-26", hour: 14, minute: 30)
        XCTAssertEqual(untilMidnight(date), "9h 30m")
    }

    func testFormatTimeUntilMidnightOmitsZeroMinutes() {
        // 19:00 → exactly 5h, no leftover minutes
        let date = makeDate("2026-04-26", hour: 19, minute: 0)
        XCTAssertEqual(untilMidnight(date), "5h")
    }

    func testFormatTimeUntilMidnight1HourLeft() {
        // 23:00 → exactly 1h to midnight
        let date = makeDate("2026-04-26", hour: 23, minute: 0)
        XCTAssertEqual(untilMidnight(date), "1h")
    }

    func testFormatTimeUntilMidnightUnder1Hour() {
        // 23:30 → 30m to midnight
        let date = makeDate("2026-04-26", hour: 23, minute: 30)
        XCTAssertEqual(untilMidnight(date), "30m")
    }

    func testFormatTimeUntilMidnightFewSecondsCeilsTo1m() {
        // 23:59:30 → 30s remaining → ceil → "1m" (never display "0m" before midnight)
        let date = makeDate("2026-04-26", hour: 23, minute: 59).addingTimeInterval(30)
        XCTAssertEqual(untilMidnight(date), "1m")
    }

    func testTodayDisplayIncludesResetCountdown() async throws {
        try writeSession("p1", "session1.jsonl", lines: [
            assistantLine(timestamp: "2026-04-26T15:00:00Z", input: 0, output: 250, cacheRead: 0, cacheCreate: 0),
        ])
        let provider = ClaudeUsageProvider(
            projectsDir: tempDir,
            clock: { self.makeDate("2026-04-26", hour: 18, minute: 0) },
            mode: .today,
            weeklyGoalTokens: testWeeklyGoal
        )
        await provider.fetchData()
        // 18:00 → 6h to midnight. 250 / 1000 = 25%.
        XCTAssertEqual(provider.cachedData?.text, "Claude\n25% today\n6h left")
    }

    func testWeekDisplayDoesNotIncludeResetCountdown() async throws {
        try writeSession("p1", "session1.jsonl", lines: [
            assistantLine(timestamp: "2026-04-26T15:00:00Z", input: 0, output: 1750, cacheRead: 0, cacheCreate: 0),
        ])
        let provider = ClaudeUsageProvider(
            projectsDir: tempDir,
            clock: { self.makeDate("2026-04-26", hour: 18, minute: 0) },
            mode: .week,
            weeklyGoalTokens: testWeeklyGoal
        )
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\n25% week")
    }

    // MARK: - Helpers

    private func makeDate(_ ymd: String, hour: Int, minute: Int) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        formatter.timeZone = TimeZone.current
        return formatter.date(from: "\(ymd) \(String(format: "%02d:%02d", hour, minute))")!
    }

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
            weeklyGoalTokens: testWeeklyGoal
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
