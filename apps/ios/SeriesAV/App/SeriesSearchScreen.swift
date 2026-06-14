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

    var body: some View {
        AVAppShellScrollableScreenScaffold(
            alignment: .leading,
            spacing: 16,
            bottomPadding: 176
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
            let samples = SeriesCatalogPreview.samples(for: selectedCollection)
            guard remoteCollectionKey == selectedCollection.cacheKey else {
                return samples
            }
            return SeriesCatalogPreview.mergingBackendResults(remoteCollectionResults, over: samples)
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

                TextField(L10n.string("add.search.placeholder"), text: $query)
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

    private var canSubmit: Bool {
        canAddSeries && trimmedQuery.isEmpty == false && exactMatchingEntry == nil
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
                        editProgress: { editorEntry = entry },
                        markNext: { store.markNextEpisodeWatched(for: entry.id) }
                    )
                }
            }

            if isSearchingCatalog && trimmedQuery.isEmpty == false {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(L10n.string("search.loading"))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 14)
            } else if isSearchingCatalog && trimmedQuery.isEmpty {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(L10n.string("search.collection.updating"))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
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

    private func addTypedSeries() {
        guard canSubmit else {
            return
        }
        guard let entry = store.addLocalSeries(title: trimmedQuery) else {
            return
        }
        addedEntry = entry
        editorEntry = entry
        query = ""
    }

    private func libraryEntry(for preview: SeriesCatalogPreview) -> SeriesLibraryEntry? {
        store.activeEntries.first {
            SeriesLibraryIdentity.normalizedSearchText($0.title) == SeriesLibraryIdentity.normalizedSearchText(preview.title)
        }
    }

    private func follow(_ preview: SeriesCatalogPreview) {
        guard canAddSeries else {
            runLimitAction()
            return
        }
        Task {
            let resolved: SeriesCatalogResolveCandidate?
            if let candidate = preview.resolvedCandidate {
                resolved = candidate
            } else {
                resolved = await resolve(preview)
            }
            guard let entry = store.addLocalSeries(
                title: preview.title,
                seriesId: resolved?.series.id,
                providerRef: resolved?.series.providerRefs.first,
                displayArtworkRef: resolved?.series.posterUrl?.absoluteString ?? preview.artwork.displayArtworkRef
            ) else {
                return
            }
            addedEntry = entry
            editorEntry = entry
        }
    }

    private func resolve(_ preview: SeriesCatalogPreview) async -> SeriesCatalogResolveCandidate? {
        guard accessController.isSignedIn else {
            return nil
        }

        do {
            let client = SeriesCatalogResolveClient(apiClient: accessController.authenticatedAPIClient())
            let response = try await client.resolve(SeriesCatalogResolveRequest(query: preview.title, year: preview.year))
            return response.candidates.first { $0.matchConfidence == "exact" || $0.matchConfidence == "strong" } ?? response.candidates.first
        } catch {
            return nil
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

        guard accessController.isSignedIn else {
            remoteCatalogQuery = searchQuery
            remoteCatalogResults = SeriesCatalogPreview.searchSamples(searchQuery)
            isSearchingCatalog = false
            return
        }

        isSearchingCatalog = true
        do {
            let client = SeriesCatalogResolveClient(apiClient: accessController.authenticatedAPIClient())
            let response = try await client.resolve(SeriesCatalogResolveRequest(query: searchQuery))
            guard searchQuery == trimmedQuery else { return }
            remoteCatalogQuery = searchQuery
            remoteCatalogResults = response.candidates.map { SeriesCatalogPreview(candidate: $0) }
        } catch {
            guard searchQuery == trimmedQuery else { return }
            remoteCatalogQuery = searchQuery
            remoteCatalogResults = SeriesCatalogPreview.searchSamples(searchQuery)
        }
        isSearchingCatalog = false
    }

    private func refreshSelectedCollection() async {
        guard accessController.isSignedIn else {
            remoteCollectionKey = ""
            remoteCollectionResults = []
            isSearchingCatalog = false
            return
        }

        let collection = selectedCollection
        let collectionKey = collection.cacheKey
        let samples = SeriesCatalogPreview.samples(for: collection)
        guard samples.isEmpty == false else {
            remoteCollectionKey = collectionKey
            remoteCollectionResults = []
            isSearchingCatalog = false
            return
        }

        isSearchingCatalog = true
        let client = SeriesCatalogResolveClient(apiClient: accessController.authenticatedAPIClient())
        var resolvedPreviews: [SeriesCatalogPreview] = []

        await withTaskGroup(of: SeriesCatalogPreview?.self) { group in
            for sample in samples {
                group.addTask {
                    do {
                        let response = try await client.resolve(SeriesCatalogResolveRequest(query: sample.title, year: sample.year))
                        guard let candidate = response.candidates.first(where: { $0.matchConfidence == "exact" || $0.matchConfidence == "strong" }) ?? response.candidates.first else {
                            return nil
                        }
                        return SeriesCatalogPreview(candidate: candidate, collections: sample.collections)
                    } catch {
                        return nil
                    }
                }
            }

            for await preview in group {
                if let preview {
                    resolvedPreviews.append(preview)
                }
            }
        }

        guard trimmedQuery.isEmpty, selectedCollection == collection else {
            return
        }

        remoteCollectionKey = collectionKey
        remoteCollectionResults = resolvedPreviews
        isSearchingCatalog = false
    }
}

private struct SeriesCatalogResultCard: View {
    let preview: SeriesCatalogPreview
    let libraryEntry: SeriesLibraryEntry?
    let canAddSeries: Bool
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

                HStack(spacing: 7) {
                    if let year = preview.year {
                        Text(String(year))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                    }

                    ForEach(preview.genres.prefix(2), id: \.self) { genre in
                        Text(genre)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AVBrandColor.accent)
                    }
                }

            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let libraryEntry {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AVBrandColor.accent)

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
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground).opacity(0.74), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct SeriesLibrarySearchResultCard: View {
    let entry: SeriesLibraryEntry
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
    let resolvedCandidate: SeriesCatalogResolveCandidate?

    init(
        id: String,
        title: String,
        year: Int?,
        genres: [String],
        artwork: SeriesSearchArtwork,
        collections: Set<SeriesSearchCollection>,
        resolvedCandidate: SeriesCatalogResolveCandidate? = nil
    ) {
        self.id = id
        self.title = title
        self.year = year
        self.genres = genres
        self.artwork = artwork
        self.collections = collections
        self.resolvedCandidate = resolvedCandidate
    }

    init(candidate: SeriesCatalogResolveCandidate, collections: Set<SeriesSearchCollection> = []) {
        let series = candidate.series
        self.init(
            id: series.id,
            title: series.title,
            year: series.year,
            genres: series.genres,
            artwork: series.posterUrl.map { .approvedPoster($0.absoluteString, seed: series.title) } ?? .fallback(seed: series.title),
            collections: collections,
            resolvedCandidate: candidate
        )
    }

    static func samples(for collection: SeriesSearchCollection) -> [SeriesCatalogPreview] {
        samples.filter { $0.collections.contains(collection) }
    }

    static func searchSamples(_ query: String) -> [SeriesCatalogPreview] {
        let normalizedQuery = SeriesLibraryIdentity.normalizedSearchText(query)
        guard normalizedQuery.isEmpty == false else {
            return samples(for: .popular)
        }
        if ["anime", "animes"].contains(normalizedQuery) {
            return samples(for: .anime)
        }
        return samples.filter {
            SeriesLibraryIdentity.normalizedSearchText($0.title).contains(normalizedQuery)
                || $0.genres.contains { SeriesLibraryIdentity.normalizedSearchText($0).contains(normalizedQuery) }
        }
    }

    static func mergingBackendResults(
        _ backendResults: [SeriesCatalogPreview],
        over samples: [SeriesCatalogPreview]
    ) -> [SeriesCatalogPreview] {
        var merged: [SeriesCatalogPreview] = []
        var usedBackendIDs = Set<String>()

        for sample in samples {
            if let backend = backendResults.bestMatch(for: sample) {
                merged.append(backend)
                usedBackendIDs.insert(backend.id)
            } else {
                merged.append(sample)
            }
        }

        for backend in backendResults where !usedBackendIDs.contains(backend.id) {
            merged.append(backend)
        }

        return merged
    }

    private static let samples: [SeriesCatalogPreview] = [
        SeriesCatalogPreview(id: "the-last-of-us", title: "The Last of Us", year: 2023, genres: ["Drama", "Sci-Fi"], artwork: .approvedPoster("https://static.tvmaze.com/uploads/images/medium_portrait/563/1409008.jpg", seed: "The Last of Us"), collections: [.popular, .drama, .sciFi]),
        SeriesCatalogPreview(id: "severance", title: "Severance", year: 2022, genres: ["Drama", "Sci-Fi"], artwork: .approvedPoster("https://static.tvmaze.com/uploads/images/medium_portrait/548/1371406.jpg", seed: "Severance"), collections: [.popular, .drama, .sciFi]),
        SeriesCatalogPreview(id: "the-bear", title: "The Bear", year: 2022, genres: ["Drama", "Comedia"], artwork: .approvedPoster("https://static.tvmaze.com/uploads/images/medium_portrait/626/1567246.jpg", seed: "The Bear"), collections: [.popular, .drama, .comedy]),
        SeriesCatalogPreview(id: "slow-horses", title: "Slow Horses", year: 2022, genres: ["Drama"], artwork: .approvedPoster("https://static.tvmaze.com/uploads/images/medium_portrait/593/1484384.jpg", seed: "Slow Horses"), collections: [.popular, .drama]),
        SeriesCatalogPreview(id: "abbott-elementary", title: "Abbott Elementary", year: 2021, genres: ["Comedia"], artwork: .approvedPoster("https://static.tvmaze.com/uploads/images/medium_portrait/586/1467109.jpg", seed: "Abbott Elementary"), collections: [.popular, .comedy]),
        SeriesCatalogPreview(id: "rick-and-morty", title: "Rick and Morty", year: 2013, genres: ["Animacion", "Sci-Fi"], artwork: .approvedPoster("https://static.tvmaze.com/uploads/images/medium_portrait/626/1566363.jpg", seed: "Rick and Morty"), collections: [.popular, .animation, .sciFi, .comedy]),
        SeriesCatalogPreview(id: "arcane", title: "Arcane", year: 2021, genres: ["Animacion", "Drama"], artwork: .approvedPoster("https://static.tvmaze.com/uploads/images/medium_portrait/536/1340287.jpg", seed: "Arcane"), collections: [.popular, .animation, .drama]),
        SeriesCatalogPreview(id: "attack-on-titan", title: "Attack on Titan", year: 2013, genres: ["Anime", "Fantasy"], artwork: .approvedPoster("https://static.tvmaze.com/uploads/images/medium_portrait/476/1191684.jpg", seed: "Attack on Titan"), collections: [.popular, .anime, .animation, .drama]),
        SeriesCatalogPreview(id: "death-note", title: "Death Note", year: 2006, genres: ["Anime", "Thriller"], artwork: .approvedPoster("https://static.tvmaze.com/uploads/images/medium_portrait/499/1249019.jpg", seed: "Death Note"), collections: [.anime, .animation, .drama]),
        SeriesCatalogPreview(id: "liar-game", title: "Liar Game", year: 2026, genres: ["Anime", "Thriller"], artwork: .approvedPoster("https://static.tvmaze.com/uploads/images/medium_portrait/620/1551709.jpg", seed: "Liar Game"), collections: [.anime]),
        SeriesCatalogPreview(id: "for-all-mankind", title: "For All Mankind", year: 2019, genres: ["Drama", "Sci-Fi"], artwork: .approvedPoster("https://static.tvmaze.com/uploads/images/medium_portrait/616/1541416.jpg", seed: "For All Mankind"), collections: [.sciFi, .drama]),
        SeriesCatalogPreview(id: "brooklyn-nine-nine", title: "Brooklyn Nine-Nine", year: 2013, genres: ["Comedia"], artwork: .approvedPoster("https://static.tvmaze.com/uploads/images/medium_portrait/402/1007484.jpg", seed: "Brooklyn Nine-Nine"), collections: [.comedy]),
        SeriesCatalogPreview(id: "bojack-horseman", title: "BoJack Horseman", year: 2014, genres: ["Animacion", "Comedia"], artwork: .approvedPoster("https://static.tvmaze.com/uploads/images/medium_portrait/405/1012627.jpg", seed: "BoJack Horseman"), collections: [.animation, .comedy])
    ]
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

private extension Array where Element == SeriesCatalogPreview {
    func bestMatch(for sample: SeriesCatalogPreview) -> SeriesCatalogPreview? {
        let sampleTitle = SeriesLibraryIdentity.normalizedSearchText(sample.title)
        if let exact = first(where: { SeriesLibraryIdentity.normalizedSearchText($0.title) == sampleTitle }) {
            return exact
        }
        return first {
            SeriesLibraryIdentity.normalizedSearchText($0.title).contains(sampleTitle)
                || sampleTitle.contains(SeriesLibraryIdentity.normalizedSearchText($0.title))
        }
    }
}
