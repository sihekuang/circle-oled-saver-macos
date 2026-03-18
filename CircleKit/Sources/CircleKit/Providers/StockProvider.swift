import Foundation

public final class StockProvider: BaseContentProvider {
    private let symbols: [String]
    private let refreshSeconds: Int
    private var currentIndex = 0
    private var stockData: [String: StockQuote] = [:]

    public override var refreshInterval: TimeInterval {
        TimeInterval(refreshSeconds)
    }

    public init(symbols: [String] = ["AAPL", "GOOGL", "TSLA"], refreshSeconds: Int = 300) {
        self.symbols = symbols.isEmpty ? ["AAPL", "GOOGL", "TSLA"] : symbols
        self.refreshSeconds = max(refreshSeconds, 5)
        super.init()
        // Show loading immediately so the display isn't blank while waiting for first fetch
        cachedData = ContentData(icon: "📈", text: "Stocks\nLoading...")
    }

    public override func fetchData() async {
        let symbol = symbols[currentIndex]

        // Show loading for this symbol if we don't have data yet
        if stockData[symbol] == nil {
            cachedData = ContentData(icon: "📈", text: "\(symbol)\nLoading...")
        }

        await fetchAllStocks()

        if let data = stockData[symbol] {
            let arrow = data.change >= 0 ? "↑" : "↓"
            let changePercent = String(format: "%.2f", abs(data.changePercent))
            cachedData = ContentData(
                icon: "📈",
                text: "\(symbol) $\(data.price)\n\(arrow) \(changePercent)%"
            )
        }

        currentIndex = (currentIndex + 1) % symbols.count
    }

    private func fetchAllStocks() async {
        for (i, symbol) in symbols.enumerated() {
            await fetchStockQuote(symbol)
            // Delay between requests to avoid rate limiting
            if i < symbols.count - 1 {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    private func fetchStockQuote(_ symbol: String) async {
        guard let url = URL(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(symbol)?interval=1d&range=1d") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(YahooChartResponse.self, from: data)

            if let result = response.chart.result?.first {
                let meta = result.meta
                let price = String(format: "%.2f", meta.regularMarketPrice)
                let previousClose = meta.chartPreviousClose ?? meta.regularMarketPrice
                let change = meta.regularMarketPrice - previousClose
                let changePercent = (change / previousClose) * 100

                stockData[symbol] = StockQuote(
                    price: price,
                    change: change,
                    changePercent: changePercent
                )
            }
        } catch {
            // Keep existing cached data if available
        }
    }
}

// MARK: - Models

private struct StockQuote {
    let price: String
    let change: Double
    let changePercent: Double
}

private struct YahooChartResponse: Decodable {
    let chart: ChartData
}

private struct ChartData: Decodable {
    let result: [ChartResult]?
}

private struct ChartResult: Decodable {
    let meta: ChartMeta
}

private struct ChartMeta: Decodable {
    let regularMarketPrice: Double
    let chartPreviousClose: Double?
}
