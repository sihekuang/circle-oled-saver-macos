import XCTest
@testable import CircleKit

final class ClaudeUsageProviderTests: XCTestCase {
    private var tempFiles: [URL] = []

    override func tearDown() {
        tempFiles.forEach { try? FileManager.default.removeItem(at: $0) }
        tempFiles.removeAll()
        super.tearDown()
    }

    // MARK: - Failure modes

    func testFileMissing() async {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("circle-test-missing-\(UUID().uuidString).json")
        let provider = ClaudeUsageProvider(statsPath: path)
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "No data\ntoday")
    }

    func testFileInvalidJSON() async throws {
        let path = makeTempFile(contents: "this is not json")
        let provider = ClaudeUsageProvider(statsPath: path)
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "No data\ntoday")
    }

    func testFileMissingDailyModelTokensKey() async throws {
        let path = makeTempFile(contents: #"{"version": 2}"#)
        let provider = ClaudeUsageProvider(statsPath: path)
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "No data\ntoday")
    }

    // MARK: - Aggregation

    func testZeroWhenNoTodayEntry() async throws {
        let json = #"""
        { "dailyModelTokens": [{ "date": "2020-01-01", "tokensByModel": { "opus": 100 } }] }
        """#
        let path = makeTempFile(contents: json)
        let provider = ClaudeUsageProvider(statsPath: path, clock: fixedClock("2026-04-26"))
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "0\ntoday")
    }

    func testSumsAllModelsForToday() async throws {
        let json = #"""
        {
          "dailyModelTokens": [
            { "date": "2026-04-26", "tokensByModel": { "opus": 1500000, "haiku": 500000 } },
            { "date": "2026-04-25", "tokensByModel": { "opus": 999999 } }
          ]
        }
        """#
        let path = makeTempFile(contents: json)
        let provider = ClaudeUsageProvider(statsPath: path, clock: fixedClock("2026-04-26"))
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "2.0M\ntoday")
    }

    func testIgnoresOtherDates() async throws {
        let json = #"""
        {
          "dailyModelTokens": [
            { "date": "2026-04-25", "tokensByModel": { "opus": 999999999 } },
            { "date": "2026-04-27", "tokensByModel": { "opus": 999999999 } }
          ]
        }
        """#
        let path = makeTempFile(contents: json)
        let provider = ClaudeUsageProvider(statsPath: path, clock: fixedClock("2026-04-26"))
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "0\ntoday")
    }

    // MARK: - Formatting

    func testFormatsSmallNumbers() async throws {
        let json = #"""
        { "dailyModelTokens": [{ "date": "2026-04-26", "tokensByModel": { "opus": 999 } }] }
        """#
        let path = makeTempFile(contents: json)
        let provider = ClaudeUsageProvider(statsPath: path, clock: fixedClock("2026-04-26"))
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "999\ntoday")
    }

    func testFormatsThousandsAt1000() async throws {
        let json = #"""
        { "dailyModelTokens": [{ "date": "2026-04-26", "tokensByModel": { "opus": 1000 } }] }
        """#
        let path = makeTempFile(contents: json)
        let provider = ClaudeUsageProvider(statsPath: path, clock: fixedClock("2026-04-26"))
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "1K\ntoday")
    }

    func testFormatsThousandsTruncates() async throws {
        let json = #"""
        { "dailyModelTokens": [{ "date": "2026-04-26", "tokensByModel": { "opus": 45678 } }] }
        """#
        let path = makeTempFile(contents: json)
        let provider = ClaudeUsageProvider(statsPath: path, clock: fixedClock("2026-04-26"))
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "45K\ntoday")
    }

    func testFormatsMillionsAt1M() async throws {
        let json = #"""
        { "dailyModelTokens": [{ "date": "2026-04-26", "tokensByModel": { "opus": 1000000 } }] }
        """#
        let path = makeTempFile(contents: json)
        let provider = ClaudeUsageProvider(statsPath: path, clock: fixedClock("2026-04-26"))
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "1.0M\ntoday")
    }

    func testFormatsMillionsOneDecimal() async throws {
        let json = #"""
        { "dailyModelTokens": [{ "date": "2026-04-26", "tokensByModel": { "opus": 3450000 } }] }
        """#
        let path = makeTempFile(contents: json)
        let provider = ClaudeUsageProvider(statsPath: path, clock: fixedClock("2026-04-26"))
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "3.5M\ntoday")
    }

    // MARK: - Icon

    func testUsesSparkleIcon() async throws {
        let json = #"""
        { "dailyModelTokens": [{ "date": "2026-04-26", "tokensByModel": { "opus": 1 } }] }
        """#
        let path = makeTempFile(contents: json)
        let provider = ClaudeUsageProvider(statsPath: path, clock: fixedClock("2026-04-26"))
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.icon, "\u{2728}")
    }

    // MARK: - Helpers

    private func makeTempFile(contents: String) -> URL {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("circle-test-\(UUID().uuidString).json")
        try! contents.write(to: path, atomically: true, encoding: .utf8)
        tempFiles.append(path)
        return path
    }

    private func fixedClock(_ ymd: String) -> () -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        let date = formatter.date(from: ymd)!
        return { date }
    }
}
