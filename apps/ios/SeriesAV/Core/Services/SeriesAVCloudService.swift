import Foundation

@MainActor
final class SeriesAVCloudService {
    private let apiClient: SeriesAVAPIClient
    private let encoder = JSONEncoder()

    init(getToken: @escaping () async throws -> String?) {
        self.apiClient = SeriesAVAPIClient(getToken: getToken)
    }

    func isConfigured() -> Bool {
        apiClient.isConfigured()
    }

    func getRecommendations() async throws -> RecommendationsEnvelope {
        try await apiClient.request("/v1/series/recommendations")
    }

    func getSharedLists() async throws -> SharedListsEnvelope {
        try await apiClient.request("/v1/series/shared-lists")
    }

    func createSharedList(title: String, description: String? = nil) async throws -> RemoteSharedListSummary {
        let body = try encoder.encode(["title": title, "description": description ?? ""])
        return try await apiClient.request("/v1/series/shared-lists", method: "POST", body: body)
    }

    func addSharedListItem(listId: String, seriesId: String, note: String? = nil) async throws -> RemoteSharedListSummary {
        let body = try encoder.encode(["seriesId": seriesId, "note": note ?? ""])
        return try await apiClient.request("/v1/series/shared-lists/\(listId)/items", method: "POST", body: body)
    }

    func removeSharedListItem(listId: String, itemId: String) async throws -> RemoteSharedListSummary {
        try await apiClient.request("/v1/series/shared-lists/\(listId)/items/\(itemId)", method: "DELETE")
    }

    func getSocialUsers(query: String? = nil) async throws -> SocialUsersEnvelope {
        let suffix: String
        if let query, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
            suffix = "?q=\(encoded)"
        } else {
            suffix = ""
        }
        return try await apiClient.request("/v1/series/people\(suffix)")
    }

    func addSharedListMember(listId: String, userId: String, role: String) async throws -> RemoteSharedListSummary {
        let body = try encoder.encode(["userId": userId, "role": role])
        return try await apiClient.request("/v1/series/shared-lists/\(listId)/members", method: "POST", body: body)
    }

    func removeSharedListMember(listId: String, userId: String) async throws -> RemoteSharedListSummary {
        try await apiClient.request("/v1/series/shared-lists/\(listId)/members/\(userId)", method: "DELETE")
    }

    func createRecommendation(recipientUserId: String, seriesId: String, message: String? = nil) async throws -> RemoteRecommendation {
        let body = try encoder.encode(["recipientUserId": recipientUserId, "seriesId": seriesId, "message": message ?? ""])
        return try await apiClient.request("/v1/series/recommendations", method: "POST", body: body)
    }

    func updateRecommendationStatus(recommendationId: String, status: String) async throws -> RemoteRecommendation {
        let body = try encoder.encode(["status": status])
        return try await apiClient.request("/v1/series/recommendations/\(recommendationId)", method: "PATCH", body: body)
    }

    func getCatalogRecord(seriesId: String) async throws -> RemoteCatalogRecord? {
        do {
            return try await apiClient.request("/v1/series/catalog/\(seriesId)")
        } catch SeriesAVAPIClientError.requestFailed(let statusCode) where statusCode == 404 {
            return nil
        }
    }

    func resolveCatalog(query: String, preferredLanguage: String? = nil) async throws -> [RemoteSeriesRecord] {
        struct ResolveRequest: Encodable {
            let query: String
            let preferredProvider: ShowSource
            let preferredLanguage: String?
        }

        let body = try encoder.encode(
            ResolveRequest(
                query: query.trimmingCharacters(in: .whitespacesAndNewlines),
                preferredProvider: .thetvdb,
                preferredLanguage: preferredLanguage
            )
        )
        let response: RemoteCatalogResolveResponse = try await apiClient.request(
            "/v1/series/catalog/resolve",
            method: "POST",
            body: body
        )
        return response.candidates.map(\.series)
    }
}
