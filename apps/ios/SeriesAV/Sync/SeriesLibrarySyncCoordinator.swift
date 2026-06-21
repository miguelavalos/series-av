import Foundation
import OSLog
import Observation

@MainActor
@Observable
final class SeriesLibrarySyncCoordinator {
    enum State: Equatable {
        case disabled
        case idle
        case syncing
        case conflict
        case failed(String)
    }

    private static let deviceIdKey = "seriesav.sync.deviceId"

    private let deviceId: String
    private let debounceNanoseconds: UInt64
    private let logger = Logger(subsystem: "com.avalsys.seriesav", category: "library-sync")

    private var etag: String?
    private var pendingPushTask: Task<Void, Never>?
    private var isApplyingRemoteEntries = false
    private var hasCompletedInitialPull = false

    private(set) var state: State = .disabled

    init(
        userDefaults: UserDefaults = .standard,
        debounceNanoseconds: UInt64 = 800_000_000
    ) {
        self.deviceId = Self.stableDeviceId(userDefaults: userDefaults)
        self.debounceNanoseconds = debounceNanoseconds
    }

    func refresh(accessController: SeriesAccessController, store: SeriesLibraryStore) async {
        guard accessController.capabilities.canUseCloudSync else {
            disable()
            return
        }

        await pullMergeAndPushIfNeeded(accessController: accessController, store: store)
    }

    func localEntriesDidChange(
        _ entries: [SeriesLibraryEntry],
        accessController: SeriesAccessController
    ) {
        guard accessController.capabilities.canUseCloudSync else {
            disable()
            return
        }
        guard !isApplyingRemoteEntries else {
            return
        }
        guard hasCompletedInitialPull else {
            return
        }

        pendingPushTask?.cancel()
        pendingPushTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: debounceNanoseconds)
            guard !Task.isCancelled else { return }
            await self.push(entries: entries, accessController: accessController)
        }
    }

    func overwriteCloudLibraryWithLocalData(
        accessController: SeriesAccessController,
        store: SeriesLibraryStore
    ) async {
        guard accessController.capabilities.canUseCloudSync else {
            disable()
            return
        }

        pendingPushTask?.cancel()
        pendingPushTask = nil
        state = .syncing

        let client = makeClient(accessController: accessController)
        do {
            let document = try await client.pushLibrary(entries: store.entries, expectedETag: nil)
            etag = document.etag
            hasCompletedInitialPull = true
            if document.data.entries != store.entries {
                isApplyingRemoteEntries = true
                store.replace(with: document.data.entries)
                isApplyingRemoteEntries = false
            }
            state = .idle
        } catch {
            logger.error("Series AV Pro library sync overwrite failed")
            state = Self.syncState(for: error)
        }
    }

    func disable() {
        pendingPushTask?.cancel()
        pendingPushTask = nil
        etag = nil
        hasCompletedInitialPull = false
        isApplyingRemoteEntries = false
        state = .disabled
    }

    func setStateForUITests(_ state: State) {
        guard SeriesUITestEnvironment.current.isEnabled else {
            return
        }
        self.state = state
    }

    private func pullMergeAndPushIfNeeded(
        accessController: SeriesAccessController,
        store: SeriesLibraryStore
    ) async {
        pendingPushTask?.cancel()
        pendingPushTask = nil
        state = .syncing

        let client = makeClient(accessController: accessController)
        do {
            let document = try await client.pullLibrary()
            etag = document.etag
            hasCompletedInitialPull = true

            let mergedEntries = Self.merge(local: store.entries, remote: document.data.entries)
            if mergedEntries != store.entries {
                isApplyingRemoteEntries = true
                store.replace(with: mergedEntries)
                isApplyingRemoteEntries = false
            }

            if mergedEntries != document.data.entries {
                let pushedDocument = try await client.pushLibrary(entries: mergedEntries, expectedETag: etag)
                etag = pushedDocument.etag
                if pushedDocument.data.entries != store.entries {
                    isApplyingRemoteEntries = true
                    store.replace(with: pushedDocument.data.entries)
                    isApplyingRemoteEntries = false
                }
            }

            state = .idle
        } catch {
            logger.error("Series AV Pro library sync pull failed")
            hasCompletedInitialPull = true
            state = Self.syncState(for: error)
        }
    }

    private func push(
        entries: [SeriesLibraryEntry],
        accessController: SeriesAccessController
    ) async {
        state = .syncing
        let client = makeClient(accessController: accessController)
        do {
            let document = try await client.pushLibrary(entries: entries, expectedETag: etag)
            etag = document.etag
            state = .idle
        } catch {
            logger.error("Series AV Pro library sync push failed")
            state = Self.syncState(for: error)
        }
    }

    private func makeClient(accessController: SeriesAccessController) -> SeriesAppDataSyncClient {
        let apiClient = accessController.authenticatedAppDataAPIClient()
        return SeriesAppDataSyncClient(deviceId: deviceId) { path, method, body, headers in
            try await apiClient.requestData(path: path, method: method, body: body, headers: headers)
        }
    }

    static func merge(
        local localEntries: [SeriesLibraryEntry],
        remote remoteEntries: [SeriesLibraryEntry]
    ) -> [SeriesLibraryEntry] {
        var merged: [String: SeriesLibraryEntry] = [:]
        var order: [String] = []

        for entry in remoteEntries + localEntries {
            let key = identityKey(for: entry)
            if merged[key] == nil {
                order.append(key)
                merged[key] = entry
                continue
            }

            guard let existing = merged[key] else { continue }
            if entry.updatedAt >= existing.updatedAt {
                merged[key] = entry
            }
        }

        return order
            .compactMap { merged[$0] }
            .sorted { first, second in
                if first.lastInteractedAt != second.lastInteractedAt {
                    return first.lastInteractedAt > second.lastInteractedAt
                }
                return first.title.localizedCaseInsensitiveCompare(second.title) == .orderedAscending
            }
    }

    private static func identityKey(for entry: SeriesLibraryEntry) -> String {
        "series:\(entry.seriesId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    }

    private static func stableDeviceId(userDefaults: UserDefaults) -> String {
        if let existing = userDefaults.string(forKey: deviceIdKey), !existing.isEmpty {
            return existing
        }
        let created = UUID().uuidString
        userDefaults.set(created, forKey: deviceIdKey)
        return created
    }

    static func syncState(for error: Error) -> State {
        if case SeriesAVAPIClientError.requestFailed(let statusCode) = error,
           statusCode == 409 || statusCode == 412 {
            return .conflict
        }
        return .failed(error.localizedDescription)
    }
}
