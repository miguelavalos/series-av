import AVAppShellFoundation
import AVBrandFoundation
import SwiftUI
import UIKit

struct SeriesSearchScreen: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @Bindable var store: SeriesLibraryStore
    let accessController: SeriesAccessController
    let startSignInFlow: () -> Void

    @State private var addedEntry: SeriesLibraryEntry?
    @State private var query = ""
    @State private var sheetDestination: SeriesSearchSheetDestination?
    @State private var selectedCollection: SeriesSearchCollection = .popular
    @State private var remoteCatalogResults: [SeriesCatalogPreview] = []
    @State private var remoteCatalogQuery = ""
    @State private var remoteCollectionResults: [SeriesCatalogPreview] = []
    @State private var remoteCollectionKey = ""
    @State private var catalogLoadState = SeriesCatalogLoadState()

    private var isTabletLayout: Bool {
        UIDevice.current.userInterfaceIdiom == .pad && horizontalSizeClass != .compact
    }

    var body: some View {
        AVAppShellScrollableScreenScaffold(
            alignment: .leading,
            spacing: 22,
            bottomPadding: isTabletLayout ? 56 : 236,
            maxContentWidth: 1120
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
        .sheet(item: $sheetDestination) { destination in
            searchSheet(for: destination)
        }
        .task(id: searchRefreshKey) {
            await refreshCatalog()
        }
        .scrollDismissesKeyboard(.interactively)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    @ViewBuilder
    private func searchSheet(for destination: SeriesSearchSheetDestination) -> some View {
        switch destination {
        case .proPaywall:
            SeriesProPaywallView(
                accessController: accessController,
                startSignInFlow: startSignInFlow
            )
        case .progressEditor(let entry):
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
        case .detail(let selection):
            SeriesDetailScreen(
                catalogItem: selection.catalogItem,
                entry: selection.entry,
                canFollow: canAddSeries,
                follow: selection.entry == nil ? {
                    if let catalogItem = selection.catalogItem {
                        follow(catalogItem)
                        sheetDestination = nil
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
                setPinned: { entry, isPinned in
                    store.setPinned(isPinned, for: entry.id)
                },
                setPrivateNote: { entry, note in
                    store.setPrivateNote(note, for: entry.id)
                },
                shareInviteClient: shareInviteClient
            )
            .presentationDetents([.large])
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

    private var displayedCatalogResults: [SeriesCatalogPreview] {
        let localTitles = Set(localMatches.map { SeriesLibraryIdentity.normalizedSearchText($0.title) })
        return SeriesSearchResultsPolicy.resultsForDisplay(
            catalogResults,
            excludingNormalizedTitles: localTitles
        ) {
            SeriesLibraryIdentity.normalizedSearchText($0.title)
        }
    }

    private var searchRefreshKey: String {
        "\(selectedCollection.cacheKey)|\(trimmedQuery)"
    }

    private var isSearchingCatalog: Bool {
        catalogLoadState.isLoading
    }

    private var searchControls: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AVBrandColor.accent)

                TextField(L10n.string("search.placeholder"), text: $query)
                    .font(.title3.weight(.bold))
                    .textInputAutocapitalization(.words)
                    .submitLabel(.search)
                    .accessibilityIdentifier("series-search-field")

                if trimmedQuery.isEmpty == false {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
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

            collectionFilters

            Text(limitText)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("series-search-limit")

            if shouldShowUpgradeAction {
                Button {
                    runLimitAction()
                } label: {
                    Label(limitActionTitle, systemImage: limitActionSystemImage)
                }
                .buttonStyle(.bordered)
                .controlSize(dynamicTypeSize.isAccessibilitySize ? .regular : .small)
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

    @ViewBuilder
    private var collectionFilters: some View {
        if dynamicTypeSize.isAccessibilitySize {
            collectionFilterMenu
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    ForEach(SeriesSearchCollection.allCases, id: \.self) { collection in
                        collectionFilterButton(collection)
                    }
                }
                .fixedSize(horizontal: true, vertical: false)

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 100), spacing: 8)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(SeriesSearchCollection.allCases, id: \.self) { collection in
                        collectionFilterButton(collection, fillsAvailableWidth: true)
                    }
                }
            }
        }
    }

    private func collectionFilterButton(
        _ collection: SeriesSearchCollection,
        fillsAvailableWidth: Bool = false
    ) -> some View {
        Button {
            selectCollection(collection)
        } label: {
            Text(collection.title)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .padding(.horizontal, fillsAvailableWidth ? 8 : 14)
                .frame(maxWidth: fillsAvailableWidth ? .infinity : nil, minHeight: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected(collection) ? Color.white : Color.primary)
        .background(isSelected(collection) ? AVBrandColor.accent : Color(.secondarySystemGroupedBackground), in: Capsule())
        .overlay {
            Capsule()
                .stroke(isSelected(collection) ? AVBrandColor.accent.opacity(0.8) : Color.primary.opacity(0.08), lineWidth: 1)
        }
        .accessibilityIdentifier("series-search-filter-\(collection.cacheKey)")
    }

    private var collectionFilterMenu: some View {
        Menu {
            ForEach(SeriesSearchCollection.allCases, id: \.self) { collection in
                Button {
                    selectCollection(collection)
                } label: {
                    if collection == selectedCollection {
                        Label(collection.title, systemImage: "checkmark")
                    } else {
                        Text(collection.title)
                    }
                }
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "line.3.horizontal.decrease")
                    .foregroundStyle(AVBrandColor.accent)
                Text(selectedCollection.title)
                    .font(.headline.weight(.bold))
                Spacer(minLength: 8)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(AVBrandColor.textPrimary)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            }
        }
        .accessibilityLabel(L10n.string("search.filter.selector.label"))
        .accessibilityValue(selectedCollection.title)
        .accessibilityIdentifier("series-search-filter-selector")
    }

    private func selectCollection(_ collection: SeriesSearchCollection) {
        selectedCollection = collection
        query = ""
    }

    private func isSelected(_ collection: SeriesSearchCollection) -> Bool {
        selectedCollection == collection && trimmedQuery.isEmpty
    }

    private func screenTitle(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.largeTitle.weight(.black))
                .foregroundStyle(AVBrandColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("series-search-title")

            Text(subtitle)
                .font(AVBrandTypography.body)
                .foregroundStyle(AVBrandColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("series-search-subtitle")
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
            return L10n.string("add.footer.pro")
        }
        guard let remainingSeriesCount else {
            return L10n.string("add.footer.pro")
        }
        if canAddSeries {
            return String(format: L10n.string("add.footer.remaining"), remainingSeriesCount)
        }
        return L10n.string("add.footer.limitReached")
    }

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(resultsTitle)
                    .font(.headline.weight(.black))
                    .fontDesign(.rounded)
                    .foregroundStyle(.primary)
                    .accessibilityIdentifier("series-search-results-title")

                Text(resultsSubtitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("series-search-results-subtitle")
            }

            if trimmedQuery.isEmpty == false && localMatches.isEmpty == false {
                LazyVGrid(columns: searchGridColumns, alignment: .leading, spacing: 10) {
                    ForEach(localMatches) { entry in
                        SeriesLibrarySearchResultCard(
                            entry: entry,
                            openDetail: { sheetDestination = .detail(SeriesSearchDetailSelection(entry: entry)) },
                            editProgress: { sheetDestination = .progressEditor(entry) },
                            markNext: { store.markNextEpisodeWatched(for: entry.id) }
                        )
                    }
                }
            }

            if isSearchingCatalog {
                SeriesCatalogResultsSkeleton()
            } else if localMatches.isEmpty && displayedCatalogResults.isEmpty {
                ContentUnavailableView(
                    L10n.string("library.search.empty.title"),
                    systemImage: "magnifyingglass",
                    description: Text(L10n.string("library.search.empty.subtitle"))
                )
            } else {
                LazyVGrid(columns: searchGridColumns, alignment: .leading, spacing: 10) {
                    ForEach(displayedCatalogResults) { preview in
                        SeriesCatalogResultCard(
                            preview: preview,
                            libraryEntry: libraryEntry(for: preview),
                            canAddSeries: canAddSeries,
                            openDetail: {
                                sheetDestination = .detail(SeriesSearchDetailSelection(
                                    catalogItem: preview.catalogItem,
                                    entry: libraryEntry(for: preview)
                                ))
                            },
                            follow: { follow(preview) },
                            editProgress: { entry in sheetDestination = .progressEditor(entry) }
                        )
                    }
                }
            }
        }
    }

    private var searchGridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: dynamicTypeSize.isAccessibilitySize ? 520 : 360), spacing: 10)]
    }

    private var resultsTitle: String {
        trimmedQuery.isEmpty ? selectedCollection.title : String(format: L10n.string("search.resultsFor"), trimmedQuery)
    }

    private var resultsSubtitle: String {
        if trimmedQuery.isEmpty {
            return isSearchingCatalog
                ? L10n.string("search.collection.updating")
                : formattedCollectionCount(displayedCatalogResults.count)
        }
        let count = localMatches.count + displayedCatalogResults.count
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
        }
    }

    private func runLimitAction() {
        switch accessController.accessMode {
        case .guest:
            startSignInFlow()
        case .signedInFree:
            sheetDestination = .proPaywall
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

        let loadToken = catalogLoadState.begin()
        defer {
            catalogLoadState.finish(loadToken)
        }

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
    }

    private func refreshSelectedCollection() async {
        let collection = selectedCollection
        let collectionKey = collection.cacheKey
        let loadToken = catalogLoadState.begin()
        defer {
            catalogLoadState.finish(loadToken)
        }

        let client = SeriesCatalogSearchClient()
        let response = try? await client.popular(
            locale: Locale.current.identifier,
            surface: "search",
            genre: collection.genreQuery,
            limit: isTabletLayout ? 18 : 12
        )

        guard trimmedQuery.isEmpty, selectedCollection == collection else {
            return
        }

        remoteCollectionKey = collectionKey
        remoteCollectionResults = (response?.results ?? [])
            .map { SeriesCatalogPreview(catalogItem: $0, collections: [collection]) }
    }
}

struct SeriesCatalogLoadState: Equatable {
    struct Token: Equatable {
        fileprivate let value: Int
    }

    private var nextTokenValue = 0
    private(set) var activeToken: Token?
    private(set) var isLoading = false

    mutating func begin() -> Token {
        nextTokenValue += 1
        let token = Token(value: nextTokenValue)
        activeToken = token
        isLoading = true
        return token
    }

    mutating func finish(_ token: Token) {
        guard activeToken == token else { return }
        activeToken = nil
        isLoading = false
    }
}

enum SeriesSearchResultsPolicy {
    static func resultsForDisplay<Result>(
        _ catalogResults: [Result],
        excludingNormalizedTitles localTitles: Set<String>,
        normalizedTitle: (Result) -> String
    ) -> [Result] {
        guard localTitles.isEmpty == false else {
            return catalogResults
        }
        return catalogResults.filter {
            !localTitles.contains(normalizedTitle($0))
        }
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let preview: SeriesCatalogPreview
    let libraryEntry: SeriesLibraryEntry?
    let canAddSeries: Bool
    let openDetail: () -> Void
    let follow: () -> Void
    let editProgress: (SeriesLibraryEntry) -> Void

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    resultButton
                    accessibilityAction
                }
            } else {
                HStack(alignment: .center, spacing: 12) {
                    resultButton
                    compactAction
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

    private var resultButton: some View {
        Button(action: openDetail) {
            resultContent
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel(preview.title)
        .accessibilityValue(accessibilityMetadataText)
        .accessibilityHint(L10n.string("detail.open"))
        .accessibilityIdentifier("series-search-catalog-\(preview.id)-open")
    }

    @ViewBuilder
    private var compactAction: some View {
        if let libraryEntry {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.body.weight(.bold))
                    .foregroundStyle(AVBrandColor.accent)

                SeriesCompactIconButton(
                    systemName: "scope",
                    style: .secondary,
                    size: 44,
                    accessibilityLabel: L10n.string("home.adjust"),
                    accessibilityIdentifier: "series-search-\(libraryEntry.id)-edit-progress"
                ) {
                    editProgress(libraryEntry)
                }
            }
        } else {
            Button(action: follow) {
                Image(systemName: canAddSeries ? "plus" : "sparkles")
                    .font(.body.weight(.black))
                    .foregroundStyle(canAddSeries ? Color.black.opacity(0.84) : AVBrandColor.accent)
                    .frame(width: 44, height: 44)
                    .background(canAddSeries ? AVBrandColor.accent : Color(.tertiarySystemGroupedBackground), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(followActionTitle)
            .accessibilityIdentifier("series-search-catalog-\(preview.id)-follow")
        }
    }

    @ViewBuilder
    private var accessibilityAction: some View {
        if let libraryEntry {
            SeriesSearchWideActionButton(
                title: L10n.string("home.adjust"),
                systemImage: "scope",
                style: .secondary,
                accessibilityIdentifier: "series-search-\(libraryEntry.id)-edit-progress"
            ) {
                editProgress(libraryEntry)
            }
        } else {
            SeriesSearchWideActionButton(
                title: followActionTitle,
                systemImage: canAddSeries ? "plus" : "sparkles",
                style: canAddSeries ? .accent : .secondary,
                accessibilityIdentifier: "series-search-catalog-\(preview.id)-follow",
                action: follow
            )
        }
    }

    private var resultContent: some View {
        HStack(alignment: .center, spacing: 12) {
            SeriesSearchPosterView(
                artwork: preview.artwork,
                width: dynamicTypeSize.isAccessibilitySize ? 72 : 64,
                height: dynamicTypeSize.isAccessibilitySize ? 100 : 88
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(preview.title)
                    .font(.headline.weight(.black))
                    .fontDesign(.rounded)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(metadataText)
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.secondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                    .fixedSize(horizontal: false, vertical: true)

                if let supplementaryMetadataText {
                    Text(supplementaryMetadataText)
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.secondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var followActionTitle: String {
        canAddSeries ? L10n.string("search.follow") : L10n.string("add.footer.upgrade")
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

    private var supplementaryMetadataText: String? {
        guard let catalogItem = preview.catalogItem else { return nil }
        return SeriesSearchSupplementaryMetadata.text(
            statusText: catalogItem.statusText,
            latestKnownEpisodeCursor: catalogItem.latestKnownEpisodeCursor,
            knownEpisodeCount: catalogItem.knownEpisodeCount
        )
    }

    private var accessibilityMetadataText: String {
        [metadataText, supplementaryMetadataText]
            .compactMap { $0 }
            .filter { $0.isEmpty == false }
            .joined(separator: ", ")
    }
}

enum SeriesCatalogAvailabilityStatus: Equatable, Sendable {
    case running
    case ended
    case upcoming
    case cancelled
    case hiatus

    init?(providerText: String?) {
        guard let providerText else { return nil }
        let normalized = providerText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch normalized {
        case "running", "continuing", "returning series":
            self = .running
        case "ended", "completed":
            self = .ended
        case "upcoming", "in development", "pre-production", "planned":
            self = .upcoming
        case "cancelled", "canceled":
            self = .cancelled
        case "hiatus", "on hiatus":
            self = .hiatus
        default:
            return nil
        }
    }

    var localizationKey: String {
        switch self {
        case .running:
            "search.metadata.status.running"
        case .ended:
            "search.metadata.status.ended"
        case .upcoming:
            "search.metadata.status.upcoming"
        case .cancelled:
            "search.metadata.status.cancelled"
        case .hiatus:
            "search.metadata.status.hiatus"
        }
    }
}

struct SeriesSearchSupplementaryMetadata {
    static func text(
        statusText: String?,
        latestKnownEpisodeCursor: SeriesEpisodeCursor?,
        knownEpisodeCount: Int?
    ) -> String? {
        var parts: [String] = []

        if let status = SeriesCatalogAvailabilityStatus(providerText: statusText) {
            parts.append(L10n.string(status.localizationKey))
        }

        if let latestKnownEpisodeCursor {
            parts.append(
                String(
                    format: L10n.string("search.metadata.throughSeason"),
                    latestKnownEpisodeCursor.seasonNumber
                )
            )
        }

        if let knownEpisodeCount, knownEpisodeCount > 0 {
            let key = knownEpisodeCount == 1
                ? "search.metadata.episodes.one"
                : "search.metadata.episodes.other"
            parts.append(String(format: L10n.string(key), knownEpisodeCount))
        }

        guard parts.isEmpty == false else { return nil }
        return parts.joined(separator: " · ")
    }
}

private struct SeriesLibrarySearchResultCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let entry: SeriesLibraryEntry
    let openDetail: () -> Void
    let editProgress: () -> Void
    let markNext: () -> Void

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    resultButton

                    VStack(spacing: 10) {
                        SeriesSearchWideActionButton(
                            title: L10n.string("home.adjust"),
                            systemImage: "scope",
                            style: .secondary,
                            accessibilityIdentifier: "series-search-\(entry.id)-edit-progress",
                            action: editProgress
                        )

                        SeriesSearchWideActionButton(
                            title: primaryProgressActionTitle(for: entry),
                            systemImage: quickProgressFilledSystemImage(for: entry),
                            style: .accent,
                            accessibilityIdentifier: "series-search-\(entry.id)-quick-progress",
                            action: markNext
                        )
                    }
                }
            } else {
                HStack(alignment: .center, spacing: 12) {
                    resultButton

                    VStack(spacing: 8) {
                        SeriesCompactIconButton(
                            systemName: "scope",
                            style: .secondary,
                            size: 44,
                            accessibilityLabel: L10n.string("home.adjust"),
                            accessibilityIdentifier: "series-search-\(entry.id)-edit-progress",
                            action: editProgress
                        )

                        SeriesCompactIconButton(
                            systemName: quickProgressFilledSystemImage(for: entry),
                            style: .accent,
                            size: 44,
                            accessibilityLabel: primaryProgressActionTitle(for: entry),
                            accessibilityIdentifier: "series-search-\(entry.id)-quick-progress",
                            action: markNext
                        )
                    }
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

    private var resultButton: some View {
        Button(action: openDetail) {
            resultContent
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel(entry.title)
        .accessibilityHint(L10n.string("detail.open"))
        .accessibilityIdentifier("series-search-library-\(entry.id)-open")
    }

    private var resultContent: some View {
        HStack(alignment: .center, spacing: 12) {
            SeriesEntryArtworkView(entry: entry, size: dynamicTypeSize.isAccessibilitySize ? 70 : 62)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.headline.weight(.black))
                    .fontDesign(.rounded)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                    .fixedSize(horizontal: false, vertical: true)

                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 4) {
                        statusLabel
                        nextEpisodeLabel
                    }
                } else {
                    HStack(spacing: 7) {
                        statusLabel
                        nextEpisodeLabel
                    }
                }

                Text(detail)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? 3 : 2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
        }
    }

    private var statusLabel: some View {
        Label(statusTitle(entry.status), systemImage: statusIconName)
            .font(.caption.weight(.bold))
            .foregroundStyle(AVBrandColor.accent)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var nextEpisodeLabel: some View {
        Text(nextEpisodeText)
            .font(.footnote.weight(.bold))
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
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

private struct SeriesSearchWideActionButton: View {
    enum Style {
        case accent
        case secondary
    }

    let title: String
    let systemImage: String
    let style: Style
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.footnote.weight(.bold))
                .foregroundStyle(foregroundColor)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 52)
                .padding(.horizontal, 10)
                .background(backgroundColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(strokeColor, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var foregroundColor: Color {
        style == .accent ? Color.black.opacity(0.84) : AVBrandColor.textPrimary
    }

    private var backgroundColor: Color {
        style == .accent ? AVBrandColor.accent : Color(.tertiarySystemGroupedBackground)
    }

    private var strokeColor: Color {
        style == .accent ? AVBrandColor.accent.opacity(0.8) : Color.primary.opacity(0.08)
    }
}

private enum SeriesSearchSheetDestination: Identifiable {
    case proPaywall
    case progressEditor(SeriesLibraryEntry)
    case detail(SeriesSearchDetailSelection)

    var id: String {
        switch self {
        case .proPaywall: "pro-paywall"
        case .progressEditor(let entry): "progress:\(entry.id)"
        case .detail(let selection): "detail:\(selection.id)"
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

    var genreQuery: String? {
        self == .popular ? nil : cacheKey
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
