import AVAviFoundation
import AVAppShellFoundation
import AVBrandFoundation
import AVSettingsFoundation
import SwiftUI
import UIKit

struct RootView: View {
    @Bindable var store: SeriesLibraryStore
    let accessController: SeriesAccessController
    let startSignInFlow: () -> Void
    let openSettings: () -> Void
    let openAccount: () -> Void
    let openLibraryTab: () -> Void
    let openSearch: () -> Void
    let openAvi: () -> Void

    var body: some View {
        SeriesWatchingHomeScreen(
            store: store,
            activeSeriesLimit: accessController.limits.activeLibrarySeries,
            accessController: accessController,
            openSettings: openSettings,
            openAccount: openAccount,
            openLibraryTab: openLibraryTab,
            openSearch: openSearch,
            openAvi: openAvi,
            startSignInFlow: startSignInFlow
        )
    }
}

#Preview {
    RootView(
        store: SeriesLibraryStore.persisted(),
        accessController: SeriesAccessController(),
        startSignInFlow: {},
        openSettings: {},
        openAccount: {},
        openLibraryTab: {},
        openSearch: {},
        openAvi: {}
    )
}

enum SeriesLibraryFilter: String, CaseIterable {
    case all
    case watching
    case wantToWatch
    case watched
    case archived
}

private struct SeriesHomeDetailSelection: Identifiable {
    let catalogItem: SeriesCatalogItem?
    let entry: SeriesLibraryEntry?

    init(catalogItem: SeriesCatalogItem?, entry: SeriesLibraryEntry?) {
        self.catalogItem = catalogItem
        self.entry = entry
    }

    init(entry: SeriesLibraryEntry) {
        self.catalogItem = nil
        self.entry = entry
    }

    var id: String {
        entry?.seriesId ?? catalogItem?.seriesId ?? UUID().uuidString
    }
}

private struct SeriesWatchingHomeScreen: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Bindable var store: SeriesLibraryStore
    let activeSeriesLimit: Int?
    let accessController: SeriesAccessController
    let openSettings: () -> Void
    let openAccount: () -> Void
    let openLibraryTab: () -> Void
    let openSearch: () -> Void
    let openAvi: () -> Void
    let startSignInFlow: () -> Void

    @State private var editorEntry: SeriesLibraryEntry?
    @State private var detailSelection: SeriesHomeDetailSelection?
    @State private var isShowingProPaywall = false
    @State private var pendingUndo: PendingLibraryUndo?
    @State private var pendingProgressUndo: PendingProgressUndo?
    @State private var popularPreviews: [SeriesHomeDiscoveryPreview] = []
    @State private var upcomingPreviews: [SeriesHomeDiscoveryPreview] = []
    @State private var recommendedPreviews: [SeriesHomeDiscoveryPreview] = []
    @State private var homeDiscoveryLoadState: SeriesHomeDiscoveryLoadState = .idle
    @State private var uiTestHomeDiscoveryLoadAttempts = 0
    @State private var artworkReconciliationSignature = ""

    private var homeState: SeriesHomeScreenState {
        SeriesHomeStateBuilder.build(
            homeEntries: store.homeEntries,
            activeEntries: store.activeEntries,
            popularPreviews: popularPreviews,
            upcomingPreviews: upcomingPreviews,
            recommendedPreviews: recommendedPreviews
        )
    }

    private var isTabletLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass != .compact
    }

    var body: some View {
        AVAppShellScrollableScreenScaffold(
            alignment: .leading,
            spacing: isTabletLayout ? 26 : 22,
            bottomPadding: isTabletLayout ? 56 : 176,
            maxContentWidth: isTabletLayout ? 1120 : 760
        ) {
            AVBrandSurface.shellBackground
        } content: {
            homeHeader(isTabletLike: isTabletLayout)

            if let currentEntry = homeState.currentEntry {
                SeriesCurrentWatchingCard(
                    entry: currentEntry,
                    fillsPrimaryActionWidth: !isTabletLayout,
                    markPrevious: {
                        pendingProgressUndo = progressUndo(for: currentEntry)
                        pendingUndo = nil
                        store.markPreviousEpisodeWatched(for: currentEntry.id)
                    },
                    markNext: {
                        pendingProgressUndo = progressUndo(
                            for: currentEntry,
                            messageKey: progressCommitMessageKey(for: currentEntry)
                        )
                        pendingUndo = nil
                        markNextEpisodeWatchedKeepingStartedSeriesOnHome(currentEntry)
                    },
                    startWatching: {
                        pendingProgressUndo = progressUndo(for: currentEntry, messageKey: "home.undo.status")
                        pendingUndo = nil
                        store.setStatus(.watching, for: currentEntry.id)
                    },
                    markWatchedThrough: { cursor in
                        pendingProgressUndo = progressUndo(
                            for: currentEntry,
                            messageKey: progressCommitMessageKey(for: currentEntry)
                        )
                        pendingUndo = nil
                        markWatchedThroughKeepingStartedSeriesOnHome(cursor, for: currentEntry)
                    },
                    editProgress: {
                        editorEntry = currentEntry
                    },
                    togglePinned: {
                        store.setPinned(currentEntry.isPinnedHomeSeries != true, for: currentEntry.id)
                    },
                    openDetail: {
                        detailSelection = SeriesHomeDetailSelection(entry: currentEntry)
                    },
                    setStatus: { status in
                        pendingProgressUndo = progressUndo(for: currentEntry, messageKey: "home.undo.status")
                        pendingUndo = nil
                        store.setStatus(status, for: currentEntry.id)
                    },
                    archive: {
                        store.archive(currentEntry.id)
                        pendingProgressUndo = nil
                        pendingUndo = PendingLibraryUndo(entryId: currentEntry.id, title: currentEntry.title, messageKey: "home.undo.archived")
                    },
                    delete: {
                        store.delete(currentEntry.id)
                        pendingProgressUndo = nil
                        pendingUndo = PendingLibraryUndo(entryId: currentEntry.id, title: currentEntry.title, messageKey: "home.undo.deleted")
                    }
                )
            } else {
                SeriesEmptyWatchingView(openSearch: openSearch)
            }

            SeriesHomeAviBrief(
                currentEntry: homeState.currentEntry,
                watchingCount: homeState.watchingCount,
                wantToWatchCount: homeState.wantToWatchCount,
                openAvi: openAvi
            )

            SeriesHomeUpcomingEpisodesSection(
                entries: store.activeEntries,
                openLibrary: openLibraryTab
            )

            if homeState.readyToStartEntries.isEmpty == false {
                SeriesWatchingQueueSection(
                    entries: homeState.readyToStartEntries,
                    title: L10n.string("home.readyToStart.title"),
                    markNext: { entry in
                        pendingProgressUndo = progressUndo(
                            for: entry,
                            messageKey: progressCommitMessageKey(for: entry)
                        )
                        pendingUndo = nil
                        markNextEpisodeWatchedKeepingStartedSeriesOnHome(entry)
                    },
                    editProgress: { entry in
                        editorEntry = entry
                    },
                    togglePinned: { entry in
                        store.setPinned(entry.isPinnedHomeSeries != true, for: entry.id)
                    },
                    openDetail: { entry in
                        detailSelection = SeriesHomeDetailSelection(entry: entry)
                    },
                    setStatus: { entry, status in
                        pendingProgressUndo = progressUndo(for: entry, messageKey: "home.undo.status")
                        pendingUndo = nil
                        store.setStatus(status, for: entry.id)
                    },
                    archive: { entry in
                        store.archive(entry.id)
                        pendingProgressUndo = nil
                        pendingUndo = PendingLibraryUndo(entryId: entry.id, title: entry.title, messageKey: "home.undo.archived")
                    },
                    delete: { entry in
                        store.delete(entry.id)
                        pendingProgressUndo = nil
                        pendingUndo = PendingLibraryUndo(entryId: entry.id, title: entry.title, messageKey: "home.undo.deleted")
                    }
                )
            }

            if homeState.secondaryEntries.isEmpty == false {
                SeriesWatchingQueueSection(
                    entries: homeState.secondaryEntries,
                    title: L10n.string("home.queue.title"),
                    markNext: { entry in
                        pendingProgressUndo = progressUndo(
                            for: entry,
                            messageKey: progressCommitMessageKey(for: entry)
                        )
                        pendingUndo = nil
                        markNextEpisodeWatchedKeepingStartedSeriesOnHome(entry)
                    },
                    editProgress: { entry in
                        editorEntry = entry
                    },
                    togglePinned: { entry in
                        store.setPinned(entry.isPinnedHomeSeries != true, for: entry.id)
                    },
                    openDetail: { entry in
                        detailSelection = SeriesHomeDetailSelection(entry: entry)
                    },
                    setStatus: { entry, status in
                        pendingProgressUndo = progressUndo(for: entry, messageKey: "home.undo.status")
                        pendingUndo = nil
                        store.setStatus(status, for: entry.id)
                    },
                    archive: { entry in
                        store.archive(entry.id)
                        pendingProgressUndo = nil
                        pendingUndo = PendingLibraryUndo(entryId: entry.id, title: entry.title, messageKey: "home.undo.archived")
                    },
                    delete: { entry in
                        store.delete(entry.id)
                        pendingProgressUndo = nil
                        pendingUndo = PendingLibraryUndo(entryId: entry.id, title: entry.title, messageKey: "home.undo.deleted")
                    }
                )
            }

            if shouldShowHomeDiscoveryFailure {
                SeriesHomeDiscoveryFailureView {
                    Task {
                        await refreshHomeDiscovery(force: true)
                    }
                }
            }

        SeriesHomeDiscoveryRail(
            title: L10n.string("home.rail.popular"),
            previews: homeState.visiblePopularPreviews,
            isLoading: isLoadingHomeDiscovery,
            isTabletLayout: isTabletLayout,
            canAddSeries: canAddSeries,
            limitActionTitle: limitActionTitle,
            addSeries: addDiscoverySeries,
            openDetail: { preview in
                detailSelection = SeriesHomeDetailSelection(catalogItem: preview.catalogItem, entry: nil)
            },
            showLimitAction: showLimitAction
            )

        SeriesHomeDiscoveryRail(
            title: L10n.string("upcoming.home.title"),
            previews: homeState.visibleUpcomingPreviews,
            isLoading: isLoadingHomeDiscovery,
            isTabletLayout: isTabletLayout,
            canAddSeries: canAddSeries,
            limitActionTitle: limitActionTitle,
            addSeries: addDiscoverySeries,
            openDetail: { preview in
                detailSelection = SeriesHomeDetailSelection(catalogItem: preview.catalogItem, entry: nil)
            },
            showLimitAction: showLimitAction
            )

        SeriesHomeDiscoveryRail(
            title: L10n.string("home.rail.recommended"),
            previews: homeState.visibleRecommendedPreviews,
            isLoading: isLoadingHomeDiscovery,
            isTabletLayout: isTabletLayout,
            canAddSeries: canAddSeries,
            limitActionTitle: limitActionTitle,
            addSeries: addDiscoverySeries,
            openDetail: { preview in
                detailSelection = SeriesHomeDetailSelection(catalogItem: preview.catalogItem, entry: nil)
            },
            showLimitAction: showLimitAction
            )
        }
        .safeAreaInset(edge: .bottom) {
            if !isTabletLayout && hasPendingHomeUndo {
                mobileHomeBottomBar
            }
        }
        .sheet(item: $editorEntry) { entry in
            SeriesProgressEditorSheet(
                entry: entry,
                markWatchedThrough: { cursor in
                    pendingProgressUndo = progressUndo(
                        for: entry,
                        messageKey: progressCommitMessageKey(for: entry)
                    )
                    pendingUndo = nil
                    markWatchedThroughKeepingStartedSeriesOnHome(cursor, for: entry)
                },
                clearProgress: {
                    pendingProgressUndo = progressUndo(for: entry)
                    pendingUndo = nil
                    store.clearProgress(for: entry.id)
                }
            )
            .presentationDetents([.large])
        }
        .sheet(item: $detailSelection) { selection in
            SeriesDetailScreen(
                catalogItem: selection.catalogItem,
                entry: selection.entry,
                canFollow: canAddSeries,
                follow: selection.entry == nil ? {
                    if canAddSeries, let catalogItem = selection.catalogItem {
                        _ = store.addCatalogSeries(catalogItem)
                        detailSelection = nil
                    } else {
                        showLimitAction()
                    }
                } : nil,
                markNext: { entry in
                    pendingProgressUndo = progressUndo(
                        for: entry,
                        messageKey: progressCommitMessageKey(for: entry)
                    )
                    pendingUndo = nil
                    markNextEpisodeWatchedKeepingStartedSeriesOnHome(entry)
                },
                markWatchedThrough: { entry, cursor in
                    pendingProgressUndo = progressUndo(
                        for: entry,
                        messageKey: progressCommitMessageKey(for: entry)
                    )
                    pendingUndo = nil
                    markWatchedThroughKeepingStartedSeriesOnHome(cursor, for: entry)
                },
                clearProgress: { entry in
                    pendingProgressUndo = progressUndo(for: entry)
                    pendingUndo = nil
                    store.clearProgress(for: entry.id)
                },
                setPinned: { entry, isPinned in
                    store.setPinned(isPinned, for: entry.id)
                },
                setPrivateNote: { entry, note in
                    store.setPrivateNote(note, for: entry.id)
                },
                archive: { entry in
                    store.archive(entry.id)
                    pendingProgressUndo = nil
                    pendingUndo = PendingLibraryUndo(entryId: entry.id, title: entry.title, messageKey: "home.undo.archived")
                },
                delete: { entry in
                    store.delete(entry.id)
                    pendingProgressUndo = nil
                    pendingUndo = PendingLibraryUndo(entryId: entry.id, title: entry.title, messageKey: "home.undo.deleted")
                },
                shareInviteClient: shareInviteClient
            )
            .presentationDetents([.large])
        }
        .sheet(isPresented: $isShowingProPaywall) {
            SeriesProPaywallView(
                accessController: accessController,
                startSignInFlow: startSignInFlow
            )
        }
        .task {
            await loadHomeDiscoveryIfNeeded()
        }
        .onAppear {
            if SeriesUITestEnvironment.current.shouldShowProgressEditor, editorEntry == nil {
                if let requestedEntryId = SeriesUITestEnvironment.current.progressEditorEntryId,
                   let requestedEntry = store.entries.first(where: { $0.id == requestedEntryId }) {
                    editorEntry = requestedEntry
                } else {
                    editorEntry = homeState.currentEntry ?? store.activeEntries.first
                }
            }
        }
        .task(id: missingArtworkSignature) {
            await reconcileMissingArtwork()
        }
    }

    private var activeLibraryLimitPolicy: SeriesActiveLibraryLimitPolicy {
        SeriesActiveLibraryLimitPolicy(
            activeCount: store.activeEntries.count,
            activeLimit: activeSeriesLimit
        )
    }

    private var canAddSeries: Bool {
        activeLibraryLimitPolicy.canAddSeries
    }

    private var remainingSeriesCount: Int? {
        activeLibraryLimitPolicy.remainingSeriesCount
    }

    private var shareInviteClient: SeriesShareInviteClient? {
        guard accessController.isSignedIn else { return nil }
        return SeriesShareInviteClient(apiClient: accessController.authenticatedAPIClient())
    }

    private var entriesNeedingCatalogMetadata: [SeriesLibraryEntry] {
        store.activeEntries.filter { $0.displayArtworkRef?.isEmpty != false || $0.latestKnownEpisodeCursor == nil || $0.knownEpisodeCount == nil }
    }

    private var missingArtworkSignature: String {
        entriesNeedingCatalogMetadata
            .map { "\($0.entryId):\($0.seriesId):\($0.title):\($0.displayArtworkRef ?? "-"):\(String(describing: $0.latestKnownEpisodeCursor)):\(String(describing: $0.knownEpisodeCount))" }
            .joined(separator: "|")
    }

    private func progressUndo(
        for entry: SeriesLibraryEntry,
        messageKey: String = "home.undo.progress"
    ) -> PendingProgressUndo {
        PendingProgressUndo(
            entryId: entry.id,
            title: entry.title,
            messageKey: messageKey,
            status: entry.status,
            lastWatchedEpisodeCursor: entry.lastWatchedEpisodeCursor,
            isPinnedHomeSeries: entry.isPinnedHomeSeries
        )
    }

    private func progressCommitMessageKey(for entry: SeriesLibraryEntry) -> String {
        entry.status == .wantToWatch ? "home.undo.nowWatching" : "home.undo.progress"
    }

    private func markNextEpisodeWatchedKeepingStartedSeriesOnHome(_ entry: SeriesLibraryEntry) {
        store.markNextEpisodeWatched(
            for: entry.id,
            pinOnHomeWhenStarting: entry.status == .wantToWatch
        )
    }

    private func markWatchedThroughKeepingStartedSeriesOnHome(
        _ cursor: SeriesEpisodeCursor,
        for entry: SeriesLibraryEntry
    ) {
        store.markWatchedThrough(
            cursor,
            for: entry.id,
            pinOnHomeWhenStarting: entry.status == .wantToWatch
        )
    }

    private func addDiscoverySeries(_ preview: SeriesHomeDiscoveryPreview) {
        guard canAddSeries else {
            showLimitAction()
            return
        }

        Task {
            guard let entry = store.addCatalogSeries(preview.catalogItem) else {
                return
            }

            pendingProgressUndo = nil
            pendingUndo = PendingLibraryUndo(entryId: entry.id, title: entry.title, messageKey: "home.undo.added")
            editorEntry = entry
        }
    }

    private var isLoadingHomeDiscovery: Bool {
        homeDiscoveryLoadState == .loading
    }

    private var homeDiscoverySnapshot: SeriesHomeDiscoverySnapshot {
        SeriesHomeDiscoverySnapshot(
            popular: popularPreviews,
            upcoming: upcomingPreviews,
            recommended: recommendedPreviews
        )
    }

    private var shouldShowHomeDiscoveryFailure: Bool {
        homeDiscoveryLoadState == .failed && homeDiscoverySnapshot.hasContent == false
    }

    private func loadHomeDiscoveryIfNeeded() async {
        if let cachedSnapshot = SeriesHomeDiscoverySessionCache.value() {
            applyHomeDiscoverySnapshot(cachedSnapshot)
            homeDiscoveryLoadState = .loaded
            reconcileMissingArtwork(
                from: cachedSnapshot.popular + cachedSnapshot.upcoming + cachedSnapshot.recommended
            )
            return
        }

        await refreshHomeDiscovery(force: false)
    }

    private func refreshHomeDiscovery(force: Bool) async {
        guard homeDiscoveryLoadState != .loading else {
            return
        }

        if force == false, let cachedSnapshot = SeriesHomeDiscoverySessionCache.value() {
            applyHomeDiscoverySnapshot(cachedSnapshot)
            homeDiscoveryLoadState = .loaded
            return
        }

        homeDiscoveryLoadState = .loading

        if shouldSimulateHomeDiscoveryFailure {
            uiTestHomeDiscoveryLoadAttempts += 1
            homeDiscoveryLoadState = homeDiscoverySnapshot.hasContent ? .loaded : .failed
            return
        }

        let client = SeriesCatalogSearchClient()
        async let popular = try? client.popular(locale: Locale.current.identifier, surface: "home", limit: 18)
        async let upcoming = try? client.popular(locale: Locale.current.identifier, surface: "upcoming", limit: 18)
        async let recommended = try? client.popular(locale: Locale.current.identifier, surface: "avi", limit: 18)

        let responses = await (popular, upcoming, recommended)
        var didCompleteRequest = false

        if let response = responses.0 {
            popularPreviews = response.results.map { SeriesHomeDiscoveryPreview(catalogItem: $0) }
            didCompleteRequest = true
        }
        if let response = responses.1 {
            upcomingPreviews = response.results.map { SeriesHomeDiscoveryPreview(catalogItem: $0) }
            didCompleteRequest = true
        }
        if let response = responses.2 {
            recommendedPreviews = response.results.map { SeriesHomeDiscoveryPreview(catalogItem: $0) }
            didCompleteRequest = true
        }

        let snapshot = homeDiscoverySnapshot
        if didCompleteRequest {
            SeriesHomeDiscoverySessionCache.store(snapshot)
            homeDiscoveryLoadState = .loaded
            reconcileMissingArtwork(from: snapshot.popular + snapshot.upcoming + snapshot.recommended)
        } else {
            homeDiscoveryLoadState = snapshot.hasContent ? .loaded : .failed
        }
    }

    private var shouldSimulateHomeDiscoveryFailure: Bool {
        switch SeriesUITestEnvironment.current.homeDiscoveryScenario {
        case "failed":
            return true
        case "failed_once":
            return uiTestHomeDiscoveryLoadAttempts == 0
        default:
            return false
        }
    }

    private func applyHomeDiscoverySnapshot(_ snapshot: SeriesHomeDiscoverySnapshot) {
        popularPreviews = snapshot.popular
        upcomingPreviews = snapshot.upcoming
        recommendedPreviews = snapshot.recommended
    }

    private func reconcileMissingArtwork(from previews: [SeriesHomeDiscoveryPreview]) {
        for entry in entriesNeedingCatalogMetadata {
            guard let preview = previews.first(where: { SeriesLibraryIdentity.sameSeries(entry, $0.catalogItem) }) else {
                continue
            }
            store.updateCatalogMetadata(
                for: entry.entryId,
                displayArtworkRef: preview.catalogItem.displayArtworkRef,
                fallbackVisualSeed: preview.title,
                latestKnownEpisodeCursor: preview.catalogItem.latestKnownEpisodeCursor,
                knownEpisodeCount: preview.catalogItem.knownEpisodeCount
            )
        }
    }

    private func reconcileMissingArtwork() async {
        let signature = missingArtworkSignature
        guard signature.isEmpty == false, signature != artworkReconciliationSignature else {
            return
        }
        artworkReconciliationSignature = signature

        let client = SeriesCatalogSearchClient()
        for entry in entriesNeedingCatalogMetadata.prefix(6) {
            let normalizedTitle = SeriesLibraryIdentity.normalizedSearchText(entry.title)
            guard let response = try? await client.search(query: entry.title, locale: Locale.current.identifier, limit: 4),
                  let catalogItem = response.results.first(where: { SeriesLibraryIdentity.sameSeries(entry, $0) })
                    ?? response.results.first(where: { SeriesLibraryIdentity.normalizedSearchText($0.title) == normalizedTitle }) else {
                continue
            }

            store.updateCatalogMetadata(
                for: entry.entryId,
                displayArtworkRef: catalogItem.displayArtworkRef,
                fallbackVisualSeed: catalogItem.title,
                latestKnownEpisodeCursor: catalogItem.latestKnownEpisodeCursor,
                knownEpisodeCount: catalogItem.knownEpisodeCount
            )
        }
    }

    private func showLimitAction() {
        switch accessController.accessMode {
        case .guest:
            startSignInFlow()
        case .signedInFree:
            isShowingProPaywall = true
        case .signedInPro:
            break
        }
    }

    private var limitActionTitle: String {
        switch accessController.accessMode {
        case .guest:
            accessController.accountIsAvailable ? L10n.string("add.footer.connectAccount") : L10n.string("profile.account.connectUnavailable")
        case .signedInFree, .signedInPro:
            L10n.string("add.footer.upgrade")
        }
    }

    @ViewBuilder
    private func homeHeader(isTabletLike: Bool) -> some View {
        if isTabletLike {
            AVAppShellScreenHeader(
                title: L10n.string("home.header.title"),
                subtitle: L10n.string("home.header.subtitle")
            )
            .padding(.bottom, 8)
        } else {
            AVAppShellHomeHeader(
                title: L10n.string("home.header.title"),
                subtitle: L10n.string("home.header.subtitle")
            ) {
                AVAppShellConfiguredBrandHeader(
                    activeItem: nil,
                    openSettings: openSettings,
                    openAccount: openAccount
                )
            }
            .padding(.bottom, 8)
        }
    }

    private var mobileHomeBottomBar: some View {
        VStack(spacing: 10) {
            if let pendingProgressUndo {
                SeriesUndoBar(
                    title: String(format: L10n.string(pendingProgressUndo.messageKey), pendingProgressUndo.title),
                    undo: {
                        store.restoreProgress(
                            status: pendingProgressUndo.status,
                            lastWatchedEpisodeCursor: pendingProgressUndo.lastWatchedEpisodeCursor,
                            isPinnedHomeSeries: pendingProgressUndo.isPinnedHomeSeries,
                            for: pendingProgressUndo.entryId
                        )
                        self.pendingProgressUndo = nil
                    },
                    dismiss: {
                        self.pendingProgressUndo = nil
                    }
                )
            } else if let pendingUndo {
                SeriesUndoBar(
                    title: String(format: L10n.string(pendingUndo.messageKey), pendingUndo.title),
                    undo: {
                        if pendingUndo.messageKey == "home.undo.added" {
                            store.delete(pendingUndo.entryId)
                        } else {
                            store.restore(pendingUndo.entryId)
                        }
                        self.pendingUndo = nil
                    },
                    dismiss: {
                        self.pendingUndo = nil
                    }
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 88)
        .background(.regularMaterial)
    }

    private var hasPendingHomeUndo: Bool {
        pendingProgressUndo != nil || pendingUndo != nil
    }

}

private struct SeriesHomeDiscoveryFailureView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let retry: () -> Void

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityContent
            } else {
                standardContent
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.discovery.failure")
    }

    private var standardContent: some View {
        HStack(spacing: 12) {
            failureIcon(size: 38)
            failureMessage
            Spacer(minLength: 8)
            retryButton(fillsAvailableWidth: false, minHeight: 44)
        }
    }

    private var accessibilityContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                failureIcon(size: 42)
                failureMessage
            }

            retryButton(fillsAvailableWidth: true, minHeight: 52)
        }
        .dynamicTypeSize(.xSmall ... .accessibility1)
    }

    private var failureMessage: some View {
        Text(L10n.string("home.discovery.failure"))
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func failureIcon(size: CGFloat) -> some View {
        Image(systemName: "wifi.exclamationmark")
            .font(.headline.weight(.bold))
            .foregroundStyle(AVBrandColor.accent)
            .frame(width: size, height: size)
            .background(AVBrandColor.accent.opacity(0.14), in: Circle())
            .accessibilityHidden(true)
    }

    private func retryButton(fillsAvailableWidth: Bool, minHeight: CGFloat) -> some View {
        Button(action: retry) {
            Label(L10n.string("common.retry"), systemImage: "arrow.clockwise")
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: fillsAvailableWidth ? .infinity : nil, minHeight: minHeight)
                .padding(.horizontal, 12)
        }
        .buttonStyle(.bordered)
        .tint(AVBrandColor.accent)
        .accessibilityIdentifier("home.discovery.retry")
    }
}

private struct SeriesHomeAviBrief: View {
    let currentEntry: SeriesLibraryEntry?
    let watchingCount: Int
    let wantToWatchCount: Int
    let openAvi: () -> Void

    @Environment(\.avCommonAppExperience) private var appExperience
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: openAvi) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    accessibilityContent
                } else {
                    standardContent
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground).opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.string("home.aviBrief.action"))
        .accessibilityValue(briefDetail)
        .accessibilityIdentifier("home.aviBrief.open")
    }

    private var standardContent: some View {
        HStack(spacing: 12) {
            assistantAvatar(size: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(appExperience.identity.assistantName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AVBrandColor.textPrimary)

                Text(briefDetail)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            actionIcon(size: 34, font: .caption.weight(.black))
        }
    }

    private var accessibilityContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                assistantAvatar(size: 40)

                Text(appExperience.identity.assistantName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(AVBrandColor.textPrimary)

                Spacer(minLength: 8)

                actionIcon(size: 40, font: .headline.weight(.black))
            }

            Text(briefDetail)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .dynamicTypeSize(.xSmall ... .accessibility1)
    }

    private func assistantAvatar(size: CGFloat) -> some View {
        Image("AviOnboardingCTA")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private func actionIcon(size: CGFloat, font: Font) -> some View {
        Image(systemName: "sparkles")
            .font(font)
            .foregroundStyle(Color.black.opacity(0.78))
            .frame(width: size, height: size)
            .background(AVBrandColor.accent, in: Circle())
            .accessibilityHidden(true)
    }

    private var briefDetail: String {
        if let currentEntry {
            return L10n.string("home.aviBrief.watching", currentEntry.title, currentEntry.progressLabel)
        }

        if watchingCount > 0 || wantToWatchCount > 0 {
            return L10n.string("home.aviBrief.library", watchingCount, wantToWatchCount)
        }

        return L10n.string("home.aviBrief.empty")
    }
}

struct PendingLibraryUndo: Identifiable, Equatable {
    var entryId: String
    var title: String
    var messageKey: String

    var id: String { "\(entryId)-\(messageKey)" }
}

enum PendingLibraryMutationUndoAction: Equatable {
    case restoreActive
    case restoreArchived
    case archive
}

struct PendingLibraryMutationUndo: Identifiable, Equatable {
    var entryId: String
    var title: String
    var messageKey: String
    var action: PendingLibraryMutationUndoAction

    var id: String { "\(entryId)-\(messageKey)" }
}

struct PendingProgressUndo: Identifiable, Equatable {
    var entryId: String
    var title: String
    var messageKey: String
    var status: SeriesLibraryEntryStatus
    var lastWatchedEpisodeCursor: SeriesEpisodeCursor?
    var isPinnedHomeSeries: Bool?

    var id: String { "\(entryId)-\(messageKey)" }
}

struct SeriesUndoBar: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let undo: () -> Void
    let dismiss: () -> Void

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityLayout
            } else {
                standardLayout
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("series.undo.bar")
    }

    private var standardLayout: some View {
        HStack(spacing: 10) {
            message(lineLimit: 2)
                .layoutPriority(1)

            Spacer(minLength: 0)

            undoButton
            dismissButton
        }
    }

    private var accessibilityLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            message(lineLimit: nil)

            HStack(spacing: 8) {
                undoButton

                Spacer(minLength: 8)

                dismissButton
            }
        }
    }

    private func message(lineLimit: Int?) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .lineLimit(lineLimit)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("series.undo.message")
    }

    private var undoButton: some View {
        Button(action: undo) {
            Text(L10n.string("home.undo"))
                .font(.subheadline.weight(.bold))
                .frame(minHeight: 44)
                .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
        .contentShape(Rectangle())
        .accessibilityIdentifier("series.undo.action")
    }

    private var dismissButton: some View {
        Button(action: dismiss) {
            Image(systemName: "xmark")
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .accessibilityLabel(L10n.string("common.close"))
        .accessibilityIdentifier("series.undo.dismiss")
    }
}

struct SeriesLibraryRow<MenuContent: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let entry: SeriesLibraryEntry
    let detail: String
    let openDetail: () -> Void
    let markNext: (() -> Void)?
    @ViewBuilder let menuContent: () -> MenuContent

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityLayout
            } else if horizontalSizeClass == .compact {
                compactLayout
            } else {
                regularLayout
            }
        }
        .padding(.vertical, horizontalSizeClass == .compact ? 0 : 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("series-library-row-\(entry.id)")
    }

    private var regularLayout: some View {
        HStack(spacing: 12) {
            detailButton

            Spacer()

            progressButton(minHeight: 36)
            actionsMenu
        }
    }

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: 6) {
            detailButton

            HStack(spacing: 10) {
                Spacer(minLength: 48)
                progressButton(minHeight: 44)
                actionsMenu
            }
        }
    }

    private var accessibilityLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            detailButton

            if markNext != nil {
                progressButton(minHeight: 52, fillsAvailableWidth: true, titleLineLimit: 2)
            }

            HStack {
                Spacer()
                actionsMenu
            }
        }
    }

    private var detailButton: some View {
        Button(action: openDetail) {
            rowContent
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(entry.title)
        .accessibilityHint(L10n.string("detail.open"))
    }

    @ViewBuilder
    private func progressButton(
        minHeight: CGFloat,
        fillsAvailableWidth: Bool = false,
        titleLineLimit: Int = 1
    ) -> some View {
        if let markNext {
            SeriesProgressPillButton(
                title: progressDisplayTitle,
                systemName: quickProgressFilledSystemImage(for: entry),
                style: .accent,
                accessibilityLabel: quickProgressAccessibilityLabel,
                accessibilityIdentifier: "series-row-\(entry.id)-quick-progress",
                minHeight: minHeight,
                fillsAvailableWidth: fillsAvailableWidth,
                isDisabled: !entry.canMarkNextEpisodeFromKnownGuide,
                titleFont: dynamicTypeSize.isAccessibilitySize
                    ? .caption2.weight(.black)
                    : .caption.weight(.black),
                titleLineLimit: titleLineLimit,
                action: markNext
            )
        }
    }

    private var actionsMenu: some View {
        Menu {
            menuContent()
        } label: {
            Image(systemName: "ellipsis")
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(L10n.string("home.actions"))
    }

    private var quickProgressAccessibilityLabel: String {
        primaryProgressActionTitle(for: entry)
    }

    private var progressDisplayTitle: String {
        let title = compactProgressActionTitle(for: entry)
        guard dynamicTypeSize.isAccessibilitySize else {
            return title
        }

        let cursor = cursorLabel(entry.nextEpisodeCursor)
        guard let cursorRange = title.range(of: cursor) else {
            return title
        }

        let prefix = title[..<cursorRange.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        let suffix = title[cursorRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
        return [prefix, cursor, suffix]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            SeriesEntryArtworkView(entry: entry, size: dynamicTypeSize.isAccessibilitySize ? 48 : 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)
        }
    }
}

private struct SeriesCurrentWatchingCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let entry: SeriesLibraryEntry
    let fillsPrimaryActionWidth: Bool
    let markPrevious: () -> Void
    let markNext: () -> Void
    let startWatching: () -> Void
    let markWatchedThrough: (SeriesEpisodeCursor) -> Void
    let editProgress: () -> Void
    let togglePinned: () -> Void
    let openDetail: () -> Void
    let setStatus: (SeriesLibraryEntryStatus) -> Void
    let archive: () -> Void
    let delete: () -> Void

    @State private var isShowingProgressSelector = false

    init(
        entry: SeriesLibraryEntry,
        fillsPrimaryActionWidth: Bool,
        markPrevious: @escaping () -> Void,
        markNext: @escaping () -> Void,
        startWatching: @escaping () -> Void,
        markWatchedThrough: @escaping (SeriesEpisodeCursor) -> Void,
        editProgress: @escaping () -> Void,
        togglePinned: @escaping () -> Void,
        openDetail: @escaping () -> Void,
        setStatus: @escaping (SeriesLibraryEntryStatus) -> Void,
        archive: @escaping () -> Void,
        delete: @escaping () -> Void
    ) {
        self.entry = entry
        self.fillsPrimaryActionWidth = fillsPrimaryActionWidth
        self.markPrevious = markPrevious
        self.markNext = markNext
        self.startWatching = startWatching
        self.markWatchedThrough = markWatchedThrough
        self.editProgress = editProgress
        self.togglePinned = togglePinned
        self.openDetail = openDetail
        self.setStatus = setStatus
        self.archive = archive
        self.delete = delete
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            heroTopBar
            heroMain
            heroControls
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(heroBackground)
        .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home-current-card")
        .sheet(isPresented: $isShowingProgressSelector) {
            SeriesProgressEditorSheet(
                entry: entry,
                markWatchedThrough: { cursor in
                    markWatchedThrough(cursor)
                },
                clearProgress: {}
            )
            .presentationDetents([.large])
        }
    }

    private var heroTopBar: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(currentTitle)
                .font(.system(size: 11, weight: .black))
                .tracking(0.7)
                .foregroundStyle(topPillTextColor)
                .textCase(.uppercase)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(topPillFill, in: Capsule())
                .overlay {
                    Capsule().stroke(topPillStroke, lineWidth: 1)
                }

            Text(currentProgressShort)
                .font(.system(size: 11, weight: .black))
                .tracking(0.4)
                .foregroundStyle(topPillTextColor.opacity(0.84))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(topPillFill.opacity(0.72), in: Capsule())
                .overlay {
                    Capsule().stroke(topPillStroke.opacity(0.72), lineWidth: 1)
                }

            Spacer(minLength: 0)
            actionsMenu
        }
    }

    private var heroMain: some View {
        Button(action: openDetail) {
            HStack(alignment: .bottom, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(entry.title)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(heroTitleColor)
                        .lineLimit(2)
                        .minimumScaleFactor(0.62)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 7) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AVBrandColor.accent)
                        Text(String(format: L10n.string("home.current.nextEpisode"), cursorLabel(entry.nextEpisodeCursor)))
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(heroTitleColor.opacity(0.82))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(heroControlSurface, in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(heroControlStroke, lineWidth: 1)
                    }
                }
                .layoutPriority(1)

                SeriesEntryArtworkView(entry: entry, size: 70)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(entry.title)
        .accessibilityHint(L10n.string("detail.open"))
    }

    private var heroControls: some View {
        HStack(spacing: 10) {
            SeriesProgressPillButton(
                title: primaryActionTitle,
                systemName: primaryIconName,
                style: .accent,
                accessibilityLabel: primaryActionAccessibilityLabel,
                accessibilityIdentifier: "home-current-primary-action",
                minHeight: 50,
                fillsAvailableWidth: fillsPrimaryActionWidth,
                isDisabled: !entry.canMarkNextEpisodeFromKnownGuide,
                action: primaryAction
            )

            Button {
                isShowingProgressSelector = true
            } label: {
                Image(systemName: "scope")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(heroControlIconColor)
                    .frame(width: 46, height: 46)
                    .background(heroControlSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(heroControlStroke, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(progressEditTitle)

            if entry.lastWatchedEpisodeCursor?.canStepBackQuickly == true {
                Button(action: markPrevious) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(heroControlIconColor)
                        .frame(width: 46, height: 46)
                        .background(heroControlSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(heroControlStroke, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(L10n.string("home.previous")), \(previousLabel)")
            }

            Spacer(minLength: 0)
        }
    }

    private var actionsMenu: some View {
        SeriesEntryActionsMenu(
            entry: entry,
            togglePinned: togglePinned,
            openDetail: openDetail,
            setStatus: setStatus,
            archive: archive,
            delete: delete
        )
    }

    private var currentTitle: String {
        entry.status == .wantToWatch
            ? L10n.string("home.current.wantToWatch.title")
            : L10n.string("home.current.title")
    }

    private var currentProgress: String {
        guard entry.status != .wantToWatch else {
            return String(format: L10n.string("home.queue.wantToWatch.progress"), cursorLabel(entry.nextEpisodeCursor))
        }
        guard entry.lastWatchedEpisodeCursor != nil else {
            return String(format: L10n.string("home.current.nextEpisode"), cursorLabel(entry.nextEpisodeCursor))
        }
        return String(format: L10n.string("home.current.progress"), entry.progressLabel)
    }

    private var currentProgressShort: String {
        if let lastWatchedEpisodeCursor = entry.lastWatchedEpisodeCursor {
            return cursorLabel(lastWatchedEpisodeCursor)
        }
        return cursorLabel(entry.nextEpisodeCursor)
    }

    private var primaryActionTitle: String {
        entry.status == .wantToWatch
            ? primaryProgressActionTitle(for: entry)
            : String(format: L10n.string("home.action.markEpisodeWatched"), cursorLabel(entry.nextEpisodeCursor))
    }

    private var primaryActionAccessibilityLabel: String {
        entry.status == .wantToWatch
            ? "\(L10n.string("home.start")), \(cursorLabel(entry.nextEpisodeCursor))"
            : primaryActionTitle
    }

    private var primaryIconName: String {
        entry.status == .wantToWatch ? "play.fill" : "checkmark"
    }

    private var primaryAction: () -> Void {
        entry.status == .wantToWatch ? startWatching : markNext
    }

    private var progressEditTitle: String {
        entry.lastWatchedEpisodeCursor == nil ? L10n.string("home.chooseEpisode") : L10n.string("home.adjust")
    }

    private var previousLabel: String {
        guard let cursor = entry.lastWatchedEpisodeCursor?.previousEpisode else {
            return L10n.string("home.notStarted")
        }
        return cursorLabel(cursor)
    }

    private var heroBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)

        return ZStack(alignment: .bottomTrailing) {
            SeriesEntryArtworkView(entry: entry, size: 210)
                .scaleEffect(1.16)
                .opacity(colorScheme == .dark ? 0.13 : 0.16)
                .blur(radius: 2)
                .offset(x: 54, y: 56)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .clipShape(shape)

            shape
                .fill(
                    LinearGradient(
                        colors: heroBackgroundColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .opacity(colorScheme == .dark ? 0.96 : 0.92)

            Image("AviOnboardingCTA")
                .resizable()
                .scaledToFit()
                .frame(width: 190)
                .opacity(colorScheme == .dark ? 0.08 : 0.12)
                .offset(x: 46, y: 28)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .clipShape(shape)
        .overlay {
            shape.stroke(heroBorderColor, lineWidth: 1)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.22 : 0.10), radius: 18, y: 8)
    }

    private var heroBackgroundColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(red: 0.13, green: 0.16, blue: 0.14),
                Color(red: 0.08, green: 0.10, blue: 0.09)
            ]
        }

        return [
            Color(red: 0.99, green: 0.98, blue: 0.94),
            Color(red: 0.95, green: 0.97, blue: 0.92)
        ]
    }

    private var heroTitleColor: Color {
        colorScheme == .dark ? .white : Color(red: 0.18, green: 0.19, blue: 0.17)
    }

    private var heroControlSurface: Color {
        colorScheme == .dark ? Color.white.opacity(0.13) : Color.white.opacity(0.76)
    }

    private var heroControlIconColor: Color {
        colorScheme == .dark ? .white.opacity(0.92) : Color(red: 0.18, green: 0.19, blue: 0.17)
    }

    private var heroControlStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.10)
    }

    private var heroBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.10)
    }

    private var topPillFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.72)
    }

    private var topPillStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.10)
    }

    private var topPillTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.84) : Color(red: 0.18, green: 0.19, blue: 0.17).opacity(0.78)
    }
}

private struct SeriesWatchingQueueSection: View {
    let entries: [SeriesLibraryEntry]
    let title: String
    let markNext: (SeriesLibraryEntry) -> Void
    let editProgress: (SeriesLibraryEntry) -> Void
    let togglePinned: (SeriesLibraryEntry) -> Void
    let openDetail: (SeriesLibraryEntry) -> Void
    let setStatus: (SeriesLibraryEntry, SeriesLibraryEntryStatus) -> Void
    let archive: (SeriesLibraryEntry) -> Void
    let delete: (SeriesLibraryEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                ForEach(entries) { entry in
                    HStack(spacing: 12) {
                        Button {
                            openDetail(entry)
                        } label: {
                            HStack(spacing: 12) {
                                SeriesEntryArtworkView(entry: entry, size: 42)
                                    .accessibilityHidden(true)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(entry.title)
                                        .font(.system(size: 15, weight: .semibold))
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.82)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(queueProgress(for: entry))
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.76)
                                        .allowsTightening(true)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .layoutPriority(1)

                                Spacer(minLength: 0)
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .accessibilityLabel(entry.title)
                        .accessibilityHint(L10n.string("detail.open"))

                        SeriesProgressPillButton(
                            title: compactProgressActionTitle(for: entry),
                            systemName: quickProgressFilledSystemImage(for: entry),
                            style: .accent,
                            accessibilityLabel: primaryActionTitle(for: entry),
                            accessibilityIdentifier: "series-queue-\(entry.id)-quick-progress",
                            minHeight: 36,
                            isDisabled: !entry.canMarkNextEpisodeFromKnownGuide
                        ) {
                            markNext(entry)
                        }

                        SeriesEntryActionsMenu(
                            entry: entry,
                            togglePinned: { togglePinned(entry) },
                            openDetail: { openDetail(entry) },
                            editProgress: { editProgress(entry) },
                            setStatus: { setStatus(entry, $0) },
                            archive: { archive(entry) },
                            delete: { delete(entry) }
                        )
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 12)
                    .frame(minHeight: 68)
                    .background(Color(.secondarySystemGroupedBackground).opacity(0.72), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground).opacity(0.44), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func queueProgress(for entry: SeriesLibraryEntry) -> String {
        guard entry.status != .wantToWatch else {
            return String(format: L10n.string("home.queue.wantToWatch.progress"), cursorLabel(entry.nextEpisodeCursor))
        }
        return "\(entry.progressLabel) → \(cursorLabel(entry.nextEpisodeCursor))"
    }

    private func primaryActionTitle(for entry: SeriesLibraryEntry) -> String {
        primaryProgressActionTitle(for: entry)
    }
}

private struct SeriesHomeDiscoveryRail: View {
    private static let tabletGridSpacing: CGFloat = 14
    private static let tabletMaxDisplayCount = 18

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let previews: [SeriesHomeDiscoveryPreview]
    let isLoading: Bool
    let isTabletLayout: Bool
    let canAddSeries: Bool
    let limitActionTitle: String
    let addSeries: (SeriesHomeDiscoveryPreview) -> Void
    let openDetail: (SeriesHomeDiscoveryPreview) -> Void
    let showLimitAction: () -> Void

    @State private var tabletGridWidth: CGFloat = 0

    var body: some View {
        if isLoading || previews.isEmpty == false {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)
                    .dynamicTypeSize(.xSmall ... .accessibility1)

                if isTabletLayout {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: cardItemWidth, maximum: cardItemWidth), spacing: Self.tabletGridSpacing, alignment: .top)],
                        alignment: .leading,
                        spacing: 18
                    ) {
                        discoveryCards(skeletonCount: tabletSkeletonCount, displayPreviews: tabletDisplayPreviews)
                    }
                    .padding(.vertical, 3)
                    .background {
                        GeometryReader { proxy in
                            Color.clear.preference(key: SeriesHomeDiscoveryRailWidthKey.self, value: proxy.size.width)
                        }
                    }
                    .onPreferenceChange(SeriesHomeDiscoveryRailWidthKey.self) { width in
                        tabletGridWidth = width
                    }
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 12) {
                            discoveryCards(skeletonCount: 4, displayPreviews: previews)
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
            .padding(.top, 6)
        }
    }

    private var tabletDisplayPreviews: [SeriesHomeDiscoveryPreview] {
        Array(previews.prefix(tabletDisplayCount(availableCount: previews.count)))
    }

    private var tabletSkeletonCount: Int {
        let columns = tabletColumnCount
        return max(columns, min(Self.tabletMaxDisplayCount, columns * 2))
    }

    private func tabletDisplayCount(availableCount: Int) -> Int {
        guard availableCount > 0 else {
            return 0
        }

        let cappedCount = min(availableCount, Self.tabletMaxDisplayCount)
        let columns = tabletColumnCount
        let completeRowsCount = cappedCount - cappedCount % columns
        return completeRowsCount >= columns ? completeRowsCount : cappedCount
    }

    private var tabletColumnCount: Int {
        guard tabletGridWidth > 0 else {
            return 4
        }

        let columnStride = cardItemWidth + Self.tabletGridSpacing
        return max(1, Int((tabletGridWidth + Self.tabletGridSpacing) / columnStride))
    }

    private var cardItemWidth: CGFloat {
        SeriesHomeDiscoveryCard.itemWidth(for: dynamicTypeSize)
    }

    @ViewBuilder
    private func discoveryCards(skeletonCount: Int, displayPreviews: [SeriesHomeDiscoveryPreview]) -> some View {
        if isLoading && previews.isEmpty {
            ForEach(0..<skeletonCount, id: \.self) { index in
                SeriesHomeDiscoverySkeletonCard(seed: index)
            }
        } else {
            ForEach(displayPreviews) { preview in
                SeriesHomeDiscoveryCard(
                    preview: preview,
                    canAddSeries: canAddSeries,
                    limitActionTitle: limitActionTitle,
                    addSeries: { addSeries(preview) },
                    openDetail: { openDetail(preview) },
                    showLimitAction: showLimitAction
                )
            }
        }
    }
}

private struct SeriesHomeDiscoveryRailWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct SeriesHomeDiscoverySkeletonCard: View {
    let seed: Int

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))
                .frame(width: artworkWidth, height: artworkHeight)
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .fill(Color(.secondarySystemGroupedBackground))
                        .frame(width: actionSize, height: actionSize)
                        .padding(actionInset)
                }

            skeletonLine(
                width: seed.isMultiple(of: 2) ? artworkWidth * 0.9 : artworkWidth * 0.72,
                height: dynamicTypeSize.isAccessibilitySize ? 22 : 14
            )
            skeletonLine(
                width: seed.isMultiple(of: 2) ? artworkWidth * 0.58 : artworkWidth * 0.7,
                height: dynamicTypeSize.isAccessibilitySize ? 18 : 11
            )
        }
        .frame(width: SeriesHomeDiscoveryCard.itemWidth(for: dynamicTypeSize), alignment: .leading)
        .redacted(reason: .placeholder)
        .accessibilityHidden(true)
    }

    private var artworkWidth: CGFloat {
        SeriesHomeDiscoveryCard.artworkWidth(for: dynamicTypeSize)
    }

    private var artworkHeight: CGFloat {
        SeriesHomeDiscoveryCard.artworkHeight(for: dynamicTypeSize)
    }

    private var actionSize: CGFloat {
        SeriesHomeDiscoveryCard.actionSize(for: dynamicTypeSize)
    }

    private var actionInset: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 8 : 7
    }
}

private func skeletonLine(width: CGFloat, height: CGFloat) -> some View {
    RoundedRectangle(cornerRadius: height / 2, style: .continuous)
        .fill(Color(.tertiarySystemGroupedBackground))
        .frame(width: width, height: height)
}

private struct SeriesHomeDiscoveryCard: View {
    private static let standardItemWidth: CGFloat = 108
    private static let accessibleItemWidth: CGFloat = 152
    private static let standardArtworkWidth: CGFloat = 96
    private static let accessibleArtworkWidth: CGFloat = 140

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let preview: SeriesHomeDiscoveryPreview
    let canAddSeries: Bool
    let limitActionTitle: String
    let addSeries: () -> Void
    let openDetail: () -> Void
    let showLimitAction: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Button(action: openDetail) {
                cardContent
            }
            .buttonStyle(.plain)
            .accessibilityLabel(preview.title)
            .accessibilityValue(preview.metadataText)
            .accessibilityHint(L10n.string("detail.open"))
            .accessibilityIdentifier("home.discovery.card.\(preview.id)")

            actionButton
                .padding(.leading, artworkWidth - actionSize - actionInset)
                .padding(.top, artworkHeight - actionSize - actionInset)
        }
        .frame(width: itemWidth, alignment: .leading)
        .dynamicTypeSize(.xSmall ... .accessibility1)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 9) {
            SeriesHomePreviewArtwork(preview: preview, width: artworkWidth, height: artworkHeight)

            Text(preview.title)
                .font(titleFont)
                .foregroundStyle(.primary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                .allowsTightening(true)
                .truncationMode(.tail)
                .frame(
                    width: artworkWidth,
                    height: dynamicTypeSize.isAccessibilitySize ? nil : 36,
                    alignment: .topLeading
                )
                .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)

            Text(preview.metadataText)
                .font(metadataFont)
                .foregroundStyle(.secondary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(0.82)
                .frame(width: artworkWidth, alignment: .leading)
                .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        Button {
            canAddSeries ? addSeries() : showLimitAction()
        } label: {
            Image(systemName: canAddSeries ? "plus" : "sparkles")
                .font(actionFont)
                .foregroundStyle(AVBrandColor.accent)
                .frame(width: actionSize, height: actionSize)
                .background(.regularMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(canAddSeries ? L10n.string("search.follow") : limitActionTitle)
        .accessibilityIdentifier("home.discovery.action.\(preview.id)")
    }

    static func itemWidth(for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        dynamicTypeSize.isAccessibilitySize ? accessibleItemWidth : standardItemWidth
    }

    static func artworkWidth(for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        dynamicTypeSize.isAccessibilitySize ? accessibleArtworkWidth : standardArtworkWidth
    }

    static func artworkHeight(for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 193 : 132
    }

    static func actionSize(for dynamicTypeSize: DynamicTypeSize) -> CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 44 : 34
    }

    private var itemWidth: CGFloat {
        Self.itemWidth(for: dynamicTypeSize)
    }

    private var artworkWidth: CGFloat {
        Self.artworkWidth(for: dynamicTypeSize)
    }

    private var artworkHeight: CGFloat {
        Self.artworkHeight(for: dynamicTypeSize)
    }

    private var actionSize: CGFloat {
        Self.actionSize(for: dynamicTypeSize)
    }

    private var actionInset: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 8 : 7
    }

    private var titleFont: Font {
        dynamicTypeSize.isAccessibilitySize
            ? .subheadline.weight(.bold)
            : .system(size: preview.titleFontSize, weight: .black, design: .rounded)
    }

    private var metadataFont: Font {
        dynamicTypeSize.isAccessibilitySize
            ? .caption.weight(.semibold)
            : .system(size: 11, weight: .bold)
    }

    private var actionFont: Font {
        dynamicTypeSize.isAccessibilitySize
            ? .headline.weight(.black)
            : .system(size: 15, weight: .black)
    }
}

private struct SeriesHomePreviewArtwork: View {
    let preview: SeriesHomeDiscoveryPreview
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Group {
            if let url = preview.posterURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        SeriesPosterMark(seed: preview.title, size: width)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        SeriesPosterMark(seed: preview.title, size: width)
                    @unknown default:
                        SeriesPosterMark(seed: preview.title, size: width)
                    }
                }
            } else {
                SeriesPosterMark(seed: preview.title, size: width)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.24), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
    }
}

private struct SeriesEntryActionsMenu: View {
    let entry: SeriesLibraryEntry
    let togglePinned: () -> Void
    var openDetail: (() -> Void)? = nil
    var editProgress: (() -> Void)? = nil
    let setStatus: (SeriesLibraryEntryStatus) -> Void
    let archive: () -> Void
    let delete: () -> Void

    @State private var isConfirmingDelete = false

    var body: some View {
        Menu {
            if let openDetail {
                Button(action: openDetail) {
                    Label(L10n.string("detail.open"), systemImage: "info.circle")
                }

                Divider()
            }

            SeriesStatusButtons(entry: entry, setStatus: setStatus)

            if let editProgress {
                Button(action: editProgress) {
                    Label(L10n.string("home.adjust"), systemImage: "slider.horizontal.3")
                }
            }

            Divider()

            Button(action: togglePinned) {
                Label(pinTitle, systemImage: entry.isPinnedHomeSeries == true ? "pin.slash" : "pin")
            }

            Button(action: archive) {
                Label(L10n.string("home.archiveSeries"), systemImage: "archivebox")
            }

            Divider()

            Button(role: .destructive) {
                isConfirmingDelete = true
            } label: {
                Label(L10n.string("home.deleteSeries"), systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(L10n.string("home.actions"))
        .confirmationDialog(
            L10n.string("detail.delete.confirm.title"),
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button(L10n.string("detail.delete.confirm.action"), role: .destructive, action: delete)
            Button(L10n.string("common.cancel"), role: .cancel) {}
        } message: {
            Text(L10n.string("detail.delete.confirm.detail"))
        }
    }

    private var pinTitle: String {
        entry.isPinnedHomeSeries == true ? L10n.string("home.unpin") : L10n.string("home.pin")
    }
}

struct SeriesCompactIconButton: View {
    enum Style {
        case accent
        case secondary
    }

    let systemName: String
    var style: Style = .secondary
    var size: CGFloat = 40
    var iconSize: CGFloat = 16
    let accessibilityLabel: String
    var accessibilityIdentifier: String?
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .black))
                .foregroundStyle(foregroundColor)
                .frame(width: size, height: size)
                .background(backgroundColor, in: Circle())
                .overlay {
                    Circle().stroke(strokeColor, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.42 : 1)
        .accessibilityLabel(accessibilityLabel)
        .modifier(SeriesOptionalAccessibilityIdentifier(identifier: accessibilityIdentifier))
    }

    private var foregroundColor: Color {
        switch style {
        case .accent:
            Color.black.opacity(0.84)
        case .secondary:
            Color.primary
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .accent:
            AVBrandColor.accent
        case .secondary:
            Color(.tertiarySystemGroupedBackground)
        }
    }

    private var strokeColor: Color {
        switch style {
        case .accent:
            Color.black.opacity(0.08)
        case .secondary:
            Color.primary.opacity(0.08)
        }
    }
}

struct SeriesProgressPillButton: View {
    enum Style {
        case accent
        case secondary
    }

    let title: String
    let systemName: String
    var style: Style = .secondary
    let accessibilityLabel: String
    var accessibilityIdentifier: String?
    var minHeight: CGFloat = 40
    var fillsAvailableWidth = false
    var isDisabled = false
    var titleFont: Font = .system(size: 13, weight: .black, design: .rounded)
    var titleLineLimit = 1
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemName)
                    .accessibilityHidden(true)

                Text(title)
                    .lineLimit(titleLineLimit)
                    .minimumScaleFactor(0.72)
                    .allowsTightening(true)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .font(titleFont)
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: fillsAvailableWidth ? .infinity : nil, minHeight: minHeight)
            .padding(.horizontal, 13)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(strokeColor, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.42 : 1)
        .accessibilityLabel(accessibilityLabel)
        .modifier(SeriesOptionalAccessibilityIdentifier(identifier: accessibilityIdentifier))
    }

    private var foregroundColor: Color {
        switch style {
        case .accent:
            Color.black.opacity(0.84)
        case .secondary:
            Color.primary
        }
    }

    private var backgroundColor: Color {
        switch style {
        case .accent:
            AVBrandColor.accent
        case .secondary:
            Color(.tertiarySystemGroupedBackground)
        }
    }

    private var strokeColor: Color {
        switch style {
        case .accent:
            Color.black.opacity(0.08)
        case .secondary:
            Color.primary.opacity(0.08)
        }
    }
}

private struct SeriesOptionalAccessibilityIdentifier: ViewModifier {
    let identifier: String?

    func body(content: Content) -> some View {
        if let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}

struct SeriesStatusButtons: View {
    let entry: SeriesLibraryEntry
    let setStatus: (SeriesLibraryEntryStatus) -> Void

    var body: some View {
        Section(L10n.string("library.status.menu.title")) {
            ForEach(SeriesLibraryEntryStatus.allCases, id: \.self) { status in
                if status != entry.status {
                    Button {
                        setStatus(status)
                    } label: {
                        Label(statusActionTitle(status), systemImage: statusIcon(status, isSelected: false))
                    }
                }
            }
        }
    }
}

func statusActionTitle(_ status: SeriesLibraryEntryStatus) -> String {
    String(format: L10n.string("library.status.action"), statusTitle(status))
}

func statusTitle(_ status: SeriesLibraryEntryStatus) -> String {
    switch status {
    case .wantToWatch:
        L10n.string("library.status.wantToWatch")
    case .watching:
        L10n.string("library.status.watching")
    case .watched:
        L10n.string("library.status.watched")
    }
}

private func statusIcon(_ status: SeriesLibraryEntryStatus, isSelected: Bool) -> String {
    if isSelected {
        return "checkmark.circle.fill"
    }

    switch status {
    case .wantToWatch:
        return "bookmark"
    case .watching:
        return "play.circle"
    case .watched:
        return "checkmark.circle"
    }
}

struct SeriesProgressEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let entry: SeriesLibraryEntry
    let markWatchedThrough: (SeriesEpisodeCursor) -> Void
    let clearProgress: () -> Void
    private let episodeGuideClient: SeriesEpisodeGuideClient

    @State private var selectedSeasonNumber: Int
    @State private var selectedEpisodeNumber: Int
    @State private var visibleSeasonCount: Int
    @State private var visibleEpisodeCount: Int
    @State private var isShowingExtendedEpisodes: Bool
    @State private var episodeGuideState: SeriesProgressGuideState = .generic

    init(
        entry: SeriesLibraryEntry,
        markWatchedThrough: @escaping (SeriesEpisodeCursor) -> Void,
        clearProgress: @escaping () -> Void,
        episodeGuideClient: SeriesEpisodeGuideClient = SeriesEpisodeGuideClient(apiClient: SeriesAVAPIClient())
    ) {
        self.entry = entry
        self.markWatchedThrough = markWatchedThrough
        self.clearProgress = clearProgress
        self.episodeGuideClient = episodeGuideClient
        let cursor = entry.lastWatchedEpisodeCursor ?? SeriesEpisodeCursor(seasonNumber: 1, episodeNumber: 1)
        let boundedSeason = min(max(1, cursor.seasonNumber), Self.maxSeasonCount)
        let boundedEpisode = min(max(1, cursor.episodeNumber), Self.maxEpisodeCount)
        _selectedSeasonNumber = State(initialValue: boundedSeason)
        _selectedEpisodeNumber = State(initialValue: boundedEpisode)
        _visibleSeasonCount = State(initialValue: max(8, boundedSeason + 2))
        _visibleEpisodeCount = State(initialValue: min(Self.maxEpisodeCount, max(Self.defaultEpisodeCount, boundedEpisode + 6)))
        _isShowingExtendedEpisodes = State(initialValue: boundedEpisode > Self.defaultEpisodeCount)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    progressHero
                    seasonSelector
                    episodeSelector
                    explanation
                    clearProgressAction
                }
                .padding(18)
                .frame(maxWidth: 680, alignment: .topLeading)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .background(AVBrandSurface.shellBackground.ignoresSafeArea())
            .navigationTitle(entry.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("common.cancel")) {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Text(L10n.string("home.editor.saveHint"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(.regularMaterial)
            }
            .task(id: entry.seriesId) {
                await loadEpisodeGuide()
            }
        }
    }

    private var progressHero: some View {
        AVAppShellCard {
            HStack(alignment: .center, spacing: 14) {
                SeriesEntryArtworkView(entry: entry, size: 74)

                VStack(alignment: .leading, spacing: 7) {
                    Text(entry.lastWatchedEpisodeCursor == nil ? L10n.string("home.editor.startPrompt") : L10n.string("home.adjust"))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(selectedCursorLabel)
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)

                        Text(String(format: L10n.string("home.editor.watchedThrough"), selectedCursorLabel))
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(nextEpisodeSummaryText)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AVBrandColor.accent)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        Label(editorGuideCoverageText, systemImage: editorGuideCoverageSystemImage)
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: 0)
            }
        }
    }

    private var seasonSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.string("home.editor.season.short"))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(seasonNumbers, id: \.self) { season in
                        selectorChip(
                            title: "S\(season)",
                            accessibilityLabel: String(format: L10n.string("home.editor.season"), season),
                            isSelected: selectedSeasonNumber == season
                        ) {
                            selectSeason(season)
                        }
                    }

                    if canShowMoreSeasons {
                        moreChip(title: L10n.string("home.editor.moreSeasons")) {
                            visibleSeasonCount = min(visibleSeasonCount + 4, Self.maxSeasonCount)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var episodeSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.string("home.editor.episode.short"))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.secondary)

                Spacer()

                if isShowingExtendedEpisodes {
                    Text(L10n.string("home.editor.extendedRange"))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AVBrandColor.accent)
                }
            }

            if let loadedGuide {
                LazyVStack(spacing: 8) {
                    ForEach(loadedGuide.items(in: selectedSeasonNumber), id: \.cursor) { item in
                        episodeGuideRow(item) {
                            selectEpisode(item.episodeNumber, commitsSelection: true)
                        }
                    }
                }

                if shouldShowProviderNumberingNote {
                    Label(L10n.string("detail.numbering.providerNote"), systemImage: "number")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                LazyVGrid(columns: episodeColumns, alignment: .leading, spacing: 8) {
                    ForEach(episodeNumbers, id: \.self) { episode in
                        episodeChip(
                            title: episodeChipTitle(for: episode),
                            episode: episode
                        ) {
                            selectEpisode(episode, commitsSelection: true)
                        }
                    }

                    if shouldShowMoreEpisodes {
                        moreChip(title: L10n.string("home.editor.moreEpisodes")) {
                            isShowingExtendedEpisodes = true
                            visibleEpisodeCount = min(visibleEpisodeCount + Self.defaultEpisodeCount, Self.maxEpisodeCount)
                        }
                    }
                }
            }

            if isProgressAheadOfGuide {
                guideMismatchNotice
            }
        }
    }

    private var explanation: some View {
        Text(explanationText)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var clearProgressAction: some View {
        HStack {
            Button(role: entry.lastWatchedEpisodeCursor == nil ? nil : .destructive) {
                clearProgress()
                dismiss()
            } label: {
                Label(L10n.string("home.notStarted"), systemImage: "xmark.circle")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .accessibilityLabel(L10n.string("home.notStarted"))

            Spacer(minLength: 0)
        }
    }

    private var selectedCursorLabel: String {
        cursorLabel(selectedCursor)
    }

    private var selectedCursor: SeriesEpisodeCursor {
        SeriesEpisodeCursor(seasonNumber: selectedSeasonNumber, episodeNumber: selectedEpisodeNumber)
    }

    private var nextEpisodeSummaryText: String {
        if entry.lastWatchedEpisodeCursor == nil {
            return String(format: L10n.string("home.editor.startTransition"), cursorLabel(selectedCursor.nextEpisode))
        }
        return String(format: L10n.string("home.current.nextEpisode"), cursorLabel(selectedCursor.nextEpisode))
    }

    private var seasonNumbers: [Int] {
        if let guide = loadedGuide {
            return guide.seasonNumbers
        }
        return Array(1...min(visibleSeasonCount, Self.maxSeasonCount))
    }

    private var episodeNumbers: [Int] {
        if let guide = loadedGuide {
            return guide.episodeNumbers(in: selectedSeasonNumber)
        }
        return Array(1...min(visibleEpisodeCount, Self.maxEpisodeCount))
    }

    private static let maxSeasonCount = 30
    private static let defaultEpisodeCount = 12
    private static let maxEpisodeCount = 200

    private var canShowMoreSeasons: Bool {
        if loadedGuide != nil {
            return false
        }
        return visibleSeasonCount < Self.maxSeasonCount
    }

    private var episodeColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 58), spacing: 8)]
    }

    private var loadedGuide: SeriesProgressEpisodeGuide? {
        if case let .loaded(guide) = episodeGuideState {
            return guide
        }
        return nil
    }

    private var shouldShowMoreEpisodes: Bool {
        loadedGuide == nil && visibleEpisodeCount < Self.maxEpisodeCount
    }

    private var isProgressAheadOfGuide: Bool {
        guard let latestCursor = loadedGuide?.latestCursor else {
            return false
        }
        return selectedCursor > latestCursor
    }

    private var shouldShowProviderNumberingNote: Bool {
        guard let latestCursor = loadedGuide?.latestCursor,
              let absoluteEpisodeNumber = loadedGuide?.absoluteEpisodeNumber(for: latestCursor) else {
            return false
        }
        return absoluteEpisodeNumber != latestCursor.episodeNumber
    }

    private var guideMismatchNotice: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.orange)

            Text(String(format: L10n.string("home.editor.guideMismatch"), selectedCursorLabel, knownEpisodeLabel(cursor: loadedGuide?.latestCursor ?? selectedCursor, absoluteEpisodeNumber: loadedGuide?.latestCursor.flatMap { loadedGuide?.absoluteEpisodeNumber(for: $0) })))
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var editorGuideCoverageText: String {
        switch episodeGuideState {
        case .loaded(let guide):
            if let latestCursor = guide.latestCursor {
                return String(
                    format: L10n.string("home.editor.guideCoverage.latest"),
                    knownEpisodeLabel(
                        cursor: latestCursor,
                        absoluteEpisodeNumber: guide.absoluteEpisodeNumber(for: latestCursor)
                    )
                )
            }
            return L10n.string("home.editor.guideCoverage.unavailable")
        case .loading:
            return L10n.string("home.editor.guideCoverage.loading")
        case .generic, .unavailable:
            return L10n.string("home.editor.guideCoverage.generic")
        }
    }

    private var editorGuideCoverageSystemImage: String {
        switch episodeGuideState {
        case .loaded(let guide) where guide.latestCursor != nil:
            "checkmark.seal.fill"
        case .loading:
            "hourglass"
        default:
            "exclamationmark.triangle.fill"
        }
    }

    private var explanationText: String {
        switch episodeGuideState {
        case .loaded:
            L10n.string("home.editor.footer.realGuide")
        case .loading:
            L10n.string("home.editor.footer.loadingGuide")
        case .generic, .unavailable:
            L10n.string("home.editor.footer")
        }
    }

    private func episodeChipTitle(for episode: Int) -> String {
        "E\(episode)"
    }

    private func episodeGuideRow(_ item: SeriesEpisodeGuideItem, action: @escaping () -> Void) -> some View {
        let isSelected = item.cursor == selectedCursor
        let isWatched = item.cursor <= selectedCursor
        let fill = isSelected ? AVBrandColor.accent.opacity(0.20) : Color(.secondarySystemGroupedBackground)
        let stroke = isSelected ? AVBrandColor.accent.opacity(0.9) : (isWatched ? AVBrandColor.accent.opacity(0.34) : Color.primary.opacity(0.08))

        return Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected ? AVBrandColor.accent : Color(.tertiarySystemGroupedBackground))

                    Text(loadedGuide?.absoluteEpisodeNumber(for: item.cursor).map { "E\($0)" } ?? "E\(item.episodeNumber)")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                        .foregroundStyle(isSelected ? Color.black.opacity(0.84) : Color.primary)
                }
                .frame(width: 58, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    if loadedGuide?.absoluteEpisodeNumber(for: item.cursor) != nil {
                        Text(cursorLabel(item.cursor))
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    Text(episodeTitle(for: item))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if let airDate = item.airDate, !airDate.isEmpty {
                        Text(airDate)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isWatched ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(isWatched ? AVBrandColor.accent : Color.secondary.opacity(0.45))
                    .frame(width: 24, height: 24)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .background(fill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(stroke, lineWidth: 1)
        }
        .accessibilityLabel(String(format: L10n.string("home.editor.episode"), item.episodeNumber))
    }

    private func episodeTitle(for item: SeriesEpisodeGuideItem) -> String {
        if let title = item.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return title
        }
        return String(format: L10n.string("home.editor.episode"), item.episodeNumber)
    }

    private func genericCursor(for episode: Int) -> SeriesEpisodeCursor {
        SeriesEpisodeCursor(seasonNumber: selectedSeasonNumber, episodeNumber: episode)
    }

    private func genericEpisodeLabel(for episode: Int) -> some View {
        let cursor = genericCursor(for: episode)
        let isSelected = cursor == selectedCursor
        let isWatched = cursor <= selectedCursor

        return VStack(spacing: 5) {
            Text("E\(episode)")
                .font(.system(size: 14, weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.74)

            Image(systemName: isWatched ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isSelected ? Color.white.opacity(0.88) : (isWatched ? AVBrandColor.accent : Color.secondary.opacity(0.55)))
        }
        .frame(maxWidth: .infinity, minHeight: 48)
        .padding(.horizontal, 8)
    }

    private func episodeChip(title: String, episode: Int, action: @escaping () -> Void) -> some View {
        let cursor = genericCursor(for: episode)
        let isSelected = cursor == selectedCursor
        let isWatched = cursor <= selectedCursor
        let fill = isSelected ? AVBrandColor.accent : Color(.secondarySystemGroupedBackground)
        let stroke = isSelected ? AVBrandColor.accent.opacity(0.8) : (isWatched ? AVBrandColor.accent.opacity(0.30) : Color.primary.opacity(0.08))
        let foreground = isSelected ? Color.white : Color.primary

        return Button(action: action) {
            genericEpisodeLabel(for: episode)
        }
        .buttonStyle(.plain)
        .foregroundStyle(foreground)
        .background(fill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(stroke, lineWidth: 1)
        }
        .accessibilityLabel(String(format: L10n.string("home.editor.episode"), episode))
    }

    private func selectorChip(title: String, accessibilityLabel: String? = nil, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.74)
                .frame(maxWidth: .infinity, minHeight: 42)
                .padding(.horizontal, 10)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .background(isSelected ? AVBrandColor.accent : Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? AVBrandColor.accent.opacity(0.8) : Color.primary.opacity(0.08), lineWidth: 1)
        }
        .accessibilityLabel(accessibilityLabel ?? title)
    }

    private func moreChip(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .black))
                .frame(maxWidth: .infinity, minHeight: 42)
        }
        .buttonStyle(.plain)
        .foregroundStyle(AVBrandColor.accent)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AVBrandColor.accent.opacity(0.28), lineWidth: 1)
        }
        .accessibilityLabel(title)
    }

    private func selectSeason(_ season: Int) {
        selectedSeasonNumber = season
        visibleSeasonCount = max(visibleSeasonCount, season + 3)
        if let guide = loadedGuide, !guide.contains(selectedCursor) {
            let fallbackEpisode = guide.episodeNumbers(in: season).first ?? 1
            selectedEpisodeNumber = fallbackEpisode
        }
    }

    private func selectEpisode(_ episode: Int, commitsSelection: Bool = false) {
        selectedEpisodeNumber = episode
        if loadedGuide != nil {
            if commitsSelection {
                commitSelectedEpisode()
            }
            return
        }
        if episode > Self.defaultEpisodeCount {
            isShowingExtendedEpisodes = true
            visibleEpisodeCount = min(Self.maxEpisodeCount, max(visibleEpisodeCount, episode + 6))
        } else if isShowingExtendedEpisodes {
            visibleEpisodeCount = max(visibleEpisodeCount, Self.defaultEpisodeCount * 2)
        } else {
            visibleEpisodeCount = Self.defaultEpisodeCount
        }
        if commitsSelection {
            commitSelectedEpisode()
        }
    }

    private func commitSelectedEpisode() {
        markWatchedThrough(selectedCursor)
        dismiss()
    }

    private func loadEpisodeGuide() async {
        guard !entry.seriesId.isEmpty else {
            episodeGuideState = .generic
            return
        }

        episodeGuideState = .loading

        do {
            let response = try await episodeGuideClient.episodes(
                for: entry.seriesId,
                lastWatchedEpisodeCursor: entry.lastWatchedEpisodeCursor
            )
            let guide = SeriesProgressEpisodeGuide(items: response.items)
            guard !guide.items.isEmpty else {
                episodeGuideState = .unavailable
                return
            }

            if !guide.contains(selectedCursor), let latestCursor = guide.latestCursor, selectedCursor <= latestCursor {
                let clampedCursor = guide.clampedCursor(selectedCursor)
                selectedSeasonNumber = clampedCursor.seasonNumber
                selectedEpisodeNumber = clampedCursor.episodeNumber
            }
            episodeGuideState = .loaded(guide)
        } catch {
            episodeGuideState = .unavailable
        }
    }
}

private enum SeriesProgressGuideState: Equatable {
    case generic
    case loading
    case loaded(SeriesProgressEpisodeGuide)
    case unavailable
}

private struct SeriesProgressEpisodeGuide: Equatable {
    var items: [SeriesEpisodeGuideItem]

    init(items: [SeriesEpisodeGuideItem]) {
        self.items = items
            .filter { $0.seasonNumber > 0 && $0.episodeNumber > 0 }
            .sorted {
                if $0.seasonNumber == $1.seasonNumber {
                    return $0.episodeNumber < $1.episodeNumber
                }
                return $0.seasonNumber < $1.seasonNumber
            }
    }

    var seasonNumbers: [Int] {
        Array(Set(items.map(\.seasonNumber))).sorted()
    }

    var latestCursor: SeriesEpisodeCursor? {
        items.last?.cursor
    }

    func episodeNumbers(in season: Int) -> [Int] {
        items
            .filter { $0.seasonNumber == season }
            .map(\.episodeNumber)
    }

    func items(in season: Int) -> [SeriesEpisodeGuideItem] {
        items.filter { $0.seasonNumber == season }
    }

    func item(for cursor: SeriesEpisodeCursor) -> SeriesEpisodeGuideItem? {
        items.first { $0.seasonNumber == cursor.seasonNumber && $0.episodeNumber == cursor.episodeNumber }
    }

    func absoluteEpisodeNumber(for cursor: SeriesEpisodeCursor) -> Int? {
        index(for: cursor).map { $0 + 1 }
    }

    func contains(_ cursor: SeriesEpisodeCursor) -> Bool {
        item(for: cursor) != nil
    }

    func clampedCursor(_ cursor: SeriesEpisodeCursor) -> SeriesEpisodeCursor {
        if contains(cursor) {
            return cursor
        }

        let sameSeasonEpisodes = episodeNumbers(in: cursor.seasonNumber)
        if let nearestEpisode = sameSeasonEpisodes.min(by: { abs($0 - cursor.episodeNumber) < abs($1 - cursor.episodeNumber) }) {
            return SeriesEpisodeCursor(seasonNumber: cursor.seasonNumber, episodeNumber: nearestEpisode)
        }

        return items.first?.cursor ?? SeriesEpisodeCursor(seasonNumber: 1, episodeNumber: 1)
    }

    func previous(before cursor: SeriesEpisodeCursor) -> SeriesEpisodeCursor? {
        let index = index(for: cursor)
        guard let index, index > items.startIndex else {
            return nil
        }
        return items[items.index(before: index)].cursor
    }

    func next(after cursor: SeriesEpisodeCursor) -> SeriesEpisodeCursor? {
        let index = index(for: cursor)
        guard let index else {
            return items.first?.cursor
        }
        let nextIndex = items.index(after: index)
        guard nextIndex < items.endIndex else {
            return nil
        }
        return items[nextIndex].cursor
    }

    private func index(for cursor: SeriesEpisodeCursor) -> [SeriesEpisodeGuideItem].Index? {
        items.firstIndex { $0.seasonNumber == cursor.seasonNumber && $0.episodeNumber == cursor.episodeNumber }
    }
}

struct SeriesEntryArtworkView: View {
    let entry: SeriesLibraryEntry
    let size: CGFloat

    var body: some View {
        if let url = displayArtworkURL {
            SeriesRemoteArtworkView(url: url, seed: fallbackSeed, size: size)
        } else {
            SeriesPosterMark(seed: fallbackSeed, size: size)
        }
    }

    private var displayArtworkURL: URL? {
        guard let ref = entry.displayArtworkRef else {
            return nil
        }
        return URL(string: ref)
    }

    private var fallbackSeed: String {
        entry.fallbackVisualSeed ?? entry.title
    }
}

private struct SeriesRemoteArtworkView: View {
    let url: URL
    let seed: String
    let size: CGFloat

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                SeriesPosterMark(seed: seed, size: size)
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size * 1.38)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.10), radius: 10, y: 5)
            case .failure:
                SeriesPosterMark(seed: seed, size: size)
            @unknown default:
                SeriesPosterMark(seed: seed, size: size)
            }
        }
    }
}

struct SeriesPosterMark: View {
    let seed: String
    let size: CGFloat

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: palette,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Text(initials)
                .font(.system(size: size * 0.24, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .padding(size * 0.12)
        }
        .frame(width: size, height: size * 1.38)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.35), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.10), radius: 10, y: 5)
    }

    private var initials: String {
        seed
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }

    private var palette: [Color] {
        let palettes: [[Color]] = [
            [Color(red: 0.18, green: 0.33, blue: 0.43), Color(red: 0.79, green: 0.32, blue: 0.26)],
            [Color(red: 0.18, green: 0.43, blue: 0.36), Color(red: 0.86, green: 0.67, blue: 0.30)],
            [Color(red: 0.42, green: 0.23, blue: 0.35), Color(red: 0.28, green: 0.50, blue: 0.66)]
        ]
        let index = abs(seed.hashValue) % palettes.count
        return palettes[index]
    }
}

private struct SeriesEmptyWatchingView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let openSearch: () -> Void

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityLayout
            } else {
                standardLayout
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.empty-state")
    }

    private var standardLayout: some View {
        HStack(alignment: .center, spacing: 16) {
            SeriesEmptyPosterPlaceholder(size: 74)

            VStack(alignment: .leading, spacing: 10) {
                emptyCopy

                Button(action: openSearch) {
                    Label(L10n.string("home.add"), systemImage: "magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .accessibilityIdentifier("home.empty.search")
            }
        }
    }

    private var accessibilityLayout: some View {
        VStack(alignment: .leading, spacing: 18) {
            emptyCopy

            Button(action: openSearch) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                    Text(L10n.string("home.add"))
                    Spacer(minLength: 0)
                }
                .font(.headline.weight(.bold))
                .dynamicTypeSize(.xSmall ... .accessibility1)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                .foregroundStyle(.white)
                .background(AVBrandColor.accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.string("home.add"))
            .accessibilityIdentifier("home.empty.search")
        }
    }

    private var emptyCopy: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.string("home.empty.title"))
                .font(.title3.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)

            Text(L10n.string("home.empty.subtitle"))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .dynamicTypeSize(.xSmall ... .accessibility1)
    }
}

private struct SeriesEmptyPosterPlaceholder: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))
                .frame(width: size, height: size * 1.38)
                .overlay(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground))
                        .frame(width: size * 0.42, height: 8)
                        .padding(10)
                }
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(AVBrandColor.accent, in: Circle())
                        .padding(7)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.primary.opacity(0.07), lineWidth: 1)
                }
        }
        .accessibilityHidden(true)
    }
}

func cursorLabel(_ cursor: SeriesEpisodeCursor) -> String {
    "S\(cursor.seasonNumber) E\(cursor.episodeNumber)"
}

func knownEpisodeLabel(cursor: SeriesEpisodeCursor, absoluteEpisodeNumber: Int?) -> String {
    guard let absoluteEpisodeNumber else {
        return cursorLabel(cursor)
    }
    return "E\(absoluteEpisodeNumber) · \(cursorLabel(cursor))"
}

func quickProgressActionTitle(for entry: SeriesLibraryEntry) -> String {
    String(format: L10n.string("home.action.markEpisodeWatched"), cursorLabel(entry.nextEpisodeCursor))
}

func primaryProgressActionTitle(for entry: SeriesLibraryEntry) -> String {
    if entry.status == .wantToWatch {
        return "\(L10n.string("home.start")) \(cursorLabel(entry.nextEpisodeCursor))"
    }
    return quickProgressActionTitle(for: entry)
}

func compactProgressActionTitle(for entry: SeriesLibraryEntry) -> String {
    if entry.status == .wantToWatch {
        return primaryProgressActionTitle(for: entry)
    }
    return String(format: L10n.string("home.current.nextEpisode"), cursorLabel(entry.nextEpisodeCursor))
}

func quickProgressMenuSystemImage(for entry: SeriesLibraryEntry) -> String {
    entry.status == .wantToWatch ? "play.circle" : "checkmark.circle"
}

func quickProgressFilledSystemImage(for entry: SeriesLibraryEntry) -> String {
    entry.status == .wantToWatch ? "play.fill" : "checkmark"
}
