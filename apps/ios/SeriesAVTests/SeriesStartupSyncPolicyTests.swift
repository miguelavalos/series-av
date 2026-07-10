import XCTest
@testable import SeriesAV

final class SeriesStartupSyncPolicyTests: XCTestCase {
    func testSkipsLibrarySyncWhenCloudSyncIsUnavailable() {
        let policy = SeriesStartupSyncPolicy(canUseCloudSync: false)

        XCTAssertFalse(policy.shouldScheduleLibrarySync)
    }

    func testSchedulesFirstAvailableCloudSync() {
        let policy = SeriesStartupSyncPolicy(canUseCloudSync: true)

        XCTAssertTrue(policy.shouldScheduleLibrarySync)
    }

    func testSkipsRecentAutomaticLibrarySync() {
        let now = Date(timeIntervalSince1970: 1_000)
        let policy = SeriesStartupSyncPolicy(
            canUseCloudSync: true,
            lastLibrarySyncRequestedAt: now.addingTimeInterval(-60),
            now: now
        )

        XCTAssertFalse(policy.shouldScheduleLibrarySync)
    }

    func testAllowsAutomaticLibrarySyncAfterInterval() {
        let now = Date(timeIntervalSince1970: 1_000)
        let policy = SeriesStartupSyncPolicy(
            canUseCloudSync: true,
            lastLibrarySyncRequestedAt: now.addingTimeInterval(-SeriesStartupSyncPolicy.automaticLibrarySyncInterval),
            now: now
        )

        XCTAssertTrue(policy.shouldScheduleLibrarySync)
    }

    func testRetriesFailedSyncOnNextForegroundEvenInsideInterval() {
        let now = Date(timeIntervalSince1970: 1_000)
        let policy = SeriesStartupSyncPolicy(
            canUseCloudSync: true,
            shouldRetryAfterFailure: true,
            lastLibrarySyncRequestedAt: now.addingTimeInterval(-60),
            now: now
        )

        XCTAssertTrue(policy.shouldScheduleLibrarySync)
    }
}
