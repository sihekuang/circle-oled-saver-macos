import Foundation

/// Process-wide in-memory cache of Claude Code's OAuth access token.
///
/// Every keychain read is an opportunity for macOS to show its "Circle wants
/// to use your confidential information" prompt (e.g. after an app update
/// whose signature no longer matches the item's ACL). The overlay builds a
/// fresh `ClaudeUsageProvider` per OLED display on every show, so without a
/// shared cache each activation re-read the keychain once per display. Here
/// we read once and reuse the token until it expires or the server rejects it.
public final class ClaudeCodeTokenCache {
    public static let shared = ClaudeCodeTokenCache()

    private let clock: () -> Date
    private let reader: () -> Result<ClaudeCodeKeychain.Credential, ClaudeCodeKeychain.ReadError>
    private let lock = NSLock()
    private var cached: ClaudeCodeKeychain.Credential?

    init(
        clock: @escaping () -> Date = { Date() },
        reader: @escaping () -> Result<ClaudeCodeKeychain.Credential, ClaudeCodeKeychain.ReadError> = { ClaudeCodeKeychain.read() }
    ) {
        self.clock = clock
        self.reader = reader
    }

    /// Returns the cached access token, reading the keychain only when there
    /// is no token yet or the cached one has expired. Failures aren't cached —
    /// callers decide whether to try again (see `ClaudeUsageProvider`, which
    /// stops reading entirely after a denial).
    public func token() -> Result<String, ClaudeCodeKeychain.ReadError> {
        lock.lock()
        defer { lock.unlock() }

        if let cached, !cached.isExpired(now: clock()) {
            return .success(cached.accessToken)
        }
        switch reader() {
        case .success(let credential):
            cached = credential
            return .success(credential.accessToken)
        case .failure(let error):
            cached = nil
            return .failure(error)
        }
    }

    /// Drops the cached token, e.g. after a 401, so the next `token()` call
    /// picks up whatever Claude Code has refreshed it to.
    public func invalidate() {
        lock.lock()
        cached = nil
        lock.unlock()
    }
}
