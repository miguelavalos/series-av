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
}
