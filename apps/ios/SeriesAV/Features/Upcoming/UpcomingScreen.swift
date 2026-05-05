import SwiftUI

struct UpcomingScreen: View {
    @EnvironmentObject private var libraryStore: SeriesLibraryStore

    let bottomContentPadding: CGFloat

    @State private var selectedDetail: SelectedShowDetail?
    private let service = TVMazeService()

    private var watchingShows: [LibraryShow] {
        libraryStore.shows
            .filter { $0.status == .watching }
            .sorted { lhs, rhs in
                let lhsEpisode = lhs.nextEpisode
                let rhsEpisode = rhs.nextEpisode
                return episodeSortKey(lhsEpisode, fallback: lhs.lastUpdatedAt) < episodeSortKey(rhsEpisode, fallback: rhs.lastUpdatedAt)
            }
    }

    private var queuedShows: [LibraryShow] {
        libraryStore.shows
            .filter { $0.status == .paused || $0.status == .completed }
            .sorted { $0.lastUpdatedAt > $1.lastUpdatedAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ShellBrandHeader(statusTitle: statusTitle)

                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.string("upcoming.title"))
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(SeriesTheme.textPrimary)

                    Text(L10n.string("upcoming.subtitle"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(SeriesTheme.textSecondary)
                }

                spotlightCard

                ShellSection(
                    title: L10n.string("upcoming.next.title"),
                    subtitle: L10n.string("upcoming.next.subtitle")
                ) {
                    if watchingShows.isEmpty {
                        EmptyStateCard(
                            title: L10n.string("upcoming.empty.title"),
                            detail: L10n.string("upcoming.empty.detail")
                        )
                    } else {
                        ForEach(watchingShows) { show in
                            Button {
                                selectedDetail = .library(id: show.id)
                            } label: {
                                UpcomingShowRow(show: show)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !queuedShows.isEmpty {
                    ShellSection(
                        title: L10n.string("upcoming.queue.title"),
                        subtitle: L10n.string("upcoming.queue.subtitle")
                    ) {
                        ForEach(queuedShows.prefix(4)) { show in
                            Button {
                                selectedDetail = .library(id: show.id)
                            } label: {
                                LibraryRowCard(show: show)
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

    @ViewBuilder
    private var spotlightCard: some View {
        if let show = watchingShows.first {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(L10n.string("upcoming.spotlight.eyebrow"))
                        .font(.system(size: 12, weight: .semibold))
                        .tracking(1.2)
                        .foregroundStyle(SeriesTheme.highlight)

                    Spacer()

                    ShellStatusPill(title: nextEpisodeLabel(for: show))
                }

                Button {
                    selectedDetail = .library(id: show.id)
                } label: {
                    HStack(spacing: 12) {
                        SeriesPosterView(imageURL: show.imageURL, title: show.title, width: 64, height: 90)

                        VStack(alignment: .leading, spacing: 8) {
                            Text(show.title)
                                .font(.system(size: 19, weight: .bold))
                                .foregroundStyle(SeriesTheme.textInverse)
                                .lineLimit(2)

                            Text(nextEpisodeDetail(for: show))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(SeriesTheme.highlight)

                            Text(show.summary ?? L10n.string("upcoming.spotlight.fallback"))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(SeriesTheme.textInverse.opacity(0.68))
                                .fixedSize(horizontal: false, vertical: true)
                                .lineLimit(3)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(SeriesTheme.darkSurface)
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "calendar.badge.clock")
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
        } else {
            EmptyStateCard(
                title: L10n.string("upcoming.spotlight.empty.title"),
                detail: L10n.string("upcoming.spotlight.empty.detail")
            )
        }
    }

    private var statusTitle: String {
        watchingShows.isEmpty
            ? L10n.string("upcoming.status.empty")
            : L10n.string("upcoming.status.count", watchingShows.count)
    }

    private func nextEpisodeLabel(for show: LibraryShow) -> String {
        guard let nextEpisode = show.nextEpisode else { return L10n.string("upcoming.status.ready") }
        return "S\(nextEpisode.season)E\(nextEpisode.episode)"
    }

    private func nextEpisodeDetail(for show: LibraryShow) -> String {
        guard let nextEpisode = show.nextEpisode else {
            return L10n.string("upcoming.next.unknown")
        }

        if let airdate = nextEpisode.airdate, !airdate.isEmpty {
            return L10n.string("upcoming.next.withDate", nextEpisode.season, nextEpisode.episode, airdate)
        }

        return L10n.string("upcoming.next.episode", nextEpisode.season, nextEpisode.episode)
    }

    private func episodeSortKey(_ episode: UpcomingEpisode?, fallback: String) -> String {
        guard let episode else { return "9999-\(fallback)" }
        return "\(episode.airdate ?? "9999-99-99")-\(episode.season)-\(episode.episode)"
    }
}

private struct UpcomingShowRow: View {
    let show: LibraryShow

    var body: some View {
        HStack(spacing: 14) {
            SeriesPosterView(imageURL: show.imageURL, title: show.title, width: 74, height: 108)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text(show.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(SeriesTheme.textPrimary)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    Text(nextLabel)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(SeriesTheme.highlight)
                }

                Text(detail)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SeriesTheme.highlight)

                Text(show.summary ?? L10n.string("upcoming.row.fallback"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(SeriesTheme.textSecondary)
                    .lineLimit(3)
            }
        }
        .padding(18)
        .background(upcomingCardBackground)
    }

    private var nextLabel: String {
        guard let nextEpisode = show.nextEpisode else { return L10n.string("upcoming.row.ready") }
        return "S\(nextEpisode.season)E\(nextEpisode.episode)"
    }

    private var detail: String {
        guard let nextEpisode = show.nextEpisode else { return L10n.string("upcoming.next.unknown") }
        if let airdate = nextEpisode.airdate, !airdate.isEmpty {
            return L10n.string("upcoming.next.withDate", nextEpisode.season, nextEpisode.episode, airdate)
        }
        return L10n.string("upcoming.next.episode", nextEpisode.season, nextEpisode.episode)
    }
}

private var upcomingCardBackground: some View {
    RoundedRectangle(cornerRadius: 24, style: .continuous)
        .fill(SeriesTheme.cardSurface)
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(SeriesTheme.borderSubtle, lineWidth: 1)
        }
}
