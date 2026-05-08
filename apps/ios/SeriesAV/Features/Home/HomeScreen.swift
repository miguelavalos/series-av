import SwiftUI

struct HomeScreen: View {
    @EnvironmentObject private var libraryStore: SeriesLibraryStore

    let service: TVMazeService
    let bottomContentPadding: CGFloat

    @State private var activeCollection: SeriesBrowseCollection = .popular
    @State private var shows: [CatalogShowSummary] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedDetail: SelectedShowDetail?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ShellBrandHeader(statusTitle: isLoading ? L10n.string("shell.status.refreshing") : L10n.string("shell.status.live"))

                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.string("home.title"))
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(SeriesTheme.textPrimary)

                    Text(L10n.string("home.subtitle"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(SeriesTheme.textSecondary)
                }

                NowWatchingPanel(currentShow: libraryStore.continueWatching().first)

                if !libraryStore.continueWatching().isEmpty {
                    ShellSection(
                        title: L10n.string("home.continue.title"),
                        subtitle: L10n.string("home.continue.subtitle")
                    ) {
                        ForEach(libraryStore.continueWatching()) { show in
                            Button {
                                selectedDetail = .library(id: show.id)
                            } label: {
                                LibraryRowCard(show: show)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                collectionPicker

                ShellSection(
                    title: activeCollection == .popular ? L10n.string("home.featured.popular") : L10n.string("home.featured.collection", activeCollection.title.lowercased()),
                    subtitle: L10n.string("home.featured.subtitle")
                ) {
                    if let errorMessage {
                        EmptyStateCard(title: L10n.string("home.error.title"), detail: errorMessage)
                    } else if isLoading {
                        EmptyStateCard(title: L10n.string("state.loading.title"), detail: L10n.string("home.loading.detail"))
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
        .task(id: activeCollection) {
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

    private var collectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(SeriesBrowseCollection.allCases) { collection in
                    Button(collection.title) {
                        activeCollection = collection
                    }
                    .font(.system(size: 13, weight: .bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(activeCollection == collection ? SeriesTheme.highlight : SeriesTheme.cardSurface, in: Capsule())
                    .foregroundStyle(activeCollection == collection ? Color.white : SeriesTheme.textPrimary)
                    .overlay {
                        Capsule()
                            .stroke(activeCollection == collection ? SeriesTheme.highlight : SeriesTheme.borderSubtle, lineWidth: 1)
                    }
                }
            }
        }
    }

    private func load() async {
        if ProcessInfo.processInfo.environment["SERIESAV_UI_TESTS"] == "1" {
            shows = ScreenshotCatalogFixtures.shows
            isLoading = false
            errorMessage = nil
            return
        }

        isLoading = true
        errorMessage = nil
        do {
            shows = try await service.browse(collection: activeCollection)
        } catch {
            shows = []
            errorMessage = L10n.string("home.error.detail")
        }
        isLoading = false
    }
}

enum ScreenshotCatalogFixtures {
    static let shows: [CatalogShowSummary] = [
        show(id: "studio-journey", title: "Studio Journey", year: 2026, summary: "A compact production diary with clear seasons, episode progress, and a calm watch queue.", genres: ["Drama", "Documentary"]),
        show(id: "city-signals", title: "City Signals", year: 2025, summary: "Short science-fiction episodes for keeping a current queue tidy across busy weeks.", genres: ["Sci-Fi", "Mystery"]),
        show(id: "open-season", title: "Open Season", year: 2024, summary: "A rights-safe sample series used for local progress, completed status, and library filters.", genres: ["Comedy"]),
        show(id: "night-archive", title: "Night Archive", year: 2023, summary: "A paused fixture title that keeps the profile and library counts realistic for screenshots.", genres: ["Drama"])
    ]

    private static func show(id: String, title: String, year: Int, summary: String, genres: [String]) -> CatalogShowSummary {
        CatalogShowSummary(
            source: .tvmaze,
            sourceId: "screenshot-\(id)",
            canonicalSeriesId: "screenshot-\(id)",
            title: title,
            year: year,
            imageURL: nil,
            summary: summary,
            genres: genres
        )
    }
}

private struct NowWatchingPanel: View {
    let currentShow: LibraryShow?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L10n.string("home.now.eyebrow"))
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(1.2)
                    .foregroundStyle(SeriesTheme.highlight)

                Spacer()

                ShellStatusPill(title: currentShow == nil ? L10n.string("home.now.ready.status") : L10n.string("home.now.watching.status"))
            }

            HStack(spacing: 12) {
                if let currentShow {
                    SeriesPosterView(imageURL: currentShow.imageURL, title: currentShow.title, width: 64, height: 90)
                } else {
                    EmptySeriesArtwork(width: 64, height: 90)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(currentShow?.title ?? L10n.string("home.now.empty.title"))
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(SeriesTheme.textInverse)
                        .lineLimit(2)

                    if let nextEpisode = currentShow?.nextEpisode {
                        Text(L10n.string("home.now.next", nextEpisode.season, nextEpisode.episode))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(SeriesTheme.highlight)
                    }

                    Text(currentShow?.summary ?? L10n.string("home.now.empty.detail"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(SeriesTheme.textInverse.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(3)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(SeriesTheme.darkSurface)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "play.tv.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(SeriesTheme.highlight.opacity(0.18))
                        .padding(.top, 18)
                        .padding(.trailing, 16)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(SeriesTheme.borderSubtle.opacity(0.48), lineWidth: 1)
                }
        )
        .shadow(color: SeriesTheme.softShadow.opacity(0.72), radius: 16, y: 8)
    }
}

private struct EmptySeriesArtwork: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [SeriesTheme.darkSurface, SeriesTheme.highlight.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: width, height: height)
            .overlay {
                Image(systemName: "play.tv.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(SeriesTheme.highlight)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            }
    }
}
