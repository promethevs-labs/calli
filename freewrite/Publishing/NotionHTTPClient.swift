import Foundation

protocol NotionHTTPClient {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

/// Construct only at the application boundary when publishing is enabled.
final class URLSessionNotionHTTPClient: NotionHTTPClient {
    private let session: URLSession

    init(session: URLSession) {
        self.session = session
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw NotionPublishError.invalidResponse
        }
        return (data, response)
    }
}
