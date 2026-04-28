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
        let usage: AnthropicUsage
        do {
            usage = try await usageClient.fetchUsage()
        } catch AnthropicUsageClient.ClientError.missingToken {
            cachedData = ContentData(icon: "\u{2728}", text: "Claude\nsign in to CC")
            return
        } catch AnthropicUsageClient.ClientError.http(let status, _) where status == 401 {
            cachedData = ContentData(icon: "\u{2728}", text: "Claude\nsign in to CC")
            return
        } catch {
            cachedData = ContentData(icon: "\u{2728}", text: "Claude\noffline")
            return
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
