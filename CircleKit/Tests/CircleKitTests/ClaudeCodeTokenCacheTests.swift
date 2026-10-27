import XCTest
@testable import CircleKit

final class ClaudeCodeTokenCacheTests: XCTestCase {

    private typealias Credential = ClaudeCodeKeychain.Credential

    func testReusesCachedTokenWithoutRereadingKeychain() {
        var reads = 0
        let now = Date(timeIntervalSince1970: 1_000_000)
        let cache = ClaudeCodeTokenCache(clock: { now }, reader: {
            reads += 1
            return .success(Credential(accessToken: "tok", refreshToken: nil, expiresAt: now.addingTimeInterval(3600)))
        })
        XCTAssertEqual(try cache.token().get(), "tok")
        XCTAssertEqual(try cache.token().get(), "tok")
        XCTAssertEqual(reads, 1, "every keychain read is a chance for a macOS prompt — read once")
    }

    func testRereadsAfterTokenExpires() {
        var reads = 0
        var now = Date(timeIntervalSince1970: 1_000_000)
        let expiry = now.addingTimeInterval(3600)
        let cache = ClaudeCodeTokenCache(clock: { now }, reader: {
            reads += 1
            return .success(Credential(accessToken: "tok\(reads)", refreshToken: nil, expiresAt: expiry))
        })
        XCTAssertEqual(try cache.token().get(), "tok1")
        now = expiry
        XCTAssertEqual(try cache.token().get(), "tok2")
        XCTAssertEqual(reads, 2)
    }

    func testKeepsTokenWithoutExpiryUntilInvalidated() {
        var reads = 0
        var now = Date(timeIntervalSince1970: 1_000_000)
        let cache = ClaudeCodeTokenCache(clock: { now }, reader: {
            reads += 1
            return .success(Credential(accessToken: "tok\(reads)", refreshToken: nil, expiresAt: nil))
        })
        XCTAssertEqual(try cache.token().get(), "tok1")
        now = now.addingTimeInterval(7 * 86400)
        XCTAssertEqual(try cache.token().get(), "tok1")
        cache.invalidate()
        XCTAssertEqual(try cache.token().get(), "tok2")
        XCTAssertEqual(reads, 2)
    }

    func testFailuresAreNotCached() {
        var reads = 0
        var result: Result<Credential, ClaudeCodeKeychain.ReadError> = .failure(.accessDenied)
        let cache = ClaudeCodeTokenCache(reader: {
            reads += 1
            return result
        })
        XCTAssertEqual(cache.token(), .failure(.accessDenied))
        result = .success(Credential(accessToken: "tok", refreshToken: nil, expiresAt: nil))
        XCTAssertEqual(cache.token(), .success("tok"))
        XCTAssertEqual(reads, 2)
    }
}
