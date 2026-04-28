import Foundation
import Security

/// Reads Claude Code's OAuth credential blob from the macOS Keychain.
///
/// Claude Code stores its credentials under service `Claude Code-credentials`
/// as a JSON object shaped like:
/// ```
/// {
///   "claudeAiOauth": {
///     "accessToken":  "sk-ant-oat01-...",
///     "refreshToken": "sk-ant-ort01-...",
///     "expiresAt":    1777438748673,   // ms since epoch
///     "scopes":       ["user:inference", ...]
///   }
/// }
/// ```
///
/// We don't refresh tokens ourselves — Claude Code does it in the background
/// when its CLI runs. We just read whatever access token is current at fetch
/// time. The first read by an unrelated process triggers the standard macOS
/// keychain permission prompt; clicking "Always Allow" makes subsequent reads
/// silent.
public enum ClaudeCodeKeychain {
    public static let service = "Claude Code-credentials"

    public enum ReadError: Error, Equatable {
        /// No keychain entry — Claude Code isn't installed, or the user has
        /// never signed in.
        case notFound
        /// The entry exists but the user denied access to this app.
        case accessDenied
        /// SecItemCopyMatching returned an unexpected status.
        case unexpectedStatus(OSStatus)
        /// The blob exists but isn't UTF-8 / valid JSON / has no access token.
        case malformed(String)
    }

    public struct Credential: Equatable {
        public let accessToken: String
        public let refreshToken: String?
        /// Absolute expiry time. `nil` if Claude Code's blob omits it (rare).
        public let expiresAt: Date?

        public func isExpired(now: Date = Date(), skew: TimeInterval = 30) -> Bool {
            guard let expiresAt else { return false }
            return now.addingTimeInterval(skew) >= expiresAt
        }
    }

    /// Reads and parses the Claude Code credential blob. Returns nil on any
    /// failure, swallowing the specific reason — callers that need diagnostics
    /// should use `read()` instead.
    public static func readAccessToken() -> String? {
        switch read() {
        case .success(let cred): return cred.accessToken
        case .failure: return nil
        }
    }

    /// Reads and parses the credential blob, surfacing a typed error on
    /// failure so the Settings UI can give a useful status message.
    public static func read() -> Result<Credential, ReadError> {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: NSUserName(),
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess: break
        case errSecItemNotFound: return .failure(.notFound)
        case errSecAuthFailed, errSecUserCanceled: return .failure(.accessDenied)
        // -25293 is errSecAuthFailed; -128 is user-cancelled; -25308 is interaction-not-allowed.
        case -25308: return .failure(.accessDenied)
        default: return .failure(.unexpectedStatus(status))
        }

        guard let data = item as? Data else {
            return .failure(.malformed("keychain item was not Data"))
        }
        return parse(data)
    }

    static func parse(_ data: Data) -> Result<Credential, ReadError> {
        struct Outer: Decodable {
            let claudeAiOauth: Inner?
        }
        struct Inner: Decodable {
            let accessToken: String?
            let refreshToken: String?
            let expiresAt: Double?  // milliseconds since epoch
        }

        let decoder = JSONDecoder()
        let outer: Outer
        do {
            outer = try decoder.decode(Outer.self, from: data)
        } catch {
            return .failure(.malformed("invalid JSON: \(error)"))
        }
        guard let inner = outer.claudeAiOauth else {
            return .failure(.malformed("missing claudeAiOauth"))
        }
        guard let access = inner.accessToken, !access.isEmpty else {
            return .failure(.malformed("missing accessToken"))
        }
        let expiresAt = inner.expiresAt.map { Date(timeIntervalSince1970: $0 / 1000.0) }
        return .success(Credential(
            accessToken: access,
            refreshToken: inner.refreshToken,
            expiresAt: expiresAt
        ))
    }
}
