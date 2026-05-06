import Foundation

enum SeriesAVAPIClientError: LocalizedError {
    case missingToken
    case missingBaseURL
    case requestFailed(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .missingToken:
            "Missing Apps AV account token."
        case .missingBaseURL:
            "Missing Apps AV API base URL."
        case .requestFailed(let statusCode):
            "Apps AV API request failed with status \(statusCode)."
        }
    }
}

@MainActor
final class SeriesAVAPIClient {
    private let getToken: () async throws -> String?
    private let session: URLSession
    private let decoder: JSONDecoder

    init(
        getToken: @escaping () async throws -> String?,
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.getToken = getToken
        self.session = session
        self.decoder = decoder
    }

    func isConfigured() -> Bool {
        AppConfig.avAppsAPIBaseURL != nil
    }

    func request<T: Decodable>(_ path: String, method: String = "GET", body: Data? = nil) async throws -> T {
        let (data, _) = try await requestRaw(path, method: method, body: body)
        return try decoder.decode(T.self, from: data)
    }

    func fetchAccountSummary() async throws -> AccountSummary {
        try await request("v1/me")
    }

    func requestAccountDeletion() async throws -> DeleteAccountRequestResponse {
        try await request("v1/me/delete-account-request", method: "POST")
    }

    func finalizeAccountDeletion() async throws -> DeleteAccountFinalizeResponse {
        try await request("v1/me/delete-account-finalize", method: "POST")
    }

    func unlinkCurrentApp() async throws -> UnlinkAppResponse {
        try await request("v1/apps/seriesav/link", method: "DELETE")
    }

    func requestRaw(
        _ path: String,
        method: String = "GET",
        body: Data? = nil,
        headers: [String: String] = [:],
        allowedStatusCodes: Range<Int> = 200..<300
    ) async throws -> (Data, HTTPURLResponse) {
        guard let token = try await getToken(), !token.isEmpty else {
            throw SeriesAVAPIClientError.missingToken
        }
        guard let baseURL = AppConfig.avAppsAPIBaseURL else {
            throw SeriesAVAPIClientError.missingBaseURL
        }

        let sanitizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let url = baseURL.appending(path: sanitizedPath)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        for (header, value) in headers {
            request.setValue(value, forHTTPHeaderField: header)
        }
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard allowedStatusCodes.contains(httpResponse.statusCode) else {
            throw SeriesAVAPIClientError.requestFailed(statusCode: httpResponse.statusCode)
        }
        return (data, httpResponse)
    }
}
