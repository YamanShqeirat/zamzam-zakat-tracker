import Foundation

protocol FinancialDataService {
    func fetchAccounts() async throws -> [SimpleFINAccount]
}

struct SimpleFINAccount {
    let id: String
    let name: String
    let balance: Decimal
    let currency: String
    let institutionName: String?
    let balanceDate: Date
}

enum SimpleFINError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case authenticationFailed
    case httpError(Int)
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid SimpleFIN access URL"
        case .invalidResponse: return "Invalid response from SimpleFIN"
        case .authenticationFailed: return "SimpleFIN authentication failed. Reconfigure your access token."
        case .httpError(let code): return "SimpleFIN returned HTTP \(code)"
        case .decodingError: return "Failed to parse SimpleFIN response"
        }
    }
}

final class SimpleFINService: FinancialDataService {
    private let accessURL: String
    private let session: URLSession

    init(accessURL: String, session: URLSession = .shared) {
        self.accessURL = accessURL
        self.session = session
    }

    func fetchAccounts() async throws -> [SimpleFINAccount] {
        // SimpleFIN access URL embeds basic-auth credentials, e.g.
        //   https://user:pass@beta-bridge.simplefin.org/simplefin
        // We split them out into an Authorization header and request the
        // /accounts endpoint with a cleaned URL.
        guard let components = URLComponents(string: accessURL + "/accounts"),
              let user = components.user,
              let pass = components.password else {
            throw SimpleFINError.invalidURL
        }

        var sanitized = components
        sanitized.user = nil
        sanitized.password = nil

        guard let url = sanitized.url else {
            throw SimpleFINError.invalidURL
        }

        let credentials = "\(user):\(pass)"
        let base64 = Data(credentials.utf8).base64EncodedString()

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Basic \(base64)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SimpleFINError.invalidResponse
        }

        if httpResponse.statusCode == 403 {
            throw SimpleFINError.authenticationFailed
        }

        guard httpResponse.statusCode == 200 else {
            throw SimpleFINError.httpError(httpResponse.statusCode)
        }

        let accountSet: SimpleFINAccountSet
        do {
            accountSet = try JSONDecoder().decode(SimpleFINAccountSet.self, from: data)
        } catch {
            throw SimpleFINError.decodingError
        }

        return accountSet.accounts.map { account in
            SimpleFINAccount(
                id: account.id,
                name: account.name,
                balance: Decimal(string: account.balance) ?? 0,
                currency: account.currency,
                institutionName: account.org?.name,
                balanceDate: Date(timeIntervalSince1970: TimeInterval(account.balanceDate))
            )
        }
    }
}

// MARK: - SimpleFIN JSON response models

struct SimpleFINAccountSet: Codable {
    let accounts: [SimpleFINAccountJSON]

    enum CodingKeys: String, CodingKey {
        case accounts
    }
}

struct SimpleFINAccountJSON: Codable {
    let id: String
    let name: String
    let balance: String
    let currency: String
    let balanceDate: Int
    let org: SimpleFINOrg?

    enum CodingKeys: String, CodingKey {
        case id, name, balance, currency
        case balanceDate = "balance-date"
        case org
    }
}

struct SimpleFINOrg: Codable {
    let name: String?
    let url: String?
}
