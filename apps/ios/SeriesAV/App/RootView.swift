import AVAviFoundation
import AVAppShellFoundation
import AVBrandFoundation
import AVSettingsFoundation
import SwiftUI

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

private struct SeriesWatchingHomeScreen: View {
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
    @State private var detailEntry: SeriesLibraryEntry?
    @State private var isShowingProPaywall = false
    @State private var pendingUndo: PendingLibraryUndo?
    @State private var pendingProgressUndo: PendingProgressUndo?
    @State private var popularPreviews: [SeriesHomeDiscoveryPreview] = []
    @State private var upcomingPreviews: [SeriesHomeDiscoveryPreview] = []
    @State private var recommendedPreviews: [SeriesHomeDiscoveryPreview] = []
    @State private var isLoadingHomeDiscovery = true
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

    var body: some View {
        AVAppShellScrollableScreenScaffold(
            alignment: .leading,
            spacing: 22,
            bottomPadding: 176
        ) {
            AVBrandSurface.shellBackground
        } content: {
            homeHeader

            if let currentEntry = homeState.currentEntry {
                SeriesCurrentWatchingCard(
                    entry: currentEntry,
                    markPrevious: {
                        pendingProgressUndo = progressUndo(for: currentEntry)
                        pendingUndo = nil
                        store.markPreviousEpisodeWatched(for: currentEntry.id)
                    },
                    markNext: {
                        pendingProgressUndo = progressUndo(for: currentEntry)
                        pendingUndo = nil
                        store.markNextEpisodeWatched(for: currentEntry.id)
                    },
                    startWatching: {
                        pendingProgressUndo = progressUndo(for: currentEntry, messageKey: "home.undo.status")
                        pendingUndo = nil
                        store.setStatus(.watching, for: currentEntry.id)
                    },
                    markWatchedThrough: { cursor in
                        pendingProgressUndo = progressUndo(for: currentEntry)
                        pendingUndo = nil
                        store.markWatchedThrough(cursor, for: currentEntry.id)
                    },
                    editProgress: {
                        editorEntry = currentEntry
                    },
                    togglePinned: {
                        store.setPinned(currentEntry.isPinnedHomeSeries != true, for: currentEntry.id)
                    },
                    openDetail: {
                        detailEntry = currentEntry
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

            SeriesHomeUpcomingEpisodesSection(
                entries: store.activeEntries,
                openLibrary: openLibraryTab
            )

            if homeState.secondaryEntries.isEmpty == false {
                SeriesWatchingQueueSection(
                    entries: homeState.secondaryEntries,
                    markNext: { entry in
                        pendingProgressUndo = progressUndo(for: entry)
                        pendingUndo = nil
                        store.markNextEpisodeWatched(for: entry.id)
                    },
                    editProgress: { entry in
                        editorEntry = entry
                    },
                    togglePinned: { entry in
                        store.setPinned(entry.isPinnedHomeSeries != true, for: entry.id)
                    },
                    openDetail: { entry in
                        detailEntry = entry
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

            SeriesHomeDiscoveryRail(
                title: L10n.string("home.rail.popular"),
                previews: homeState.visiblePopularPreviews,
                isLoading: isLoadingHomeDiscovery,
                canAddSeries: canAddSeries,
                limitActionTitle: limitActionTitle,
                addSeries: addDiscoverySeries,
                showLimitAction: showLimitAction
            )

            SeriesHomeDiscoveryRail(
                title: L10n.string("upcoming.home.title"),
                previews: homeState.visibleUpcomingPreviews,
                isLoading: isLoadingHomeDiscovery,
                canAddSeries: canAddSeries,
                limitActionTitle: limitActionTitle,
                addSeries: addDiscoverySeries,
                showLimitAction: showLimitAction
            )

            SeriesHomeDiscoveryRail(
                title: L10n.string("home.rail.recommended"),
                previews: homeState.visibleRecommendedPreviews,
                isLoading: isLoadingHomeDiscovery,
                canAddSeries: canAddSeries,
                limitActionTitle: limitActionTitle,
                addSeries: addDiscoverySeries,
                showLimitAction: showLimitAction
            )
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                if let pendingProgressUndo {
                    SeriesUndoBar(
                        title: String(format: L10n.string(pendingProgressUndo.messageKey), pendingProgressUndo.title),
                        undo: {
                            store.restoreProgress(
                                status: pendingProgressUndo.status,
                                lastWatchedEpisodeCursor: pendingProgressUndo.lastWatchedEpisodeCursor,
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

                if homeState.currentEntry == nil {
                    Button(action: openSearch) {
                        Label(L10n.string("home.add"), systemImage: "magnifyingglass")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.regularMaterial)
        }
        .sheet(item: $editorEntry) { entry in
            SeriesProgressEditorSheet(
                entry: entry,
                markWatchedThrough: { cursor in
                    pendingProgressUndo = progressUndo(for: entry)
                    pendingUndo = nil
                    store.markWatchedThrough(cursor, for: entry.id)
                },
                clearProgress: {
                    pendingProgressUndo = progressUndo(for: entry)
                    pendingUndo = nil
                    store.clearProgress(for: entry.id)
                }
            )
            .presentationDetents([.large])
        }
        .sheet(item: $detailEntry) { entry in
            SeriesDetailScreen(
                entry: entry,
                markNext: { entry in
                    pendingProgressUndo = progressUndo(for: entry)
                    pendingUndo = nil
                    store.markNextEpisodeWatched(for: entry.id)
                },
                markWatchedThrough: { entry, cursor in
                    pendingProgressUndo = progressUndo(for: entry)
                    pendingUndo = nil
                    store.markWatchedThrough(cursor, for: entry.id)
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
            await refreshHomeDiscovery()
        }
        .onAppear {
            if SeriesUITestEnvironment.current.shouldShowProgressEditor, editorEntry == nil {
                editorEntry = homeState.currentEntry ?? store.activeEntries.first
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

    private var missingArtworkEntries: [SeriesLibraryEntry] {
        store.activeEntries.filter { $0.displayArtworkRef?.isEmpty != false }
    }

    private var missingArtworkSignature: String {
        missingArtworkEntries
            .map { "\($0.entryId):\($0.seriesId):\($0.title)" }
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
            lastWatchedEpisodeCursor: entry.lastWatchedEpisodeCursor
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

    private func refreshHomeDiscovery() async {
        isLoadingHomeDiscovery = true
        let client = SeriesCatalogSearchClient()
        async let popular = try? client.popular(locale: Locale.current.identifier, surface: "home", limit: 10)
        async let upcoming = try? client.popular(locale: Locale.current.identifier, surface: "upcoming", limit: 10)
        async let recommended = try? client.popular(locale: Locale.current.identifier, surface: "avi", limit: 10)

        popularPreviews = (await popular)?.results.map { SeriesHomeDiscoveryPreview(catalogItem: $0) } ?? []
        upcomingPreviews = (await upcoming)?.results.map { SeriesHomeDiscoveryPreview(catalogItem: $0) } ?? []
        recommendedPreviews = (await recommended)?.results.map { SeriesHomeDiscoveryPreview(catalogItem: $0) } ?? []
        reconcileMissingArtwork(from: popularPreviews + upcomingPreviews + recommendedPreviews)
        isLoadingHomeDiscovery = false
    }

    private func reconcileMissingArtwork(from previews: [SeriesHomeDiscoveryPreview]) {
        for entry in missingArtworkEntries {
            guard let preview = previews.first(where: { SeriesLibraryIdentity.sameSeries(entry, $0.catalogItem) }) else {
                continue
            }
            store.updateArtworkIfMissing(
                for: entry.entryId,
                displayArtworkRef: preview.catalogItem.displayArtworkRef,
                fallbackVisualSeed: preview.title
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
        for entry in missingArtworkEntries.prefix(6) {
            guard entry.displayArtworkRef?.isEmpty != false else {
                continue
            }

            let normalizedTitle = SeriesLibraryIdentity.normalizedSearchText(entry.title)
            guard let response = try? await client.search(query: entry.title, locale: Locale.current.identifier, limit: 4),
                  let catalogItem = response.results.first(where: { SeriesLibraryIdentity.sameSeries(entry, $0) })
                    ?? response.results.first(where: { SeriesLibraryIdentity.normalizedSearchText($0.title) == normalizedTitle }),
                  catalogItem.displayArtworkRef?.isEmpty == false else {
                continue
            }

            store.updateArtworkIfMissing(
                for: entry.entryId,
                displayArtworkRef: catalogItem.displayArtworkRef,
                fallbackVisualSeed: catalogItem.title
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

    private var homeHeader: some View {
        AVAppShellHomeHeader(
            title: L10n.string("home.header.title"),
            subtitle: L10n.string("home.header.subtitle")
        ) {
            AVAppShellConfiguredBrandHeader(
                activeItem: nil,
                openSettings: openSettings,
                openAccount: openAccount
            )
        } content: {
            SeriesHomeAviBrief(
                currentEntry: homeState.currentEntry,
                watchingCount: homeState.watchingCount,
                wantToWatchCount: homeState.wantToWatchCount,
                openAvi: openAvi
            )
        }
        .padding(.bottom, 8)
    }

}

private struct SeriesHomeAviBrief: View {
    let currentEntry: SeriesLibraryEntry?
    let watchingCount: Int
    let wantToWatchCount: Int
    let openAvi: () -> Void

    @Environment(\.avCommonAppExperience) private var appExperience

    var body: some View {
        AVAviHomeBriefCard(
            identity: appExperience.identity,
            detail: briefDetail,
            actionAccessibilityLabel: L10n.string("home.aviBrief.action"),
            accessibilityIdentifier: "home.aviBrief.open",
            openAvi: openAvi
        ) {
            Image("AviOnboardingCTA")
                .resizable()
                .scaledToFit()
                .frame(width: 50, height: 50)
        }
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

    var id: String { "\(entryId)-\(messageKey)" }
}

struct SeriesUndoBar: View {
    let title: String
    let undo: () -> Void
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(2)

            Spacer()

            Button(L10n.string("home.undo"), action: undo)
                .font(.system(size: 13, weight: .bold))

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .frame(width: 28, height: 28)
            }
            .accessibilityLabel(L10n.string("common.close"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }
}

struct SeriesLibraryRow<MenuContent: View>: View {
    let entry: SeriesLibraryEntry
    let detail: String
    let openDetail: () -> Void
    let markNext: (() -> Void)?
    @ViewBuilder let menuContent: () -> MenuContent

    var body: some View {
        HStack(spacing: 12) {
            Button(action: openDetail) {
                rowContent
            }
            .buttonStyle(.plain)
            .accessibilityLabel(entry.title)
            .accessibilityHint(L10n.string("detail.open"))

            Spacer()

            if let markNext {
                Button(action: markNext) {
                    Image(systemName: entry.status == .wantToWatch ? "play.fill" : "checkmark")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(Color.black.opacity(0.84))
                        .frame(width: 36, height: 36)
                        .background(AVBrandColor.accent, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(quickProgressAccessibilityLabel)
            }

            Menu {
                menuContent()
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(L10n.string("home.actions"))
        }
        .padding(.vertical, 4)
    }

    private var quickProgressAccessibilityLabel: String {
        let actionTitle = entry.status == .wantToWatch ? L10n.string("home.start") : L10n.string("home.next")
        return "\(actionTitle) \(cursorLabel(entry.nextEpisodeCursor))"
    }

    private var rowContent: some View {
        HStack(spacing: 12) {
            SeriesEntryArtworkView(entry: entry, size: 36)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)
        }
    }
}

private struct SeriesCurrentWatchingCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let entry: SeriesLibraryEntry
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
                    Text(String(format: L10n.string("home.current.nextEpisode"), cursorLabel(entry.nextEpisodeCursor)))
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .monospacedDigit()
                }
                .foregroundStyle(AVBrandColor.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AVBrandColor.accent.opacity(colorScheme == .dark ? 0.18 : 0.14), in: Capsule())
            }
            .layoutPriority(1)

            SeriesEntryArtworkView(entry: entry, size: 70)
                .accessibilityHidden(true)
        }
    }

    private var heroControls: some View {
        HStack(spacing: 10) {
            Button(action: primaryAction) {
                Image(systemName: primaryIconName)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(Color.black.opacity(0.84))
                    .frame(width: 50, height: 50)
                    .background(AVBrandColor.accent, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(primaryActionTitle), \(cursorLabel(entry.nextEpisodeCursor))")

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
        entry.status == .wantToWatch ? L10n.string("home.start") : L10n.string("home.next")
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
    let markNext: (SeriesLibraryEntry) -> Void
    let editProgress: (SeriesLibraryEntry) -> Void
    let togglePinned: (SeriesLibraryEntry) -> Void
    let openDetail: (SeriesLibraryEntry) -> Void
    let setStatus: (SeriesLibraryEntry, SeriesLibraryEntryStatus) -> Void
    let archive: (SeriesLibraryEntry) -> Void
    let delete: (SeriesLibraryEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(queueTitle)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.secondary)

            VStack(spacing: 6) {
                ForEach(entries) { entry in
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
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .layoutPriority(1)

                        Spacer(minLength: 0)

                        Button {
                            markNext(entry)
                        } label: {
                            Image(systemName: entry.status == .wantToWatch ? "play.fill" : "checkmark")
                                .font(.system(size: 14, weight: .black))
                                .foregroundStyle(Color.black.opacity(0.84))
                                .frame(width: 34, height: 34)
                                .background(AVBrandColor.accent, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(primaryActionTitle(for: entry))

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
                    .padding(10)
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

    private var queueTitle: String {
        entries.allSatisfy { $0.status == .wantToWatch }
            ? L10n.string("home.queue.wantToWatch.title")
            : L10n.string("home.queue.title")
    }

    private func queueProgress(for entry: SeriesLibraryEntry) -> String {
        guard entry.status != .wantToWatch else {
            return String(format: L10n.string("home.queue.wantToWatch.progress"), cursorLabel(entry.nextEpisodeCursor))
        }
        return String(format: L10n.string("home.queue.progress"), entry.progressLabel, cursorLabel(entry.nextEpisodeCursor))
    }

    private func primaryActionTitle(for entry: SeriesLibraryEntry) -> String {
        entry.status == .wantToWatch ? L10n.string("home.start") : L10n.string("shell.watch.next")
    }
}

private struct SeriesHomeDiscoveryRail: View {
    let title: String
    let previews: [SeriesHomeDiscoveryPreview]
    let isLoading: Bool
    let canAddSeries: Bool
    let limitActionTitle: String
    let addSeries: (SeriesHomeDiscoveryPreview) -> Void
    let showLimitAction: () -> Void

    var body: some View {
        if isLoading || previews.isEmpty == false {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        if isLoading && previews.isEmpty {
                            ForEach(0..<4, id: \.self) { index in
                                SeriesHomeDiscoverySkeletonCard(seed: index)
                            }
                        } else {
                            ForEach(previews) { preview in
                                SeriesHomeDiscoveryCard(
                                    preview: preview,
                                    canAddSeries: canAddSeries,
                                    limitActionTitle: limitActionTitle,
                                    addSeries: { addSeries(preview) },
                                    showLimitAction: showLimitAction
                                )
                            }
                        }
                    }
                    .padding(.vertical, 3)
                }
            }
            .padding(.top, 6)
        }
    }
}

private struct SeriesHomeDiscoverySkeletonCard: View {
    let seed: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(.tertiarySystemGroupedBackground))
                .frame(width: 92, height: 128)
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .fill(Color(.secondarySystemGroupedBackground))
                        .frame(width: 34, height: 34)
                        .padding(7)
                }

            skeletonLine(width: seed.isMultiple(of: 2) ? 82 : 68, height: 14)
            skeletonLine(width: seed.isMultiple(of: 2) ? 52 : 64, height: 11)
        }
        .frame(width: SeriesHomeDiscoveryCard.itemWidth, alignment: .leading)
        .redacted(reason: .placeholder)
        .accessibilityHidden(true)
    }
}

private func skeletonLine(width: CGFloat, height: CGFloat) -> some View {
    RoundedRectangle(cornerRadius: height / 2, style: .continuous)
        .fill(Color(.tertiarySystemGroupedBackground))
        .frame(width: width, height: height)
}

private struct SeriesHomeDiscoveryCard: View {
    static let itemWidth: CGFloat = 108
    private static let artworkWidth: CGFloat = 96

    let preview: SeriesHomeDiscoveryPreview
    let canAddSeries: Bool
    let limitActionTitle: String
    let addSeries: () -> Void
    let showLimitAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .bottomTrailing) {
                SeriesHomePreviewArtwork(preview: preview, width: Self.artworkWidth, height: 132)

                actionButton
                    .padding(7)
            }

            Text(preview.title)
                .font(.system(size: preview.titleFontSize, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .allowsTightening(true)
                .truncationMode(.tail)
                .frame(width: Self.artworkWidth, height: 36, alignment: .topLeading)

            Text(preview.metadataText)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(width: Self.artworkWidth, alignment: .leading)
        }
        .frame(width: Self.itemWidth, alignment: .leading)
    }

    @ViewBuilder
    private var actionButton: some View {
        Button {
            canAddSeries ? addSeries() : showLimitAction()
        } label: {
            Image(systemName: canAddSeries ? "plus" : "sparkles")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(AVBrandColor.accent)
                .frame(width: 34, height: 34)
                .background(.regularMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(canAddSeries ? L10n.string("search.follow") : limitActionTitle)
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
                Label(L10n.string("home.archive"), systemImage: "archivebox")
            }

            Divider()

            Button(role: .destructive, action: delete) {
                Label(L10n.string("home.delete"), systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(L10n.string("home.actions"))
    }

    private var pinTitle: String {
        entry.isPinnedHomeSeries == true ? L10n.string("home.unpin") : L10n.string("home.pin")
    }
}

struct SeriesStatusButtons: View {
    let entry: SeriesLibraryEntry
    let setStatus: (SeriesLibraryEntryStatus) -> Void

    var body: some View {
        ForEach(SeriesLibraryEntryStatus.allCases, id: \.self) { status in
            if status != entry.status {
                Button {
                    setStatus(status)
                } label: {
                    Label(statusTitle(status), systemImage: statusIcon(status, isSelected: false))
                }
            }
        }
    }
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

                        Text(String(format: L10n.string("home.current.nextEpisode"), cursorLabel(selectedCursor.nextEpisode)))
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AVBrandColor.accent)
                            .lineLimit(2)
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
                            commitEpisode(item.episodeNumber)
                        }
                    }
                }
            } else {
                LazyVGrid(columns: episodeColumns, alignment: .leading, spacing: 8) {
                    ForEach(episodeNumbers, id: \.self) { episode in
                        episodeChip(
                            title: episodeChipTitle(for: episode),
                            episode: episode
                        ) {
                            commitEpisode(episode)
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
        }
    }

    private var explanation: some View {
        Text(explanationText)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var clearProgressAction: some View {
        Button(role: entry.lastWatchedEpisodeCursor == nil ? nil : .destructive) {
            clearProgress()
            dismiss()
        } label: {
            Text(L10n.string("home.notStarted"))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    private var selectedCursorLabel: String {
        cursorLabel(selectedCursor)
    }

    private var selectedCursor: SeriesEpisodeCursor {
        SeriesEpisodeCursor(seasonNumber: selectedSeasonNumber, episodeNumber: selectedEpisodeNumber)
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

                    Text("E\(item.episodeNumber)")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(isSelected ? Color.black.opacity(0.84) : Color.primary)
                }
                .frame(width: 48, height: 44)

                VStack(alignment: .leading, spacing: 4) {
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

    private func selectEpisode(_ episode: Int) {
        selectedEpisodeNumber = episode
        if loadedGuide != nil {
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
    }

    private func commitEpisode(_ episode: Int) {
        selectEpisode(episode)
        markWatchedThrough(SeriesEpisodeCursor(seasonNumber: selectedSeasonNumber, episodeNumber: episode))
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

            let clampedCursor = guide.clampedCursor(selectedCursor)
            selectedSeasonNumber = clampedCursor.seasonNumber
            selectedEpisodeNumber = clampedCursor.episodeNumber
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
    let openSearch: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            SeriesEmptyPosterPlaceholder(size: 74)

            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.string("home.empty.title"))
                        .font(.system(size: 22, weight: .bold))
                    Text(L10n.string("home.empty.subtitle"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(action: openSearch) {
                    Label(L10n.string("home.add"), systemImage: "magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
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
