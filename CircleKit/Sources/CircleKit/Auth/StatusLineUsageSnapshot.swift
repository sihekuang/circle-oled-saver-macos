import Foundation

/// Reads the rate-limit snapshot a Claude Code status line script saves to
/// `~/Library/Application Support/Circle/claude-rate-limits.json`:
/// ```
/// {"captured_at": 1793216243,
///  "rate_limits": {"five_hour": {"used_percentage": 1, "resets_at": 1793229000},
///                  "seven_day": {"used_percentage": 22, "resets_at": 1793707200}}}
/// ```
/// `rate_limits` is Claude Code's documented status line field. The file only
/// updates while Claude Code is in use, so it's the fallback for when the
/// `claude` CLI can't be run or its output can't be read.
public enum StatusLineUsageSnapshot {
    public static var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Circle/claude-rate-limits.json")
    }

    /// Returns nil when the file is missing or unreadable, or when every
    /// window in it has already reset (so its numbers no longer apply).
    public static func read(from url: URL = defaultURL, now: Date = Date()) -> AnthropicUsage? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return parse(data, now: now)
    }

    static func parse(_ data: Data, now: Date) -> AnthropicUsage? {
        struct File: Decodable {
            let rate_limits: Limits?
        }
        struct Limits: Decodable {
            let five_hour: Window?
            let seven_day: Window?
        }
        struct Window: Decodable {
            let used_percentage: Double
            let resets_at: TimeInterval?
        }

        guard let file = try? JSONDecoder().decode(File.self, from: data),
              let limits = file.rate_limits else {
            return nil
        }

        func bucket(_ window: Window?) -> AnthropicUsage.Bucket? {
            guard let window, let resetsAt = window.resets_at else { return nil }
            let date = Date(timeIntervalSince1970: resetsAt)
            guard date > now else { return nil }
            return AnthropicUsage.Bucket(utilization: window.used_percentage, resetsAt: date)
        }

        let usage = AnthropicUsage(fiveHour: bucket(limits.five_hour), sevenDay: bucket(limits.seven_day))
        return usage.isEmpty ? nil : usage
    }
}
