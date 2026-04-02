import Foundation

struct Coin: Codable, Identifiable, Hashable {
    let id: String
    let symbol: String
    let name: String
    let image: String
    let currentPrice: Double
    let marketCapRank: Int
    let priceChangePercentage24h: Double
    let sparklineIn7d: SparklineData?
    var amountHeld: Double?

    enum CodingKeys: String, CodingKey {
        case id, symbol, name, image
        case currentPrice = "current_price"
        case marketCapRank = "market_cap_rank"
        case priceChangePercentage24h = "price_change_percentage_24h"
        case sparklineIn7d = "sparkline_in_7d"
    }
    
    var currentHoldingsValue: Double { (amountHeld ?? 0) * currentPrice }
    var priceDisplay: String { currentPrice.formatted(.currency(code: "USD")) }
    var isPositive: Bool { priceChangePercentage24h >= 0 }
}

struct SparklineData: Codable, Hashable {
    let price: [Double]
}

// New model for historical chart data
struct MarketChartData: Codable {
    let prices: [[Double]] // Format: [Timestamp, Price]
}

struct NewsArticle: Identifiable {
    let id = UUID()
    let title: String
    let source: String
    let timeAgo: String
    let imageName: String
}
