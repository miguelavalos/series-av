import XCTest
@testable import SeriesAV

@MainActor
final class SeriesLibrarySyncCoordinatorTests: XCTestCase {
    func testMergeKeepsNewestEntryForResolvedSeriesIdentity() {
        let older = makeEntry(
            entryId: "local-the-bear",
            seriesId: "series-the-bear",
            title: "The Bear",
            updatedAt: date("2026-06-14T10:00:00Z"),
            lastInteractedAt: date("2026-06-14T10:00:00Z"),
            cursor: SeriesEpisodeCursor(seasonNumber: 1, episodeNumber: 2)
        )
        let newer = makeEntry(
            entryId: "remote-the-bear",
            seriesId: "series-the-bear",
            title: "The Bear",
            updatedAt: date("2026-06-14T11:00:00Z"),
            lastInteractedAt: date("2026-06-14T11:00:00Z"),
            cursor: SeriesEpisodeCursor(seasonNumber: 1, episodeNumber: 4)
        )

        let merged = SeriesLibrarySyncCoordinator.merge(local: [older], remote: [newer])

        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged.first?.entryId, "remote-the-bear")
        XCTAssertEqual(merged.first?.lastWatchedEpisodeCursor, SeriesEpisodeCursor(seasonNumber: 1, episodeNumber: 4))
    }

    func testMergeUsesCanonicalSeriesIdForCatalogEntries() {
        let remote = makeEntry(
            entryId: "remote-provider",
            seriesId: "series-arcane",
            title: "Arcane",
            updatedAt: date("2026-06-14T10:00:00Z"),
            lastInteractedAt: date("2026-06-14T10:00:00Z")
        )
        let local = makeEntry(
            entryId: "local-provider",
            seriesId: "series-arcane",
            title: "Arcane",
            updatedAt: date("2026-06-14T12:00:00Z"),
            lastInteractedAt: date("2026-06-14T12:00:00Z")
        )

        let merged = SeriesLibrarySyncCoordinator.merge(local: [local], remote: [remote])

        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged.first?.entryId, "local-provider")
    }

    func testMergeKeepsDistinctCatalogEntries() {
        let first = makeEntry(entryId: "local-one", seriesId: "series-one", title: "One", updatedAt: date("2026-06-14T10:00:00Z"))
        let second = makeEntry(entryId: "local-two", seriesId: "series-two", title: "Two", updatedAt: date("2026-06-14T11:00:00Z"))

        let merged = SeriesLibrarySyncCoordinator.merge(local: [first, second], remote: [])

        XCTAssertEqual(merged.map(\.entryId), ["local-two", "local-one"])
    }

    func testSyncStateTreatsRevisionConflictsAsConflict() {
        XCTAssertEqual(
            SeriesLibrarySyncCoordinator.syncState(for: SeriesAVAPIClientError.requestFailed(statusCode: 409)),
            .conflict
        )
        XCTAssertEqual(
            SeriesLibrarySyncCoordinator.syncState(for: SeriesAVAPIClientError.requestFailed(statusCode: 412)),
            .conflict
        )
    }

    func testSyncStateKeepsOtherRequestFailuresGeneric() {
        guard case .failed = SeriesLibrarySyncCoordinator.syncState(
            for: SeriesAVAPIClientError.requestFailed(statusCode: 500)
        ) else {
            return XCTFail("Expected non-conflict request failures to stay generic")
        }
    }

    private func makeEntry(
        entryId: String,
        seriesId: String,
        title: String,
        updatedAt: Date,
        lastInteractedAt: Date? = nil,
        cursor: SeriesEpisodeCursor? = nil
    ) -> SeriesLibraryEntry {
        SeriesLibraryEntry(
            entryId: entryId,
            seriesId: seriesId,
            title: title,
            status: cursor == nil ? .wantToWatch : .watching,
            lastWatchedEpisodeCursor: cursor,
            addedAt: date("2026-06-14T09:00:00Z"),
            updatedAt: updatedAt,
            lastInteractedAt: lastInteractedAt ?? updatedAt
        )
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}
