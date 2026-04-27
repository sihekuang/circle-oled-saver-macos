import Foundation

public final class ClaudeUsageProvider: BaseContentProvider {
    public override var refreshInterval: TimeInterval { 30.0 }

    private let projectsDir: URL
    private let clock: () -> Date
    private let mode: ClaudeUsageMode
    private let weeklyGoalTokens: Int

    public override convenience init() {
        let settings = SettingsManager.shared
        self.init(
            projectsDir: FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".claude/projects"),
            clock: { Date() },
            mode: settings.claudeUsageMode,
            weeklyGoalTokens: settings.claudeUsageWeeklyGoalMTokens * 1_000_000
        )
    }

    init(
        projectsDir: URL,
        clock: @escaping () -> Date = { Date() },
        mode: ClaudeUsageMode = .today,
        weeklyGoalTokens: Int = 0
    ) {
        self.projectsDir = projectsDir
        self.clock = clock
        self.mode = mode
        self.weeklyGoalTokens = weeklyGoalTokens
        super.init()
    }

    public override func fetchData() async {
        let now = clock()
        let todayPrefix = dateString(for: now)
        let weekPrefixes = Set((0..<7).map {
            dateString(for: now.addingTimeInterval(TimeInterval(-86400 * $0)))
        })

        let totals = aggregate(weekPrefixes: weekPrefixes, todayPrefix: todayPrefix, now: now)

        guard weeklyGoalTokens > 0 else {
            cachedData = ContentData(icon: "\u{2728}", text: "Set goal\nin Settings")
            return
        }

        switch mode {
        case .today:
            // Today's tokens vs the daily share of the weekly goal.
            let dailyTarget = Double(weeklyGoalTokens) / 7
            let pct = Int((Double(totals.today) / dailyTarget) * 100)
            cachedData = ContentData(icon: "\u{2728}", text: "\(pct)%\ntoday")
        case .week:
            let pct = Int((Double(totals.week) / Double(weeklyGoalTokens)) * 100)
            cachedData = ContentData(icon: "\u{2728}", text: "\(pct)%\nweek")
        }
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

        // Skip files modified before the start of the 7-day window — they can't
        // contain entries for any of the dates we care about.
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

                    // Active token usage: what the user actually generated this
                    // session. Cache reads are excluded — they're background
                    // re-reads of the cached system prompt on every turn and
                    // would dwarf the real usage signal.
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
