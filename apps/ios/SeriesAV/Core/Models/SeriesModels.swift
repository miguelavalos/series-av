import Foundation
import SwiftUI

enum AccessMode: String, Codable {
    case guest
    case signedInFree
    case signedInPro
}

enum PlanTier: String, Codable {
    case free
    case pro
}

struct AccessCapabilities: Codable {
    let isSignedIn: Bool
    let canUseBackend: Bool
    let canUsePremiumFeatures: Bool
    let canUseCloudSync: Bool
    let canManagePlan: Bool

    static func forMode(_ mode: AccessMode) -> AccessCapabilities {
        AccessCapabilities(
            isSignedIn: mode != .guest,
            canUseBackend: mode == .signedInPro,
            canUsePremiumFeatures: mode == .signedInPro,
            canUseCloudSync: mode == .signedInPro,
            canManagePlan: mode != .guest
        )
    }
}

struct AccountUser: Codable, Equatable {
    let id: String
    let displayName: String
    let emailAddress: String?
}

enum ShowStatus: String, Codable, CaseIterable, Identifiable {
    case watching
    case completed
    case paused
    case dropped

    var id: String { rawValue }

    var title: String {
        switch self {
        case .watching: L10n.string("showStatus.watching")
        case .completed: L10n.string("showStatus.completed")
        case .paused: L10n.string("showStatus.paused")
        case .dropped: L10n.string("showStatus.dropped")
        }
    }
}

enum ShowSource: String, Codable {
    case tvmaze
    case thetvdb
}

enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

struct AppSettings: Codable {
    var theme: AppTheme = .system
}

struct CatalogShowSummary: Codable, Identifiable, Hashable {
    var id: String { "\(source.rawValue):\(sourceId)" }
    let source: ShowSource
    let sourceId: String
    let canonicalSeriesId: String?
    let title: String
    let year: Int?
    let imageURL: URL?
    let summary: String?
    let genres: [String]
}

struct EpisodeSnapshot: Codable, Identifiable, Hashable {
    let id: String
    let season: Int
    let episode: Int
    let title: String
    let summary: String?
    let imageURL: URL?
    let airdate: String?
    let isAired: Bool
}

struct UpcomingEpisode: Codable, Hashable {
    let season: Int
    let episode: Int
    let airdate: String?
}

struct ShowSnapshot: Codable, Hashable {
    let source: ShowSource
    let sourceId: String
    let canonicalSeriesId: String?
    let title: String
    let year: Int?
    let imageURL: URL?
    let summary: String?
    let genres: [String]
    let episodeCountBySeason: [String: Int]
    let totalEpisodeCountBySeason: [String: Int]
    let episodesBySeason: [String: [EpisodeSnapshot]]
    let nextEpisode: UpcomingEpisode?
}

struct LibraryShow: Codable, Identifiable, Hashable {
    let id: String
    var snapshot: ShowSnapshot
    var status: ShowStatus
    var lastWatchedSeason: Int?
    var lastWatchedEpisode: Int?
    var startedAt: String?
    var completedAt: String?
    var lastUpdatedAt: String

    var title: String { snapshot.title }
    var imageURL: URL? { snapshot.imageURL }
    var summary: String? { snapshot.summary }
    var year: Int? { snapshot.year }
    var genres: [String] { snapshot.genres }
    var nextEpisode: UpcomingEpisode? { snapshot.nextEpisode }
    var episodesBySeason: [String: [EpisodeSnapshot]] { snapshot.episodesBySeason }
}

enum SeriesBrowseCollection: String, CaseIterable, Identifiable {
    case popular
    case comedy
    case drama
    case scienceFiction = "science-fiction"
    case animation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .popular: L10n.string("browse.popular")
        case .comedy: L10n.string("browse.comedy")
        case .drama: L10n.string("browse.drama")
        case .scienceFiction: L10n.string("browse.scienceFiction")
        case .animation: L10n.string("browse.animation")
        }
    }
}
