import Foundation

class CoinService {
    func fetchMarketData() async throws -> [Coin] {
        let urlString = "https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=50&page=1&sparkline=true&price_change_percentage=24h"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([Coin].self, from: data)
    }

    func fetchCoinHistory(id: String, days: String) async throws -> [(Date, Double)] {
        let urlString = "https://api.coingecko.com/api/v3/coins/\(id)/market_chart?vs_currency=usd&days=\(days)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let result = try JSONDecoder().decode(MarketChartData.self, from: data)
        
        return result.prices.compactMap { point in
            guard point.count == 2 else { return nil }
            let date = Date(timeIntervalSince1970: point[0] / 1000)
            return (date, point[1])
        }
    }
}
