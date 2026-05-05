import SwiftUI

struct SelectedShowDetail: Identifiable {
    let id: String
    let libraryShowID: String?
    let summary: CatalogShowSummary?
    let remoteSeriesID: String?

    static func library(id: String) -> SelectedShowDetail {
        SelectedShowDetail(id: "library:\(id)", libraryShowID: id, summary: nil, remoteSeriesID: nil)
    }

    static func summary(_ summary: CatalogShowSummary) -> SelectedShowDetail {
        SelectedShowDetail(id: "summary:\(summary.id)", libraryShowID: nil, summary: summary, remoteSeriesID: nil)
    }

    static func remote(seriesID: String) -> SelectedShowDetail {
        SelectedShowDetail(id: "remote:\(seriesID)", libraryShowID: nil, summary: nil, remoteSeriesID: seriesID)
    }
}

private enum ShowDetailTab: String, CaseIterable, Identifiable {
    case episodes
    case info
    case social

    var id: String { rawValue }

    var title: String {
        switch self {
        case .episodes: "Episodes"
        case .info: "Info"
        case .social: "Social"
        }
    }
}

struct ShowDetailScreen: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var libraryStore: SeriesLibraryStore
    @EnvironmentObject private var socialStore: SeriesSocialStore

    let libraryShowID: String?
    let summary: CatalogShowSummary?
    let remoteSeriesID: String?
    let service: TVMazeService

    @State private var snapshot: ShowSnapshot?
    @State private var libraryShow: LibraryShow?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isShowingSharedListSheet = false
    @State private var isShowingRecommendSheet = false
    @State private var isOverviewExpanded = false
    @State private var expandedSeason: Int?
    @State private var selectedSeason: Int?
    @State private var selectedEpisode: EpisodeSnapshot?
    @State private var episodePendingUnwatch: EpisodeSnapshot?
    @State private var selectedTab: ShowDetailTab = .episodes

    init(
        libraryShowID: String? = nil,
        summary: CatalogShowSummary? = nil,
        remoteSeriesID: String? = nil,
        service: TVMazeService
    ) {
        self.libraryShowID = libraryShowID
        self.summary = summary
        self.remoteSeriesID = remoteSeriesID
        self.service = service
    }

    var body: some View {
        VStack(spacing: 0) {
            if let snapshot = resolvedSnapshot ?? fallbackSnapshot {
                detailHeader(snapshot: snapshot)
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 12)
                    .background(.ultraThinMaterial)

                Picker("Detail", selection: $selectedTab) {
                    ForEach(ShowDetailTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                .background(.ultraThinMaterial)

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        switch selectedTab {
                        case .episodes:
                            episodeNavigator(snapshot: snapshot)
                        case .info:
                            infoTab(snapshot: snapshot)
                        case .social:
                            socialTab(snapshot: snapshot)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        InlineBackButton(title: "Back") {
                            dismiss()
                        }

                        if isLoading {
                            EmptyStateCard(title: "Loading", detail: "Refreshing show detail and episode metadata.")
                        } else if let errorMessage {
                            EmptyStateCard(title: "Detail unavailable", detail: errorMessage)
                        }
                    }
                    .padding(24)
                }
            }
        }
        .background(SeriesTheme.shellBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await load()
        }
        .sheet(isPresented: $isShowingSharedListSheet) {
            SharedListPickerSheet(
                isPresented: $isShowingSharedListSheet,
                seriesID: resolvedSeriesID,
                title: resolvedSnapshot?.title ?? summary?.title ?? "Series"
            )
        }
        .sheet(isPresented: $isShowingRecommendSheet) {
            RecommendSeriesSheet(
                isPresented: $isShowingRecommendSheet,
                seriesID: resolvedSeriesID,
                title: resolvedSnapshot?.title ?? summary?.title ?? "Series"
            )
        }
        .sheet(item: $selectedEpisode) { episode in
            EpisodeDetailSheet(
                episode: episode,
                isWatched: isEpisodeWatched(episode),
                trackAction: {
                    handleEpisodeProgressTap(episode)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .alert("Update watched progress?", isPresented: Binding(
            get: { episodePendingUnwatch != nil },
            set: { if !$0 { episodePendingUnwatch = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                episodePendingUnwatch = nil
            }
            Button("Update progress", role: .destructive) {
                if let episode = episodePendingUnwatch {
                    unwatchThrough(episode)
                }
                episodePendingUnwatch = nil
                selectedEpisode = nil
            }
        } message: {
            Text(unwatchMessage)
        }
    }

    private var resolvedSnapshot: ShowSnapshot? {
        libraryShow?.snapshot ?? snapshot
    }

    private var fallbackSnapshot: ShowSnapshot? {
        if let summary {
            return ShowSnapshot(
                source: summary.source,
                sourceId: summary.sourceId,
                canonicalSeriesId: summary.canonicalSeriesId,
                title: summary.title,
                year: summary.year,
                imageURL: summary.imageURL,
                summary: summary.summary,
                genres: summary.genres,
                episodeCountBySeason: [:],
                totalEpisodeCountBySeason: [:],
                episodesBySeason: [:],
                nextEpisode: nil
            )
        }

        if let remoteSeriesID,
           let metadata = socialStore.seriesMetadataById[remoteSeriesID] {
            return ShowSnapshot(
                source: .tvmaze,
                sourceId: remoteSeriesID,
                canonicalSeriesId: remoteSeriesID,
                title: metadata.title,
                year: nil,
                imageURL: metadata.imageURL,
                summary: nil,
                genres: [],
                episodeCountBySeason: [:],
                totalEpisodeCountBySeason: [:],
                episodesBySeason: [:],
                nextEpisode: nil
            )
        }

        return nil
    }

    private var resolvedSeriesID: String {
        resolvedSnapshot?.canonicalSeriesId
            ?? remoteSeriesID
            ?? summary?.canonicalSeriesId
            ?? buildSourceKey(
                source: resolvedSnapshot?.source ?? summary?.source ?? .tvmaze,
                sourceId: resolvedSnapshot?.sourceId ?? summary?.sourceId ?? ""
            )
    }

    private var accessControllerCanShare: Bool {
        !resolvedSeriesID.isEmpty
    }

    private func detailHeader(snapshot: ShowSnapshot) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(SeriesTheme.textPrimary)
                    .frame(width: 38, height: 38)
                    .background(SeriesTheme.mutedSurface, in: Circle())
            }
            .buttonStyle(.plain)

            SeriesPosterView(imageURL: snapshot.imageURL, title: snapshot.title, width: 48, height: 68)

            VStack(alignment: .leading, spacing: 4) {
                Text(snapshot.title)
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(SeriesTheme.textPrimary)
                    .lineLimit(1)

                Text(detailHeroSubtitle(snapshot: snapshot))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(SeriesTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if let episode = featuredEpisode(snapshot: snapshot), episode.isAired {
                Button {
                    handleEpisodeProgressTap(episode)
                } label: {
                    Image(systemName: "play.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(SeriesTheme.brandBlack)
                        .frame(width: 42, height: 42)
                        .background(SeriesTheme.highlight, in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func episodeNavigator(snapshot: ShowSnapshot) -> some View {
        if snapshot.episodesBySeason.isEmpty {
            if isLoading {
                EpisodeLoadingCard()
            } else {
                EmptyStateCard(
                    title: "Episode data unavailable",
                    detail: "This source did not return trackable season metadata yet."
                )
            }
        } else {
            if libraryShow == nil {
                Button {
                    addSnapshotToLibrary(snapshot)
                } label: {
                    primaryButtonLabel("Add to My Series")
                }
                .buttonStyle(.plain)
            }

            featuredEpisodeCard(snapshot: snapshot)
            seasonSelector(snapshot: snapshot)

            if let season = activeSeason(snapshot: snapshot) {
                selectedSeasonEpisodes(snapshot: snapshot, season: season)
            }
        }
    }

    private func seasonSelector(snapshot: ShowSnapshot) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(seasonNumbers(snapshot), id: \.self) { season in
                    let selected = activeSeason(snapshot: snapshot) == season
                    Button {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.9)) {
                            selectedSeason = season
                            expandedSeason = season
                        }
                    } label: {
                        Text("S\(season)")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(selected ? SeriesTheme.brandBlack : SeriesTheme.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 11)
                            .background(selected ? SeriesTheme.highlight : SeriesTheme.cardSurface, in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(selected ? SeriesTheme.highlight : SeriesTheme.borderSubtle, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func selectedSeasonEpisodes(snapshot: ShowSnapshot, season: Int) -> some View {
        let episodes = snapshot.episodesBySeason[String(season)] ?? []
        let airedCount = snapshot.episodeCountBySeason[String(season)] ?? 0
        let totalCount = snapshot.totalEpisodeCountBySeason[String(season)] ?? airedCount
        let watchedCount = watchedCount(snapshot: snapshot, season: season)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Season \(season)")
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(SeriesTheme.textPrimary)
                    Text(totalCount > airedCount ? "\(watchedCount) watched of \(airedCount) aired · \(totalCount) total" : "\(watchedCount) watched of \(airedCount) aired")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(SeriesTheme.textSecondary)
                }
                Spacer()
            }

            ProgressView(value: airedCount > 0 ? Double(watchedCount) / Double(airedCount) : 0)
                .tint(SeriesTheme.highlight)

            ForEach(episodes) { episode in
                episodeRow(episode)
            }
        }
        .padding(18)
        .background(detailCardBackground)
    }

    @ViewBuilder
    private func infoTab(snapshot: ShowSnapshot) -> some View {
        overview(snapshot: snapshot)
        metadata(snapshot: snapshot)
        actions(snapshot: snapshot)
    }

    @ViewBuilder
    private func socialTab(snapshot: ShowSnapshot) -> some View {
        if accessControllerCanShare {
            shareActions(snapshot: snapshot)
        } else {
            EmptyStateCard(title: "Sharing unavailable", detail: "This series does not have a shareable identifier yet.")
        }
    }

    private func hero(snapshot: ShowSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                SeriesPosterView(imageURL: snapshot.imageURL, title: snapshot.title, width: 92, height: 134)

                VStack(alignment: .leading, spacing: 8) {
                    if let summary = snapshot.summary, !summary.isEmpty {
                        Text(summary)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(SeriesTheme.textSecondary)
                            .lineLimit(1)
                    }

                    ShellRow(
                        systemImage: "sparkles.tv",
                        title: "Series AV Detail",
                        detail: detailHeroMeta(snapshot: snapshot)
                    )

                    if let nextEpisode = snapshot.nextEpisode {
                        ShellRow(
                            systemImage: "calendar.badge.clock",
                            title: "Next episode",
                            detail: "S\(nextEpisode.season)E\(nextEpisode.episode)\(nextEpisode.airdate.map { " · \($0)" } ?? "")"
                        )
                    }
                }
            }

        }
        .padding(18)
        .background(detailCardBackground)
    }

    @ViewBuilder
    private func overview(snapshot: ShowSnapshot) -> some View {
        if let summary = snapshot.summary, !summary.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Overview")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(SeriesTheme.textPrimary)

                Text(summary)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(SeriesTheme.textSecondary)
                    .lineSpacing(2)
                    .lineLimit(isOverviewExpanded ? nil : 8)
                    .fixedSize(horizontal: false, vertical: true)

                if summary.count > 280 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            isOverviewExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(isOverviewExpanded ? "Show less" : "Read more")
                                .font(.system(size: 14, weight: .bold))
                            Image(systemName: isOverviewExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(SeriesTheme.highlight)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(detailCardBackground)
        }
    }

    @ViewBuilder
    private func actions(snapshot: ShowSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Library")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(SeriesTheme.textPrimary)

                Text("Track status and progress without leaving the show detail view.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(SeriesTheme.textSecondary)
            }

            if let libraryShow {
                ShellRow(
                    systemImage: "rectangle.stack.badge.person.crop",
                    title: "Current status",
                    detail: libraryShow.status.title
                )

                Picker(
                    "Status",
                    selection: Binding(
                        get: { libraryShow.status },
                        set: { newValue in
                            self.libraryShow?.status = newValue
                            libraryStore.updateStatus(id: libraryShow.id, status: newValue)
                        }
                    )
                ) {
                    ForEach(ShowStatus.allCases) { status in
                        Text(status.title).tag(status)
                    }
                }
                .pickerStyle(.segmented)

                if let episode = nextTrackableEpisode(snapshot: snapshot) {
                    Button {
                        handleEpisodeProgressTap(episode)
                    } label: {
                        primaryButtonLabel("Mark \(episodeCode(episode)) watched")
                    }
                    .buttonStyle(.plain)
                }

                Button(role: .destructive) {
                    libraryStore.removeShow(id: libraryShow.id)
                    self.libraryShow = nil
                } label: {
                    destructiveButtonLabel("Remove from library")
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    addSnapshotToLibrary(snapshot)
                } label: {
                    primaryButtonLabel("Add to My Series")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(detailCardBackground)
    }

    private func shareActions(snapshot: ShowSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Sharing")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(SeriesTheme.textPrimary)

                Text("Use Account AV social features to recommend this show or place it in a shared watchlist.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(SeriesTheme.textSecondary)
            }

            if let nextEpisode = snapshot.nextEpisode {
                ShellRow(
                    systemImage: "person.2",
                    title: "Social context",
                    detail: "Next up: S\(nextEpisode.season)E\(nextEpisode.episode)"
                )
            }

            HStack(spacing: 12) {
                Button {
                    isShowingSharedListSheet = true
                } label: {
                    secondaryButtonLabel("Add to Shared List")
                }
                .buttonStyle(.plain)

                Button {
                    isShowingRecommendSheet = true
                } label: {
                    primaryButtonLabel("Recommend")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(detailCardBackground)
    }

    private func metadata(snapshot: ShowSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Stats")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(SeriesTheme.textPrimary)

                Text("Season and episode counts styled as a compact AV shell card.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(SeriesTheme.textSecondary)
            }

            HStack(spacing: 12) {
                statCard("Seasons", value: String(snapshot.episodesBySeason.keys.count))
                statCard("Aired", value: String(snapshot.episodeCountBySeason.values.reduce(0, +)))
                statCard("Total", value: String(snapshot.totalEpisodeCountBySeason.values.reduce(0, +)))
            }

            if let nextEpisode = snapshot.nextEpisode {
                ShellRow(
                    systemImage: "calendar",
                    title: "Next episode",
                    detail: "S\(nextEpisode.season)E\(nextEpisode.episode)\(nextEpisode.airdate.map { " · \($0)" } ?? "")"
                )
            } else {
                ShellRow(
                    systemImage: "calendar",
                    title: "Next episode",
                    detail: "No upcoming episode metadata available right now."
                )
            }
        }
        .padding(20)
        .background(detailCardBackground)
    }

    @ViewBuilder
    private func featuredEpisodeCard(snapshot: ShowSnapshot) -> some View {
        if let episode = featuredEpisode(snapshot: snapshot) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(featuredEpisodeEyebrow(episode))
                        .font(.system(size: 12, weight: .bold))
                        .tracking(1)
                        .foregroundStyle(SeriesTheme.textSecondary)
                    Text(episodeCode(episode))
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(SeriesTheme.textPrimary)
                }

                HStack(alignment: .center, spacing: 14) {
                    EpisodeArtworkView(episode: episode, width: 118, height: 86)

                    VStack(alignment: .leading, spacing: 7) {
                        Text(episode.title)
                            .font(.system(size: 20, weight: .black))
                            .foregroundStyle(SeriesTheme.textPrimary)
                            .lineLimit(1)

                        Text(episode.summary ?? episodeFallbackSummary(episode))
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(SeriesTheme.textSecondary)
                            .lineLimit(2)

                        HStack(spacing: 8) {
                            metaChip(isEpisodeWatched(episode) ? "Watched" : episode.isAired ? "Up next" : "Coming soon", tone: episode.isAired ? .accent : .secondary)
                            if let airdate = episode.airdate {
                                metaChip(airdate, tone: .light)
                            }
                        }
                    }

                    Button {
                        handleEpisodeProgressTap(episode)
                    } label: {
                        Image(systemName: isEpisodeWatched(episode) ? "checkmark" : episode.isAired ? "checkmark.circle" : "clock")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(episode.isAired ? SeriesTheme.highlight : SeriesTheme.textSecondary)
                            .frame(width: 42, height: 42)
                            .background(SeriesTheme.mutedSurface, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!episode.isAired)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedEpisode = episode
                }
            }
            .padding(18)
            .background(detailCardBackground)
        }
    }

    private func episodes(snapshot: ShowSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Episodes")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(SeriesTheme.textPrimary)

                Text("Season breakdown and progress-ready episode metadata.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(SeriesTheme.textSecondary)
            }

            if snapshot.episodesBySeason.isEmpty {
                if isLoading {
                    EpisodeLoadingCard()
                } else {
                    EmptyStateCard(
                        title: "Episode data unavailable",
                        detail: "This source did not return trackable season metadata yet."
                    )
                }
            } else {
                ForEach(seasonNumbers(snapshot), id: \.self) { season in
                    seasonCard(snapshot: snapshot, season: season)
                }
            }
        }
        .padding(22)
        .background(detailCardBackground)
    }

    private func seasonCard(snapshot: ShowSnapshot, season: Int) -> some View {
        let episodes = snapshot.episodesBySeason[String(season)] ?? []
        let airedCount = snapshot.episodeCountBySeason[String(season)] ?? 0
        let totalCount = snapshot.totalEpisodeCountBySeason[String(season)] ?? airedCount
        let watchedCount = watchedCount(snapshot: snapshot, season: season)
        let isOpen = expandedSeason == season

        return VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                    expandedSeason = isOpen ? nil : season
                }
            } label: {
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Season \(season)")
                                .font(.system(size: 24, weight: .black))
                                .foregroundStyle(SeriesTheme.textPrimary)
                            Text(totalCount > airedCount ? "\(watchedCount) watched of \(airedCount) aired · \(totalCount) total" : "\(watchedCount) watched of \(airedCount) aired")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(SeriesTheme.textSecondary)
                        }
                        Spacer()
                        Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(SeriesTheme.textPrimary)
                            .frame(width: 42, height: 42)
                            .background(SeriesTheme.mutedSurface, in: Circle())
                    }

                    ProgressView(value: airedCount > 0 ? Double(watchedCount) / Double(airedCount) : 0)
                        .tint(SeriesTheme.highlight)
                }
                .padding(18)
            }
            .buttonStyle(.plain)

            if isOpen {
                VStack(spacing: 10) {
                    ForEach(episodes) { episode in
                        episodeRow(episode)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(SeriesTheme.cardSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(SeriesTheme.borderSubtle, lineWidth: 1)
                }
        )
    }

    private func episodeRow(_ episode: EpisodeSnapshot) -> some View {
        let watched = isEpisodeWatched(episode)
        let isNext = nextTrackableEpisode(snapshot: resolvedSnapshot ?? fallbackSnapshot)?.id == episode.id

        return HStack(spacing: 12) {
            EpisodeArtworkView(episode: episode, width: 102, height: 76)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    metaChip(episodeCode(episode), tone: .light)
                    if watched {
                        metaChip("Watched", tone: .accent)
                    } else if isNext {
                        metaChip("Next", tone: .secondary)
                    } else if !episode.isAired {
                        metaChip("Coming soon", tone: .secondary)
                    }
                }

                Text(episode.title)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(SeriesTheme.textPrimary)
                    .lineLimit(1)

                Text(episode.summary ?? episodeFallbackSummary(episode))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(SeriesTheme.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 4)

            Button {
                handleEpisodeProgressTap(episode)
            } label: {
                Image(systemName: watched ? "checkmark" : episode.isAired ? "checkmark.circle" : "clock")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(watched ? SeriesTheme.highlight : isNext ? SeriesTheme.highlight : SeriesTheme.textSecondary)
                    .frame(width: 40, height: 40)
                    .background(SeriesTheme.mutedSurface, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!episode.isAired)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(watched ? SeriesTheme.highlight.opacity(0.1) : SeriesTheme.mutedSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(isNext ? SeriesTheme.highlight.opacity(0.55) : watched ? SeriesTheme.highlight.opacity(0.22) : SeriesTheme.borderSubtle, lineWidth: 1)
                }
        )
        .opacity(episode.isAired ? 1 : 0.68)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedEpisode = episode
        }
    }

    private func statCard(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(SeriesTheme.textSecondary)
            Text(value)
                .font(.system(size: 20, weight: .black))
                .foregroundStyle(SeriesTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(SeriesTheme.mutedSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(SeriesTheme.borderSubtle, lineWidth: 1)
                }
        )
    }

    private func primaryButtonLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(SeriesTheme.brandBlack)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(SeriesTheme.highlight, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func secondaryButtonLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(SeriesTheme.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(SeriesTheme.mutedSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(SeriesTheme.borderSubtle, lineWidth: 1)
            }
    }

    private func destructiveButtonLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color.red.opacity(0.82), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var detailCardBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(SeriesTheme.cardSurface)
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(SeriesTheme.borderSubtle, lineWidth: 1)
            }
    }

    private func markWatched(season: Int, episode: Int) {
        let show = libraryShow ?? {
            guard let snapshot = resolvedSnapshot ?? fallbackSnapshot else { return nil }
            return addSnapshotToLibrary(snapshot)
        }()

        guard let show else { return }
        libraryShow = show
        libraryStore.markWatched(id: show.id, season: season, episode: episode)
        self.libraryShow = libraryStore.show(id: show.id)
    }

    @discardableResult
    private func addSnapshotToLibrary(_ snapshot: ShowSnapshot) -> LibraryShow {
        let added = libraryStore.addShow(snapshot: snapshot)
        libraryShow = added
        return added
    }

    private func handleEpisodeProgressTap(_ episode: EpisodeSnapshot) {
        guard episode.isAired else { return }
        if isEpisodeWatched(episode) {
            episodePendingUnwatch = episode
        } else {
            markWatched(season: episode.season, episode: episode.episode)
            selectedEpisode = nil
        }
    }

    private var unwatchMessage: String {
        guard let episode = episodePendingUnwatch else {
            return "This will update your watched progress."
        }

        if let previous = previousEpisode(before: episode) {
            return "This will move your progress back to \(episodeCode(previous)). Episodes after that will no longer be marked as watched."
        }

        return "This will clear watched progress for this series."
    }

    private func unwatchThrough(_ episode: EpisodeSnapshot) {
        guard let libraryShow else { return }
        if let previous = previousEpisode(before: episode) {
            libraryStore.markWatched(id: libraryShow.id, season: previous.season, episode: previous.episode)
        } else {
            libraryStore.clearWatchedProgress(id: libraryShow.id)
        }
        self.libraryShow = libraryStore.show(id: libraryShow.id)
    }

    private func previousEpisode(before episode: EpisodeSnapshot) -> EpisodeSnapshot? {
        guard let snapshot = resolvedSnapshot ?? fallbackSnapshot else { return nil }
        let episodes = seasonNumbers(snapshot)
            .flatMap { snapshot.episodesBySeason[String($0)] ?? [] }
            .filter { $0.isAired }
            .sorted {
                if $0.season != $1.season { return $0.season < $1.season }
                return $0.episode < $1.episode
            }

        guard let index = episodes.firstIndex(where: { $0.season == episode.season && $0.episode == episode.episode }),
              index > 0 else {
            return nil
        }

        return episodes[index - 1]
    }

    private func seasonNumbers(_ snapshot: ShowSnapshot) -> [Int] {
        snapshot.episodesBySeason.keys.compactMap(Int.init).sorted()
    }

    private func activeSeason(snapshot: ShowSnapshot) -> Int? {
        if let selectedSeason, seasonNumbers(snapshot).contains(selectedSeason) {
            return selectedSeason
        }
        return preferredExpandedSeason(snapshot)
    }

    private func isEpisodeWatched(_ episode: EpisodeSnapshot) -> Bool {
        guard let libraryShow,
              let lastSeason = libraryShow.lastWatchedSeason,
              let lastEpisode = libraryShow.lastWatchedEpisode else {
            return false
        }

        if episode.season < lastSeason { return true }
        if episode.season > lastSeason { return false }
        return episode.episode <= lastEpisode
    }

    private func watchedCount(snapshot: ShowSnapshot, season: Int) -> Int {
        guard let libraryShow,
              let lastSeason = libraryShow.lastWatchedSeason,
              let lastEpisode = libraryShow.lastWatchedEpisode else {
            return 0
        }

        let airedCount = snapshot.episodeCountBySeason[String(season)] ?? 0
        if season < lastSeason { return airedCount }
        if season > lastSeason { return 0 }
        return max(0, min(lastEpisode, airedCount))
    }

    private func nextTrackableEpisode(snapshot: ShowSnapshot?) -> EpisodeSnapshot? {
        guard let snapshot else { return nil }
        let episodes = seasonNumbers(snapshot).flatMap { snapshot.episodesBySeason[String($0)] ?? [] }
        guard !episodes.isEmpty else { return nil }

        if let libraryShow,
           let lastSeason = libraryShow.lastWatchedSeason,
           let lastEpisode = libraryShow.lastWatchedEpisode {
            return episodes.first { episode in
                episode.isAired && (episode.season > lastSeason || (episode.season == lastSeason && episode.episode > lastEpisode))
            }
        }

        return episodes.first { $0.isAired } ?? episodes.first
    }

    private func featuredEpisode(snapshot: ShowSnapshot) -> EpisodeSnapshot? {
        if libraryShow?.status == .completed,
           let libraryShow,
           let lastSeason = libraryShow.lastWatchedSeason,
           let lastEpisode = libraryShow.lastWatchedEpisode {
            return snapshot.episodesBySeason[String(lastSeason)]?.first { $0.episode == lastEpisode }
        }

        return nextTrackableEpisode(snapshot: snapshot)
    }

    private func featuredEpisodeEyebrow(_ episode: EpisodeSnapshot) -> String {
        if libraryShow?.status == .completed { return "Completed" }
        if !episode.isAired { return "Upcoming" }
        if isEpisodeWatched(episode) { return "Latest watched" }
        return libraryShow?.lastWatchedSeason == nil ? "Start watching" : "Continue watching"
    }

    private func episodeCode(_ episode: EpisodeSnapshot) -> String {
        "S\(episode.season)E\(episode.episode)"
    }

    private func episodeFallbackSummary(_ episode: EpisodeSnapshot) -> String {
        if let airdate = episode.airdate {
            return episode.isAired ? "Aired \(airdate)." : "Expected \(airdate)."
        }
        return "No episode summary available yet."
    }

    private enum ChipTone {
        case light
        case accent
        case secondary
    }

    private func metaChip(_ label: String, tone: ChipTone) -> some View {
        let background: Color = switch tone {
        case .light: SeriesTheme.cardSurface
        case .accent: SeriesTheme.highlight.opacity(0.12)
        case .secondary: SeriesTheme.mutedSurface
        }
        let foreground: Color = switch tone {
        case .light: SeriesTheme.textPrimary
        case .accent: SeriesTheme.highlight
        case .secondary: SeriesTheme.textSecondary
        }

        return Text(label.uppercased())
            .font(.system(size: 11, weight: .black))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(background, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(SeriesTheme.borderSubtle, lineWidth: 1)
            }
    }

    private func load() async {
        if let libraryShowID {
            libraryShow = libraryStore.show(id: libraryShowID)
            if let snapshot = libraryShow?.snapshot {
                self.snapshot = snapshot
                isOverviewExpanded = false
                expandedSeason = preferredExpandedSeason(snapshot)
                selectedSeason = expandedSeason
            }
        } else if let summary,
                  let existingShow = libraryStore.findShow(
                    source: summary.source,
                    sourceID: summary.sourceId,
                    canonicalSeriesID: summary.canonicalSeriesId
                  ) {
            libraryShow = existingShow
            snapshot = existingShow.snapshot
            isOverviewExpanded = false
            expandedSeason = preferredExpandedSeason(existingShow.snapshot)
            selectedSeason = expandedSeason
        }

        isLoading = true
        defer { isLoading = false }

        if let source = libraryShow?.snapshot.source ?? summary?.source,
           let sourceID = libraryShow?.snapshot.sourceId ?? summary?.sourceId,
           source == .tvmaze {
            do {
                let fresh = try await service.snapshot(for: sourceID)
                snapshot = fresh
                isOverviewExpanded = false
                expandedSeason = expandedSeason ?? preferredExpandedSeason(fresh)
                selectedSeason = selectedSeason ?? expandedSeason
                if let libraryShowID {
                    libraryStore.mergeSnapshot(id: libraryShowID, snapshot: fresh)
                    libraryShow = libraryStore.show(id: libraryShowID)
                }
                errorMessage = nil
                return
            } catch {
                if snapshot == nil {
                    errorMessage = "Unable to load this series right now."
                }
            }
        }

        let lookupRemoteSeriesID = remoteSeriesID
            ?? libraryShow?.snapshot.canonicalSeriesId
            ?? summary?.canonicalSeriesId
            ?? remoteSourceKey

        if let lookupRemoteSeriesID {
            if let remoteSnapshot = await socialStore.getSeriesSnapshot(seriesId: lookupRemoteSeriesID) {
                applyLoadedSnapshot(remoteSnapshot)
            } else if snapshot == nil {
                errorMessage = "Unable to load this series right now."
            }
        }

        if loadedSnapshotHasNoEpisodes,
           let enrichedSnapshot = await socialStore.enrichSeriesSnapshot(
            seriesId: lookupRemoteSeriesID,
            providerRefs: enrichmentProviderRefs()
           ) {
            applyLoadedSnapshot(enrichedSnapshot)
        }
    }

    private var remoteSourceKey: String? {
        guard let summary, summary.source != .tvmaze else { return nil }
        return buildSourceKey(source: summary.source, sourceId: summary.sourceId)
    }

    private var loadedSnapshotHasNoEpisodes: Bool {
        guard let snapshot = resolvedSnapshot ?? fallbackSnapshot else { return true }
        return snapshot.episodesBySeason.isEmpty
    }

    private func applyLoadedSnapshot(_ loadedSnapshot: ShowSnapshot) {
        snapshot = loadedSnapshot
        isOverviewExpanded = false
        expandedSeason = expandedSeason ?? preferredExpandedSeason(loadedSnapshot)
        selectedSeason = selectedSeason ?? expandedSeason
        errorMessage = nil
        if let id = libraryShow?.id ?? libraryShowID {
            libraryStore.mergeSnapshot(id: id, snapshot: loadedSnapshot)
            libraryShow = libraryStore.show(id: id)
        }
    }

    private func enrichmentProviderRefs() -> [RemoteSeriesProviderRef] {
        let source = summary?.source ?? libraryShow?.snapshot.source ?? snapshot?.source
        let sourceId = summary?.sourceId ?? libraryShow?.snapshot.sourceId ?? snapshot?.sourceId

        guard let source, let sourceId, !sourceId.isEmpty else { return [] }

        let now = ISO8601DateFormatter().string(from: Date())
        return [
            RemoteSeriesProviderRef(
                provider: source,
                providerSeriesId: sourceId,
                providerURL: providerURL(source: source, sourceId: sourceId),
                matchConfidence: "strong",
                isPrimary: true,
                createdAt: now,
                updatedAt: now
            )
        ]
    }

    private func providerURL(source: ShowSource, sourceId: String) -> String? {
        switch source {
        case .tvmaze:
            return "https://www.tvmaze.com/shows/\(sourceId)"
        case .thetvdb:
            return "https://thetvdb.com/dereferrer/series/\(sourceId)"
        }
    }

    private func firstTrackableSeason(snapshot: ShowSnapshot) -> Int? {
        snapshot.episodesBySeason.keys.compactMap(Int.init).sorted().first
    }

    private func firstTrackableEpisode(snapshot: ShowSnapshot, season: Int) -> Int? {
        snapshot.episodesBySeason[String(season)]?.first?.episode
    }

    private func preferredExpandedSeason(_ snapshot: ShowSnapshot) -> Int? {
        nextTrackableEpisode(snapshot: snapshot)?.season ?? firstTrackableSeason(snapshot: snapshot)
    }

    private func detailHeroSubtitle(snapshot: ShowSnapshot) -> String {
        let genres = snapshot.genres.prefix(3).joined(separator: " • ")
        let seasons = snapshot.episodesBySeason.keys.count
        let totalEpisodes = snapshot.totalEpisodeCountBySeason.values.reduce(0, +)

        let parts = [
            snapshot.year.map { String($0) },
            genres.isEmpty ? nil : genres,
            seasons > 0 ? "\(seasons) season\(seasons == 1 ? "" : "s")" : nil,
            totalEpisodes > 0 ? "\(totalEpisodes) episodes" : nil
        ].compactMap { $0 }

        if parts.isEmpty {
            return "Inspect seasons, progress, and social actions without leaving the native shell."
        }

        return parts.joined(separator: "  ·  ")
    }

    private func detailHeroMeta(snapshot: ShowSnapshot) -> String {
        let airedCount = snapshot.episodeCountBySeason.values.reduce(0, +)
        let totalCount = snapshot.totalEpisodeCountBySeason.values.reduce(0, +)

        if airedCount > 0 || totalCount > 0 {
            return "\(airedCount) aired episodes tracked across \(max(snapshot.episodesBySeason.keys.count, 1)) seasons."
        }

        return "Track progress, recommendations, and shared lists from the native detail view."
    }
}

private struct EpisodeArtworkView: View {
    let episode: EpisodeSnapshot
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        Group {
            if let imageURL = episode.imageURL {
                CachedRemoteImage(url: imageURL) {
                    placeholder
                }
            } else {
                placeholder
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(SeriesTheme.borderSubtle.opacity(0.7), lineWidth: 1)
        }
    }

    private var placeholder: some View {
        ZStack {
            SeriesTheme.mutedSurface
            Text(initials)
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(SeriesTheme.highlight)
        }
    }

    private var initials: String {
        let initials = episode.title.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
        return initials.isEmpty ? "AV" : initials
    }
}

private struct EpisodeLoadingCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                ProgressView()
                    .tint(SeriesTheme.highlight)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Loading episodes")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(SeriesTheme.textPrimary)

                    Text("Fetching seasons and progress-ready metadata.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(SeriesTheme.textSecondary)
                }
            }

            VStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(SeriesTheme.cardSurface)
                        .frame(height: index == 0 ? 68 : 54)
                        .overlay(alignment: .leading) {
                            VStack(alignment: .leading, spacing: 8) {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(SeriesTheme.mutedSurface)
                                    .frame(width: index == 0 ? 170 : 130, height: 12)
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(SeriesTheme.mutedSurface)
                                    .frame(width: index == 2 ? 96 : 140, height: 10)
                            }
                            .padding(.horizontal, 14)
                        }
                }
            }
            .redacted(reason: .placeholder)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(SeriesTheme.cardSurface)
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(SeriesTheme.borderSubtle, lineWidth: 1)
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading episodes")
    }
}

private struct EpisodeDetailSheet: View {
    let episode: EpisodeSnapshot
    let isWatched: Bool
    let trackAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                EpisodeArtworkView(episode: episode, width: 126, height: 92)

                VStack(alignment: .leading, spacing: 8) {
                    Text("S\(episode.season)E\(episode.episode)")
                        .font(.system(size: 12, weight: .black))
                        .tracking(0.8)
                        .foregroundStyle(SeriesTheme.highlight)
                    Text(episode.title)
                        .font(.system(size: 24, weight: .black))
                        .foregroundStyle(SeriesTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let airdate = episode.airdate {
                        Text(episode.isAired ? "Aired \(airdate)" : "Expected \(airdate)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(SeriesTheme.textSecondary)
                    }
                }
            }

            Text(episode.summary ?? fallbackSummary)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(SeriesTheme.textSecondary)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: trackAction) {
                Text(trackLabel)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(episode.isAired ? SeriesTheme.brandBlack : SeriesTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(episode.isAired ? SeriesTheme.highlight : SeriesTheme.mutedSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!episode.isAired)

            Spacer(minLength: 0)
        }
        .padding(22)
        .background(SeriesTheme.shellBackground.ignoresSafeArea())
    }

    private var trackLabel: String {
        if !episode.isAired { return "Episode not aired yet" }
        return isWatched ? "Move progress to S\(episode.season)E\(episode.episode)" : "Mark S\(episode.season)E\(episode.episode) watched"
    }

    private var fallbackSummary: String {
        if let airdate = episode.airdate {
            return episode.isAired ? "This episode aired on \(airdate)." : "This episode is expected on \(airdate)."
        }
        return "No episode summary available yet."
    }
}

private struct SharedListPickerSheet: View {
    @EnvironmentObject private var socialStore: SeriesSocialStore
    @Binding var isPresented: Bool

    let seriesID: String
    let title: String

    @State private var newListTitle = ""

    var body: some View {
        NavigationStack {
            List {
                if socialStore.sharedLists.isEmpty {
                    Text("No shared lists yet. Create one below.")
                        .foregroundStyle(SeriesTheme.mutedText)
                } else {
                    ForEach(socialStore.sharedLists) { listSummary in
                        Button(listSummary.list.title) {
                            Task {
                                _ = await socialStore.addShowToSharedList(listId: listSummary.list.id, seriesId: seriesID)
                                isPresented = false
                            }
                        }
                    }
                }

                Section("Create New List") {
                    TextField("List title", text: $newListTitle)
                    Button("Create and Add") {
                        Task {
                            guard let created = await socialStore.createSharedList(title: newListTitle.trimmingCharacters(in: .whitespacesAndNewlines)),
                                  !newListTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                            _ = await socialStore.addShowToSharedList(listId: created.list.id, seriesId: seriesID)
                            isPresented = false
                        }
                    }
                    .disabled(newListTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Add \(title)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                }
            }
        }
    }
}

private struct RecommendSeriesSheet: View {
    @EnvironmentObject private var socialStore: SeriesSocialStore
    @Binding var isPresented: Bool

    let seriesID: String
    let title: String

    @State private var query = ""
    @State private var message = ""
    @State private var users: [RemoteSocialUser] = []

    var body: some View {
        NavigationStack {
            List {
                Section("Message") {
                    TextField("Optional note", text: $message, axis: .vertical)
                }
                Section("Recipients") {
                    ForEach(users) { user in
                        Button {
                            Task {
                                _ = await socialStore.createRecommendation(
                                    recipientUserId: user.userId,
                                    seriesId: seriesID,
                                    message: message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : message
                                )
                                isPresented = false
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.displayName ?? user.email ?? user.userId)
                                Text(user.email ?? user.relationship)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(SeriesTheme.mutedText)
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, prompt: "Search people")
            .navigationTitle("Recommend \(title)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { isPresented = false }
                }
            }
            .task { await loadUsers() }
            .task(id: query) { await loadUsers() }
        }
    }

    private func loadUsers() async {
        users = await socialStore.searchPeople(query: query)
    }
}
