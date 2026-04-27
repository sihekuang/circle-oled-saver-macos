import XCTest
@testable import CircleKit

final class SuggestWeeklyGoalTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("circle-suggest-tests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - Empty / missing

    func testReturnsMinimumWhenProjectsDirMissing() {
        let missing = tempDir.appendingPathComponent("does-not-exist")
        let result = ClaudeUsageProvider.suggestWeeklyGoalMTokens(
            projectsDir: missing,
            clock: fixedClock("2026-04-26")
        )
        XCTAssertEqual(result, 100)
    }

    func testReturnsMinimumWhenNoData() throws {
        try makeProject("p1")
        let result = ClaudeUsageProvider.suggestWeeklyGoalMTokens(
            projectsDir: tempDir,
            clock: fixedClock("2026-04-26")
        )
        XCTAssertEqual(result, 100)
    }

    // MARK: - Bucket math

    func testPicksMaxBucketAcrossFourWeeks() throws {
        // Bucket 0 (this week, 0–6 days ago): 200M active
        // Bucket 1 (7–13 days ago):           500M  ← max
        // Bucket 2 (14–20 days ago):          100M
        // Bucket 3 (21–27 days ago):           50M
        try writeAssistant("2026-04-26", active: 200_000_000) // bucket 0
        try writeAssistant("2026-04-18", active: 500_000_000) // bucket 1 (8 days ago)
        try writeAssistant("2026-04-11", active: 100_000_000) // bucket 2 (15 days ago)
        try writeAssistant("2026-04-04", active:  50_000_000) // bucket 3 (22 days ago)

        let result = ClaudeUsageProvider.suggestWeeklyGoalMTokens(
            projectsDir: tempDir,
            clock: fixedClock("2026-04-26")
        )
        // 500M × 1.2 = 600M, already a multiple of 100 → 600
        XCTAssertEqual(result, 600)
    }

    func testRoundsUpToNearestSliderStep() throws {
        // 234M × 1.2 = 280.8M → rounds up to 300
        try writeAssistant("2026-04-26", active: 234_000_000)

        let result = ClaudeUsageProvider.suggestWeeklyGoalMTokens(
            projectsDir: tempDir,
            clock: fixedClock("2026-04-26")
        )
        XCTAssertEqual(result, 300)
    }

    func testClampsToMinimumForSmallUsage() throws {
        // 1M × 1.2 = 1.2M → ceil(0.012) = 1 → 100M floor
        try writeAssistant("2026-04-26", active: 1_000_000)

        let result = ClaudeUsageProvider.suggestWeeklyGoalMTokens(
            projectsDir: tempDir,
            clock: fixedClock("2026-04-26")
        )
        XCTAssertEqual(result, 100)
    }

    func testClampsToMaximumForHugeUsage() throws {
        // 50B × 1.2 = 60B → would exceed 10000M slider max
        try writeAssistant("2026-04-26", active: 50_000_000_000)

        let result = ClaudeUsageProvider.suggestWeeklyGoalMTokens(
            projectsDir: tempDir,
            clock: fixedClock("2026-04-26")
        )
        XCTAssertEqual(result, 10000)
    }

    // MARK: - Window boundary

    func testIgnoresEntriesOutsideWindow() throws {
        // 30 days ago = out of 28-day window
        try writeAssistant("2026-03-27", active: 999_999_999_999, file: "old.jsonl")
        // 20 days ago = bucket 2
        try writeAssistant("2026-04-06", active: 200_000_000, file: "recent.jsonl")

        let result = ClaudeUsageProvider.suggestWeeklyGoalMTokens(
            projectsDir: tempDir,
            clock: fixedClock("2026-04-26")
        )
        // 200M × 1.2 = 240M → rounds up to 300
        XCTAssertEqual(result, 300)
    }

    // MARK: - Cache reads excluded

    func testExcludesCacheReadsFromSuggestion() throws {
        try writeSession("p1", "session1.jsonl", lines: [
            // Heavy cache read (would suggest a huge goal if counted), but only
            // 100M of active output. Should suggest based on active = 100M.
            #"{"type":"assistant","timestamp":"2026-04-26T10:00:00Z","message":{"usage":{"input_tokens":0,"output_tokens":100000000,"cache_read_input_tokens":50000000000,"cache_creation_input_tokens":0}}}"#,
        ])

        let result = ClaudeUsageProvider.suggestWeeklyGoalMTokens(
            projectsDir: tempDir,
            clock: fixedClock("2026-04-26")
        )
        // 100M × 1.2 = 120M → rounds up to 200
        XCTAssertEqual(result, 200)
    }

    // MARK: - Sums within a bucket

    func testSumsMultipleEntriesInSameBucket() throws {
        // Three entries today, all in bucket 0
        try writeAssistant("2026-04-26", active: 100_000_000, file: "a.jsonl")
        try writeAssistant("2026-04-25", active: 200_000_000, file: "b.jsonl")
        try writeAssistant("2026-04-20", active: 200_000_000, file: "c.jsonl")
        // Total bucket 0 = 500M. × 1.2 = 600M → 600
        let result = ClaudeUsageProvider.suggestWeeklyGoalMTokens(
            projectsDir: tempDir,
            clock: fixedClock("2026-04-26")
        )
        XCTAssertEqual(result, 600)
    }

    // MARK: - Helpers

    private func makeProject(_ name: String) throws {
        try FileManager.default.createDirectory(
            at: tempDir.appendingPathComponent(name),
            withIntermediateDirectories: true
        )
    }

    private func writeAssistant(_ date: String, active: Int, file: String = "session.jsonl") throws {
        try writeSession("p1", file, lines: [
            #"{"type":"assistant","timestamp":"\#(date)T10:00:00Z","message":{"usage":{"input_tokens":0,"output_tokens":\#(active),"cache_read_input_tokens":0,"cache_creation_input_tokens":0}}}"#,
        ])
    }

    private func writeSession(_ project: String, _ session: String, lines: [String]) throws {
        let projectDir = tempDir.appendingPathComponent(project)
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
        let file = projectDir.appendingPathComponent(session)
        // Append if file already exists so multiple writeAssistant calls land in
        // one file when they share the session name.
        let content = lines.joined(separator: "\n") + "\n"
        if let existing = try? String(contentsOf: file, encoding: .utf8) {
            try (existing + content).write(to: file, atomically: true, encoding: .utf8)
        } else {
            try content.write(to: file, atomically: true, encoding: .utf8)
        }
    }

    private func fixedClock(_ ymd: String) -> () -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        let date = formatter.date(from: ymd)!
        return { date }
    }
}
