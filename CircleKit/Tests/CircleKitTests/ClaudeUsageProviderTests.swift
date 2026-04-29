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

    // MARK: - Keychain access gate

    func testWithoutKeychainAccessShowsOpenSettingsAndSkipsKeychain() async {
        var tokenProviderCalled = false
        let client = AnthropicUsageClient(
            session: stubSession(),
            tokenProvider: {
                tokenProviderCalled = true
                return "sk-ant-oat01-test"
            }
        )
        let provider = ClaudeUsageProvider(
            mode: .today,
            usageClient: client,
            hasKeychainAccess: { false }
        )
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\nopen Settings")
        XCTAssertFalse(tokenProviderCalled, "must not read keychain when access not granted")
    }

    func testGrantingAccessAfterGatedFetchUpdatesOnNextTick() async {
        // Until access flips on, ball shows "open Settings". After it flips,
        // the next fetch reads the keychain and renders normally. This is the
        // post-denial recovery path — user clicks Check Connection in
        // Settings, succeeds, flag flips, next provider tick renders.
        var hasAccess = false
        MockURLProtocol.responder = { request in
            let body = #"{"five_hour":{"utilization":42.0,"resets_at":null}}"#
            return (Data(body.utf8), Self.ok(request.url!))
        }
        let client = AnthropicUsageClient(
            session: stubSession(),
            tokenProvider: { "sk-ant-oat01-test" }
        )
        let provider = ClaudeUsageProvider(
            mode: .today,
            usageClient: client,
            hasKeychainAccess: { hasAccess }
        )
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\nopen Settings")

        hasAccess = true
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\n42% session")
    }

    // MARK: - No token (Claude Code not signed in)

    func testNoTokenShowsSignInPrompt() async {
        let client = AnthropicUsageClient(
            session: stubSession(),
            tokenProvider: { nil }
        )
        let provider = ClaudeUsageProvider(
            mode: .today,
            usageClient: client,
            hasKeychainAccess: { true }
        )
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\nsign in to CC")
    }

    func testEmptyTokenShowsSignInPrompt() async {
        let client = AnthropicUsageClient(
            session: stubSession(),
            tokenProvider: { "" }
        )
        let provider = ClaudeUsageProvider(
            mode: .today,
            usageClient: client,
            hasKeychainAccess: { true }
        )
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

    func testServerErrorShowsOfflineWhenNoCachedData() async {
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

    func testServerErrorKeepsLastKnownData() async {
        // First call succeeds, second call 5xx — ball should keep showing the
        // last good reading, not "offline".
        var callCount = 0
        MockURLProtocol.responder = { request in
            callCount += 1
            if callCount == 1 {
                let body = #"{"five_hour":{"utilization":42.0,"resets_at":null}}"#
                return (Data(body.utf8), Self.ok(request.url!))
            }
            return (Data("oops".utf8), Self.status(request.url!, 500))
        }
        let client = AnthropicUsageClient(
            session: stubSession(),
            tokenProvider: { "sk-ant-oat01-test" }
        )
        // Override transient backoff so the second call goes through.
        var now = isoDate("2026-04-28T12:00:00Z")
        let provider = ClaudeUsageProvider(clock: { now }, mode: .today, usageClient: client)
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\n42% session")
        // Advance past the transient backoff window.
        now = now.addingTimeInterval(120)
        await provider.fetchData()
        // Still the previous good data, not "offline".
        XCTAssertEqual(provider.cachedData?.text, "Claude\n42% session")
    }

    // MARK: - Rate limiting (429)

    func testRateLimitedWithoutRetryAfterUsesDefaultBackoff() async {
        var callCount = 0
        MockURLProtocol.responder = { request in
            callCount += 1
            return (Data("rate limited".utf8), Self.status(request.url!, 429))
        }
        let client = AnthropicUsageClient(
            session: stubSession(),
            tokenProvider: { "sk-ant-oat01-test" }
        )
        var now = isoDate("2026-04-28T12:00:00Z")
        let provider = ClaudeUsageProvider(clock: { now }, mode: .today, usageClient: client)
        await provider.fetchData()
        XCTAssertEqual(callCount, 1)
        // Advance 10 minutes — still inside the 30min default backoff.
        now = now.addingTimeInterval(10 * 60)
        await provider.fetchData()
        XCTAssertEqual(callCount, 1, "should NOT have made a second network call")
        // Advance past 30 minutes — backoff cleared, network call resumes.
        now = now.addingTimeInterval(25 * 60)
        await provider.fetchData()
        XCTAssertEqual(callCount, 2)
    }

    func testRateLimitedHonorsRetryAfterHeader() async {
        var callCount = 0
        MockURLProtocol.responder = { request in
            callCount += 1
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 429,
                httpVersion: nil,
                headerFields: ["Retry-After": "60"]
            )!
            return (Data("rate limited".utf8), response)
        }
        let client = AnthropicUsageClient(
            session: stubSession(),
            tokenProvider: { "sk-ant-oat01-test" }
        )
        var now = isoDate("2026-04-28T12:00:00Z")
        let provider = ClaudeUsageProvider(clock: { now }, mode: .today, usageClient: client)
        await provider.fetchData()
        // 30s later — still inside the 60s window the server requested.
        now = now.addingTimeInterval(30)
        await provider.fetchData()
        XCTAssertEqual(callCount, 1)
        // 90s total — past Retry-After, retry happens.
        now = now.addingTimeInterval(60)
        await provider.fetchData()
        XCTAssertEqual(callCount, 2)
    }

    func testRateLimitedKeepsLastKnownData() async {
        var callCount = 0
        MockURLProtocol.responder = { request in
            callCount += 1
            if callCount == 1 {
                let body = #"{"five_hour":{"utilization":42.0,"resets_at":null}}"#
                return (Data(body.utf8), Self.ok(request.url!))
            }
            return (Data("rate limited".utf8), Self.status(request.url!, 429))
        }
        let client = AnthropicUsageClient(
            session: stubSession(),
            tokenProvider: { "sk-ant-oat01-test" }
        )
        var now = isoDate("2026-04-28T12:00:00Z")
        let provider = ClaudeUsageProvider(clock: { now }, mode: .today, usageClient: client)
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\n42% session")
        // Force the 429 by advancing past the *previous* backoff (none yet).
        now = now.addingTimeInterval(31 * 60)
        await provider.fetchData()
        // Last good data preserved, NOT "offline".
        XCTAssertEqual(provider.cachedData?.text, "Claude\n42% session")
    }

    func testSuccessClearsBackoff() async {
        var callCount = 0
        MockURLProtocol.responder = { request in
            callCount += 1
            if callCount == 1 {
                return (Data("rate limited".utf8), Self.status(request.url!, 429))
            }
            let body = #"{"five_hour":{"utilization":12.0,"resets_at":null}}"#
            return (Data(body.utf8), Self.ok(request.url!))
        }
        let client = AnthropicUsageClient(
            session: stubSession(),
            tokenProvider: { "sk-ant-oat01-test" }
        )
        var now = isoDate("2026-04-28T12:00:00Z")
        let provider = ClaudeUsageProvider(clock: { now }, mode: .today, usageClient: client)
        await provider.fetchData()
        // Past the 30min default backoff → call goes through and succeeds.
        now = now.addingTimeInterval(31 * 60)
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\n12% session")
        // Subsequent fetch happens immediately with no backoff.
        await provider.fetchData()
        XCTAssertEqual(callCount, 3)
    }

    // MARK: - Token aggregation (JSONL)

    func testAppendsTokensToTodayDisplayWhenAvailable() async {
        MockURLProtocol.responder = { request in
            let body = #"{"five_hour":{"utilization":33.0,"resets_at":"2026-04-28T18:00:00+00:00"}}"#
            return (Data(body.utf8), Self.ok(request.url!))
        }
        let client = AnthropicUsageClient(
            session: stubSession(),
            tokenProvider: { "sk-ant-oat01-test" }
        )
        let now = isoDate("2026-04-28T12:00:00Z")
        // resets_at 18:00, window = 5h → window start = 13:00.
        var capturedSince: Date?
        let provider = ClaudeUsageProvider(
            clock: { now },
            mode: .today,
            usageClient: client,
            tokensSince: { since in
                capturedSince = since
                return 1_234_567
            }
        )
        await provider.fetchData()
        XCTAssertEqual(capturedSince, isoDate("2026-04-28T13:00:00Z"))
        XCTAssertEqual(provider.cachedData?.text, "Claude\n33% session \u{00B7} 1.2M\n6h left")
    }

    func testAppendsTokensToWeekDisplayWithSevenDayWindow() async {
        MockURLProtocol.responder = { request in
            let body = #"{"seven_day":{"utilization":48.0,"resets_at":"2026-04-30T00:00:00+00:00"}}"#
            return (Data(body.utf8), Self.ok(request.url!))
        }
        let client = AnthropicUsageClient(
            session: stubSession(),
            tokenProvider: { "sk-ant-oat01-test" }
        )
        let now = isoDate("2026-04-29T00:00:00Z")
        var capturedSince: Date?
        let provider = ClaudeUsageProvider(
            clock: { now },
            mode: .week,
            usageClient: client,
            tokensSince: { since in
                capturedSince = since
                return 12_500_000
            }
        )
        await provider.fetchData()
        // resets_at 2026-04-30T00:00, window = 7d → window start = 2026-04-23T00:00.
        XCTAssertEqual(capturedSince, isoDate("2026-04-23T00:00:00Z"))
        XCTAssertEqual(provider.cachedData?.text, "Claude\n48% week \u{00B7} 13M\n24h left")
    }

    func testZeroTokensOmitsTokenSegment() async {
        MockURLProtocol.responder = { request in
            let body = #"{"five_hour":{"utilization":33.0,"resets_at":"2026-04-28T18:00:00+00:00"}}"#
            return (Data(body.utf8), Self.ok(request.url!))
        }
        let client = AnthropicUsageClient(
            session: stubSession(),
            tokenProvider: { "sk-ant-oat01-test" }
        )
        let now = isoDate("2026-04-28T12:00:00Z")
        let provider = ClaudeUsageProvider(
            clock: { now },
            mode: .today,
            usageClient: client,
            tokensSince: { _ in 0 }
        )
        await provider.fetchData()
        XCTAssertEqual(provider.cachedData?.text, "Claude\n33% session\n6h left")
    }

    func testTokensNotAppendedWhenResetsAtMissing() async {
        MockURLProtocol.responder = { request in
            let body = #"{"five_hour":{"utilization":15.0,"resets_at":null}}"#
            return (Data(body.utf8), Self.ok(request.url!))
        }
        let client = AnthropicUsageClient(
            session: stubSession(),
            tokenProvider: { "sk-ant-oat01-test" }
        )
        var called = false
        let provider = ClaudeUsageProvider(
            mode: .today,
            usageClient: client,
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

    // MARK: - Retry-After parsing

    func testRetryAfterParsesIntegerSeconds() {
        XCTAssertEqual(AnthropicUsageClient.parseRetryAfter("120"), 120)
    }

    func testRetryAfterParsesWithWhitespace() {
        XCTAssertEqual(AnthropicUsageClient.parseRetryAfter("  60  "), 60)
    }

    func testRetryAfterClampsNegative() {
        XCTAssertEqual(AnthropicUsageClient.parseRetryAfter("-5"), 0)
    }

    func testRetryAfterReturnsNilForMissing() {
        XCTAssertNil(AnthropicUsageClient.parseRetryAfter(nil))
    }

    func testRetryAfterReturnsNilForHTTPDate() {
        // HTTP-date form not supported; we fall back to default backoff.
        XCTAssertNil(AnthropicUsageClient.parseRetryAfter("Wed, 21 Oct 2026 07:28:00 GMT"))
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
