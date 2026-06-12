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

    func testUpsertDeduplicatesByProviderRefBeforeLocalEntryId() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let store = SeriesLibraryStore(entries: [
            SeriesLibraryEntry(
                entryId: "local-a",
                providerRef: SeriesProviderRef(provider: "tvmaze", providerSeriesId: "123"),
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
                providerRef: SeriesProviderRef(provider: "tvmaze", providerSeriesId: "123"),
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

    func testAddLocalSeriesTrimsTitleAndDeduplicatesByLocalSeriesId() {
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let store = SeriesLibraryStore()

        let first = store.addLocalSeries(title: "  Example Show  ", at: date)
        let second = store.addLocalSeries(title: "Example Show", at: date.addingTimeInterval(10))

        XCTAssertEqual(first?.title, "Example Show")
        XCTAssertEqual(second?.seriesId, "local-example-show")
        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(store.entries[0].status, .watching)
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

    func testPersistedStoreLoadsSavedLocalSeries() {
        let defaults = isolatedUserDefaults()
        let store = SeriesLibraryStore.persisted(userDefaults: defaults)

        store.addLocalSeries(title: "Persisted Show", at: Date(timeIntervalSince1970: 1_800_000_000))

        let reloadedStore = SeriesLibraryStore.persisted(userDefaults: defaults)
        XCTAssertEqual(reloadedStore.entries.map(\.title), ["Persisted Show"])
        XCTAssertEqual(reloadedStore.entries[0].status, .watching)
    }

    func testPersistedStoreSavesProgressChanges() {
        let defaults = isolatedUserDefaults()
        let store = SeriesLibraryStore.persisted(userDefaults: defaults)
        let entry = store.addLocalSeries(title: "Progress Show", at: Date(timeIntervalSince1970: 1_800_000_000))

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
}
