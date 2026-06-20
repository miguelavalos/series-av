import XCTest
@testable import SeriesAV

final class SeriesHomeStateBuilderTests: XCTestCase {
    func testBuildPromotesFirstHomeEntryAndKeepsSecondaryQueue() {
        let current = entry(id: "current", title: "Current", status: .watching, interactedAt: date(30))
        let next = entry(id: "next", title: "Next", status: .watching, interactedAt: date(20))
        let later = entry(id: "later", title: "Later", status: .wantToWatch, interactedAt: date(10))

        let state = SeriesHomeStateBuilder.build(
            homeEntries: [current, next],
            activeEntries: [current, next, later],
            popularPreviews: [],
            upcomingPreviews: [],
            recommendedPreviews: []
        )

        XCTAssertEqual(state.currentEntry?.entryId, "current")
        XCTAssertEqual(state.secondaryEntries.map(\.entryId), ["next"])
        XCTAssertEqual(state.watchingCount, 2)
        XCTAssertEqual(state.wantToWatchCount, 1)
    }

    func testBuildFiltersDiscoveryPreviewsAlreadyInLibrary() {
        let libraryEntry = entry(id: "series-a", title: "Series A", status: .watching, interactedAt: date(10))
        let duplicatePreview = preview(id: "series-a", title: "Series A")
        let visiblePreview = preview(id: "series-b", title: "Series B")

        let state = SeriesHomeStateBuilder.build(
            homeEntries: [libraryEntry],
            activeEntries: [libraryEntry],
            popularPreviews: [duplicatePreview, visiblePreview],
            upcomingPreviews: [duplicatePreview],
            recommendedPreviews: [visiblePreview]
        )

        XCTAssertEqual(state.visiblePopularPreviews.map(\.id), ["series-b"])
        XCTAssertEqual(state.visibleUpcomingPreviews, [])
        XCTAssertEqual(state.visibleRecommendedPreviews.map(\.id), ["series-b"])
    }

    func testPreviewMetadataUsesYearAndFirstGenre() {
        let preview = preview(id: "series", title: "A Very Long Series Title That Needs Smaller Type", year: 2026, genres: ["Drama", "Comedy"])

        XCTAssertEqual(preview.metadataText, "2026 · Drama")
        XCTAssertEqual(preview.titleFontSize, 12.5)
    }

    private func entry(
        id: String,
        title: String,
        status: SeriesLibraryEntryStatus,
        interactedAt: Date
    ) -> SeriesLibraryEntry {
        SeriesLibraryEntry(
            entryId: id,
            seriesId: id,
            title: title,
            status: status,
            addedAt: interactedAt,
            updatedAt: interactedAt,
            lastInteractedAt: interactedAt
        )
    }

    private func preview(
        id: String,
        title: String,
        year: Int? = 2026,
        genres: [String] = ["Drama"]
    ) -> SeriesHomeDiscoveryPreview {
        SeriesHomeDiscoveryPreview(
            catalogItem: SeriesCatalogItem(
                seriesId: id,
                providerRef: SeriesProviderRef(provider: "tvmaze", providerSeriesId: id, providerUrl: nil, isPrimary: true),
                providerRefs: [SeriesProviderRef(provider: "tvmaze", providerSeriesId: id, providerUrl: nil, isPrimary: true)],
                title: title,
                startYear: year,
                statusText: "Running",
                summary: nil,
                genres: genres,
                displayArtwork: SeriesCatalogItem.DisplayArtwork(
                    kind: "providerPoster",
                    url: nil,
                    assetName: nil,
                    fallbackSeed: title,
                    aspectRatio: nil,
                    policy: SeriesCatalogItem.DisplayArtwork.Policy(
                        displayState: "fallbackOnly",
                        reasonCode: nil,
                        evaluatedAt: date(0)
                    )
                ),
                displayBackdrop: nil,
                episodeGuideState: "available",
                visibility: "public",
                enrichmentStatus: "providerFallback",
                artworkStatus: "none",
                metadataUpdatedAt: date(0)
            )
        )
    }

    private func date(_ offset: TimeInterval) -> Date {
        Date(timeIntervalSince1970: 1_800_000_000 + offset)
    }
}
