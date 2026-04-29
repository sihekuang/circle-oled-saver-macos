import XCTest
@testable import CircleKit

final class JSONLUsageReaderTests: XCTestCase {

    private var tempRoot: URL!

    override func setUp() {
        super.setUp()
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("jsonl-usage-tests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempRoot)
        super.tearDown()
    }

    func testReturnsZeroWhenRootMissing() {
        let bogus = tempRoot.appendingPathComponent("does-not-exist")
        XCTAssertEqual(JSONLUsageReader.tokensSince(Date(), root: bogus), 0)
    }

    func testReturnsZeroWhenRootEmpty() {
        XCTAssertEqual(JSONLUsageReader.tokensSince(Date(), root: tempRoot), 0)
    }

    func testSumsBillableTokensAcrossFiles() throws {
        try writeJSONL("session-a.jsonl", lines: [
            entry(timestamp: "2026-04-28T12:00:00.000Z", input: 100, output: 200, cacheCreation: 50, cacheRead: 9999)
        ])
        try writeJSONL("nested/session-b.jsonl", lines: [
            entry(timestamp: "2026-04-28T13:00:00.000Z", input: 10, output: 20, cacheCreation: 5)
        ])
        let since = isoDate("2026-04-28T00:00:00Z")
        // 100+200+50 + 10+20+5 = 385 — cache_read excluded.
        XCTAssertEqual(JSONLUsageReader.tokensSince(since, root: tempRoot), 385)
    }

    func testExcludesCacheReadTokens() throws {
        try writeJSONL("a.jsonl", lines: [
            entry(timestamp: "2026-04-28T12:00:00.000Z", input: 0, output: 0, cacheCreation: 0, cacheRead: 1_000_000)
        ])
        XCTAssertEqual(JSONLUsageReader.tokensSince(isoDate("2026-04-28T00:00:00Z"), root: tempRoot), 0)
    }

    func testFiltersByTimestamp() throws {
        try writeJSONL("a.jsonl", lines: [
            entry(timestamp: "2026-04-28T11:00:00.000Z", input: 100, output: 0, cacheCreation: 0),
            entry(timestamp: "2026-04-28T13:00:00.000Z", input: 200, output: 0, cacheCreation: 0)
        ])
        let since = isoDate("2026-04-28T12:00:00Z")
        XCTAssertEqual(JSONLUsageReader.tokensSince(since, root: tempRoot), 200)
    }

    func testToleratesMalformedLines() throws {
        try writeJSONL("a.jsonl", lines: [
            "not json at all",
            "{\"timestamp\":\"bad-date\",\"message\":{\"usage\":{\"input_tokens\":1}}}",
            entry(timestamp: "2026-04-28T12:00:00.000Z", input: 50, output: 25, cacheCreation: 0),
            "",
            "{ truncated"
        ])
        XCTAssertEqual(JSONLUsageReader.tokensSince(isoDate("2026-04-28T00:00:00Z"), root: tempRoot), 75)
    }

    func testHandlesEntriesWithoutUsage() throws {
        try writeJSONL("a.jsonl", lines: [
            "{\"timestamp\":\"2026-04-28T12:00:00.000Z\",\"type\":\"user\"}",
            entry(timestamp: "2026-04-28T12:01:00.000Z", input: 1, output: 2, cacheCreation: 3)
        ])
        XCTAssertEqual(JSONLUsageReader.tokensSince(isoDate("2026-04-28T00:00:00Z"), root: tempRoot), 6)
    }

    func testSkipsNonJsonlFiles() throws {
        try writeFile("notes.txt", contents: "input_tokens 999\n")
        try writeJSONL("a.jsonl", lines: [
            entry(timestamp: "2026-04-28T12:00:00.000Z", input: 10, output: 0, cacheCreation: 0)
        ])
        XCTAssertEqual(JSONLUsageReader.tokensSince(isoDate("2026-04-28T00:00:00Z"), root: tempRoot), 10)
    }

    func testHandlesPlainISO8601WithoutFractionalSeconds() throws {
        try writeJSONL("a.jsonl", lines: [
            entry(timestamp: "2026-04-28T12:00:00Z", input: 7, output: 0, cacheCreation: 0)
        ])
        XCTAssertEqual(JSONLUsageReader.tokensSince(isoDate("2026-04-28T00:00:00Z"), root: tempRoot), 7)
    }

    // MARK: - Helpers

    private func entry(
        timestamp: String,
        input: Int,
        output: Int,
        cacheCreation: Int,
        cacheRead: Int = 0
    ) -> String {
        """
        {"timestamp":"\(timestamp)","message":{"usage":{"input_tokens":\(input),"output_tokens":\(output),"cache_creation_input_tokens":\(cacheCreation),"cache_read_input_tokens":\(cacheRead)}}}
        """
    }

    private func writeJSONL(_ relativePath: String, lines: [String]) throws {
        try writeFile(relativePath, contents: lines.joined(separator: "\n") + "\n")
    }

    private func writeFile(_ relativePath: String, contents: String) throws {
        let url = tempRoot.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }

    private func isoDate(_ s: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: s)!
    }
}
