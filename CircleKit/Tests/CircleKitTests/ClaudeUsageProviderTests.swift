import XCTest
@testable import CircleKit

final class ClaudeUsageProviderTests: XCTestCase {

    override func setUp() {
        super.setUp()
        MockURLProtocol.responder = nil
    }

    override func tearDown() {
        MockURLProtocol.responder = nil
        super.tearDown()
    }

    // MARK: - No stored credential

    func testNoTokenShowsPasteKey() async {
        let client = AnthropicUsageClient(
            session: stubSession(),
            tokenProvider: { nil }
        )
        let provider = ClaudeUsageProvider(mode: .today, usageClient: client)
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\npaste key")
    }

    func testEmptyTokenShowsPasteKey() async {
        let client = AnthropicUsageClient(
            session: stubSession(),
            tokenProvider: { "   " }
        )
        let provider = ClaudeUsageProvider(mode: .today, usageClient: client)
        await provider.fetchData()
        // Trimmed empty → unknown → paste key. Detection trims whitespace.
        XCTAssertEqual(provider.cachedData?.text, "Claude\npaste key")
    }

    // MARK: - OAuth path (utilization %)

    func testOAuthTodayShowsSessionPercentage() async {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.host, "api.anthropic.com")
            XCTAssertEqual(request.url?.path, "/api/oauth/usage")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer sk-ant-oat01-test")
            XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-beta"), "oauth-2025-04-20")
            let body = #"{"five_hour":{"utilization":33.0,"resets_at":"2026-04-28T18:00:00+00:00"},"seven_day":{"utilization":48.0,"resets_at":"2026-04-30T00:00:00+00:00"}}"#
            return (Data(body.utf8), Self.ok(request.url!))
        }
        let client = AnthropicUsageClient(
            session: stubSession(),
            tokenProvider: { "sk-ant-oat01-test" }
        )
        let now = isoDate("2026-04-28T12:00:00Z")
        let provider = ClaudeUsageProvider(clock: { now }, mode: .today, usageClient: client)
        await provider.fetchData()
        // 18:00 - 12:00 = 6h until reset.
        XCTAssertEqual(provider.cachedData?.text, "Claude\n33% session\n6h left")
    }

    func testOAuthWeekShowsWeekPercentage() async {
        MockURLProtocol.responder = { request in
            let body = #"{"seven_day":{"utilization":48.0,"resets_at":"2026-04-28T03:00:00+00:00"}}"#
            return (Data(body.utf8), Self.ok(request.url!))
        }
        let client = AnthropicUsageClient(
            session: stubSession(),
            tokenProvider: { "sk-ant-oat01-test" }
        )
        let now = isoDate("2026-04-28T00:00:00Z")
        let provider = ClaudeUsageProvider(clock: { now }, mode: .week, usageClient: client)
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\n48% week\n3h left")
    }

    func testOAuth401ShowsRePaste() async {
        MockURLProtocol.responder = { request in
            return (Data("expired".utf8), Self.status(request.url!, 401))
        }
        let client = AnthropicUsageClient(
            session: stubSession(),
            tokenProvider: { "sk-ant-oat01-expired" }
        )
        let provider = ClaudeUsageProvider(mode: .today, usageClient: client)
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\nre-paste key")
    }

    func testOAuthServerErrorShowsOffline() async {
        MockURLProtocol.responder = { request in
            return (Data("oops".utf8), Self.status(request.url!, 500))
        }
        let client = AnthropicUsageClient(
            session: stubSession(),
            tokenProvider: { "sk-ant-oat01-test" }
        )
        let provider = ClaudeUsageProvider(mode: .today, usageClient: client)
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\noffline")
    }

    // MARK: - Admin path (USD cost)

    func testAdminTodayShowsDollarCost() async {
        MockURLProtocol.responder = { request in
            XCTAssertEqual(request.url?.host, "api.anthropic.com")
            XCTAssertEqual(request.url?.path, "/v1/organizations/cost_report")
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "sk-ant-admin01-test")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            // amount is in CENTS as a decimal string. 430.00 cents = $4.30
            let body = #"""
            {
              "data": [
                {
                  "starting_at": "2026-04-28T00:00:00Z",
                  "ending_at": "2026-04-29T00:00:00Z",
                  "results": [
                    {"amount": "300.00", "currency": "USD"},
                    {"amount": "130.00", "currency": "USD"}
                  ]
                }
              ],
              "has_more": false,
              "next_page": null
            }
            """#
            return (Data(body.utf8), Self.ok(request.url!))
        }
        let client = AnthropicUsageClient(
            session: stubSession(),
            tokenProvider: { "sk-ant-admin01-test" }
        )
        let now = isoDate("2026-04-28T12:00:00Z")
        let provider = ClaudeUsageProvider(clock: { now }, mode: .today, usageClient: client)
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\n$4.30 today")
    }

    func testAdminWeekSumsAcrossBuckets() async {
        MockURLProtocol.responder = { request in
            // 7 days × 100 cents = 700 cents = $7.00
            let bucket = """
            {"starting_at":"2026-04-22T00:00:00Z","ending_at":"2026-04-23T00:00:00Z","results":[{"amount":"100.00","currency":"USD"}]}
            """
            let body = "{\"data\":[\(Array(repeating: bucket, count: 7).joined(separator: ","))],\"has_more\":false,\"next_page\":null}"
            return (Data(body.utf8), Self.ok(request.url!))
        }
        let client = AnthropicUsageClient(
            session: stubSession(),
            tokenProvider: { "sk-ant-admin01-test" }
        )
        let now = isoDate("2026-04-28T12:00:00Z")
        let provider = ClaudeUsageProvider(clock: { now }, mode: .week, usageClient: client)
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\n$7.00 week")
    }

    func testAdminPaginationFollowsNextPage() async {
        var callCount = 0
        MockURLProtocol.responder = { request in
            callCount += 1
            if callCount == 1 {
                XCTAssertNil(request.url?.query?.contains("page=") == true ? "" : nil)
                let body = #"""
                {
                  "data": [{"starting_at":"2026-04-28T00:00:00Z","ending_at":"2026-04-29T00:00:00Z","results":[{"amount":"500.00","currency":"USD"}]}],
                  "has_more": true,
                  "next_page": "page_two"
                }
                """#
                return (Data(body.utf8), Self.ok(request.url!))
            } else {
                XCTAssertTrue(request.url?.query?.contains("page=page_two") ?? false)
                let body = #"""
                {
                  "data": [{"starting_at":"2026-04-28T00:00:00Z","ending_at":"2026-04-29T00:00:00Z","results":[{"amount":"250.00","currency":"USD"}]}],
                  "has_more": false,
                  "next_page": null
                }
                """#
                return (Data(body.utf8), Self.ok(request.url!))
            }
        }
        let client = AnthropicUsageClient(
            session: stubSession(),
            tokenProvider: { "sk-ant-admin01-test" }
        )
        let now = isoDate("2026-04-28T12:00:00Z")
        let provider = ClaudeUsageProvider(clock: { now }, mode: .today, usageClient: client)
        await provider.fetchData()
        // 500 + 250 = 750 cents = $7.50
        XCTAssertEqual(provider.cachedData?.text, "Claude\n$7.50 today")
        XCTAssertEqual(callCount, 2)
    }

    func testAdmin401ShowsRePaste() async {
        MockURLProtocol.responder = { request in
            (Data("bad".utf8), Self.status(request.url!, 401))
        }
        let client = AnthropicUsageClient(
            session: stubSession(),
            tokenProvider: { "sk-ant-admin01-bad" }
        )
        let provider = ClaudeUsageProvider(mode: .today, usageClient: client)
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\nre-paste key")
    }

    // MARK: - adminWindow

    func testAdminWindowToday() {
        let now = isoDate("2026-04-28T15:30:00Z")
        let (start, end, label) = ClaudeUsageProvider.adminWindow(mode: .today, now: now)
        XCTAssertEqual(label, "today")
        XCTAssertEqual(iso(start), "2026-04-28T00:00:00Z")
        XCTAssertEqual(iso(end), "2026-04-29T00:00:00Z")
    }

    func testAdminWindowWeek() {
        let now = isoDate("2026-04-28T15:30:00Z")
        let (start, end, label) = ClaudeUsageProvider.adminWindow(mode: .week, now: now)
        XCTAssertEqual(label, "week")
        // 6 days back from start of today, end = start of tomorrow → 7-day window
        XCTAssertEqual(iso(start), "2026-04-22T00:00:00Z")
        XCTAssertEqual(iso(end), "2026-04-29T00:00:00Z")
    }

    // MARK: - formatUSD

    func testFormatUSDZero() {
        XCTAssertEqual(ClaudeUsageProvider.formatUSD(0), "$0.00")
    }

    func testFormatUSDSubDollar() {
        XCTAssertEqual(ClaudeUsageProvider.formatUSD(0.42), "$0.42")
    }

    func testFormatUSDTwoDecimals() {
        XCTAssertEqual(ClaudeUsageProvider.formatUSD(4.30), "$4.30")
    }

    func testFormatUSDTriDigit() {
        XCTAssertEqual(ClaudeUsageProvider.formatUSD(123.45), "$123.45")
    }

    func testFormatUSDDropsCentsOver1000() {
        XCTAssertEqual(ClaudeUsageProvider.formatUSD(1234.56), "$1,235")
    }

    // MARK: - Helpers

    private func stubSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    private func isoDate(_ s: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: s)!
    }

    private func iso(_ d: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: d)
    }

    private static func ok(_ url: URL) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
    }

    private static func status(_ url: URL, _ code: Int) -> HTTPURLResponse {
        HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: nil)!
    }
}

// MARK: - URLProtocol stub

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    static var responder: ((URLRequest) -> (Data, HTTPURLResponse))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let responder = MockURLProtocol.responder else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (data, response) = responder(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
