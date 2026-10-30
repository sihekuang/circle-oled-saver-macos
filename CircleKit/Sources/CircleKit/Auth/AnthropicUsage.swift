import Foundation

/// A snapshot of the user's Claude subscription quota: how much of each
/// rate-limit window is used and when it resets. Produced by
/// `ClaudeCLIUsageParser` (from `claude -p /usage`) or by
/// `StatusLineUsageSnapshot` (from the status line file).
public struct AnthropicUsage: Equatable {
    public let fiveHour: Bucket?
    public let sevenDay: Bucket?
    public let sevenDaySonnet: Bucket?

    public struct Bucket: Equatable {
        /// Percent of the window used, 0–100.
        public let utilization: Double
        public let resetsAt: Date?

        public init(utilization: Double, resetsAt: Date?) {
            self.utilization = utilization
            self.resetsAt = resetsAt
        }
    }

    public init(fiveHour: Bucket?, sevenDay: Bucket?, sevenDaySonnet: Bucket? = nil) {
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
        self.sevenDaySonnet = sevenDaySonnet
    }

    var isEmpty: Bool { fiveHour == nil && sevenDay == nil && sevenDaySonnet == nil }
}
