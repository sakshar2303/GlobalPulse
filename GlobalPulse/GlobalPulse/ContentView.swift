import SwiftUI
import Charts

struct ContentView: View {
    @State private var viewModel = CoinViewModel()

    var body: some View {
        Group {
            if !viewModel.isLoggedIn {
                loginView
            } else {
                TabView {
                    NavigationStack { HomeView() }
                        .tabItem { Label("Home", systemImage: "house.fill") }
                    
                    NavigationStack { MarketView() }
                        .tabItem { Label("Markets", systemImage: "chart.bar.fill") }
                    
                    NavigationStack { PortfolioView() }
                        .tabItem { Label("Portfolio", systemImage: "bag.fill") }
                }
            }
        }
        .environment(viewModel)
        .preferredColorScheme(.dark)
        .task { await viewModel.refreshData() }
    }

    private var loginView: some View {
        VStack(spacing: 30) {
            Image(systemName: "bolt.shield.fill").font(.system(size: 80)).foregroundStyle(.blue.gradient)
            Text("GlobalPulse").font(.largeTitle).bold()
            Button("Launch Terminal") { viewModel.isLoggedIn = true }.buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Trading View (WITH API CHART)
struct TradingView: View {
    let coin: Coin
    @Environment(CoinViewModel.self) private var viewModel
    @State private var amount = ""
    @State private var selectedPeriod = "1"
    @State private var showAlert = false
    @State private var alertMessage = ""
    @Environment(\.dismiss) var dismiss
    
    let periods = [("1", "1D"), ("7", "1W"), ("30", "1M"), ("365", "1Y")]

    var body: some View {
        Form {
            Section {
                VStack {
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(periods, id: \.0) { period in
                            Text(period.1).tag(period.0)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedPeriod) {
                        Task { await viewModel.fetchHistory(for: coin.id, days: selectedPeriod) }
                    }
                    .padding(.bottom, 10)

                    if viewModel.isLoadingChart {
                        ProgressView().frame(height: 180)
                    } else {
                        Chart {
                            ForEach(viewModel.coinHistory, id: \.0) { point in
                                LineMark(
                                    x: .value("Time", point.0),
                                    y: .value("Price", point.1)
                                )
                                .foregroundStyle(coin.isPositive ? .green : .red)
                                
                                AreaMark(
                                    x: .value("Time", point.0),
                                    y: .value("Price", point.1)
                                )
                                .foregroundStyle(LinearGradient(colors: [coin.isPositive ? .green : .red, .clear], startPoint: .top, endPoint: .bottom))
                                .opacity(0.1)
                            }
                        }
                        .frame(height: 180)
                        .chartYScale(domain: .automatic(includesZero: false))
                        .chartXAxis(.hidden)
                    }
                }
            } header: { Text("Market Performance") }

            Section("Execute Trade") {
                TextField("Amount", text: $amount).keyboardType(.decimalPad)
                HStack {
                    Button("Buy") { handleTrade(isBuy: true) }.foregroundStyle(.green).bold()
                    Spacer()
                    Button("Sell") { handleTrade(isBuy: false) }.foregroundStyle(.red).bold()
                }
            }
        }
        .navigationTitle(coin.symbol.uppercased())
        .task { await viewModel.fetchHistory(for: coin.id, days: selectedPeriod) }
        .alert("Confirmed", isPresented: $showAlert) {
            Button("OK") { dismiss() }
        } message: { Text(alertMessage) }
    }
    
    private func handleTrade(isBuy: Bool) {
        if let v = Double(amount) {
            viewModel.trade(coin: coin, amount: isBuy ? v : -v)
            alertMessage = "Successfully \(isBuy ? "bought" : "sold") \(v) \(coin.symbol.uppercased())."
            showAlert = true
        }
    }
}

// MARK: - Market, Portfolio, Home, and Row Views (Simplified for space)

struct MarketView: View {
    @Environment(CoinViewModel.self) private var viewModel
    var body: some View {
        List(viewModel.filteredCoins) { coin in
            NavigationLink(destination: TradingView(coin: coin)) {
                CoinRow(coin: coin, showHoldings: false)
            }
        }.navigationTitle("Markets").searchable(text: Bindable(viewModel).searchText)
    }
}

struct PortfolioView: View {
    @Environment(CoinViewModel.self) private var viewModel
    var body: some View {
        VStack {
            VStack {
                Text("Portfolio Value").font(.caption).bold().foregroundStyle(.secondary)
                Text(viewModel.totalPortfolioValue.formatted(.currency(code: "USD"))).font(.largeTitle).bold()
            }.padding(.vertical)
            List(viewModel.portfolioCoins) { coin in
                NavigationLink(destination: TradingView(coin: coin)) {
                    CoinRow(coin: coin, showHoldings: true)
                }
            }
        }.navigationTitle("Portfolio").id(viewModel.portfolioUpdateID)
    }
}

struct HomeView: View {
    @Environment(CoinViewModel.self) private var viewModel
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Market Sentiment: \(Int(viewModel.marketSentimentScore * 100))%").font(.headline).padding()
                ForEach(viewModel.newsArticles) { article in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(article.title).font(.subheadline).bold()
                            Text(article.source).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: article.imageName).foregroundStyle(.blue)
                    }.padding().background(Color(.secondarySystemBackground)).cornerRadius(12).padding(.horizontal)
                }
            }
        }.navigationTitle("GlobalPulse")
    }
}

struct CoinRow: View {
    let coin: Coin
    let showHoldings: Bool
    var body: some View {
        HStack {
            AsyncImage(url: URL(string: coin.image)) { img in img.resizable().scaledToFit() } placeholder: { Circle().fill(.gray) }.frame(width: 30, height: 30)
            VStack(alignment: .leading) {
                Text(coin.symbol.uppercased()).bold()
                Text(coin.name).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(showHoldings ? coin.currentHoldingsValue.formatted(.currency(code: "USD")) : coin.priceDisplay).bold()
        }
    }
}g
