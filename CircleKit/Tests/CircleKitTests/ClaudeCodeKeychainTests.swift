import XCTest
@testable import CircleKit

final class ClaudeCodeKeychainTests: XCTestCase {

    // MARK: - Parsing the JSON blob Claude Code stores

    func testParsesFullClaudeCodeBlob() throws {
        // Real shape — captured from the live keychain entry.
        let json = #"""
        {
          "claudeAiOauth": {
            "accessToken": "sk-ant-oat01-abc",
            "refreshToken": "sk-ant-ort01-def",
            "expiresAt": 1777438748673,
            "scopes": ["user:inference"],
            "subscriptionType": "max",
            "rateLimitTier": "default_claude_max_20x"
          }
        }
        """#
        let result = ClaudeCodeKeychain.parse(Data(json.utf8))
        guard case .success(let cred) = result else {
            return XCTFail("expected success, got \(result)")
        }
        XCTAssertEqual(cred.accessToken, "sk-ant-oat01-abc")
        XCTAssertEqual(cred.refreshToken, "sk-ant-ort01-def")
        // 1777438748673 ms → seconds → Date
        let expiry = try XCTUnwrap(cred.expiresAt)
        XCTAssertEqual(expiry.timeIntervalSince1970, 1777438748.673, accuracy: 0.001)
    }

    func testParsesBlobWithoutOptionalFields() {
        let json = #"""
        { "claudeAiOauth": { "accessToken": "sk-ant-oat01-only" } }
        """#
        let result = ClaudeCodeKeychain.parse(Data(json.utf8))
        guard case .success(let cred) = result else {
            return XCTFail("expected success")
        }
        XCTAssertEqual(cred.accessToken, "sk-ant-oat01-only")
        XCTAssertNil(cred.refreshToken)
        XCTAssertNil(cred.expiresAt)
    }

    func testRejectsBlobMissingClaudeAiOauth() {
        let json = #"{ "something_else": {} }"#
        let result = ClaudeCodeKeychain.parse(Data(json.utf8))
        guard case .failure(let error) = result, case .malformed = error else {
            return XCTFail("expected malformed failure")
        }
    }

    func testRejectsBlobMissingAccessToken() {
        let json = #"{ "claudeAiOauth": { "refreshToken": "..." } }"#
        let result = ClaudeCodeKeychain.parse(Data(json.utf8))
        guard case .failure(let error) = result, case .malformed = error else {
            return XCTFail("expected malformed failure")
        }
    }

    func testRejectsBlobWithEmptyAccessToken() {
        let json = #"{ "claudeAiOauth": { "accessToken": "" } }"#
        let result = ClaudeCodeKeychain.parse(Data(json.utf8))
        guard case .failure(let error) = result, case .malformed = error else {
            return XCTFail("expected malformed failure")
        }
    }

    func testRejectsInvalidJSON() {
        let result = ClaudeCodeKeychain.parse(Data("not json".utf8))
        guard case .failure(let error) = result, case .malformed = error else {
            return XCTFail("expected malformed failure")
        }
    }

    // MARK: - isExpired

    func testIsExpiredFalseWithComfortableMargin() {
        let cred = ClaudeCodeKeychain.Credential(
            accessToken: "x",
            refreshToken: nil,
            expiresAt: Date().addingTimeInterval(3600)
        )
        XCTAssertFalse(cred.isExpired())
    }

    func testIsExpiredTrueAfterExpiry() {
        let cred = ClaudeCodeKeychain.Credential(
            accessToken: "x",
            refreshToken: nil,
            expiresAt: Date().addingTimeInterval(-60)
        )
        XCTAssertTrue(cred.isExpired())
    }

    func testIsExpiredTrueWithinSkewWindow() {
        // 10 seconds away, but we want a 30s skew buffer
        let cred = ClaudeCodeKeychain.Credential(
            accessToken: "x",
            refreshToken: nil,
            expiresAt: Date().addingTimeInterval(10)
        )
        XCTAssertTrue(cred.isExpired(skew: 30))
    }

    func testIsExpiredFalseWhenNoExpiryDate() {
        let cred = ClaudeCodeKeychain.Credential(
            accessToken: "x",
            refreshToken: nil,
            expiresAt: nil
        )
        XCTAssertFalse(cred.isExpired())
    }
}
