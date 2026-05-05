import Foundation

struct RemoteEpisodeRecord: Decodable {
    let seasonNumber: Int
    let episodeNumber: Int
    let title: String
    let summary: String?
    let airDate: String?
    let imageURL: String?
    let isAired: Bool?

    enum CodingKeys: String, CodingKey {
        case seasonNumber, episodeNumber, title, summary, isAired
        case airDate = "airDate"
        case imageURL = "imageUrl"
    }
}

struct RemoteSeasonOrderRecord: Decodable {
    let id: String
    let isDefault: Bool
    let label: String
}

struct RemoteSeriesProviderRef: Decodable, Encodable {
    let provider: ShowSource
    let providerSeriesId: String
    let providerURL: String?
    let matchConfidence: String
    let isPrimary: Bool
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case provider, providerSeriesId, matchConfidence, isPrimary, createdAt, updatedAt
        case providerURL = "providerUrl"
    }
}

struct RemoteSeriesRecord: Decodable {
    let id: String
    let title: String
    let originalTitle: String?
    let summary: String?
    let status: String?
    let year: Int?
    let metadataSource: String
    let posterURL: String?
    let backdropURL: String?
    let genres: [String]
    let providerRefs: [RemoteSeriesProviderRef]
    let defaultSeasonOrderId: String?
    let lastEnrichedAt: String?
    let createdAt: String
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, title, originalTitle, summary, status, year, metadataSource, genres, providerRefs, defaultSeasonOrderId, lastEnrichedAt, createdAt, updatedAt
        case posterURL = "posterUrl"
        case backdropURL = "backdropUrl"
    }
}

struct RemoteCatalogRecord: Decodable {
    let series: RemoteSeriesRecord
    let seasonOrders: [RemoteSeasonOrderRecord]
    let episodes: [RemoteEpisodeRecord]
}

struct RemoteRecommendation: Decodable, Identifiable {
    let id: String
    let senderUserId: String
    let recipientUserId: String
    let seriesId: String
    let message: String?
    let status: String
    let createdAt: String
    let updatedAt: String
}

struct RemoteSharedList: Decodable, Identifiable {
    let id: String
    let ownerUserId: String
    let title: String
    let description: String?
    let visibility: String
    let createdAt: String
    let updatedAt: String
}

struct RemoteSharedListMember: Decodable, Identifiable {
    let id: String
    let listId: String
    let userId: String
    let displayName: String?
    let email: String?
    let role: String
    let invitedByUserId: String?
    let createdAt: String
}

struct RemoteSharedListItem: Decodable, Identifiable {
    let id: String
    let listId: String
    let seriesId: String
    let addedByUserId: String
    let note: String?
    let createdAt: String
}

struct RemoteSharedListSummary: Decodable, Identifiable {
    var id: String { list.id }
    let list: RemoteSharedList
    let members: [RemoteSharedListMember]
    let items: [RemoteSharedListItem]
}

struct RemoteSocialUser: Decodable, Identifiable {
    var id: String { userId }
    let userId: String
    let displayName: String?
    let email: String?
    let relationship: String
}

struct SocialSeriesMetadata {
    let title: String
    let imageURL: URL?
}

struct RecommendationsEnvelope: Decodable {
    let recommendations: [RemoteRecommendation]
    let generatedAt: String
}

struct SharedListsEnvelope: Decodable {
    let lists: [RemoteSharedListSummary]
    let generatedAt: String
}

struct SocialUsersEnvelope: Decodable {
    let users: [RemoteSocialUser]
    let generatedAt: String
}

struct RemoteLibraryEntry: Codable {
    let id: String
    let userId: String
    let seriesId: String
    let status: ShowStatus
    let lastWatchedSeason: Int?
    let lastWatchedEpisode: Int?
    let rating: Int?
    let notes: String?
    let startedAt: String?
    let completedAt: String?
    let createdAt: String
    let updatedAt: String
}

struct RemoteLibraryPayload: Codable {
    let appId: String
    let resource: String
    let deviceId: String
    let sentAt: String
    let entries: [RemoteLibraryEntry]
}

struct RemoteAppDataResponse: Decodable {
    let data: RemoteLibraryPayload
    let updatedAt: String
    let revision: Int
    let etag: String
}
