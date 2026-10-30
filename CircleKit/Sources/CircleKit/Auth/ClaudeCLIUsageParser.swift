import Foundation

/// Parses the text that `claude -p /usage` prints, e.g.
/// ```
/// Current session: 6% used · resets Oct 30 at 12:29am (America/Los_Angeles)
/// Current week (all models): 35% used · resets Nov 3 at 3:59am (America/Los_Angeles)
/// Current week (Sonnet only): 0% used · resets Nov 3 at 4am (America/Los_Angeles)
/// ```
/// This is human-readable output, not a documented format, so parsing is
/// deliberately forgiving: a line whose reset time can't be read still yields
/// its percentage, and an unrecognized reset phrase just leaves `resetsAt` nil.
public enum ClaudeCLIUsageParser {
    /// Returns nil when the output has none of the usage lines, which is what
    /// Claude Code prints when it isn't signed in with a subscription.
    public static func parse(_ output: String, now: Date = Date()) -> AnthropicUsage? {
        var fiveHour: AnthropicUsage.Bucket?
        var sevenDay: AnthropicUsage.Bucket?
        var sevenDaySonnet: AnthropicUsage.Bucket?

        for rawLine in output.split(whereSeparator: \.isNewline) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard let colon = line.firstIndex(of: ":") else { continue }
            let label = line[..<colon]
            let rest = line[line.index(after: colon)...]
            switch label {
            case "Current session":
                fiveHour = bucket(from: rest, now: now)
            case "Current week (all models)":
                sevenDay = bucket(from: rest, now: now)
            case "Current week (Sonnet only)":
                sevenDaySonnet = bucket(from: rest, now: now)
            default:
                continue
            }
        }

        let usage = AnthropicUsage(fiveHour: fiveHour, sevenDay: sevenDay, sevenDaySonnet: sevenDaySonnet)
        return usage.isEmpty ? nil : usage
    }

    /// Parses `" 6% used · resets Oct 30 at 12:29am (America/Los_Angeles)"`.
    static func bucket(from text: Substring, now: Date) -> AnthropicUsage.Bucket? {
        let pattern = #"^\s*(\d+(?:\.\d+)?)%\s+used(?:.*?\bresets\s+(.+))?$"#
        guard let match = firstMatch(pattern, in: String(text)),
              let percent = Double(match[1] ?? "") else {
            return nil
        }
        let resetsAt = match[2].flatMap { parseResetTime($0, now: now) }
        return AnthropicUsage.Bucket(utilization: percent, resetsAt: resetsAt)
    }

    private static let months = ["jan", "feb", "mar", "apr", "may", "jun",
                                 "jul", "aug", "sep", "oct", "nov", "dec"]

    /// Understands "Oct 30 at 12:29am", "Nov 3 at 4am", "4pm" (next
    /// occurrence) and "in 2h 5m", each optionally followed by an IANA time
    /// zone in parentheses.
    static func parseResetTime(_ text: String, now: Date) -> Date? {
        var phrase = text.trimmingCharacters(in: .whitespaces)
        var timeZone = TimeZone.current
        if let tzMatch = firstMatch(#"^(.*?)\s*\(([^)]+)\)\s*$"#, in: phrase) {
            phrase = tzMatch[1] ?? phrase
            if let name = tzMatch[2], let zone = TimeZone(identifier: name) {
                timeZone = zone
            }
        }

        if let relative = firstMatch(#"^in\s+(?:(\d+)d\s*)?(?:(\d+)h\s*)?(?:(\d+)m)?$"#, in: phrase) {
            let days = Double(relative[1] ?? "") ?? 0
            let hours = Double(relative[2] ?? "") ?? 0
            let minutes = Double(relative[3] ?? "") ?? 0
            let seconds = ((days * 24 + hours) * 60 + minutes) * 60
            return seconds > 0 ? now.addingTimeInterval(seconds) : nil
        }

        let absolute = #"^(?:([A-Za-z]{3})[a-z]*\.?\s+(\d{1,2})(?:,\s*\d{4})?\s+at\s+)?(\d{1,2})(?::(\d{2}))?\s*([ap]m)$"#
        guard let m = firstMatch(absolute, in: phrase.lowercased()),
              var hour = Int(m[3] ?? ""), (1...12).contains(hour) else {
            return nil
        }
        let minute = Int(m[4] ?? "") ?? 0
        if m[5] == "pm", hour != 12 { hour += 12 }
        if m[5] == "am", hour == 12 { hour = 0 }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        components.second = 0

        if let monthName = m[1] {
            guard let monthIndex = months.firstIndex(of: monthName),
                  let day = Int(m[2] ?? "") else {
                return nil
            }
            components.month = monthIndex + 1
            components.day = day
            // No year in the output: a date well in the past means it's next
            // year's (e.g. "Jan 2" seen on Dec 30).
            guard let date = calendar.date(from: components) else { return nil }
            if date < now.addingTimeInterval(-86400) {
                return calendar.date(byAdding: .year, value: 1, to: date)
            }
            return date
        }

        // Time only: the next time the clock reads that.
        guard let date = calendar.date(from: components) else { return nil }
        return date < now ? calendar.date(byAdding: .day, value: 1, to: date) : date
    }

    /// Capture groups of the first match, index 0 being the whole match.
    /// Groups that didn't participate are nil.
    private static func firstMatch(_ pattern: String, in text: String) -> [String?]? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }
        return (0..<match.numberOfRanges).map { i in
            Range(match.range(at: i), in: text).map { String(text[$0]) }
        }
    }
}
