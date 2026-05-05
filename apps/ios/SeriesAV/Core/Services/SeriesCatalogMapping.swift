import Foundation

func buildSourceKey(source: ShowSource, sourceId: String) -> String {
    "\(source.rawValue):\(sourceId)"
}

func parseSourceKey(_ sourceKey: String) -> (source: ShowSource, sourceId: String) {
    if sourceKey.hasPrefix("thetvdb:") {
        return (.thetvdb, String(sourceKey.dropFirst("thetvdb:".count)))
    }
    if sourceKey.hasPrefix("tvmaze:") {
        return (.tvmaze, String(sourceKey.dropFirst("tvmaze:".count)))
    }
    return (.tvmaze, sourceKey)
}

func mapRemoteRecordToShowSnapshot(_ record: RemoteCatalogRecord, sourceOverride: ShowSource? = nil) -> ShowSnapshot {
    let primaryProviderRef = record.series.providerRefs.first(where: { $0.isPrimary }) ?? record.series.providerRefs.first
    let source = sourceOverride ?? primaryProviderRef?.provider ?? .thetvdb
    let sourceId = primaryProviderRef?.providerSeriesId ?? record.series.id
    let episodes = record.episodes.sorted {
        if $0.seasonNumber != $1.seasonNumber {
            return $0.seasonNumber < $1.seasonNumber
        }
        return $0.episodeNumber < $1.episodeNumber
    }

    var episodeCountBySeason: [String: Int] = [:]
    var totalEpisodeCountBySeason: [String: Int] = [:]
    var episodesBySeason: [String: [EpisodeSnapshot]] = [:]
    var nextEpisode: UpcomingEpisode?

    for episode in episodes {
        let seasonKey = String(episode.seasonNumber)
        let snapshot = EpisodeSnapshot(
            id: "\(episode.seasonNumber)-\(episode.episodeNumber)",
            season: episode.seasonNumber,
            episode: episode.episodeNumber,
            title: episode.title,
            summary: stripHTML(episode.summary),
            imageURL: URL(string: episode.imageURL ?? ""),
            airdate: episode.airDate,
            isAired: episode.isAired ?? true
        )
        episodesBySeason[seasonKey, default: []].append(snapshot)
        totalEpisodeCountBySeason[seasonKey] = max(totalEpisodeCountBySeason[seasonKey] ?? 0, episode.episodeNumber)
        if snapshot.isAired {
            episodeCountBySeason[seasonKey] = max(episodeCountBySeason[seasonKey] ?? 0, episode.episodeNumber)
        } else if nextEpisode == nil {
            nextEpisode = UpcomingEpisode(season: episode.seasonNumber, episode: episode.episodeNumber, airdate: episode.airDate)
        }
    }

    return ShowSnapshot(
        source: source,
        sourceId: sourceId,
        canonicalSeriesId: record.series.id,
        title: record.series.title,
        year: record.series.year,
        imageURL: URL(string: record.series.posterURL ?? ""),
        summary: stripHTML(record.series.summary),
        genres: record.series.genres,
        episodeCountBySeason: episodeCountBySeason,
        totalEpisodeCountBySeason: totalEpisodeCountBySeason,
        episodesBySeason: episodesBySeason,
        nextEpisode: nextEpisode
    )
}

func mapRemoteRecordToSummary(_ record: RemoteCatalogRecord) -> CatalogShowSummary {
    let primaryProviderRef = record.series.providerRefs.first(where: { $0.isPrimary }) ?? record.series.providerRefs.first
    return CatalogShowSummary(
        source: primaryProviderRef?.provider ?? .thetvdb,
        sourceId: primaryProviderRef?.providerSeriesId ?? record.series.id,
        canonicalSeriesId: record.series.id,
        title: record.series.title,
        year: record.series.year,
        imageURL: URL(string: record.series.posterURL ?? ""),
        summary: stripHTML(record.series.summary),
        genres: record.series.genres
    )
}

func stripHTML(_ value: String?) -> String? {
    guard let value, !value.isEmpty else { return nil }
    let cleaned = value
        .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
        .replacingOccurrences(of: "&nbsp;", with: " ")
        .replacingOccurrences(of: "&amp;", with: "&")
        .replacingOccurrences(of: "&quot;", with: "\"")
        .replacingOccurrences(of: "&#39;", with: "'")
        .replacingOccurrences(of: "&apos;", with: "'")
        .replacingOccurrences(of: "&lt;", with: "<")
        .replacingOccurrences(of: "&gt;", with: ">")
        .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    return cleaned.isEmpty ? nil : cleaned
}
