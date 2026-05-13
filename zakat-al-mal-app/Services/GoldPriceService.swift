import Foundation

protocol GoldPriceService {
    func fetchGoldPricePerGram() async throws -> Decimal
    func fetchSilverPricePerGram() async throws -> Decimal
}

enum GoldPriceError: Error {
    case invalidURL
    case invalidResponse
    case apiError(String)
}

struct GoldAPIResponse: Codable {
    let price: Decimal
    let timestamp: Int

    enum CodingKeys: String, CodingKey {
        case price
        case timestamp
    }
}

final class GoldAPIService: GoldPriceService {
    private let apiKey: String
    private let session: URLSession

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func fetchGoldPricePerGram() async throws -> Decimal {
        try await fetchPricePerGram(symbol: "XAU")
    }

    func fetchSilverPricePerGram() async throws -> Decimal {
        try await fetchPricePerGram(symbol: "XAG")
    }

    private func fetchPricePerGram(symbol: String) async throws -> Decimal {
        guard let url = URL(string: "https://www.goldapi.io/api/\(symbol)/USD") else {
            throw GoldPriceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-access-token")

        let (data, response) = try await session.data(for: request)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw GoldPriceError.apiError("HTTP \(http.statusCode)")
        }

        let decoded = try JSONDecoder().decode(GoldAPIResponse.self, from: data)
        // GoldAPI returns price per troy ounce. 1 troy ounce = 31.1035 grams.
        return decoded.price / Decimal(31.1035)
    }
}

/// Fallback: if the primary service is unreachable, surface the most-recent
/// price instead of throwing. Tracks staleness per-metal so callers can
/// flag the UI when they're showing a cached value.
final class CachedGoldPriceService: GoldPriceService {
    private let primaryService: GoldPriceService
    private(set) var cachedGoldPrice: Decimal?
    private(set) var goldCacheDate: Date?
    private(set) var lastGoldFetchWasStale: Bool = false
    private(set) var cachedSilverPrice: Decimal?
    private(set) var silverCacheDate: Date?
    private(set) var lastSilverFetchWasStale: Bool = false

    init(primaryService: GoldPriceService) {
        self.primaryService = primaryService
    }

    func fetchGoldPricePerGram() async throws -> Decimal {
        do {
            let price = try await primaryService.fetchGoldPricePerGram()
            cachedGoldPrice = price
            goldCacheDate = Date()
            lastGoldFetchWasStale = false
            return price
        } catch {
            if let cached = cachedGoldPrice {
                lastGoldFetchWasStale = true
                return cached
            }
            throw error
        }
    }

    func fetchSilverPricePerGram() async throws -> Decimal {
        do {
            let price = try await primaryService.fetchSilverPricePerGram()
            cachedSilverPrice = price
            silverCacheDate = Date()
            lastSilverFetchWasStale = false
            return price
        } catch {
            if let cached = cachedSilverPrice {
                lastSilverFetchWasStale = true
                return cached
            }
            throw error
        }
    }
}
