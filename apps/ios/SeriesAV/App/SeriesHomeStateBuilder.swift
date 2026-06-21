import CoreGraphics
import Foundation

struct SeriesHomeScreenState: Equatable {
    var currentEntry: SeriesLibraryEntry?
    var secondaryEntries: [SeriesLibraryEntry]
    var readyToStartEntries: [SeriesLibraryEntry]
    var watchingCount: Int
    var wantToWatchCount: Int
    var visiblePopularPreviews: [SeriesHomeDiscoveryPreview]
    var visibleUpcomingPreviews: [SeriesHomeDiscoveryPreview]
    var visibleRecommendedPreviews: [SeriesHomeDiscoveryPreview]
}

enum SeriesHomeStateBuilder {
    static func build(
        homeEntries: [SeriesLibraryEntry],
        activeEntries: [SeriesLibraryEntry],
        popularPreviews: [SeriesHomeDiscoveryPreview],
        upcomingPreviews: [SeriesHomeDiscoveryPreview],
        recommendedPreviews: [SeriesHomeDiscoveryPreview]
    ) -> SeriesHomeScreenState {
        SeriesHomeScreenState(
            currentEntry: homeEntries.first,
            secondaryEntries: Array(homeEntries.dropFirst()),
            readyToStartEntries: readyToStartEntries(
                from: activeEntries,
                excluding: homeEntries,
                limit: 3
            ),
            watchingCount: activeEntries.filter { $0.status == .watching }.count,
            wantToWatchCount: activeEntries.filter { $0.status == .wantToWatch }.count,
            visiblePopularPreviews: visiblePreviews(popularPreviews, excluding: activeEntries),
            visibleUpcomingPreviews: visiblePreviews(upcomingPreviews, excluding: activeEntries),
            visibleRecommendedPreviews: visiblePreviews(recommendedPreviews, excluding: activeEntries)
        )
    }

    static func visiblePreviews(
        _ previews: [SeriesHomeDiscoveryPreview],
        excluding libraryEntries: [SeriesLibraryEntry]
    ) -> [SeriesHomeDiscoveryPreview] {
        previews.filter { preview in
            libraryEntries.contains { SeriesLibraryIdentity.sameSeries($0, preview.catalogItem) } == false
        }
    }

    private static func readyToStartEntries(
        from activeEntries: [SeriesLibraryEntry],
        excluding homeEntries: [SeriesLibraryEntry],
        limit: Int
    ) -> [SeriesLibraryEntry] {
        activeEntries
            .filter { entry in
                entry.status == .wantToWatch && homeEntries.contains { $0.id == entry.id } == false
            }
            .prefix(limit)
            .map { $0 }
    }
}

struct SeriesHomeDiscoveryPreview: Identifiable, Equatable {
    let id: String
    let title: String
    let year: Int?
    let genres: [String]
    let posterURL: URL?
    let catalogItem: SeriesCatalogItem

    init(catalogItem: SeriesCatalogItem) {
        self.id = catalogItem.seriesId
        self.title = catalogItem.title
        self.year = catalogItem.startYear
        self.genres = catalogItem.genres
        self.posterURL = catalogItem.displayArtwork.url
        self.catalogItem = catalogItem
    }

    var metadataText: String {
        let parts = [
            year.map(String.init),
            genres.first
        ].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }

        return parts.joined(separator: " · ")
    }

    var titleFontSize: CGFloat {
        title.count > 30 ? 12.5 : 14
    }
}
