import AVExternalLinkFoundation
import XCTest
@testable import SeriesAV

final class SeriesDetailPresentationBuilderTests: XCTestCase {
    func testBuildUsesEntryTitleWhenEntryTitleIsNotProviderId() {
        let entry = libraryEntry(
            id: "entry",
            seriesId: "provider-1",
            title: "Local Title",
            status: .watching
        )
        let catalogItem = catalogItem(id: "provider-1", title: "Catalog Title", year: 2026, genres: ["Drama", "Mystery"])

        let presentation = SeriesDetailPresentationBuilder.build(
            catalogItem: catalogItem,
            resolvedCatalogItem: nil,
            entry: entry,
            searchEngine: .duckDuckGo,
            fallbackTitle: "Fallback"
        )

        XCTAssertEqual(presentation.title, "Local Title")
        XCTAssertEqual(presentation.metadataText, "2026 · Drama · Mystery")
        XCTAssertEqual(presentation.externalSearchQuery, "Local Title 2026")
    }

    func testBuildFallsBackToCatalogTitleWhenEntryTitleIsProviderId() {
        let entry = libraryEntry(
            id: "entry",
            seriesId: "provider-1",
            title: "provider-1",
            status: .wantToWatch
        )
        let catalogItem = catalogItem(id: "provider-1", title: "Catalog Title")

        let presentation = SeriesDetailPresentationBuilder.build(
            catalogItem: nil,
            resolvedCatalogItem: catalogItem,
            entry: entry,
            searchEngine: .google,
            fallbackTitle: "Fallback"
        )

        XCTAssertEqual(presentation.title, "Catalog Title")
    }

    func testExternalSearchQueryDoesNotDuplicateYearAlreadyInTitle() {
        let catalogItem = catalogItem(id: "dororo", title: "Dororo 2019", year: 2019)

        XCTAssertEqual(SeriesDetailPresentationBuilder.externalSearchQuery(title: "Dororo 2019", catalogItem: catalogItem), "Dororo 2019")
        XCTAssertEqual(SeriesDetailPresentationBuilder.externalSearchQuery(title: "Dororo", catalogItem: catalogItem), "Dororo 2019")
    }

    func testSourceLinksPreferEnrichedExternalLinksAndFallbackForWebSearch() {
        let imdbURL = URL(string: "https://www.imdb.com/title/tt123/")!
        let wikipediaURL = URL(string: "https://en.wikipedia.org/wiki/Example")!
        let catalogItem = catalogItem(
            id: "series",
            title: "Example Series",
            externalLinks: [
                SeriesExternalLink(kind: "IMDB", label: "IMDb", url: imdbURL),
                SeriesExternalLink(kind: "wikipedia", label: "Wikipedia", url: wikipediaURL),
            ]
        )

        let links = SeriesDetailPresentationBuilder.sourceLinks(
            catalogItem: catalogItem,
            externalSearchQuery: "Example Series 2026",
            searchEngine: .bing
        )

        XCTAssertEqual(links.map(\.kind), [.imdb, .wikipedia, .web])
        XCTAssertEqual(links[0].url, imdbURL)
        XCTAssertEqual(links[1].url, wikipediaURL)
        XCTAssertEqual(links[2].url.host, "www.bing.com")
        XCTAssertTrue(links[2].url.absoluteString.contains("Example%20Series%202026%20series"))
    }

    func testDetailEntryFillsMissingArtworkFromCatalog() {
        let entry = libraryEntry(
            id: "entry",
            seriesId: "series",
            title: "Entry Title",
            status: .watching,
            displayArtworkRef: nil,
            fallbackVisualSeed: nil
        )
        let catalogItem = catalogItem(
            id: "series",
            title: "Catalog Title",
            artworkURL: URL(string: "https://img.example.com/poster.jpg")
        )

        let detailEntry = SeriesDetailPresentationBuilder.detailEntry(entry: entry, catalogItem: catalogItem)

        XCTAssertEqual(detailEntry?.displayArtworkRef, "https://img.example.com/poster.jpg")
        XCTAssertEqual(detailEntry?.fallbackVisualSeed, "Catalog Title")
    }

    func testTrackingPresentationMatchesStatus() {
        let wantToWatch = libraryEntry(id: "want", seriesId: "want", title: "Want", status: .wantToWatch)
        let watching = libraryEntry(
            id: "watching",
            seriesId: "watching",
            title: "Watching",
            status: .watching,
            lastWatchedEpisodeCursor: SeriesEpisodeCursor(seasonNumber: 2, episodeNumber: 3)
        )

        XCTAssertEqual(SeriesDetailPresentationBuilder.detailStatusIcon(.wantToWatch), "bookmark.fill")
        XCTAssertEqual(SeriesDetailPresentationBuilder.detailStatusIcon(.watching), "play.circle.fill")
        XCTAssertEqual(SeriesDetailPresentationBuilder.detailStatusIcon(.watched), "checkmark.circle.fill")
        XCTAssertEqual(
            SeriesDetailPresentationBuilder.nextActionTitle(for: wantToWatch),
            String(format: L10n.string("home.action.markEpisodeWatched"), "S1 E1")
        )
        XCTAssertEqual(
            SeriesDetailPresentationBuilder.nextActionTitle(for: watching),
            String(format: L10n.string("home.action.markEpisodeWatched"), "S2 E4")
        )
        XCTAssertTrue(SeriesDetailPresentationBuilder.trackingDetail(for: watching).contains("S2 E3"))
        XCTAssertTrue(SeriesDetailPresentationBuilder.trackingDetail(for: watching).contains("S2 E4"))
    }

    private func libraryEntry(
        id: String,
        seriesId: String,
        title: String,
        status: SeriesLibraryEntryStatus,
        lastWatchedEpisodeCursor: SeriesEpisodeCursor? = nil,
        displayArtworkRef: String? = nil,
        fallbackVisualSeed: String? = nil
    ) -> SeriesLibraryEntry {
        SeriesLibraryEntry(
            entryId: id,
            seriesId: seriesId,
            title: title,
            status: status,
            lastWatchedEpisodeCursor: lastWatchedEpisodeCursor,
            displayArtworkRef: displayArtworkRef,
            fallbackVisualSeed: fallbackVisualSeed,
            addedAt: date,
            updatedAt: date,
            lastInteractedAt: date
        )
    }

    private func catalogItem(
        id: String,
        title: String,
        year: Int? = 2026,
        genres: [String] = ["Drama"],
        artworkURL: URL? = nil,
        externalLinks: [SeriesExternalLink]? = nil
    ) -> SeriesCatalogItem {
        SeriesCatalogItem(
            seriesId: id,
            providerRef: SeriesProviderRef(provider: "tvmaze", providerSeriesId: id, providerUrl: nil, isPrimary: true),
            providerRefs: [SeriesProviderRef(provider: "tvmaze", providerSeriesId: id, providerUrl: nil, isPrimary: true)],
            title: title,
            startYear: year,
            statusText: "Running",
            summary: nil,
            genres: genres,
            displayArtwork: SeriesCatalogItem.DisplayArtwork(
                kind: artworkURL == nil ? "fallback" : "providerPoster",
                url: artworkURL,
                assetName: nil,
                fallbackSeed: title,
                aspectRatio: nil,
                policy: SeriesCatalogItem.DisplayArtwork.Policy(
                    displayState: artworkURL == nil ? "fallbackOnly" : "available",
                    reasonCode: nil,
                    evaluatedAt: date
                )
            ),
            displayBackdrop: nil,
            episodeGuideState: "available",
            visibility: "public",
            enrichmentStatus: "providerFallback",
            artworkStatus: artworkURL == nil ? "none" : "available",
            externalLinks: externalLinks,
            metadataUpdatedAt: date
        )
    }

    private var date: Date {
        Date(timeIntervalSince1970: 1_800_000_000)
    }
}
