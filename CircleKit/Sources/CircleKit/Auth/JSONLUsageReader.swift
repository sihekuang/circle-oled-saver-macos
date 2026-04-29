import Foundation

/// Aggregates billable tokens from Claude Code's per-session JSONL logs at
/// `~/.claude/projects/**/*.jsonl`. The OAuth `/api/oauth/usage` endpoint only
/// reports a percentage; for an absolute "X.YM tokens" number we read the
/// local logs Claude Code writes anyway.
///
/// "Billable" here = `input_tokens + output_tokens + cache_creation_input_tokens`.
/// `cache_read_input_tokens` is intentionally excluded — those are charged at a
/// discount and including them inflated the displayed numbers (the prior 84%
/// week false reading).
public enum JSONLUsageReader {
    public static var defaultRoot: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects", isDirectory: true)
    }

    /// Sums billable tokens across every `*.jsonl` under `root` whose entries
    /// have `timestamp >= since`. Files whose mtime is older than `since` are
    /// skipped wholesale — they cannot contain entries in the window. Returns
    /// 0 when the root doesn't exist (Claude Code not installed, or fresh
    /// account with no sessions yet).
    public static func tokensSince(
        _ since: Date,
        root: URL = defaultRoot,
        fileManager: FileManager = .default
    ) -> Int {
        guard fileManager.fileExists(atPath: root.path) else { return 0 }
        let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey]
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total = 0
        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl" else { continue }
            let attrs = try? url.resourceValues(forKeys: Set(keys))
            guard attrs?.isRegularFile == true else { continue }
            if let mtime = attrs?.contentModificationDate, mtime < since { continue }
            total += sumFile(url, since: since)
        }
        return total
    }

    static func sumFile(_ url: URL, since: Date) -> Int {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return 0 }
        let decoder = JSONDecoder()
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        let marker = Data("input_tokens".utf8)

        var total = 0
        var lineStart = data.startIndex
        let newline: UInt8 = 0x0A

        func consume(_ slice: Data) {
            guard !slice.isEmpty else { return }
            // Cheap reject — most lines are user messages or tool results with
            // no usage block, and parsing them would dominate runtime.
            guard slice.range(of: marker) != nil else { return }
            guard let entry = try? decoder.decode(Entry.self, from: slice) else { return }
            guard let timestamp = entry.timestamp else { return }
            let date = withFractional.date(from: timestamp) ?? plain.date(from: timestamp)
            guard let date, date >= since else { return }
            guard let usage = entry.message?.usage else { return }
            total += usage.billableTotal
        }

        for i in data.indices {
            if data[i] == newline {
                consume(data.subdata(in: lineStart..<i))
                lineStart = i + 1
            }
        }
        if lineStart < data.endIndex {
            consume(data.subdata(in: lineStart..<data.endIndex))
        }
        return total
    }

    private struct Entry: Decodable {
        let timestamp: String?
        let message: Message?

        struct Message: Decodable {
            let usage: Usage?
        }

        struct Usage: Decodable {
            let inputTokens: Int?
            let outputTokens: Int?
            let cacheCreationInputTokens: Int?

            enum CodingKeys: String, CodingKey {
                case inputTokens = "input_tokens"
                case outputTokens = "output_tokens"
                case cacheCreationInputTokens = "cache_creation_input_tokens"
            }

            var billableTotal: Int {
                (inputTokens ?? 0) + (outputTokens ?? 0) + (cacheCreationInputTokens ?? 0)
            }
        }
    }
}
