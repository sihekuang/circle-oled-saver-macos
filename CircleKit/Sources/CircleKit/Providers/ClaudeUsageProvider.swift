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

    /// Earliest time we'll attempt another fetch after a failure. nil means
    /// "no backoff active". When set in the future, `fetchData()` keeps the
    /// last known `cachedData` instead of overwriting it.
    private var skipUntil: Date?

    public override convenience init() {
        self.init(
            clock: { Date() },
            mode: SettingsManager.shared.claudeUsageMode,
            fetchUsage: { try await ClaudeCLIUsageClient.shared.fetchUsage() }
        )
    }

    init(
        clock: @escaping () -> Date = { Date() },
        mode: ClaudeUsageMode = .today,
        fetchUsage: @escaping () async throws -> AnthropicUsage
    ) {
        self.clock = clock
        self.mode = mode
        self.fetchUsage = fetchUsage
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
        switch (mode, usage.fiveHour) {
        case (.today, let session?):
            bucket = session
            label = "session"
        default:
            // Week mode, or a plan with no 5-hour limit (`/usage` then prints
            // only the week lines) — show the weekly figure.
            bucket = usage.sevenDay
            label = "week"
        }

        guard let bucket else {
            cachedData = ContentData(icon: "\u{2728}", text: "Claude\nno data")
            return
        }

        let pct = Int(bucket.utilization.rounded())
        let headline = "\(pct)% \(label)"

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
