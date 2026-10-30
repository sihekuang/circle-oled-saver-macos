import Foundation

public final class ClaudeUsageProvider: BaseContentProvider {
    /// 5 minutes. Usage percentages move slowly, and each fresh reading runs
    /// the `claude` CLI, which costs a couple of seconds of CPU.
    public static let pollInterval: TimeInterval = 300.0
    public override var refreshInterval: TimeInterval { Self.pollInterval }

    /// Backoff when Claude Code isn't installed or isn't signed in. Gives
    /// the user time to fix it without re-running the CLI every tick.
    static let setupFailureBackoff: TimeInterval = 5 * 60

    /// Backoff after the CLI timed out or couldn't be launched.
    static let transientFailureBackoff: TimeInterval = 60

    private let clock: () -> Date
    private let mode: ClaudeUsageMode
    private let fetchUsage: () async throws -> AnthropicUsage
    /// Reads Claude Code's local JSONL logs to get an absolute token count
    /// for the current window. `/usage` only gives utilization %.
    private let tokensSince: (Date) -> Int

    /// Earliest time we'll attempt another fetch after a failure. nil means
    /// "no backoff active". When set in the future, `fetchData()` keeps the
    /// last known `cachedData` instead of overwriting it.
    private var skipUntil: Date?

    public override convenience init() {
        self.init(
            clock: { Date() },
            mode: SettingsManager.shared.claudeUsageMode,
            fetchUsage: { try await ClaudeCLIUsageClient.shared.fetchUsage() },
            tokensSince: { JSONLUsageReader.tokensSince($0) }
        )
    }

    init(
        clock: @escaping () -> Date = { Date() },
        mode: ClaudeUsageMode = .today,
        fetchUsage: @escaping () async throws -> AnthropicUsage,
        tokensSince: @escaping (Date) -> Int = { _ in 0 }
    ) {
        self.clock = clock
        self.mode = mode
        self.fetchUsage = fetchUsage
        self.tokensSince = tokensSince
        super.init()
    }

    public override func fetchData() async {
        if let skipUntil, skipUntil > clock() {
            // Inside a backoff window — keep whatever the ball is already showing.
            return
        }

        let usage: AnthropicUsage
        do {
            usage = try await fetchUsage()
        } catch ClaudeCLIUsageClient.ClientError.notInstalled {
            cachedData = ContentData(icon: "\u{2728}", text: "Claude\ninstall CC")
            skipUntil = clock().addingTimeInterval(Self.setupFailureBackoff)
            return
        } catch ClaudeCLIUsageClient.ClientError.notSignedIn {
            cachedData = ContentData(icon: "\u{2728}", text: "Claude\nsign in to CC")
            skipUntil = clock().addingTimeInterval(Self.setupFailureBackoff)
            return
        } catch {
            // Timed out or couldn't launch. Show "unavailable" only if we have
            // nothing better to display; otherwise keep the last good reading
            // visible. Either way, back off briefly so we don't burn the next tick.
            if cachedData == nil {
                cachedData = ContentData(icon: "\u{2728}", text: "Claude\nunavailable")
            }
            skipUntil = clock().addingTimeInterval(Self.transientFailureBackoff)
            return
        }

        // Success — clear backoff and render fresh data.
        skipUntil = nil

        let bucket: AnthropicUsage.Bucket?
        let label: String
        let windowDuration: TimeInterval
        switch mode {
        case .today:
            bucket = usage.fiveHour
            label = "session"
            windowDuration = 5 * 3600
        case .week:
            bucket = usage.sevenDay
            label = "week"
            windowDuration = 7 * 86400
        }

        guard let bucket else {
            cachedData = ContentData(icon: "\u{2728}", text: "Claude\nno data")
            return
        }

        let pct = Int(bucket.utilization.rounded())
        var headline = "\(pct)% \(label)"
        // Append "· X.YM" when we can locate the window start (resetsAt minus
        // the window duration) and the local JSONL aggregation finds entries.
        if let resetsAt = bucket.resetsAt {
            let windowStart = resetsAt.addingTimeInterval(-windowDuration)
            let tokens = tokensSince(windowStart)
            if tokens > 0 {
                headline += " \u{00B7} \(Self.formatTokens(tokens)) used"
            }
        }

        if let resetsAt = bucket.resetsAt {
            let remaining = max(0, resetsAt.timeIntervalSince(clock()))
            cachedData = ContentData(
                icon: "\u{2728}",
                text: "Claude\n\(headline)\n\(Self.formatTimeRemaining(seconds: remaining)) left"
            )
        } else {
            cachedData = ContentData(icon: "\u{2728}", text: "Claude\n\(headline)")
        }
    }

    /// Formats a token count in millions. Always shows one decimal place under
    /// 10M (e.g. "1.2M"), drops the decimal at 10M+ to keep the line short.
    public static func formatTokens(_ count: Int) -> String {
        let millions = Double(count) / 1_000_000.0
        if millions >= 10 {
            return "\(Int(millions.rounded()))M"
        }
        return String(format: "%.1fM", millions)
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
