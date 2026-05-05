import SwiftUI

struct SearchScreen: View {
    let service: TVMazeService
    let cloudService: SeriesAVCloudService?
    let bottomContentPadding: CGFloat

    @EnvironmentObject private var languageController: AppLanguageController

    @State private var query = ""
    @State private var submittedQuery = ""
    @State private var activeCollection: SeriesBrowseCollection = .popular
    @State private var shows: [CatalogShowSummary] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedDetail: SelectedShowDetail?
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ShellBrandHeader(statusTitle: isLoading ? L10n.string("search.status.searching") : L10n.string("tab.search"))

                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.string("search.title"))
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(SeriesTheme.textPrimary)

                    Text(L10n.string("search.subtitle"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(SeriesTheme.textSecondary)
                }

                SearchField(
                    query: $query,
                    prompt: L10n.string("tab.search"),
                    onSubmit: submitSearch,
                    onClear: clearSearch
                )
                VStack(alignment: .leading, spacing: 14) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(SeriesBrowseCollection.allCases) { collection in
                                Button(collection.title) {
                                    query = ""
                                    submittedQuery = ""
                                    activeCollection = collection
                                    loadFeaturedCollection()
                                }
                                .font(.system(size: 13, weight: .bold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(activeCollection == collection && submittedQuery.isEmpty ? SeriesTheme.highlight : SeriesTheme.cardSurface, in: Capsule())
                                .foregroundStyle(activeCollection == collection && submittedQuery.isEmpty ? Color.white : SeriesTheme.textPrimary)
                                .overlay {
                                    Capsule()
                                        .stroke(activeCollection == collection && submittedQuery.isEmpty ? SeriesTheme.highlight : SeriesTheme.borderSubtle, lineWidth: 1)
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
                    title: !submittedQuery.isEmpty ? L10n.string("search.results.title", submittedQuery) : L10n.string("search.featured.title", activeCollection.title),
                    subtitle: isLoading ? L10n.string("search.loading.inline") : L10n.string("search.results.subtitle")
                ) {
                    if let errorMessage {
                        EmptyStateCard(title: L10n.string("search.error.title"), detail: errorMessage)
                    } else if isLoading {
                        SearchResultsSkeleton()
                    } else if shows.isEmpty {
                        EmptyStateCard(title: L10n.string("search.empty.title"), detail: L10n.string("search.empty.detail"))
                    } else {
                        ForEach(shows) { show in
                            Button {
                                selectedDetail = .summary(show)
                            } label: {
                                ShowRowCard(show: show)
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
        .background(SeriesTheme.shellBackground.ignoresSafeArea())
        .task {
            loadFeaturedCollection()
        }
        .onDisappear {
            loadTask?.cancel()
        }
        .sheet(item: $selectedDetail) { detail in
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
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func load(query searchQuery: String?) async {
        isLoading = true
        errorMessage = nil
        if searchQuery != nil {
            shows = []
        }
        defer {
            if !Task.isCancelled {
                isLoading = false
            }
        }

        do {
            if let searchQuery {
                shows = try await search(query: searchQuery)
            } else {
                shows = try await service.browse(collection: activeCollection)
            }
        } catch is CancellationError {
            return
        } catch {
            shows = []
            errorMessage = L10n.string("search.error.detail")
        }
    }

    private func submitSearch() {
        let searchQuery = trimmedQuery
        guard searchQuery.count >= 2 else {
            clearSearch()
            return
        }

        submittedQuery = searchQuery
        loadTask?.cancel()
        loadTask = Task {
            await load(query: searchQuery)
        }
    }

    private func clearSearch() {
        submittedQuery = ""
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
