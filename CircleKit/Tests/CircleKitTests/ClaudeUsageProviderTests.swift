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

    // MARK: - No token (Claude Code not signed in)

    func testNoTokenShowsSignInPrompt() async {
        let client = AnthropicUsageClient(
            session: stubSession(),
            tokenProvider: { nil }
        )
        let provider = ClaudeUsageProvider(mode: .today, usageClient: client)
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\nsign in to CC")
    }

    func testEmptyTokenShowsSignInPrompt() async {
        let client = AnthropicUsageClient(
            session: stubSession(),
            tokenProvider: { "" }
        )
        let provider = ClaudeUsageProvider(mode: .today, usageClient: client)
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\nsign in to CC")
    }

    // MARK: - Today (5h session)

    func testTodayShowsSessionPercentage() async {
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
        XCTAssertEqual(provider.cachedData?.text, "Claude\n33% session\n6h left")
    }

    func testWeekShowsWeekPercentage() async {
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

    func testMissingBucketShowsNoData() async {
        MockURLProtocol.responder = { request in
            // No five_hour, only seven_day
            let body = #"{"seven_day":{"utilization":48.0,"resets_at":"2026-04-29T00:00:00+00:00"}}"#
            return (Data(body.utf8), Self.ok(request.url!))
        }
        let client = AnthropicUsageClient(
            session: stubSession(),
            tokenProvider: { "sk-ant-oat01-test" }
        )
        let provider = ClaudeUsageProvider(mode: .today, usageClient: client)
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\nno data")
    }

    func testBucketWithoutResetsAtSkipsCountdown() async {
        MockURLProtocol.responder = { request in
            let body = #"{"five_hour":{"utilization":15.0,"resets_at":null}}"#
            return (Data(body.utf8), Self.ok(request.url!))
        }
        let client = AnthropicUsageClient(
            session: stubSession(),
            tokenProvider: { "sk-ant-oat01-test" }
        )
        let provider = ClaudeUsageProvider(mode: .today, usageClient: client)
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\n15% session")
    }

    // MARK: - Errors

    func test401ShowsSignInPrompt() async {
        MockURLProtocol.responder = { request in
            return (Data("expired".utf8), Self.status(request.url!, 401))
        }
        let client = AnthropicUsageClient(
            session: stubSession(),
            tokenProvider: { "sk-ant-oat01-expired" }
        )
        let provider = ClaudeUsageProvider(mode: .today, usageClient: client)
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\nsign in to CC")
    }

    func testServerErrorShowsOffline() async {
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
