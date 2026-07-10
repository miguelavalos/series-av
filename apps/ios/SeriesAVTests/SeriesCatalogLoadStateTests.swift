import XCTest
@testable import SeriesAV

final class SeriesCatalogLoadStateTests: XCTestCase {
    func testCurrentRequestFinishClearsLoadingState() {
        var state = SeriesCatalogLoadState()

        let token = state.begin()
        state.finish(token)

        XCTAssertFalse(state.isLoading)
        XCTAssertNil(state.activeToken)
    }

    func testStaleRequestFinishDoesNotClearCurrentLoadingState() {
        var state = SeriesCatalogLoadState()

        let staleToken = state.begin()
        let currentToken = state.begin()
        state.finish(staleToken)

        XCTAssertTrue(state.isLoading)
        XCTAssertEqual(state.activeToken, currentToken)

        state.finish(currentToken)

        XCTAssertFalse(state.isLoading)
        XCTAssertNil(state.activeToken)
    }
}

final class SeriesSearchResultsPolicyTests: XCTestCase {
    func testOddCatalogResultCountIsPreservedForDisplay() {
        let results = ["Series A", "Series B", "Series C"]

        let displayedResults = SeriesSearchResultsPolicy.resultsForDisplay(
            results,
            excludingNormalizedTitles: [],
            normalizedTitle: { $0 }
        )

        XCTAssertEqual(displayedResults, results)
    }

    func testCatalogResultAlreadyInLibraryIsExcludedWithoutDroppingOthers() {
        let displayedResults = SeriesSearchResultsPolicy.resultsForDisplay(
            ["series-a", "series-b", "series-c"],
            excludingNormalizedTitles: ["series-b"],
            normalizedTitle: { $0 }
        )

        XCTAssertEqual(displayedResults, ["series-a", "series-c"])
    }
}

final class SeriesSearchSupplementaryMetadataTests: XCTestCase {
    func testBuildsLocalizedStatusGuideSeasonAndEpisodeCount() {
        let text = SeriesSearchSupplementaryMetadata.text(
            statusText: "Running",
            latestKnownEpisodeCursor: SeriesEpisodeCursor(seasonNumber: 2, episodeNumber: 8),
            knownEpisodeCount: 16
        )

        XCTAssertEqual(
            text,
            [
                L10n.string("search.metadata.status.running"),
                String(format: L10n.string("search.metadata.throughSeason"), 2),
                String(format: L10n.string("search.metadata.episodes.other"), 16)
            ].joined(separator: " · ")
        )
    }

    func testUnknownProviderStatusIsNotShownRaw() {
        let text = SeriesSearchSupplementaryMetadata.text(
            statusText: "Unexpected provider value",
            latestKnownEpisodeCursor: SeriesEpisodeCursor(seasonNumber: 1, episodeNumber: 8),
            knownEpisodeCount: 8
        )

        XCTAssertFalse(text?.contains("Unexpected provider value") == true)
        XCTAssertEqual(
            text,
            [
                String(format: L10n.string("search.metadata.throughSeason"), 1),
                String(format: L10n.string("search.metadata.episodes.other"), 8)
            ].joined(separator: " · ")
        )
    }

    func testReturnsNilWhenNoSupplementaryMetadataIsAvailable() {
        XCTAssertNil(
            SeriesSearchSupplementaryMetadata.text(
                statusText: nil,
                latestKnownEpisodeCursor: nil,
                knownEpisodeCount: nil
            )
        )
    }

    func testNormalizesCommonProviderStatuses() {
        XCTAssertEqual(SeriesCatalogAvailabilityStatus(providerText: "Continuing"), .running)
        XCTAssertEqual(SeriesCatalogAvailabilityStatus(providerText: "Ended"), .ended)
        XCTAssertEqual(SeriesCatalogAvailabilityStatus(providerText: "In Development"), .upcoming)
        XCTAssertEqual(SeriesCatalogAvailabilityStatus(providerText: "Canceled"), .cancelled)
        XCTAssertEqual(SeriesCatalogAvailabilityStatus(providerText: "On Hiatus"), .hiatus)
    }
}
