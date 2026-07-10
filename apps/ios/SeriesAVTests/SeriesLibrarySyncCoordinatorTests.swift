import XCTest
@testable import SeriesAV

@MainActor
final class SeriesLibrarySyncCoordinatorTests: XCTestCase {
    func testFailedInitialPullBlocksAutomaticPushUntilSuccessfulRetry() async {
        let localEntry = makeEntry(
            entryId: "local-one",
            seriesId: "series-local",
            title: "Local",
            updatedAt: date("2026-06-14T11:00:00Z")
        )
        let remoteEntry = makeEntry(
            entryId: "remote-one",
            seriesId: "series-remote",
            title: "Remote",
            updatedAt: date("2026-06-14T12:00:00Z")
        )
        let client = StubSeriesLibrarySyncClient(pullOutcomes: [
            .failure(statusCode: 500),
            .success(makeDocument(entries: [remoteEntry], revision: 4))
        ])
        let coordinator = SeriesLibrarySyncCoordinator(
            userDefaults: isolatedUserDefaults(),
            debounceNanoseconds: 0,
            clientFactory: { _, _ in client }
        )
        let accessController = await makeProAccessController()
        let store = SeriesLibraryStore(entries: [localEntry])

        await coordinator.refresh(accessController: accessController, store: store)

        guard case .failed = coordinator.state else {
            return XCTFail("Expected the failed initial pull to remain failed")
        }
        coordinator.localEntriesDidChange(store.entries, accessController: accessController)
        await Task.yield()
        let blockedPushCount = await client.pushCount()
        XCTAssertEqual(blockedPushCount, 0)

        await coordinator.refresh(accessController: accessController, store: store)

        XCTAssertEqual(coordinator.state, .idle)
        XCTAssertEqual(Set(store.entries.map(\.seriesId)), ["series-local", "series-remote"])
        var pushes = await client.recordedPushes()
        XCTAssertEqual(pushes.count, 1)
        XCTAssertEqual(pushes.first?.expectedETag, "\"revision-4\"")
        XCTAssertEqual(Set(pushes.first?.entries.map(\.seriesId) ?? []), ["series-local", "series-remote"])

        let nextEntry = makeEntry(
            entryId: "local-two",
            seriesId: "series-local-two",
            title: "Local Two",
            updatedAt: date("2026-06-14T13:00:00Z")
        )
        store.upsert(nextEntry)
        coordinator.localEntriesDidChange(store.entries, accessController: accessController)
        await waitForPushCount(2, client: client)

        pushes = await client.recordedPushes()
        XCTAssertEqual(pushes.count, 2)
        XCTAssertEqual(pushes.last?.expectedETag, "\"revision-5\"")
    }

    func testExplicitCloudOverwriteStillPushesWithoutETag() async {
        let client = StubSeriesLibrarySyncClient(pullOutcomes: [])
        let coordinator = SeriesLibrarySyncCoordinator(
            userDefaults: isolatedUserDefaults(),
            debounceNanoseconds: 0,
            clientFactory: { _, _ in client }
        )
        let accessController = await makeProAccessController()
        let entry = makeEntry(
            entryId: "local-one",
            seriesId: "series-local",
            title: "Local",
            updatedAt: date("2026-06-14T11:00:00Z")
        )

        await coordinator.overwriteCloudLibraryWithLocalData(
            accessController: accessController,
            store: SeriesLibraryStore(entries: [entry])
        )

        XCTAssertEqual(coordinator.state, .idle)
        let pushes = await client.recordedPushes()
        XCTAssertEqual(pushes.count, 1)
        XCTAssertNil(pushes.first?.expectedETag)
    }

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

    private func makeDocument(
        entries: [SeriesLibraryEntry],
        revision: Int
    ) -> SeriesLibraryDocument {
        SeriesLibraryDocument(
            data: SeriesLibraryEnvelope(
                appId: "seriesav",
                resource: "seriesLibrary",
                deviceId: "remote-device",
                sentAt: date("2026-06-14T12:00:00Z"),
                entries: entries
            ),
            updatedAt: date("2026-06-14T12:00:00Z"),
            revision: revision,
            etag: "\"revision-\(revision)\""
        )
    }

    private func makeProAccessController() async -> SeriesAccessController {
        let user = SeriesAccountUser(
            id: "apps-av-user-sync",
            displayName: "Sync User",
            emailAddress: "sync@example.com"
        )
        let controller = SeriesAccessController(
            accountService: SyncTestAccountService(user: user),
            profileResolver: SyncTestProfileResolver(user: user),
            entitlementService: SyncTestEntitlementService(),
            userDefaults: isolatedUserDefaults()
        )
        await controller.syncFromAccountProvider()
        XCTAssertTrue(controller.capabilities.canUseCloudSync)
        return controller
    }

    private func isolatedUserDefaults() -> UserDefaults {
        let suiteName = "series-av-sync-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func waitForPushCount(
        _ expectedCount: Int,
        client: StubSeriesLibrarySyncClient
    ) async {
        for _ in 0..<100 {
            guard await client.pushCount() < expectedCount else {
                break
            }
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
        let finalPushCount = await client.pushCount()
        XCTAssertEqual(finalPushCount, expectedCount)
    }
}

private actor StubSeriesLibrarySyncClient: SeriesLibrarySyncing {
    enum PullOutcome: Sendable {
        case failure(statusCode: Int)
        case success(SeriesLibraryDocument)
    }

    struct PushRequest: Sendable {
        let entries: [SeriesLibraryEntry]
        let expectedETag: String?
    }

    private var pullOutcomes: [PullOutcome]
    private var pushes: [PushRequest] = []

    init(pullOutcomes: [PullOutcome]) {
        self.pullOutcomes = pullOutcomes
    }

    func pullLibrary() async throws -> SeriesLibraryDocument {
        guard pullOutcomes.isEmpty == false else {
            throw SeriesAVAPIClientError.requestFailed(statusCode: 500)
        }
        switch pullOutcomes.removeFirst() {
        case .failure(let statusCode):
            throw SeriesAVAPIClientError.requestFailed(statusCode: statusCode)
        case .success(let document):
            return document
        }
    }

    func pushLibrary(
        entries: [SeriesLibraryEntry],
        expectedETag: String?
    ) async throws -> SeriesLibraryDocument {
        pushes.append(PushRequest(entries: entries, expectedETag: expectedETag))
        let revision = 4 + pushes.count
        let timestamp = Date(timeIntervalSince1970: 1_781_438_400)
        return SeriesLibraryDocument(
            data: SeriesLibraryEnvelope(
                appId: "seriesav",
                resource: "seriesLibrary",
                deviceId: "stub-device",
                sentAt: timestamp,
                entries: entries
            ),
            updatedAt: timestamp,
            revision: revision,
            etag: "\"revision-\(revision)\""
        )
    }

    func pushCount() -> Int {
        pushes.count
    }

    func recordedPushes() -> [PushRequest] {
        pushes
    }
}

@MainActor
private struct SyncTestAccountService: SeriesAVAccountServicing {
    let user: SeriesAccountUser

    var isAvailable: Bool { true }
    var providerSessionUser: SeriesAccountUser? { user }

    func restoreSession() async -> SeriesAVAccountSessionRestoreResult {
        .active(user)
    }

    func getToken() async throws -> String? { "sync-token" }
    func signInWithApple() async throws {}
    func signInWithGoogle() async throws {}
    func signOut() async throws {}
}

@MainActor
private struct SyncTestProfileResolver: SeriesAccountProfileResolving {
    let user: SeriesAccountUser

    func resolveCurrentAccountUser() async throws -> SeriesAccountUser {
        user
    }
}

@MainActor
private struct SyncTestEntitlementService: SeriesEntitlementServicing {
    private let access = SeriesResolvedAccess(
        platformUserId: "apps-av-user-sync",
        planTier: .pro,
        accessMode: .signedInPro,
        capabilities: .forMode(.signedInPro),
        limits: .forMode(.signedInPro)
    )

    func resolveAccess(for user: SeriesAccountUser?) -> SeriesResolvedAccess {
        user == nil ? .guest : access
    }

    func refreshAccess(for user: SeriesAccountUser?) async -> SeriesResolvedAccess {
        user == nil ? .guest : access
    }
}
