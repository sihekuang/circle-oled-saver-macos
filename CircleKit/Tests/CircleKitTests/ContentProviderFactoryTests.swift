import XCTest
@testable import CircleKit

final class ContentProviderFactoryTests: XCTestCase {

    func testEmptyWhenAllToggledOff() {
        let providers = makeContentProviders(
            clockEnabled: false,
            clockFormat24h: false,
            systemInfoEnabled: false,
            showBattery: true,
            stockEnabled: false,
            stockSymbols: "AAPL",
            stockRefreshSeconds: 300,
            claudeUsageEnabled: false
        )
        XCTAssertTrue(providers.isEmpty)
    }

    func testOnlyClock() {
        let providers = makeContentProviders(
            clockEnabled: true,
            clockFormat24h: false,
            systemInfoEnabled: false,
            showBattery: true,
            stockEnabled: false,
            stockSymbols: "",
            stockRefreshSeconds: 300,
            claudeUsageEnabled: false
        )
        XCTAssertEqual(providers.count, 1)
        XCTAssertTrue(providers[0] is ClockProvider)
    }

    func testOnlySystemInfo() {
        let providers = makeContentProviders(
            clockEnabled: false,
            clockFormat24h: false,
            systemInfoEnabled: true,
            showBattery: true,
            stockEnabled: false,
            stockSymbols: "",
            stockRefreshSeconds: 300,
            claudeUsageEnabled: false
        )
        XCTAssertEqual(providers.count, 1)
        XCTAssertTrue(providers[0] is SystemInfoProvider)
    }

    func testOnlyStocks() {
        let providers = makeContentProviders(
            clockEnabled: false,
            clockFormat24h: false,
            systemInfoEnabled: false,
            showBattery: true,
            stockEnabled: true,
            stockSymbols: "AAPL, GOOGL",
            stockRefreshSeconds: 300,
            claudeUsageEnabled: false
        )
        XCTAssertEqual(providers.count, 1)
        XCTAssertTrue(providers[0] is StockProvider)
    }

    func testOnlyClaudeUsage() {
        let providers = makeContentProviders(
            clockEnabled: false,
            clockFormat24h: false,
            systemInfoEnabled: false,
            showBattery: true,
            stockEnabled: false,
            stockSymbols: "",
            stockRefreshSeconds: 300,
            claudeUsageEnabled: true
        )
        XCTAssertEqual(providers.count, 1)
        XCTAssertTrue(providers[0] is ClaudeUsageProvider)
    }

    func testAllEnabled() {
        let providers = makeContentProviders(
            clockEnabled: true,
            clockFormat24h: true,
            systemInfoEnabled: true,
            showBattery: false,
            stockEnabled: true,
            stockSymbols: "AAPL",
            stockRefreshSeconds: 60,
            claudeUsageEnabled: true
        )
        XCTAssertEqual(providers.count, 4)
        XCTAssertTrue(providers.contains { $0 is ClockProvider })
        XCTAssertTrue(providers.contains { $0 is SystemInfoProvider })
        XCTAssertTrue(providers.contains { $0 is StockProvider })
        XCTAssertTrue(providers.contains { $0 is ClaudeUsageProvider })
    }

    func testStockEnabledWithEmptySymbolsStillCreatesProvider() {
        // Stock toggle controls inclusion — symbol parsing is the provider's concern.
        let providers = makeContentProviders(
            clockEnabled: false,
            clockFormat24h: false,
            systemInfoEnabled: false,
            showBattery: false,
            stockEnabled: true,
            stockSymbols: "",
            stockRefreshSeconds: 300,
            claudeUsageEnabled: false
        )
        XCTAssertEqual(providers.count, 1)
        XCTAssertTrue(providers[0] is StockProvider)
    }
}
