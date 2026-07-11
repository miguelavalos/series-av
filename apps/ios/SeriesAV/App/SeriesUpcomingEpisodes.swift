import AVAppShellFoundation
import AVBrandFoundation
import SwiftUI

struct SeriesUpcomingEpisode: Identifiable, Equatable, Sendable {
    var entryId: String
    var seriesTitle: String
    var item: SeriesEpisodeGuideItem
    var airDate: Date

    var id: String {
        "\(entryId)-\(item.seasonNumber)-\(item.episodeNumber)-\(item.airDate ?? "")"
    }

    var cursor: SeriesEpisodeCursor {
        item.cursor
    }
}

enum SeriesUpcomingEpisodesState: Equatable {
    case idle
    case loading
    case loaded([SeriesUpcomingEpisode])
    case unavailable
}

@MainActor
final class SeriesUpcomingEpisodesModel: ObservableObject {
    @Published private(set) var state: SeriesUpcomingEpisodesState = .idle

    private let client: SeriesEpisodeGuideClient
    private let calendar: Calendar
    private let horizonDays: Int
    private let maxEntries: Int

    init(
        client: SeriesEpisodeGuideClient = SeriesEpisodeGuideClient(apiClient: SeriesAVAPIClient()),
        calendar: Calendar = .current,
        horizonDays: Int = 60,
        maxEntries: Int = 12
    ) {
        self.client = client
        self.calendar = calendar
        self.horizonDays = horizonDays
        self.maxEntries = maxEntries
    }

    func load(entries: [SeriesLibraryEntry]) async {
        let resolvedEntries = entries
            .filter { $0.archivedAt == nil && $0.deletedAt == nil }
            .filter { $0.seriesId.isEmpty == false }

        guard !resolvedEntries.isEmpty else {
            state = .loaded([])
            return
        }

        if SeriesUITestEnvironment.current.upcomingEpisodesScenario == "sample" {
            state = .loaded(uiTestUpcomingEpisodes(entries: resolvedEntries))
            return
        }

        state = .loading
        let today = calendar.startOfDay(for: Date())
        let horizon = calendar.date(byAdding: .day, value: horizonDays, to: today) ?? today

        let loadedItems = await withTaskGroup(of: [SeriesUpcomingEpisode].self) { group in
            for entry in resolvedEntries {
                group.addTask { [client] in
                    do {
                        let response = try await client.episodes(
                            for: entry.seriesId,
                            lastWatchedEpisodeCursor: entry.lastWatchedEpisodeCursor
                        )
                        return response.items.compactMap { item in
                            guard
                                let airDate = SeriesUpcomingEpisodesModel.date(from: item.airDate),
                                airDate >= today,
                                airDate <= horizon,
                                item.relativeState == .next || item.relativeState == .pending
                            else {
                                return nil
                            }

                            return SeriesUpcomingEpisode(
                                entryId: entry.id,
                                seriesTitle: entry.title,
                                item: item,
                                airDate: airDate
                            )
                        }
                    } catch {
                        return []
                    }
                }
            }

            var items: [SeriesUpcomingEpisode] = []
            for await itemGroup in group {
                items.append(contentsOf: itemGroup)
            }
            return items
        }

        state = .loaded(
            loadedItems
                .sorted {
                    if $0.airDate != $1.airDate {
                        return $0.airDate < $1.airDate
                    }
                    if $0.seriesTitle != $1.seriesTitle {
                        return $0.seriesTitle.localizedStandardCompare($1.seriesTitle) == .orderedAscending
                    }
                    return $0.cursor < $1.cursor
                }
                .prefix(maxEntries)
                .map { $0 }
        )
    }

    private func uiTestUpcomingEpisodes(entries: [SeriesLibraryEntry]) -> [SeriesUpcomingEpisode] {
        let today = calendar.startOfDay(for: Date())
        return zip(entries.prefix(3), [1, 3, 8]).compactMap { entry, dayOffset in
            guard let airDate = calendar.date(byAdding: .day, value: dayOffset, to: today) else {
                return nil
            }
            let cursor = entry.lastWatchedEpisodeCursor?.nextEpisode ?? SeriesEpisodeCursor(seasonNumber: 1, episodeNumber: 1)
            let item = SeriesEpisodeGuideItem(
                seasonNumber: cursor.seasonNumber,
                episodeNumber: cursor.episodeNumber,
                title: "Episodio de estreno con un título suficientemente largo",
                airDate: Self.airDateFormatter.string(from: airDate),
                reliability: .reliable,
                relativeState: .next,
                supportedActions: []
            )
            return SeriesUpcomingEpisode(
                entryId: entry.id,
                seriesTitle: entry.title,
                item: item,
                airDate: airDate
            )
        }
    }

    private nonisolated static func date(from value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }
        return airDateFormatter.date(from: value)
    }

    private nonisolated static let airDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

struct SeriesUpcomingEpisodesSection: View {
    let entries: [SeriesLibraryEntry]
    let markWatchedThrough: (SeriesLibraryEntry, SeriesEpisodeCursor) -> Void

    @StateObject private var model = SeriesUpcomingEpisodesModel()

    var body: some View {
        Group {
            switch model.state {
            case .idle, .loading:
                upcomingCard {
                    Label(L10n.string("upcoming.loading"), systemImage: "calendar.badge.clock")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AVBrandColor.textSecondary)
                }
            case .loaded(let episodes):
                if episodes.isEmpty {
                    EmptyView()
                } else {
                    upcomingCard {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionHeader(
                                title: L10n.string("upcoming.title"),
                                subtitle: L10n.string("upcoming.subtitle")
                            )

                            ForEach(episodes) { episode in
                                SeriesUpcomingEpisodeRow(
                                    episode: episode,
                                    entry: entries.first { $0.id == episode.entryId },
                                    markWatchedThrough: markWatchedThrough
                                )

                                if episode.id != episodes.last?.id {
                                    Divider()
                                        .padding(.leading, 60)
                                        .opacity(0.55)
                                }
                            }
                        }
                    }
                }
            case .unavailable:
                EmptyView()
            }
        }
        .task(id: entries.upcomingLoadSignature) {
            await model.load(entries: entries)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    private func upcomingCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        AVAppShellCard {
            content()
        }
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(AVBrandColor.textPrimary)
                .accessibilityIdentifier("series-upcoming-section-title")

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(AVBrandColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("series-upcoming-section-subtitle")
        }
    }
}

struct SeriesHomeUpcomingEpisodesSection: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let entries: [SeriesLibraryEntry]
    let openLibrary: () -> Void

    @StateObject private var model = SeriesUpcomingEpisodesModel(maxEntries: 3)

    var body: some View {
        VStack(spacing: 0) {
            if case .loaded(let episodes) = model.state, !episodes.isEmpty {
                AVAppShellCard {
                    VStack(alignment: .leading, spacing: 12) {
                        homeHeader

                        ForEach(episodes) { episode in
                            HStack(alignment: .top, spacing: 10) {
                                SeriesUpcomingDateBadge(
                                    date: episode.airDate,
                                    accessibilityIdentifier: "series-home-upcoming-\(episode.entryId)-date"
                                )

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(episode.seriesTitle)
                                        .font(.headline)
                                        .foregroundStyle(AVBrandColor.textPrimary)
                                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .accessibilityIdentifier("series-home-upcoming-\(episode.entryId)-title")

                                    Text(upcomingEpisodeDetail(episode))
                                        .font(.footnote.weight(.medium))
                                        .foregroundStyle(AVBrandColor.textSecondary)
                                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .accessibilityIdentifier("series-home-upcoming-\(episode.entryId)-detail")
                                }

                                Spacer(minLength: 0)
                            }

                            if episode.id != episodes.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .task(id: entries.upcomingLoadSignature) {
            await model.load(entries: entries)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }

    @ViewBuilder
    private var homeHeader: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 8) {
                homeTitle
                openLibraryButton
            }
        } else {
            HStack(alignment: .firstTextBaseline) {
                homeTitle
                Spacer()
                openLibraryButton
            }
        }
    }

    private var homeTitle: some View {
        Text(L10n.string("upcoming.home.title"))
            .font(.title3.weight(.black))
            .foregroundStyle(AVBrandColor.textPrimary)
            .accessibilityIdentifier("series-home-upcoming-title")
    }

    private var openLibraryButton: some View {
        Button(action: openLibrary) {
            Text(L10n.string("upcoming.home.openLibrary"))
                .font(.subheadline.weight(.bold))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityIdentifier("series-home-upcoming-open-library")
    }
}

private struct SeriesUpcomingEpisodeRow: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let episode: SeriesUpcomingEpisode
    let entry: SeriesLibraryEntry?
    let markWatchedThrough: (SeriesLibraryEntry, SeriesEpisodeCursor) -> Void

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    episodeSummary
                    HStack {
                        Spacer(minLength: 0)
                        actionMenu
                    }
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    episodeSummary
                    actionMenu
                }
            }
        }
    }

    private var episodeSummary: some View {
        HStack(alignment: .top, spacing: 12) {
            SeriesUpcomingDateBadge(
                date: episode.airDate,
                accessibilityIdentifier: "series-upcoming-\(episode.entryId)-date"
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(episode.seriesTitle)
                    .font(.headline)
                    .foregroundStyle(AVBrandColor.textPrimary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                    .accessibilityIdentifier("series-upcoming-\(episode.entryId)-title")

                Text(cursorLabel(episode.cursor))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AVBrandColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("series-upcoming-\(episode.entryId)-detail")

                if let episodeTitle = upcomingEpisodeTitle(episode) {
                    Text(episodeTitle)
                        .font(.subheadline)
                        .foregroundStyle(AVBrandColor.textSecondary)
                        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("series-upcoming-\(episode.entryId)-episode-title")
                }

                Text(relativeDateText(for: episode.airDate))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AVBrandColor.accent)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("series-upcoming-\(episode.entryId)-relative-date")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var actionMenu: some View {
        if let entry {
            Menu {
                Button {
                    markWatchedThrough(entry, episode.cursor)
                } label: {
                    Label(L10n.string("upcoming.adjustProgress"), systemImage: "checkmark.circle")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.bold))
                    .foregroundStyle(AVBrandColor.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(
                        Color(.secondarySystemGroupedBackground),
                        in: Circle()
                    )
                    .overlay {
                        Circle()
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    }
            }
            .accessibilityLabel(actionTitle)
            .accessibilityIdentifier(actionIdentifier)
        }
    }

    private var actionTitle: String {
        String(format: L10n.string("detail.episodes.action.setPoint.accessibility"), cursorLabel(episode.cursor))
    }

    private var actionIdentifier: String {
        "series-upcoming-episode-\(episode.cursor.seasonNumber)-\(episode.cursor.episodeNumber)-set-progress"
    }
}

private struct SeriesUpcomingDateBadge: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let date: Date
    let accessibilityIdentifier: String

    var body: some View {
        VStack(spacing: 2) {
            Text(month)
                .font(.caption2.weight(.black))
                .foregroundStyle(AVBrandColor.accent)
                .textCase(.uppercase)

            Text(day)
                .font(.title3.weight(.black))
                .foregroundStyle(AVBrandColor.textPrimary)
        }
        .frame(
            width: dynamicTypeSize.isAccessibilitySize ? 64 : 48,
            height: dynamicTypeSize.isAccessibilitySize ? 64 : 48
        )
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(date.formatted(.dateTime.day().month(.wide).locale(L10n.locale)))
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var month: String {
        date.formatted(.dateTime.month(.abbreviated).locale(L10n.locale))
    }

    private var day: String {
        date.formatted(.dateTime.day().locale(L10n.locale))
    }
}

private func upcomingEpisodeDetail(_ episode: SeriesUpcomingEpisode) -> String {
    [cursorLabel(episode.cursor), upcomingEpisodeTitle(episode), relativeDateText(for: episode.airDate)]
        .compactMap { $0 }
        .joined(separator: " · ")
}

private func upcomingEpisodeTitle(_ episode: SeriesUpcomingEpisode) -> String? {
    guard let rawTitle = episode.item.title?.trimmingCharacters(in: .whitespacesAndNewlines), !rawTitle.isEmpty else {
        return nil
    }

    let normalizedTitle = rawTitle
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: L10n.locale)
        .lowercased()
    let episodeNumber = episode.item.episodeNumber
    let placeholders = [
        "tba",
        "tbd",
        "to be announced",
        "episode \(episodeNumber)",
        "episodio \(episodeNumber)",
        "episodi \(episodeNumber)",
        "folge \(episodeNumber)"
    ]

    return placeholders.contains(normalizedTitle) ? nil : rawTitle
}

private func relativeDateText(for date: Date) -> String {
    let calendar = Calendar.current
    if calendar.isDateInToday(date) {
        return L10n.string("upcoming.date.today")
    }
    if calendar.isDateInTomorrow(date) {
        return L10n.string("upcoming.date.tomorrow")
    }

    let formatter = RelativeDateTimeFormatter()
    formatter.locale = L10n.locale
    formatter.unitsStyle = .full
    return formatter.localizedString(for: date, relativeTo: Date())
}

private extension Array where Element == SeriesLibraryEntry {
    var upcomingLoadSignature: String {
        map { entry in
            [
                entry.id,
                entry.seriesId,
                entry.lastWatchedEpisodeCursor.map(cursorLabel) ?? "",
                entry.updatedAt.ISO8601Format()
            ].joined(separator: ":")
        }
        .joined(separator: "|")
    }
}
