import Foundation

public final class ClaudeUsageProvider: BaseContentProvider {
    public override var refreshInterval: TimeInterval { 30.0 }

    public override init() {
        super.init()
    }

    public override func fetchData() async {
        guard let stats = readStatsCache() else {
            cachedData = ContentData(icon: "\u{2728}", text: "No data\ntoday")
            return
        }

        let today = todayString()
        let total = stats.dailyModelTokens
            .first { $0.date == today }?
            .tokensByModel
            .values
            .reduce(0, +) ?? 0

        cachedData = ContentData(
            icon: "\u{2728}",
            text: "\(formatTokens(total))\ntoday"
        )
    }

    private func readStatsCache() -> StatsCache? {
        let path = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/stats-cache.json")
        guard let data = try? Data(contentsOf: path) else { return nil }
        return try? JSONDecoder().decode(StatsCache.self, from: data)
    }

    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: Date())
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return "\(count / 1_000)K"
        } else {
            return "\(count)"
        }
    }
}

private struct StatsCache: Decodable {
    let dailyModelTokens: [DailyModelTokens]
}

private struct DailyModelTokens: Decodable {
    let date: String
    let tokensByModel: [String: Int]
}
