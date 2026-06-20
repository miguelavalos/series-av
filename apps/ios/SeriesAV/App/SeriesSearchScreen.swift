import AVAppShellFoundation
import AVBrandFoundation
import SwiftUI

struct SeriesSearchScreen: View {
    @Bindable var store: SeriesLibraryStore
    let accessController: SeriesAccessController
    let startSignInFlow: () -> Void

    @State private var isShowingProPaywall = false
    @State private var addedEntry: SeriesLibraryEntry?
    @State private var query = ""
    @State private var editorEntry: SeriesLibraryEntry?
    @State private var selectedCollection: SeriesSearchCollection = .popular
    @State private var remoteCatalogResults: [SeriesCatalogPreview] = []
    @State private var remoteCatalogQuery = ""
    @State private var remoteCollectionResults: [SeriesCatalogPreview] = []
    @State private var remoteCollectionKey = ""
    @State private var isSearchingCatalog = false
    @State private var detailSelection: SeriesSearchDetailSelection?

    var body: some View {
        AVAppShellScrollableScreenScaffold(
            alignment: .leading,
            spacing: 22,
            bottomPadding: 236
        ) {
            AVBrandSurface.shellBackground
        } content: {
            screenTitle(
                title: L10n.string("search.title"),
                subtitle: L10n.string("search.empty.subtitle")
            )

            searchControls

            searchResultsSection
        }
        .sheet(isPresented: $isShowingProPaywall) {
            SeriesProPaywallView(
                accessController: accessController,
                startSignInFlow: startSignInFlow
            )
        }
        .sheet(item: $editorEntry) { entry in
            SeriesProgressEditorSheet(
                entry: entry,
                markWatchedThrough: { cursor in
                    store.markWatchedThrough(cursor, for: entry.id)
                },
                clearProgress: {
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
                    if let catalogItem = selection.catalogItem {
                        follow(catalogItem)
                        detailSelection = nil
                    }
                } : nil,
                markNext: { entry in
                    store.markNextEpisodeWatched(for: entry.id)
                },
                markWatchedThrough: { entry, cursor in
                    store.markWatchedThrough(cursor, for: entry.id)
                },
                clearProgress: { entry in
                    store.clearProgress(for: entry.id)
                },
                shareInviteClient: shareInviteClient
            )
            .presentationDetents([.large])
        }
        .task(id: searchRefreshKey) {
            await refreshCatalog()
        }
    }

    private var activeLibraryLimitPolicy: SeriesActiveLibraryLimitPolicy {
        SeriesActiveLibraryLimitPolicy(
            activeCount: store.activeEntries.count,
            activeLimit: accessController.limits.activeLibrarySeries
        )
    }

    private var shareInviteClient: SeriesShareInviteClient? {
        guard accessController.isSignedIn else { return nil }
        return SeriesShareInviteClient(apiClient: accessController.authenticatedAPIClient())
    }

    private var canAddSeries: Bool {
        activeLibraryLimitPolicy.canAddSeries
    }

    private var remainingSeriesCount: Int? {
        activeLibraryLimitPolicy.remainingSeriesCount
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var catalogResults: [SeriesCatalogPreview] {
        if trimmedQuery.isEmpty {
            guard remoteCollectionKey == selectedCollection.cacheKey else {
                return []
            }
            return remoteCollectionResults
        }
        guard remoteCatalogQuery == trimmedQuery else {
            return []
        }
        return remoteCatalogResults
    }

    private var localMatches: [SeriesLibraryEntry] {
        guard trimmedQuery.isEmpty == false else {
            return []
        }
        return store.searchEntries(matching: trimmedQuery)
    }

    private var visibleCatalogResults: [SeriesCatalogPreview] {
        let localTitles = Set(localMatches.map { SeriesLibraryIdentity.normalizedSearchText($0.title) })
        guard localTitles.isEmpty == false else {
            return catalogResults
        }
        return catalogResults.filter {
            !localTitles.contains(SeriesLibraryIdentity.normalizedSearchText($0.title))
        }
    }

    private var searchRefreshKey: String {
        "\(selectedCollection.cacheKey)|\(trimmedQuery)"
    }

    private var searchControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AVBrandColor.accent)

                TextField(L10n.string("search.placeholder"), text: $query)
                    .font(.system(size: 20, weight: .bold))
                    .textInputAutocapitalization(.words)
                    .submitLabel(.search)

                if trimmedQuery.isEmpty == false {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.string("common.clear"))
                }
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SeriesSearchCollection.allCases, id: \.self) { collection in
                        Button {
                            selectedCollection = collection
                            query = ""
                        } label: {
                            Text(collection.title)
                                .font(.system(size: 13, weight: .bold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(selectedCollection == collection && trimmedQuery.isEmpty ? Color.white : Color.primary)
                        .background(selectedCollection == collection && trimmedQuery.isEmpty ? AVBrandColor.accent : Color(.secondarySystemGroupedBackground), in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(selectedCollection == collection && trimmedQuery.isEmpty ? AVBrandColor.accent.opacity(0.8) : Color.primary.opacity(0.08), lineWidth: 1)
                        }
                    }
                }
            }

            Text(limitText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if shouldShowUpgradeAction {
                Button {
                    runLimitAction()
                } label: {
                    Label(limitActionTitle, systemImage: limitActionSystemImage)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(accessController.accessMode == .guest && !accessController.accountIsAvailable)
            }

            if let addedEntry {
                SeriesUndoBar(
                    title: String(format: L10n.string("home.undo.added"), addedEntry.title),
                    undo: {
                        store.delete(addedEntry.id)
                        self.addedEntry = nil
                    },
                    dismiss: {
                        self.addedEntry = nil
                    }
                )
            }
        }
    }

    private func screenTitle(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 34, weight: .black))
                .foregroundStyle(AVBrandColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(AVBrandTypography.body)
                .foregroundStyle(AVBrandColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var exactMatchingEntry: SeriesLibraryEntry? {
        let normalizedQuery = SeriesLibraryIdentity.normalizedSearchText(query)
        guard normalizedQuery.isEmpty == false else {
            return nil
        }
        return store.activeEntries.first {
            SeriesLibraryIdentity.normalizedSearchText($0.title) == normalizedQuery
        }
    }

    private var shouldShowUpgradeAction: Bool {
        remainingSeriesCount != nil && !canAddSeries && accessController.accessMode != .signedInPro
    }

    private var limitActionTitle: String {
        switch accessController.accessMode {
        case .guest:
            accessController.accountIsAvailable ? L10n.string("add.footer.connectAccount") : L10n.string("profile.account.connectUnavailable")
        case .signedInFree:
            L10n.string("add.footer.upgrade")
        case .signedInPro:
            L10n.string("add.footer.upgrade")
        }
    }

    private var limitActionSystemImage: String {
        accessController.accessMode == .guest ? "person.crop.circle.badge.plus" : "sparkles"
    }

    private var limitText: String {
        if accessController.accessMode == .signedInPro && canAddSeries {
            return "\(L10n.string("add.footer.pro"))\n\(L10n.string("add.footer.hint"))"
        }
        guard let remainingSeriesCount else {
            return "\(L10n.string("add.footer.pro"))\n\(L10n.string("add.footer.hint"))"
        }
        if canAddSeries {
            return "\(String(format: L10n.string("add.footer.remaining"), remainingSeriesCount))\n\(L10n.string("add.footer.hint"))"
        }
        return L10n.string("add.footer.limitReached")
    }

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(resultsTitle)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .foregroundStyle(.primary)

                Text(resultsSubtitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if trimmedQuery.isEmpty == false && localMatches.isEmpty == false {
                ForEach(localMatches) { entry in
                    SeriesLibrarySearchResultCard(
                        entry: entry,
                        openDetail: { detailSelection = SeriesSearchDetailSelection(entry: entry) },
                        editProgress: { editorEntry = entry },
                        markNext: { store.markNextEpisodeWatched(for: entry.id) }
                    )
                }
            }

            if isSearchingCatalog {
                SeriesCatalogResultsSkeleton()
            } else if localMatches.isEmpty && visibleCatalogResults.isEmpty {
                ContentUnavailableView(
                    L10n.string("library.search.empty.title"),
                    systemImage: "magnifyingglass",
                    description: Text(L10n.string("library.search.empty.subtitle"))
                )
            } else {
                ForEach(visibleCatalogResults) { preview in
                    SeriesCatalogResultCard(
                        preview: preview,
                        libraryEntry: libraryEntry(for: preview),
                        canAddSeries: canAddSeries,
                        openDetail: {
                            detailSelection = SeriesSearchDetailSelection(
                                catalogItem: preview.catalogItem,
                                entry: libraryEntry(for: preview)
                            )
                        },
                        follow: { follow(preview) },
                        editProgress: { entry in editorEntry = entry }
                    )
                }
            }
        }
    }

    private var resultsTitle: String {
        trimmedQuery.isEmpty ? selectedCollection.title : String(format: L10n.string("search.resultsFor"), trimmedQuery)
    }

    private var resultsSubtitle: String {
        if trimmedQuery.isEmpty {
            return isSearchingCatalog
                ? L10n.string("search.collection.updating")
                : formattedCollectionCount(catalogResults.count)
        }
        let count = localMatches.count + visibleCatalogResults.count
        return formattedResultsCount(count)
    }

    private func formattedCollectionCount(_ count: Int) -> String {
        count == 1
            ? L10n.string("search.collection.count.one", count)
            : L10n.string("search.collection.count.other", count)
    }

    private func formattedResultsCount(_ count: Int) -> String {
        count == 1
            ? L10n.string("search.results.count.one", count)
            : L10n.string("search.results.count.other", count)
    }

    private func libraryEntry(for preview: SeriesCatalogPreview) -> SeriesLibraryEntry? {
        store.activeEntries.first {
            $0.seriesId == preview.id
        }
    }

    private func follow(_ preview: SeriesCatalogPreview) {
        guard let catalogItem = preview.catalogItem else {
            return
        }
        follow(catalogItem)
    }

    private func follow(_ catalogItem: SeriesCatalogItem) {
        guard canAddSeries else {
            runLimitAction()
            return
        }
        Task {
            guard let entry = store.addCatalogSeries(catalogItem) else {
                return
            }
            addedEntry = entry
            editorEntry = entry
        }
    }

    private func runLimitAction() {
        switch accessController.accessMode {
        case .guest:
            startSignInFlow()
        case .signedInFree:
            isShowingProPaywall = true
        case .signedInPro:
            break
        }
    }

    private func refreshCatalog() async {
        let searchQuery = trimmedQuery
        guard searchQuery.isEmpty == false else {
            remoteCatalogQuery = ""
            remoteCatalogResults = []
            await refreshSelectedCollection()
            return
        }

        isSearchingCatalog = true
        do {
            let client = SeriesCatalogSearchClient()
            let response = try await client.search(query: searchQuery, locale: Locale.current.identifier, limit: 12)
            guard searchQuery == trimmedQuery else { return }
            remoteCatalogQuery = searchQuery
            remoteCatalogResults = response.results.map { SeriesCatalogPreview(catalogItem: $0) }
        } catch {
            guard searchQuery == trimmedQuery else { return }
            remoteCatalogQuery = searchQuery
            remoteCatalogResults = []
        }
        isSearchingCatalog = false
    }

    private func refreshSelectedCollection() async {
        let collection = selectedCollection
        let collectionKey = collection.cacheKey
        isSearchingCatalog = true
        let client = SeriesCatalogSearchClient()
        let response = try? await client.popular(locale: Locale.current.identifier, surface: "search", limit: 12)

        guard trimmedQuery.isEmpty, selectedCollection == collection else {
            return
        }

        remoteCollectionKey = collectionKey
        remoteCollectionResults = (response?.results ?? [])
            .filter { collection == .popular || $0.genres.contains { SeriesLibraryIdentity.normalizedSearchText($0).contains(collection.cacheKey) } }
            .map { SeriesCatalogPreview(catalogItem: $0, collections: [collection]) }
        isSearchingCatalog = false
    }
}

private struct SeriesCatalogResultsSkeleton: View {
    var body: some View {
        VStack(spacing: 10) {
            ForEach(0..<4, id: \.self) { index in
                HStack(alignment: .center, spacing: 12) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(.tertiarySystemGroupedBackground))
                        .frame(width: 64, height: 88)

                    VStack(alignment: .leading, spacing: 8) {
                        skeletonLine(width: index.isMultiple(of: 2) ? 172 : 136, height: 18)
                        skeletonLine(width: index.isMultiple(of: 2) ? 98 : 124, height: 12)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Circle()
                        .fill(Color(.tertiarySystemGroupedBackground))
                        .frame(width: 42, height: 42)
                }
                .padding(10)
                .background(Color(.secondarySystemGroupedBackground).opacity(0.74), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                }
            }
        }
        .redacted(reason: .placeholder)
        .accessibilityHidden(true)
    }
}

private func skeletonLine(width: CGFloat, height: CGFloat) -> some View {
    RoundedRectangle(cornerRadius: height / 2, style: .continuous)
        .fill(Color(.tertiarySystemGroupedBackground))
        .frame(width: width, height: height)
}

private struct SeriesCatalogResultCard: View {
    let preview: SeriesCatalogPreview
    let libraryEntry: SeriesLibraryEntry?
    let canAddSeries: Bool
    let openDetail: () -> Void
    let follow: () -> Void
    let editProgress: (SeriesLibraryEntry) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            SeriesSearchPosterView(
                artwork: preview.artwork,
                width: 64,
                height: 88
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(preview.title)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                Text(metadataText)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let libraryEntry {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AVBrandColor.accent)

                    detailButton

                    Button {
                        editProgress(libraryEntry)
                    } label: {
                        Image(systemName: "scope")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.primary)
                            .frame(width: 40, height: 40)
                            .background(Color(.tertiarySystemGroupedBackground), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.string("home.adjust"))
                }
            } else {
                VStack(spacing: 8) {
                    detailButton

                    Button(action: follow) {
                        Image(systemName: canAddSeries ? "plus" : "sparkles")
                            .font(.system(size: 17, weight: .black))
                            .foregroundStyle(canAddSeries ? Color.black.opacity(0.84) : AVBrandColor.accent)
                            .frame(width: 42, height: 42)
                            .background(canAddSeries ? AVBrandColor.accent : Color(.tertiarySystemGroupedBackground), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(canAddSeries ? L10n.string("search.follow") : L10n.string("add.footer.upgrade"))
                }
            }
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground).opacity(0.74), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }

    private var detailButton: some View {
        Button(action: openDetail) {
            Image(systemName: "info.circle")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.primary)
                .frame(width: 40, height: 40)
                .background(Color(.tertiarySystemGroupedBackground), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.string("detail.open"))
    }

    private var metadataText: String {
        let parts = [
            preview.year.map(String.init)
        ] + preview.genres.prefix(2).map(Optional.some)

        return parts
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: " · ")
    }
}

private struct SeriesLibrarySearchResultCard: View {
    let entry: SeriesLibraryEntry
    let openDetail: () -> Void
    let editProgress: () -> Void
    let markNext: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            SeriesEntryArtworkView(entry: entry, size: 62)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                HStack(spacing: 7) {
                    Label(statusTitle(entry.status), systemImage: statusIconName)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AVBrandColor.accent)

                    Text(nextEpisodeText)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            VStack(spacing: 8) {
                Button(action: openDetail) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 40, height: 40)
                        .background(Color(.tertiarySystemGroupedBackground), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.string("detail.open"))

                Button(action: editProgress) {
                    Image(systemName: "scope")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 40, height: 40)
                        .background(Color(.tertiarySystemGroupedBackground), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.string("home.adjust"))

                Button(action: markNext) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(Color.black.opacity(0.84))
                        .frame(width: 40, height: 40)
                        .background(AVBrandColor.accent, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.string("shell.watch.next"))
            }
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground).opacity(0.74), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }

    private var detail: String {
        if entry.status == .wantToWatch {
            return "\(statusTitle(entry.status)) · \(String(format: L10n.string("home.queue.wantToWatch.progress"), cursorLabel(entry.nextEpisodeCursor)))"
        }
        return "\(statusTitle(entry.status)) · \(entry.progressLabel)"
    }

    private var nextEpisodeText: String {
        String(format: L10n.string("home.current.nextEpisode"), cursorLabel(entry.nextEpisodeCursor))
    }

    private var statusIconName: String {
        switch entry.status {
        case .wantToWatch:
            return "bookmark"
        case .watching:
            return "play.circle"
        case .watched:
            return "checkmark.circle"
        }
    }
}

private struct SeriesSearchDetailSelection: Identifiable {
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

private enum SeriesSearchCollection: CaseIterable {
    case popular
    case anime
    case drama
    case comedy
    case sciFi
    case animation

    var title: String {
        switch self {
        case .popular:
            return L10n.string("search.collection.popular")
        case .anime:
            return L10n.string("search.collection.anime")
        case .drama:
            return L10n.string("search.collection.drama")
        case .comedy:
            return L10n.string("search.collection.comedy")
        case .sciFi:
            return L10n.string("search.collection.scifi")
        case .animation:
            return L10n.string("search.collection.animation")
        }
    }

    var cacheKey: String {
        switch self {
        case .popular:
            return "popular"
        case .anime:
            return "anime"
        case .drama:
            return "drama"
        case .comedy:
            return "comedy"
        case .sciFi:
            return "sci-fi"
        case .animation:
            return "animation"
        }
    }
}

private struct SeriesCatalogPreview: Identifiable {
    let id: String
    let title: String
    let year: Int?
    let genres: [String]
    let artwork: SeriesSearchArtwork
    let collections: Set<SeriesSearchCollection>
    let catalogItem: SeriesCatalogItem?

    init(
        id: String,
        title: String,
        year: Int?,
        genres: [String],
        artwork: SeriesSearchArtwork,
        collections: Set<SeriesSearchCollection>,
        catalogItem: SeriesCatalogItem? = nil
    ) {
        self.id = id
        self.title = title
        self.year = year
        self.genres = genres
        self.artwork = artwork
        self.collections = collections
        self.catalogItem = catalogItem
    }

    init(catalogItem: SeriesCatalogItem, collections: Set<SeriesSearchCollection> = []) {
        self.init(
            id: catalogItem.seriesId,
            title: catalogItem.title,
            year: catalogItem.startYear,
            genres: catalogItem.genres,
            artwork: catalogItem.displayArtwork.url.map { .approvedPoster($0.absoluteString, seed: catalogItem.title) } ?? .fallback(seed: catalogItem.title),
            collections: collections,
            catalogItem: catalogItem
        )
    }

}

private struct SeriesSearchArtwork: Equatable {
    enum Source: Equatable {
        case curatedSeriesAV
        case approvedPoster(URL)
        case generatedFallback
        case initialsFallback
    }

    enum DisplayState: Equatable {
        case displayable
        case screenshotSafe
        case fallbackOnly
    }

    var source: Source
    var displayState: DisplayState
    var fallbackSeed: String

    var displayArtworkRef: String? {
        switch source {
        case .approvedPoster(let url):
            return displayState == .fallbackOnly ? nil : url.absoluteString
        case .curatedSeriesAV, .generatedFallback, .initialsFallback:
            return nil
        }
    }

    static func fallback(seed: String) -> SeriesSearchArtwork {
        SeriesSearchArtwork(
            source: .generatedFallback,
            displayState: .fallbackOnly,
            fallbackSeed: seed
        )
    }

    static func approvedPoster(_ urlString: String, seed: String) -> SeriesSearchArtwork {
        guard let url = URL(string: urlString) else {
            return fallback(seed: seed)
        }
        return SeriesSearchArtwork(
            source: .approvedPoster(url),
            displayState: .displayable,
            fallbackSeed: seed
        )
    }
}

private struct SeriesSearchPosterView: View {
    let artwork: SeriesSearchArtwork
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        renderedArtwork
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.28), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.10), radius: 10, y: 5)
    }

    @ViewBuilder
    private var renderedArtwork: some View {
        switch artwork.source {
        case .curatedSeriesAV, .generatedFallback, .initialsFallback:
            SeriesPosterMark(seed: artwork.fallbackSeed, size: width)
        case .approvedPoster(let url):
            switch artwork.displayState {
            case .displayable, .screenshotSafe:
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        SeriesPosterMark(seed: artwork.fallbackSeed, size: width)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        SeriesPosterMark(seed: artwork.fallbackSeed, size: width)
                    @unknown default:
                        SeriesPosterMark(seed: artwork.fallbackSeed, size: width)
                    }
                }
            case .fallbackOnly:
                SeriesPosterMark(seed: artwork.fallbackSeed, size: width)
            }
        }
    }
}
