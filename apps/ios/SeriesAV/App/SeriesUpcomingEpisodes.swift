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
    let editProgress: (SeriesLibraryEntry) -> Void

    @StateObject private var model = SeriesUpcomingEpisodesModel()

    var body: some View {
        Group {
            switch model.state {
            case .idle, .loading:
                upcomingCard {
                    Label(L10n.string("upcoming.loading"), systemImage: "calendar.badge.clock")
                        .font(.system(size: 14, weight: .semibold))
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
                                    editProgress: editProgress
                                )

                                if episode.id != episodes.last?.id {
                                    Divider()
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
    }

    private func upcomingCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        AVAppShellCard {
            content()
        }
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AVBrandColor.textSecondary)

            Text(subtitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AVBrandColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct SeriesHomeUpcomingEpisodesSection: View {
    let entries: [SeriesLibraryEntry]
    let openLibrary: () -> Void

    @StateObject private var model = SeriesUpcomingEpisodesModel(maxEntries: 3)

    var body: some View {
        Group {
            if case .loaded(let episodes) = model.state, !episodes.isEmpty {
                AVAppShellCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(L10n.string("upcoming.home.title"))
                                .font(.system(size: 18, weight: .black))
                                .foregroundStyle(AVBrandColor.textPrimary)

                            Spacer()

                            Button(L10n.string("upcoming.home.openLibrary"), action: openLibrary)
                                .font(.system(size: 13, weight: .bold))
                        }

                        ForEach(episodes) { episode in
                            HStack(alignment: .top, spacing: 10) {
                                SeriesUpcomingDateBadge(date: episode.airDate)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(episode.seriesTitle)
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(AVBrandColor.textPrimary)
                                        .lineLimit(1)

                                    Text(upcomingEpisodeDetail(episode))
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(AVBrandColor.textSecondary)
                                        .lineLimit(2)
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
    }
}

private struct SeriesUpcomingEpisodeRow: View {
    let episode: SeriesUpcomingEpisode
    let entry: SeriesLibraryEntry?
    let editProgress: (SeriesLibraryEntry) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            SeriesUpcomingDateBadge(date: episode.airDate)

            VStack(alignment: .leading, spacing: 4) {
                Text(episode.seriesTitle)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AVBrandColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(upcomingEpisodeDetail(episode))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AVBrandColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            if let entry {
                Button {
                    editProgress(entry)
                } label: {
                    Image(systemName: "checkmark.circle")
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AVBrandColor.accent)
                .accessibilityLabel(L10n.string("upcoming.adjustProgress"))
            }
        }
    }
}

private struct SeriesUpcomingDateBadge: View {
    let date: Date

    var body: some View {
        VStack(spacing: 2) {
            Text(month)
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(AVBrandColor.accent)
                .textCase(.uppercase)

            Text(day)
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(AVBrandColor.textPrimary)
        }
        .frame(width: 48, height: 48)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private var month: String {
        date.formatted(.dateTime.month(.abbreviated).locale(L10n.locale))
    }

    private var day: String {
        date.formatted(.dateTime.day().locale(L10n.locale))
    }
}

private func upcomingEpisodeDetail(_ episode: SeriesUpcomingEpisode) -> String {
    let title = episode.item.title?.trimmingCharacters(in: .whitespacesAndNewlines)
    let episodeTitle = title?.isEmpty == false ? title! : String(format: L10n.string("home.editor.episode"), episode.item.episodeNumber)
    return "\(cursorLabel(episode.cursor)) · \(episodeTitle) · \(relativeDateText(for: episode.airDate))"
}

private func relativeDateText(for date: Date) -> String {
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
