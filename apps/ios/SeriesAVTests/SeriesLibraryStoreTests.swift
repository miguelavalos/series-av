import XCTest
@testable import SeriesAV

final class SeriesLibraryStoreTests: XCTestCase {
    func testMarkWatchedThroughMovesSingleProgressCursorForwardAndBackward() {
        let initialDate = Date(timeIntervalSince1970: 1_800_000_000)
        let updatedDate = Date(timeIntervalSince1970: 1_800_000_100)
        let store = SeriesLibraryStore(entries: [
            SeriesLibraryEntry(
                entryId: "entry-1",
                seriesId: "series-1",
                title: "Example Series",
                status: .watching,
                lastWatchedEpisodeCursor: SeriesEpisodeCursor(seasonNumber: 1, episodeNumber: 2),
                addedAt: initialDate,
                updatedAt: initialDate,
                lastInteractedAt: initialDate
            )
        ])

        store.markWatchedThrough(
            SeriesEpisodeCursor(seasonNumber: 1, episodeNumber: 10),
            for: "entry-1",
            at: updatedDate
        )
        XCTAssertEqual(store.entries[0].lastWatchedEpisodeCursor, SeriesEpisodeCursor(seasonNumber: 1, episodeNumber: 10))

        store.markWatchedThrough(
            SeriesEpisodeCursor(seasonNumber: 1, episodeNumber: 5),
            for: "entry-1",
            at: updatedDate
        )
        XCTAssertEqual(store.entries[0].lastWatchedEpisodeCursor, SeriesEpisodeCursor(seasonNumber: 1, episodeNumber: 5))
    }

    func testMarkNextStartsWantToWatchAtFirstEpisode() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let store = SeriesLibraryStore(entries: [
            SeriesLibraryEntry(
                entryId: "entry",
                seriesId: "entry",
                title: "Ready",
                status: .wantToWatch,
                addedAt: date,
                updatedAt: date,
                lastInteractedAt: date
            )
        ])

        store.markNextEpisodeWatched(for: "entry", at: date.addingTimeInterval(10))

        XCTAssertEqual(store.entries[0].status, .watching)
        XCTAssertEqual(store.entries[0].lastWatchedEpisodeCursor, SeriesEpisodeCursor(seasonNumber: 1, episodeNumber: 1))
    }

    func testMarkNextCanPinReadyToStartSeriesOnHomeAtomically() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let store = SeriesLibraryStore(entries: [
            SeriesLibraryEntry(
                entryId: "entry",
                seriesId: "entry",
                title: "Ready",
                status: .wantToWatch,
                addedAt: date,
                updatedAt: date,
                lastInteractedAt: date
            )
        ])

        store.markNextEpisodeWatched(
            for: "entry",
            pinOnHomeWhenStarting: true,
            at: date.addingTimeInterval(10)
        )

        XCTAssertEqual(store.entries[0].status, .watching)
        XCTAssertEqual(store.entries[0].lastWatchedEpisodeCursor, SeriesEpisodeCursor(seasonNumber: 1, episodeNumber: 1))
        XCTAssertEqual(store.entries[0].isPinnedHomeSeries, true)
    }

    func testMarkNextDoesNotAdvanceBeyondKnownEpisodeGuide() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let store = SeriesLibraryStore(entries: [
            SeriesLibraryEntry(
                entryId: "one-piece",
                seriesId: "thetvdb:81797",
                title: "One Piece",
                status: .watching,
                lastWatchedEpisodeCursor: SeriesEpisodeCursor(seasonNumber: 23, episodeNumber: 14),
                latestKnownEpisodeCursor: SeriesEpisodeCursor(seasonNumber: 23, episodeNumber: 14),
                knownEpisodeCount: 1168,
                addedAt: date,
                updatedAt: date,
                lastInteractedAt: date
            )
        ])

        store.markNextEpisodeWatched(for: "one-piece", at: date.addingTimeInterval(10))

        XCTAssertEqual(store.entries[0].lastWatchedEpisodeCursor, SeriesEpisodeCursor(seasonNumber: 23, episodeNumber: 14))
        XCTAssertEqual(store.entries[0].updatedAt, date)
    }

    func testMarkNextAllowsAdvancingToLastKnownEpisode() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let store = SeriesLibraryStore(entries: [
            SeriesLibraryEntry(
                entryId: "one-piece",
                seriesId: "thetvdb:81797",
                title: "One Piece",
                status: .watching,
                lastWatchedEpisodeCursor: SeriesEpisodeCursor(seasonNumber: 23, episodeNumber: 13),
                latestKnownEpisodeCursor: SeriesEpisodeCursor(seasonNumber: 23, episodeNumber: 14),
                knownEpisodeCount: 1168,
                addedAt: date,
                updatedAt: date,
                lastInteractedAt: date
            )
        ])

        store.markNextEpisodeWatched(for: "one-piece", at: date.addingTimeInterval(10))

        XCTAssertEqual(store.entries[0].lastWatchedEpisodeCursor, SeriesEpisodeCursor(seasonNumber: 23, episodeNumber: 14))
        XCTAssertEqual(store.entries[0].updatedAt, date.addingTimeInterval(10))
    }

    func testMarkWatchedThroughCanPinReadyToStartSeriesOnHomeAtomically() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let store = SeriesLibraryStore(entries: [
            SeriesLibraryEntry(
                entryId: "entry",
                seriesId: "entry",
                title: "Ready",
                status: .wantToWatch,
                addedAt: date,
                updatedAt: date,
                lastInteractedAt: date
            )
        ])

        store.markWatchedThrough(
            SeriesEpisodeCursor(seasonNumber: 2, episodeNumber: 4),
            for: "entry",
            pinOnHomeWhenStarting: true,
            at: date.addingTimeInterval(10)
        )

        XCTAssertEqual(store.entries[0].status, .watching)
        XCTAssertEqual(store.entries[0].lastWatchedEpisodeCursor, SeriesEpisodeCursor(seasonNumber: 2, episodeNumber: 4))
        XCTAssertEqual(store.entries[0].isPinnedHomeSeries, true)
    }

    func testUpsertDeduplicatesByCanonicalSeriesId() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let store = SeriesLibraryStore(entries: [
            SeriesLibraryEntry(
                entryId: "local-a",
                seriesId: "series-123",
                title: "Provider Series",
                status: .wantToWatch,
                addedAt: date,
                updatedAt: date,
                lastInteractedAt: date
            )
        ])

        store.upsert(
            SeriesLibraryEntry(
                entryId: "local-b",
                seriesId: "series-123",
                title: "Provider Series",
                status: .watching,
                lastWatchedEpisodeCursor: SeriesEpisodeCursor(seasonNumber: 1, episodeNumber: 1),
                addedAt: date,
                updatedAt: date,
                lastInteractedAt: date
            )
        )

        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(store.entries[0].entryId, "local-b")
        XCTAssertEqual(store.entries[0].status, .watching)
    }

    func testUpdateArtworkIfMissingFillsPosterWithoutChangingInteractionOrder() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let updateDate = date.addingTimeInterval(100)
        let store = SeriesLibraryStore(entries: [
            SeriesLibraryEntry(
                entryId: "series-a",
                seriesId: "series-a",
                title: "Series A",
                status: .wantToWatch,
                addedAt: date,
                updatedAt: date,
                lastInteractedAt: date
            )
        ])

        let didUpdate = store.updateArtworkIfMissing(
            for: "series-a",
            displayArtworkRef: "https://img.example.com/poster.jpg",
            fallbackVisualSeed: "Series A",
            at: updateDate
        )

        XCTAssertTrue(didUpdate)
        XCTAssertEqual(store.entries[0].displayArtworkRef, "https://img.example.com/poster.jpg")
        XCTAssertEqual(store.entries[0].updatedAt, updateDate)
        XCTAssertEqual(store.entries[0].lastInteractedAt, date)
    }

    func testUpdateArtworkIfMissingDoesNotReplaceExistingPoster() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let store = SeriesLibraryStore(entries: [
            SeriesLibraryEntry(
                entryId: "series-a",
                seriesId: "series-a",
                title: "Series A",
                status: .wantToWatch,
                displayArtworkRef: "https://img.example.com/original.jpg",
                addedAt: date,
                updatedAt: date,
                lastInteractedAt: date
            )
        ])

        let didUpdate = store.updateArtworkIfMissing(
            for: "series-a",
            displayArtworkRef: "https://img.example.com/new.jpg",
            fallbackVisualSeed: "Series A",
            at: date.addingTimeInterval(100)
        )

        XCTAssertFalse(didUpdate)
        XCTAssertEqual(store.entries[0].displayArtworkRef, "https://img.example.com/original.jpg")
    }

    func testActiveEntriesPrioritizePinnedAndRecentInteractions() {
        let older = Date(timeIntervalSince1970: 1_800_000_000)
        let newer = Date(timeIntervalSince1970: 1_800_000_100)
        let store = SeriesLibraryStore(entries: [
            entry(id: "recent", title: "Recent", pinned: false, interactedAt: newer),
            entry(id: "pinned", title: "Pinned", pinned: true, interactedAt: older),
            entry(id: "archived", title: "Archived", pinned: true, interactedAt: newer, archivedAt: newer)
        ])

        XCTAssertEqual(store.activeEntries.map(\.entryId), ["pinned", "recent"])
    }

    func testHomeEntriesPrioritizeWatchingBeforeWantToWatch() {
        let older = Date(timeIntervalSince1970: 1_800_000_000)
        let newer = Date(timeIntervalSince1970: 1_800_000_100)
        let store = SeriesLibraryStore(entries: [
            SeriesLibraryEntry(
                entryId: "later",
                seriesId: "later",
                title: "Later",
                status: .wantToWatch,
                addedAt: newer,
                updatedAt: newer,
                lastInteractedAt: newer
            ),
            entry(id: "watching", title: "Watching", pinned: false, interactedAt: older)
        ])

        XCTAssertEqual(store.homeEntries.map(\.entryId), ["watching"])
    }

    func testHomeEntriesFallBackToWantToWatchBeforeWatched() {
        let older = Date(timeIntervalSince1970: 1_800_000_000)
        let newer = Date(timeIntervalSince1970: 1_800_000_100)
        let store = SeriesLibraryStore(entries: [
            SeriesLibraryEntry(
                entryId: "watched",
                seriesId: "watched",
                title: "Watched",
                status: .watched,
                lastWatchedEpisodeCursor: SeriesEpisodeCursor(seasonNumber: 1, episodeNumber: 6),
                addedAt: newer,
                updatedAt: newer,
                lastInteractedAt: newer
            ),
            SeriesLibraryEntry(
                entryId: "later",
                seriesId: "later",
                title: "Later",
                status: .wantToWatch,
                addedAt: older,
                updatedAt: older,
                lastInteractedAt: older
            )
        ])

        XCTAssertEqual(store.homeEntries.map(\.entryId), ["later"])
    }

    func testMarkPreviousEpisodeWatchedMovesBackOrClearsProgress() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let store = SeriesLibraryStore(entries: [
            entry(id: "entry", title: "Entry", pinned: false, interactedAt: date)
        ])

        store.markPreviousEpisodeWatched(for: "entry", at: date)
        XCTAssertEqual(store.entries[0].lastWatchedEpisodeCursor, nil)
        XCTAssertEqual(store.entries[0].status, .wantToWatch)

        store.markWatchedThrough(SeriesEpisodeCursor(seasonNumber: 1, episodeNumber: 10), for: "entry", at: date)
        store.markPreviousEpisodeWatched(for: "entry", at: date)
        XCTAssertEqual(store.entries[0].lastWatchedEpisodeCursor, SeriesEpisodeCursor(seasonNumber: 1, episodeNumber: 9))
        XCTAssertEqual(store.entries[0].status, .watching)
    }

    func testMarkPreviousFromFirstEpisodeClearsProgress() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let store = SeriesLibraryStore(entries: [
            entry(id: "entry", title: "Entry", pinned: false, interactedAt: date)
        ])

        XCTAssertEqual(store.entries[0].lastWatchedEpisodeCursor, SeriesEpisodeCursor(seasonNumber: 1, episodeNumber: 1))

        store.markPreviousEpisodeWatched(for: "entry", at: date.addingTimeInterval(10))

        XCTAssertNil(store.entries[0].lastWatchedEpisodeCursor)
        XCTAssertEqual(store.entries[0].status, .wantToWatch)
    }

    func testMarkPreviousFromSeasonBoundaryKeepsProgress() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let store = SeriesLibraryStore(entries: [
            SeriesLibraryEntry(
                entryId: "entry",
                seriesId: "entry",
                title: "Entry",
                status: .watching,
                lastWatchedEpisodeCursor: SeriesEpisodeCursor(seasonNumber: 2, episodeNumber: 1),
                addedAt: date,
                updatedAt: date,
                lastInteractedAt: date
            )
        ])

        store.markPreviousEpisodeWatched(for: "entry", at: date.addingTimeInterval(10))

        XCTAssertEqual(store.entries[0].lastWatchedEpisodeCursor, SeriesEpisodeCursor(seasonNumber: 2, episodeNumber: 1))
        XCTAssertEqual(store.entries[0].status, .watching)
    }

    func testClearProgressResetsEntryToWantToWatch() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let store = SeriesLibraryStore(entries: [
            entry(id: "entry", title: "Entry", pinned: false, interactedAt: date)
        ])

        store.markWatchedThrough(SeriesEpisodeCursor(seasonNumber: 2, episodeNumber: 4), for: "entry", at: date)
        store.clearProgress(for: "entry", at: date.addingTimeInterval(10))

        XCTAssertNil(store.entries[0].lastWatchedEpisodeCursor)
        XCTAssertEqual(store.entries[0].status, .wantToWatch)
    }

    func testRestoreProgressRestoresExactStatusAndCursor() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let store = SeriesLibraryStore(entries: [
            entry(id: "entry", title: "Entry", pinned: false, interactedAt: date)
        ])

        store.markNextEpisodeWatched(for: "entry", at: date.addingTimeInterval(10))
        XCTAssertEqual(store.entries[0].lastWatchedEpisodeCursor, SeriesEpisodeCursor(seasonNumber: 1, episodeNumber: 2))

        store.restoreProgress(
            status: .wantToWatch,
            lastWatchedEpisodeCursor: nil,
            isPinnedHomeSeries: false,
            for: "entry",
            at: date.addingTimeInterval(20)
        )

        XCTAssertEqual(store.entries[0].status, .wantToWatch)
        XCTAssertNil(store.entries[0].lastWatchedEpisodeCursor)
        XCTAssertEqual(store.entries[0].isPinnedHomeSeries, false)
    }

    func testAddCatalogSeriesTrimsTitleAndDeduplicatesBySeriesId() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let store = SeriesLibraryStore()

        let first = store.addCatalogSeries(catalogItem(id: "series-example", title: "  Example Show  "), at: date)
        let second = store.addCatalogSeries(catalogItem(id: "series-example", title: "Example Show"), at: date.addingTimeInterval(10))

        XCTAssertEqual(first?.title, "Example Show")
        XCTAssertEqual(second?.seriesId, "series-example")
        XCTAssertEqual(second?.entryId, first?.entryId)
        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(store.entries[0].status, .wantToWatch)
    }

    func testActiveLibraryLimitPolicyAllowsAddingBelowLimit() {
        let policy = SeriesActiveLibraryLimitPolicy(activeCount: 24, activeLimit: 25)

        XCTAssertTrue(policy.canAddSeries)
        XCTAssertEqual(policy.remainingSeriesCount, 1)
    }

    func testActiveLibraryLimitPolicyBlocksAddingAtLimit() {
        let policy = SeriesActiveLibraryLimitPolicy(activeCount: 25, activeLimit: 25)

        XCTAssertFalse(policy.canAddSeries)
        XCTAssertEqual(policy.remainingSeriesCount, 0)
    }

    func testActiveLibraryLimitPolicyTreatsNilLimitAsUnlimited() {
        let policy = SeriesActiveLibraryLimitPolicy(activeCount: 1_000, activeLimit: nil)

        XCTAssertTrue(policy.canAddSeries)
        XCTAssertNil(policy.remainingSeriesCount)
    }

    func testSearchEntriesMatchesTitlesCaseInsensitively() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let store = SeriesLibraryStore(entries: [
            SeriesLibraryEntry(
                entryId: "entry-1",
                seriesId: "entry-1",
                title: "Misterio",
                status: .watching,
                addedAt: date,
                updatedAt: date,
                lastInteractedAt: date
            ),
            SeriesLibraryEntry(
                entryId: "entry-2",
                seriesId: "entry-2",
                title: "Comedy",
                status: .watching,
                addedAt: date,
                updatedAt: date,
                lastInteractedAt: date
            )
        ])

        XCTAssertEqual(store.searchEntries(matching: "misterio").map(\.entryId), ["entry-1"])
    }

    func testPersistedStoreLoadsSavedCatalogSeries() {
        let defaults = isolatedUserDefaults()
        let store = SeriesLibraryStore.persisted(userDefaults: defaults)

        store.addCatalogSeries(catalogItem(id: "series-persisted", title: "Persisted Show"), at: Date(timeIntervalSince1970: 1_800_000_000))

        let reloadedStore = SeriesLibraryStore.persisted(userDefaults: defaults)
        XCTAssertEqual(reloadedStore.entries.map(\.title), ["Persisted Show"])
        XCTAssertEqual(reloadedStore.entries[0].status, .wantToWatch)
    }

    func testPersistedStoreSavesProgressChanges() {
        let defaults = isolatedUserDefaults()
        let store = SeriesLibraryStore.persisted(userDefaults: defaults)
        let entry = store.addCatalogSeries(catalogItem(id: "series-progress", title: "Progress Show"), at: Date(timeIntervalSince1970: 1_800_000_000))

        store.markWatchedThrough(SeriesEpisodeCursor(seasonNumber: 2, episodeNumber: 8), for: entry?.id ?? "")

        let reloadedStore = SeriesLibraryStore.persisted(userDefaults: defaults)
        XCTAssertEqual(reloadedStore.entries[0].lastWatchedEpisodeCursor, SeriesEpisodeCursor(seasonNumber: 2, episodeNumber: 8))
    }

    func testArchiveRestoreAndDeleteKeepActionsReversibleInStore() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let store = SeriesLibraryStore(entries: [
            entry(id: "entry", title: "Entry", pinned: true, interactedAt: date)
        ])

        store.archive("entry", at: date)
        XCTAssertEqual(store.activeEntries, [])
        XCTAssertEqual(store.archivedEntries.map(\.entryId), ["entry"])
        XCTAssertEqual(store.entries[0].archivedAt, date)
        XCTAssertEqual(store.entries[0].isPinnedHomeSeries, false)

        store.restore("entry", at: date)
        XCTAssertEqual(store.activeEntries.map(\.entryId), ["entry"])
        XCTAssertEqual(store.archivedEntries, [])
        XCTAssertNil(store.entries[0].archivedAt)

        store.delete("entry", at: date)
        XCTAssertEqual(store.activeEntries, [])
        XCTAssertEqual(store.archivedEntries, [])
        XCTAssertEqual(store.deletedEntries.map(\.entryId), ["entry"])
        XCTAssertEqual(store.entries[0].deletedAt, date)

        store.restore("entry", at: date)
        XCTAssertEqual(store.activeEntries.map(\.entryId), ["entry"])
        XCTAssertEqual(store.deletedEntries, [])
        XCTAssertNil(store.entries[0].deletedAt)
    }

    func testPinnedSeriesMovesToHomeFocus() {
        let older = Date(timeIntervalSince1970: 1_800_000_000)
        let newer = Date(timeIntervalSince1970: 1_800_000_100)
        let store = SeriesLibraryStore(entries: [
            entry(id: "recent", title: "Recent", pinned: false, interactedAt: newer),
            entry(id: "older", title: "Older", pinned: false, interactedAt: older)
        ])

        store.setPinned(true, for: "older", at: newer)

        XCTAssertEqual(store.homeEntries.map(\.entryId), ["older", "recent"])
    }

    func testSetStatusKeepsHomeFocusedOnWatchingAndClearsProgressForWantToWatch() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let store = SeriesLibraryStore(entries: [
            entry(id: "entry", title: "Entry", pinned: true, interactedAt: date)
        ])

        store.setStatus(.watched, for: "entry", at: date)
        XCTAssertEqual(store.entries[0].status, .watched)
        XCTAssertEqual(store.entries[0].isPinnedHomeSeries, false)
        XCTAssertEqual(store.homeEntries.map(\.entryId), ["entry"])

        store.setStatus(.wantToWatch, for: "entry", at: date)
        XCTAssertEqual(store.entries[0].status, .wantToWatch)
        XCTAssertNil(store.entries[0].lastWatchedEpisodeCursor)
    }

    func testSetPrivateNoteTrimsAndClearsBlankNotes() {
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)
        let t1 = Date(timeIntervalSince1970: 1_700_000_200)
        let store = SeriesLibraryStore(entries: [
            entry(id: "entry", title: "Series A", pinned: false, interactedAt: t0)
        ])

        store.setPrivateNote("  Watch with Ana  ", for: "entry", at: t1)

        XCTAssertEqual(store.entries[0].privateNote, "Watch with Ana")
        XCTAssertEqual(store.entries[0].updatedAt, t1)
        XCTAssertEqual(store.entries[0].lastInteractedAt, t1)

        store.setPrivateNote("   ", for: "entry", at: t1)

        XCTAssertNil(store.entries[0].privateNote)
    }

    private func entry(
        id: String,
        title: String,
        pinned: Bool,
        interactedAt: Date,
        archivedAt: Date? = nil
    ) -> SeriesLibraryEntry {
        SeriesLibraryEntry(
            entryId: id,
            seriesId: id,
            title: title,
            status: .watching,
            lastWatchedEpisodeCursor: SeriesEpisodeCursor(seasonNumber: 1, episodeNumber: 1),
            isPinnedHomeSeries: pinned,
            archivedAt: archivedAt,
            addedAt: interactedAt,
            updatedAt: interactedAt,
            lastInteractedAt: interactedAt
        )
    }

    private func isolatedUserDefaults() -> UserDefaults {
        let suiteName = "series-av-library-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func catalogItem(id: String, title: String) -> SeriesCatalogItem {
        SeriesCatalogItem(
            seriesId: id,
            providerRef: SeriesProviderRef(provider: "tvmaze", providerSeriesId: id, providerUrl: nil, isPrimary: true),
            providerRefs: [SeriesProviderRef(provider: "tvmaze", providerSeriesId: id, providerUrl: nil, isPrimary: true)],
            title: title,
            startYear: 2026,
            statusText: "Running",
            summary: nil,
            genres: ["Drama"],
            displayArtwork: SeriesCatalogItem.DisplayArtwork(
                kind: "providerPoster",
                url: nil,
                assetName: nil,
                fallbackSeed: title,
                aspectRatio: nil,
                policy: SeriesCatalogItem.DisplayArtwork.Policy(
                    displayState: "fallbackOnly",
                    reasonCode: nil,
                    evaluatedAt: Date(timeIntervalSince1970: 1_800_000_000)
                )
            ),
            displayBackdrop: nil,
            episodeGuideState: "available",
            visibility: "public",
            enrichmentStatus: "providerFallback",
            artworkStatus: "none",
            metadataUpdatedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }
}
