import Foundation

enum SeriesAVAPIClientError: Error, Equatable {
    case missingBaseURL
    case missingToken
    case requestFailed(statusCode: Int)
}

struct SeriesAVAPIClient: Sendable {
    var baseURL: URL?
    var tokenProvider: @Sendable () async throws -> String?
    var urlSession: URLSession

    init(
        baseURL: URL? = AppConfig.apiBaseURL,
        urlSession: URLSession = .shared,
        tokenProvider: @escaping @Sendable () async throws -> String? = { nil }
    ) {
        self.baseURL = baseURL
        self.urlSession = urlSession
        self.tokenProvider = tokenProvider
    }

    func requestData(
        path: String,
        method: String = "GET",
        body: Data? = nil,
        headers: [String: String] = [:]
    ) async throws -> (Data, String?) {
        guard let baseURL else {
            throw SeriesAVAPIClientError.missingBaseURL
        }
        guard let token = try await tokenProvider(), !token.isEmpty else {
            throw SeriesAVAPIClientError.missingToken
        }

        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.httpBody = body
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SeriesAVAPIClientError.requestFailed(statusCode: -1)
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw SeriesAVAPIClientError.requestFailed(statusCode: httpResponse.statusCode)
        }
        return (data, httpResponse.value(forHTTPHeaderField: "ETag"))
    }
}
