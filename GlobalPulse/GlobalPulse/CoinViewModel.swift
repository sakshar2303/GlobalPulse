import Foundation
import SwiftUI
import Observation
import NaturalLanguage

@Observable
class CoinViewModel {
    var coins: [Coin] = []
    var coinHistory: [(Date, Double)] = [] // Stores graph points
    var isLoadingChart = false
    var searchText: String = ""
    var isLoggedIn = false
    var marketSentimentScore: Double = 0.0
    var portfolioUpdateID = UUID()
    
    var newsArticles: [NewsArticle] = [
        NewsArticle(title: "Institutional investors are pouring billions into Bitcoin ETFs.", source: "CryptoDaily", timeAgo: "5m ago", imageName: "chart.line.uptrend.xyaxis"),
        NewsArticle(title: "New security concerns arise over decentralized exchange vulnerabilities.", source: "Block Insider", timeAgo: "1h ago", imageName: "lock.shield"),
        NewsArticle(title: "Ethereum reaches new milestone in network scalability.", source: "TechPulse", timeAgo: "2h ago", imageName: "bolt.fill")
    ]
    
    private let service = CoinService()
    private let portfolioKey = "global_pulse_portfolio"

    var totalPortfolioValue: Double {
        coins.reduce(0) { $0 + $1.currentHoldingsValue }
    }
    
    var portfolioCoins: [Coin] {
        coins.filter { ($0.amountHeld ?? 0) > 0 }
    }
    
    var filteredCoins: [Coin] {
        searchText.isEmpty ? coins : coins.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.symbol.localizedCaseInsensitiveContains(searchText)
        }
    }

    @MainActor
    func fetchHistory(for coinId: String, days: String) async {
        isLoadingChart = true
        do {
            coinHistory = try await service.fetchCoinHistory(id: coinId, days: days)
        } catch {
            print("Chart error: \(error)")
        }
        isLoadingChart = false
    }

    func trade(coin: Coin, amount: Double) {
        var saved = UserDefaults.standard.dictionary(forKey: portfolioKey) as? [String: Double] ?? [:]
        let currentAmount = saved[coin.id] ?? 0
        let newAmount = max(0, currentAmount + amount)
        saved[coin.id] = newAmount
        UserDefaults.standard.set(saved, forKey: portfolioKey)
        
        if let index = self.coins.firstIndex(where: { $0.id == coin.id }) {
            self.coins[index].amountHeld = newAmount
            self.portfolioUpdateID = UUID()
        }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    @MainActor
    func refreshData() async {
        do {
            let fetched = try await service.fetchMarketData()
            let saved = UserDefaults.standard.dictionary(forKey: portfolioKey) as? [String: Double] ?? [:]
            self.coins = fetched.map {
                var c = $0
                c.amountHeld = saved[$0.id]
                return c
            }
            analyzeMarketSentiment()
        } catch {
            print("Fetch error: \(error)")
        }
    }

    func analyzeMarketSentiment() {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        var totalScore: Double = 0
        for article in newsArticles {
            tagger.string = article.title
            let (sentiment, _) = tagger.tag(at: article.title.startIndex, unit: .paragraph, scheme: .sentimentScore)
            if let score = Double(sentiment?.rawValue ?? "0") { totalScore += score }
        }
        self.marketSentimentScore = ((totalScore / Double(max(1, newsArticles.count))) + 1.0) / 2.0
    }
}
