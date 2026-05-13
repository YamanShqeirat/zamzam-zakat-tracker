import Foundation

/// One-time exchange of a SimpleFIN setup token for a permanent access URL.
/// The setup token is a base64-encoded claim URL — POSTing to it returns
/// the access URL in the response body. The exchange can only be performed once.
enum SimpleFINSetup {
    /// Exchange a setup token for a permanent access URL.
    /// Caller is responsible for persisting the returned URL (typically via `KeychainService`).
    static func claimAccessURL(
        setupToken: String,
        session: URLSession = .shared
    ) async throws -> String {
        // 1. Base64-decode the setup token to get the claim URL.
        guard let data = Data(base64Encoded: setupToken),
              let claimURLString = String(data: data, encoding: .utf8),
              let claimURL = URL(string: claimURLString.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw SimpleFINError.invalidURL
        }

        // 2. POST to the claim URL with an empty body.
        var request = URLRequest(url: claimURL)
        request.httpMethod = "POST"
        request.setValue("0", forHTTPHeaderField: "Content-Length")

        let (responseData, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw SimpleFINError.authenticationFailed
        }

        // 3. The response body is the access URL.
        guard let accessURL = String(data: responseData, encoding: .utf8) else {
            throw SimpleFINError.decodingError
        }

        return accessURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
