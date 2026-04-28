import Foundation

/// Captures the subset of settings that affect content provider construction
/// and rotation. Compared in CircleRenderer to decide whether to rebuild the
/// rotator when settings change.
struct ContentSettingsSnapshot: Equatable {
    let clockEnabled: Bool
    let clockFormat24h: Bool
    let systemInfoEnabled: Bool
    let showBattery: Bool
    let stockEnabled: Bool
    let stockSymbols: String
    let stockRefreshSeconds: Int
    let claudeUsageEnabled: Bool
    let claudeUsageMode: ClaudeUsageMode
    let rotationInterval: Int

    init(
        clockEnabled: Bool,
        clockFormat24h: Bool,
        systemInfoEnabled: Bool,
        showBattery: Bool,
        stockEnabled: Bool,
        stockSymbols: String,
        stockRefreshSeconds: Int,
        claudeUsageEnabled: Bool,
        claudeUsageMode: ClaudeUsageMode,
        rotationInterval: Int
    ) {
        self.clockEnabled = clockEnabled
        self.clockFormat24h = clockFormat24h
        self.systemInfoEnabled = systemInfoEnabled
        self.showBattery = showBattery
        self.stockEnabled = stockEnabled
        self.stockSymbols = stockSymbols
        self.stockRefreshSeconds = stockRefreshSeconds
        self.claudeUsageEnabled = claudeUsageEnabled
        self.claudeUsageMode = claudeUsageMode
        self.rotationInterval = rotationInterval
    }

    init(settings: SettingsManager) {
        self.init(
            clockEnabled: settings.clockEnabled,
            clockFormat24h: settings.clockFormat24h,
            systemInfoEnabled: settings.systemInfoEnabled,
            showBattery: settings.showBattery,
            stockEnabled: settings.stockEnabled,
            stockSymbols: settings.stockSymbols,
            stockRefreshSeconds: settings.stockRefreshSeconds,
            claudeUsageEnabled: settings.claudeUsageEnabled,
            claudeUsageMode: settings.claudeUsageMode,
            rotationInterval: settings.contentRotationInterval
        )
    }
}
