import SwiftUI

struct SearchScreen: View {
    let service: TVMazeService
    let bottomContentPadding: CGFloat

    @State private var query = ""
    @State private var activeCollection: SeriesBrowseCollection = .popular
    @State private var shows: [CatalogShowSummary] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedDetail: SelectedShowDetail?

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

                SearchField(query: $query, prompt: L10n.string("tab.search"))
                VStack(alignment: .leading, spacing: 14) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(SeriesBrowseCollection.allCases) { collection in
                                Button(collection.title) {
                                    query = ""
                                    activeCollection = collection
                                }
                                .font(.system(size: 13, weight: .bold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(activeCollection == collection && trimmedQuery.count < 2 ? SeriesTheme.highlight : SeriesTheme.cardSurface, in: Capsule())
                                .foregroundStyle(activeCollection == collection && trimmedQuery.count < 2 ? Color.white : SeriesTheme.textPrimary)
                                .overlay {
                                    Capsule()
                                        .stroke(activeCollection == collection && trimmedQuery.count < 2 ? SeriesTheme.highlight : SeriesTheme.borderSubtle, lineWidth: 1)
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
                    title: trimmedQuery.count >= 2 ? L10n.string("search.results.title", trimmedQuery) : L10n.string("search.featured.title", activeCollection.title),
                    subtitle: isLoading ? L10n.string("search.loading.inline") : L10n.string("search.results.subtitle")
                ) {
                    if let errorMessage {
                        EmptyStateCard(title: L10n.string("search.error.title"), detail: errorMessage)
                    } else if isLoading {
                        EmptyStateCard(title: L10n.string("state.loading.title"), detail: L10n.string("search.loading.detail"))
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
        .task(id: searchRequestKey) {
            await load()
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

    private var searchRequestKey: String {
        "\(query)|\(activeCollection.rawValue)"
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            if trimmedQuery.count >= 2 {
                try await Task.sleep(for: .milliseconds(250))
                try Task.checkCancellation()
            }
            if trimmedQuery.count >= 2 {
                shows = try await service.search(query: query)
            } else {
                shows = try await service.browse(collection: activeCollection)
            }
        } catch is CancellationError {
            return
        } catch {
            shows = []
            errorMessage = L10n.string("search.error.detail")
        }
        isLoading = false
    }
}
