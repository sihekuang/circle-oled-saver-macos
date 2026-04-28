import Foundation

public final class ClaudeUsageProvider: BaseContentProvider {
    public override var refreshInterval: TimeInterval { 30.0 }

    private let clock: () -> Date
    private let mode: ClaudeUsageMode
    private let usageClient: AnthropicUsageClient

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
        switch usageClient.currentTokenType() {
        case .oauth:
            cachedData = await fetchOAuth()
        case .admin:
            cachedData = await fetchAdmin()
        case .unknown:
            cachedData = ContentData(icon: "\u{2728}", text: "Claude\npaste key")
        }
    }

    // MARK: - OAuth (subscription utilization)

    private func fetchOAuth() async -> ContentData {
        let usage: AnthropicUsage
        do {
            usage = try await usageClient.fetchUsage()
        } catch AnthropicUsageClient.ClientError.missingToken {
            return ContentData(icon: "\u{2728}", text: "Claude\npaste key")
        } catch AnthropicUsageClient.ClientError.http(let status, _) where status == 401 {
            return ContentData(icon: "\u{2728}", text: "Claude\nre-paste key")
        } catch {
            return ContentData(icon: "\u{2728}", text: "Claude\noffline")
        }

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
            return ContentData(icon: "\u{2728}", text: "Claude\nno data")
        }

        let pct = Int(bucket.utilization.rounded())
        if let resetsAt = bucket.resetsAt {
            let remaining = max(0, resetsAt.timeIntervalSince(clock()))
            return ContentData(
                icon: "\u{2728}",
                text: "Claude\n\(pct)% \(label)\n\(Self.formatTimeRemaining(seconds: remaining)) left"
            )
        }
        return ContentData(icon: "\u{2728}", text: "Claude\n\(pct)% \(label)")
    }

    // MARK: - Admin (organization cost in USD)

    private func fetchAdmin() async -> ContentData {
        let now = clock()
        let (start, end, label) = Self.adminWindow(mode: mode, now: now)

        let usd: Double
        do {
            usd = try await usageClient.fetchCostUSD(start: start, end: end)
        } catch AnthropicUsageClient.ClientError.missingToken {
            return ContentData(icon: "\u{2728}", text: "Claude\npaste key")
        } catch AnthropicUsageClient.ClientError.http(let status, _) where status == 401 {
            return ContentData(icon: "\u{2728}", text: "Claude\nre-paste key")
        } catch {
            return ContentData(icon: "\u{2728}", text: "Claude\noffline")
        }

        return ContentData(
            icon: "\u{2728}",
            text: "Claude\n\(Self.formatUSD(usd)) \(label)"
        )
    }

    /// Time range and label for an admin cost query in the current mode.
    /// Both bounds are UTC-aligned to whole days because `cost_report` only
    /// supports `bucket_width=1d`.
    public static func adminWindow(mode: ClaudeUsageMode, now: Date) -> (start: Date, end: Date, label: String) {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let startOfToday = utc.startOfDay(for: now)
        let startOfTomorrow = utc.date(byAdding: .day, value: 1, to: startOfToday)!
        switch mode {
        case .today:
            return (startOfToday, startOfTomorrow, "today")
        case .week:
            let start = utc.date(byAdding: .day, value: -6, to: startOfToday)!
            return (start, startOfTomorrow, "week")
        }
    }

    /// Compact USD formatting for the screensaver:
    /// `$0.42` / `$4.30` / `$123.45` (always two decimals up to $999.99).
    /// At/above $1,000 it drops the cents and adds a thousands separator —
    /// `$1,234`. No locale-dependent characters; the screensaver renders a
    /// fixed font.
    public static func formatUSD(_ usd: Double) -> String {
        if usd >= 1000 {
            let whole = Int(usd.rounded())
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.usesGroupingSeparator = true
            formatter.groupingSeparator = ","
            return "$" + (formatter.string(from: NSNumber(value: whole)) ?? "\(whole)")
        }
        return String(format: "$%.2f", usd)
    }

    /// Compact "Xh Ym" / "Xh" / "Xm" countdown. Ceil to whole minutes so a
    /// few seconds remaining still renders as "1m" instead of "0m".
    static func formatTimeRemaining(seconds: TimeInterval) -> String {
        let totalMinutes = Int((seconds / 60).rounded(.up))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 && minutes > 0 { return "\(hours)h \(minutes)m" }
        if hours > 0 { return "\(hours)h" }
        return "\(minutes)m"
    }
}
