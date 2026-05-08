import SwiftUI

@MainActor
final class SearchScreenState: ObservableObject {
    @Published var query = ""
    @Published var submittedQuery = ""
    @Published var activeCollection: SeriesBrowseCollection = .popular
    @Published var shows: [CatalogShowSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedDetail: SelectedShowDetail?

    var hasLoadedContent: Bool {
        !shows.isEmpty || errorMessage != nil || isLoading
    }
}

struct SearchScreen: View {
    let service: TVMazeService
    let cloudService: SeriesAVCloudService?
    let bottomContentPadding: CGFloat
    let focusRequest: Int
    @ObservedObject var state: SearchScreenState

    @EnvironmentObject private var languageController: AppLanguageController
    @EnvironmentObject private var libraryStore: SeriesLibraryStore

    @State private var loadTask: Task<Void, Never>?
    @State private var searchFieldFocusTrigger = 0

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ShellBrandHeader(statusTitle: state.isLoading ? L10n.string("search.status.searching") : L10n.string("tab.search"))

                    VStack(alignment: .leading, spacing: 10) {
                        Text(L10n.string("search.title"))
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(SeriesTheme.textPrimary)

                        Text(L10n.string("search.subtitle"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(SeriesTheme.textSecondary)
                    }

                    SearchField(
                        query: $state.query,
                        prompt: L10n.string("tab.search"),
                        onSubmit: submitSearch,
                        onClear: clearSearch,
                        focusTrigger: searchFieldFocusTrigger
                    )
                    .id("search.input")
                    VStack(alignment: .leading, spacing: 14) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(SeriesBrowseCollection.allCases) { collection in
                                    Button(collection.title) {
                                        state.query = ""
                                        state.submittedQuery = ""
                                        state.activeCollection = collection
                                        loadFeaturedCollection()
                                    }
                                    .font(.system(size: 13, weight: .bold))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(state.activeCollection == collection && state.submittedQuery.isEmpty ? SeriesTheme.highlight : SeriesTheme.cardSurface, in: Capsule())
                                    .foregroundStyle(state.activeCollection == collection && state.submittedQuery.isEmpty ? Color.white : SeriesTheme.textPrimary)
                                    .overlay {
                                        Capsule()
                                            .stroke(state.activeCollection == collection && state.submittedQuery.isEmpty ? SeriesTheme.highlight : SeriesTheme.borderSubtle, lineWidth: 1)
                                    }
                                }
                            }
                        }
                    }
                    .padding(22)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(SeriesTheme.mutedSurface)
                            .overlay {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .stroke(SeriesTheme.borderSubtle, lineWidth: 1)
                            }
                    )

                    ShellSection(
                        title: !state.submittedQuery.isEmpty ? L10n.string("search.results.title", state.submittedQuery) : L10n.string("search.featured.title", state.activeCollection.title),
                        subtitle: state.isLoading ? L10n.string("search.loading.inline") : L10n.string("search.results.subtitle")
                    ) {
                        if let errorMessage = state.errorMessage {
                            EmptyStateCard(title: L10n.string("search.error.title"), detail: errorMessage)
                        } else if state.isLoading {
                            SearchResultsSkeleton()
                        } else if state.shows.isEmpty {
                            EmptyStateCard(title: L10n.string("search.empty.title"), detail: L10n.string("search.empty.detail"))
                        } else {
                            ForEach(state.shows) { show in
                                Button {
                                    state.selectedDetail = .summary(show)
                                } label: {
                                    ShowRowCard(show: show, libraryShow: followedShow(for: show))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(24)
                .padding(.bottom, bottomContentPadding)
            }
            .scrollIndicators(.hidden)
            .onAppear {
                if focusRequest > 0 {
                    focusSearchInput(proxy: proxy)
                }
            }
            .onChange(of: focusRequest) { _, _ in
                focusSearchInput(proxy: proxy)
            }
        }
        .background(SeriesTheme.shellBackground.ignoresSafeArea())
        .task {
            loadInitialContentIfNeeded()
        }
        .onDisappear {
            loadTask?.cancel()
        }
        .sheet(item: $state.selectedDetail) { detail in
            ShowDetailScreen(
                libraryShowID: detail.libraryShowID,
                summary: detail.summary,
                remoteSeriesID: detail.remoteSeriesID,
                service: service
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private var trimmedQuery: String {
        state.query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func focusSearchInput(proxy: ScrollViewProxy) {
        withAnimation(.snappy) {
            proxy.scrollTo("search.input", anchor: .center)
        }
        searchFieldFocusTrigger += 1
    }

    private func followedShow(for show: CatalogShowSummary) -> LibraryShow? {
        libraryStore.findShow(
            source: show.source,
            sourceID: show.sourceId,
            canonicalSeriesID: show.canonicalSeriesId
        )
    }

    private func load(query searchQuery: String?) async {
        if ProcessInfo.processInfo.environment["SERIESAV_UI_TESTS"] == "1" {
            state.shows = ScreenshotCatalogFixtures.shows
            state.isLoading = false
            state.errorMessage = nil
            return
        }

        state.isLoading = true
        state.errorMessage = nil
        if searchQuery != nil {
            state.shows = []
        }
        defer {
            if !Task.isCancelled {
                state.isLoading = false
            }
        }

        do {
            if let searchQuery {
                state.shows = try await search(query: searchQuery)
            } else {
                state.shows = try await service.browse(collection: state.activeCollection)
            }
        } catch is CancellationError {
            return
        } catch {
            state.shows = []
            state.errorMessage = L10n.string("search.error.detail")
        }
    }

    private func submitSearch() {
        let searchQuery = trimmedQuery
        guard searchQuery.count >= 2 else {
            clearSearch()
            return
        }

        state.submittedQuery = searchQuery
        loadTask?.cancel()
        loadTask = Task {
            await load(query: searchQuery)
        }
    }

    private func clearSearch() {
        state.submittedQuery = ""
        loadFeaturedCollection()
    }

    private func loadInitialContentIfNeeded() {
        guard !state.hasLoadedContent else { return }
        loadFeaturedCollection()
    }

    private func loadFeaturedCollection() {
        loadTask?.cancel()
        loadTask = Task {
            await load(query: nil)
        }
    }

    private func search(query: String) async throws -> [CatalogShowSummary] {
        if let cloudService, cloudService.isConfigured() {
            do {
                let remoteSeries = try await cloudService.resolveCatalog(
                    query: query,
                    preferredLanguage: languageController.currentLanguage.rawValue
                )
                let remoteResults = remoteSeries.map(mapRemoteSeriesToSummary)
                if !remoteResults.isEmpty {
                    return remoteResults
                }
            } catch {
                // Fall back to TVMaze so search remains useful if the Pro catalog is unavailable.
            }
        }

        return try await service.search(query: query)
    }

    private func mapRemoteSeriesToSummary(_ series: RemoteSeriesRecord) -> CatalogShowSummary {
        let primaryProviderRef = series.providerRefs.first(where: { $0.isPrimary }) ?? series.providerRefs.first
        return CatalogShowSummary(
            source: primaryProviderRef?.provider ?? .thetvdb,
            sourceId: primaryProviderRef?.providerSeriesId ?? series.id,
            canonicalSeriesId: series.id,
            title: series.title,
            year: series.year,
            imageURL: URL(string: series.posterURL ?? ""),
            summary: stripHTML(series.summary),
            genres: series.genres
        )
    }
}

private struct SearchResultsSkeleton: View {
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { index in
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(SeriesTheme.cardSurface)
                        .frame(width: 62, height: 86)

                    VStack(alignment: .leading, spacing: 10) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(SeriesTheme.cardSurface)
                            .frame(width: index == 0 ? 190 : 145, height: 16)

                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(SeriesTheme.cardSurface)
                            .frame(width: 82, height: 12)

                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(SeriesTheme.cardSurface)
                            .frame(maxWidth: .infinity, minHeight: 12, maxHeight: 12)
                    }

                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(SeriesTheme.mutedSurface)
                        .overlay {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(SeriesTheme.borderSubtle, lineWidth: 1)
                        }
                )
                .redacted(reason: .placeholder)
            }
        }
        .accessibilityLabel(L10n.string("search.loading.detail"))
    }
}
