import Foundation

public final class ClaudeUsageProvider: BaseContentProvider {
    /// 5 minutes. Usage percentages move slowly; cheaper on the endpoint and
    /// well under any reasonable per-key rate limit.
    public override var refreshInterval: TimeInterval { 300.0 }

    /// Fallback delay when the server rate-limits us without a Retry-After.
    static let defaultRateLimitBackoff: TimeInterval = 30 * 60

    /// Backoff after a 401. Claude Code may refresh its access token shortly
    /// after; no point hammering before that.
    static let authFailureBackoff: TimeInterval = 5 * 60

    /// Backoff after a transient transport / 5xx error.
    static let transientFailureBackoff: TimeInterval = 60

    private let clock: () -> Date
    private let mode: ClaudeUsageMode
    private let usageClient: AnthropicUsageClient

    /// Earliest time we'll attempt another fetch after a failure. nil means
    /// "no backoff active". When set in the future, `fetchData()` keeps the
    /// last known `cachedData` instead of overwriting it.
    private var skipUntil: Date?

    public override convenience init() {
        let settings = SettingsManager.shared
        self.init(
            clock: { Date() },
            mode: settings.claudeUsageMode,
            usageClient: AnthropicUsageClient()
        )
    }

    init(
        clock: @escaping () -> Date = { Date() },
        mode: ClaudeUsageMode = .today,
        usageClient: AnthropicUsageClient = AnthropicUsageClient()
    ) {
        self.clock = clock
        self.mode = mode
        self.usageClient = usageClient
        super.init()
    }

    public override func fetchData() async {
        if let skipUntil, skipUntil > clock() {
            // Inside a backoff window — keep whatever the ball is already showing.
            return
        }

        let usage: AnthropicUsage
        do {
            usage = try await usageClient.fetchUsage()
        } catch AnthropicUsageClient.ClientError.missingToken {
            cachedData = ContentData(icon: "\u{2728}", text: "Claude\nsign in to CC")
            skipUntil = nil
            return
        } catch AnthropicUsageClient.ClientError.http(let status, _) where status == 401 {
            cachedData = ContentData(icon: "\u{2728}", text: "Claude\nsign in to CC")
            skipUntil = clock().addingTimeInterval(Self.authFailureBackoff)
            return
        } catch AnthropicUsageClient.ClientError.rateLimited(let retryAfter) {
            // Keep last-known cachedData visible — don't overwrite with "offline".
            let delay = retryAfter ?? Self.defaultRateLimitBackoff
            skipUntil = clock().addingTimeInterval(delay)
            return
        } catch {
            // Other transport / 5xx / decoding failures. Show "offline" only if
            // we have nothing better to display; otherwise keep the last good
            // reading visible. Either way, back off briefly so we don't burn
            // the next tick.
            if cachedData == nil {
                cachedData = ContentData(icon: "\u{2728}", text: "Claude\noffline")
            }
            skipUntil = clock().addingTimeInterval(Self.transientFailureBackoff)
            return
        }

        // Success — clear backoff and render fresh data.
        skipUntil = nil

        let bucket: AnthropicUsage.Bucket?
        let label: String
        switch mode {
        case .today:
            bucket = usage.fiveHour
            label = "session"
        case .week:
            bucket = usage.sevenDay
            label = "week"
        }

        guard let bucket else {
            cachedData = ContentData(icon: "\u{2728}", text: "Claude\nno data")
            return
        }

        let pct = Int(bucket.utilization.rounded())
        if let resetsAt = bucket.resetsAt {
            let remaining = max(0, resetsAt.timeIntervalSince(clock()))
            cachedData = ContentData(
                icon: "\u{2728}",
                text: "Claude\n\(pct)% \(label)\n\(Self.formatTimeRemaining(seconds: remaining)) left"
            )
        } else {
            cachedData = ContentData(icon: "\u{2728}", text: "Claude\n\(pct)% \(label)")
        }
    }

    /// Compact "Xh Ym" / "Xh" / "Xm" countdown. Ceil to whole minutes so a
    /// few seconds remaining still renders as "1m" instead of "0m".
    public static func formatTimeRemaining(seconds: TimeInterval) -> String {
        let totalMinutes = Int((seconds / 60).rounded(.up))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 && minutes > 0 { return "\(hours)h \(minutes)m" }
        if hours > 0 { return "\(hours)h" }
        return "\(minutes)m"
    }
}
