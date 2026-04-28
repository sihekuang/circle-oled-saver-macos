import Foundation

public final class ClaudeUsageProvider: BaseContentProvider {
    public override var refreshInterval: TimeInterval { 30.0 }

    private let projectsDir: URL
    private let clock: () -> Date
    private let mode: ClaudeUsageMode
    private let authMode: ClaudeUsageAuthMode
    private let weeklyGoalTokens: Int
    private let usageClient: AnthropicUsageClient

    public override convenience init() {
        let settings = SettingsManager.shared
        self.init(
            projectsDir: FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".claude/projects"),
            clock: { Date() },
            mode: settings.claudeUsageMode,
            authMode: settings.claudeUsageAuthMode,
            weeklyGoalTokens: settings.claudeUsageWeeklyGoalMTokens * 1_000_000,
            usageClient: AnthropicUsageClient()
        )
    }

    init(
        projectsDir: URL,
        clock: @escaping () -> Date = { Date() },
        mode: ClaudeUsageMode = .today,
        authMode: ClaudeUsageAuthMode = .local,
        weeklyGoalTokens: Int = 0,
        usageClient: AnthropicUsageClient = AnthropicUsageClient()
    ) {
        self.projectsDir = projectsDir
        self.clock = clock
        self.mode = mode
        self.authMode = authMode
        self.weeklyGoalTokens = weeklyGoalTokens
        self.usageClient = usageClient
        super.init()
    }

    public override func fetchData() async {
        switch authMode {
        case .local:
            cachedData = computeLocal()
        case .anthropic:
            cachedData = await computeAnthropic()
        }
    }

    // MARK: - Local mode (CLI activity)

    private func computeLocal() -> ContentData {
        let now = clock()
        let todayPrefix = dateString(for: now)
        let weekPrefixes = Set((0..<7).map {
            dateString(for: now.addingTimeInterval(TimeInterval(-86400 * $0)))
        })

        let totals = aggregate(weekPrefixes: weekPrefixes, todayPrefix: todayPrefix, now: now)

        guard weeklyGoalTokens > 0 else {
            return ContentData(icon: "\u{2728}", text: "Claude\nset goal")
        }

        switch mode {
        case .today:
            let dailyTarget = Double(weeklyGoalTokens) / 7
            let pct = Int((Double(totals.today) / dailyTarget) * 100)
            return ContentData(icon: "\u{2728}", text: "Claude\n\(pct)% today")
        case .week:
            let pct = Int((Double(totals.week) / Double(weeklyGoalTokens)) * 100)
            return ContentData(icon: "\u{2728}", text: "Claude\n\(pct)% week")
        }
    }

    // MARK: - Anthropic mode (subscription quota)

    private func computeAnthropic() async -> ContentData {
        let usage: AnthropicUsage
        do {
            usage = try await usageClient.fetchUsage()
        } catch AnthropicUsageClient.ClientError.missingToken {
            return ContentData(icon: "\u{2728}", text: "Claude\npaste token")
        } catch AnthropicUsageClient.ClientError.http(let status, _) where status == 401 {
            return ContentData(icon: "\u{2728}", text: "Claude\nre-paste token")
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

    // MARK: - Aggregation

    private func aggregate(
        weekPrefixes: Set<String>,
        todayPrefix: String,
        now: Date
    ) -> (today: Int, week: Int) {
        var today = 0
        var week = 0

        guard let projectDirs = try? FileManager.default.contentsOfDirectory(
            at: projectsDir,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else {
            return (0, 0)
        }

        let windowStart = now.addingTimeInterval(-86400 * 7)

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        for projectDir in projectDirs {
            guard (try? projectDir.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: projectDir,
                includingPropertiesForKeys: [.contentModificationDateKey]
            ) else { continue }

            for file in files where file.pathExtension == "jsonl" {
                let mtime = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                if let mtime, mtime < windowStart { continue }

                guard let data = try? Data(contentsOf: file),
                      let content = String(data: data, encoding: .utf8) else { continue }

                for line in content.split(separator: "\n", omittingEmptySubsequences: true) {
                    guard let lineData = line.data(using: .utf8),
                          let entry = try? decoder.decode(JSONLEntry.self, from: lineData),
                          entry.type == "assistant",
                          let timestamp = entry.timestamp,
                          let usage = entry.message?.usage else { continue }

                    let dateOnly = String(timestamp.prefix(10))
                    guard weekPrefixes.contains(dateOnly) else { continue }

                    let total = (usage.inputTokens ?? 0)
                              + (usage.outputTokens ?? 0)
                              + (usage.cacheCreationInputTokens ?? 0)

                    week += total
                    if dateOnly == todayPrefix {
                        today += total
                    }
                }
            }
        }

        return (today, week)
    }

    // MARK: - Formatting

    private func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: date)
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

    // MARK: - Goal suggestion

    public static func suggestWeeklyGoalMTokens(
        projectsDir: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects"),
        clock: @escaping () -> Date = { Date() }
    ) -> Int {
        let now = clock()
        let windowDays = 28
        let windowStart = now.addingTimeInterval(-86400 * Double(windowDays))

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current

        var dateToBucket: [String: Int] = [:]
        for d in 0..<windowDays {
            let day = now.addingTimeInterval(-86400 * Double(d))
            dateToBucket[formatter.string(from: day)] = d / 7
        }

        var buckets = [0, 0, 0, 0]

        guard let projectDirs = try? FileManager.default.contentsOfDirectory(
            at: projectsDir,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else {
            return 100
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        for projectDir in projectDirs {
            guard (try? projectDir.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: projectDir,
                includingPropertiesForKeys: [.contentModificationDateKey]
            ) else { continue }

            for file in files where file.pathExtension == "jsonl" {
                let mtime = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                if let mtime, mtime < windowStart { continue }

                guard let data = try? Data(contentsOf: file),
                      let content = String(data: data, encoding: .utf8) else { continue }

                for line in content.split(separator: "\n", omittingEmptySubsequences: true) {
                    guard let lineData = line.data(using: .utf8),
                          let entry = try? decoder.decode(JSONLEntry.self, from: lineData),
                          entry.type == "assistant",
                          let timestamp = entry.timestamp,
                          let usage = entry.message?.usage else { continue }

                    let dateOnly = String(timestamp.prefix(10))
                    guard let bucket = dateToBucket[dateOnly] else { continue }

                    let active = (usage.inputTokens ?? 0)
                                + (usage.outputTokens ?? 0)
                                + (usage.cacheCreationInputTokens ?? 0)
                    buckets[bucket] += active
                }
            }
        }

        let maxBucket = buckets.max() ?? 0
        let scaled = Double(maxBucket) * 1.2
        let mTokens = Int((scaled / 1_000_000 / 100).rounded(.up)) * 100
        return min(10000, max(100, mTokens))
    }
}

private struct JSONLEntry: Decodable {
    let type: String?
    let timestamp: String?
    let message: Message?

    struct Message: Decodable {
        let usage: Usage?
    }

    struct Usage: Decodable {
        let inputTokens: Int?
        let outputTokens: Int?
        let cacheReadInputTokens: Int?
        let cacheCreationInputTokens: Int?
    }
}
