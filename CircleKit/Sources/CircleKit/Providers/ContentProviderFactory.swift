import Foundation

func makeContentProviders(
    clockEnabled: Bool,
    clockFormat24h: Bool,
    systemInfoEnabled: Bool,
    showBattery: Bool,
    stockEnabled: Bool,
    stockSymbols: String,
    stockRefreshSeconds: Int,
    claudeUsageEnabled: Bool
) -> [ContentProvider] {
    var providers: [ContentProvider] = []
    if clockEnabled {
        providers.append(ClockProvider(use24Hour: clockFormat24h))
    }
    if systemInfoEnabled {
        providers.append(SystemInfoProvider(showBattery: showBattery))
    }
    if stockEnabled {
        let symbols = stockSymbols
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        providers.append(StockProvider(
            symbols: symbols,
            refreshSeconds: stockRefreshSeconds
        ))
    }
    if claudeUsageEnabled {
        providers.append(ClaudeUsageProvider())
    }
    return providers
}
