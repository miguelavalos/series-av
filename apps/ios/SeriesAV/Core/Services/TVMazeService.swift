import Foundation

struct TVMazeService {
    private let decoder = JSONDecoder()
    private let cache = URLCache.shared

    func search(query: String) async throws -> [CatalogShowSummary] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }
        let url = URL(string: "https://api.tvmaze.com/search/shows?q=\(trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed)")!
        let payload: [TVMazeSearchResult] = try await fetch(url)
        return payload.map { mapSummary(show: $0.show) }.prefix(12).map { $0 }
    }

    func browse(collection: SeriesBrowseCollection) async throws -> [CatalogShowSummary] {
        let genre = collection == .popular ? nil : collection.rawValue
        async let page0: [TVMazeShow] = fetch(URL(string: "https://api.tvmaze.com/shows?page=0")!)
        async let page1: [TVMazeShow] = fetch(URL(string: "https://api.tvmaze.com/shows?page=1")!)
        async let page2: [TVMazeShow] = fetch(URL(string: "https://api.tvmaze.com/shows?page=2")!)
        async let page3: [TVMazeShow] = fetch(URL(string: "https://api.tvmaze.com/shows?page=3")!)
        async let page4: [TVMazeShow] = fetch(URL(string: "https://api.tvmaze.com/shows?page=4")!)
        let shows = try await (page0 + page1 + page2 + page3 + page4)
            .map(mapSummary(show:))
            .filter { summary in
                guard let genre else { return true }
                return summary.genres.contains(where: { $0.lowercased() == genre })
            }
            .sorted(by: { score($0) > score($1) })
        return rotatingFeaturedShows(from: shows, collection: collection)
    }

    func snapshot(for sourceID: String) async throws -> ShowSnapshot {
        let url = URL(string: "https://api.tvmaze.com/shows/\(sourceID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? sourceID)?embed=episodes")!
        let show: TVMazeShow = try await fetch(url)
        return mapSnapshot(show: show)
    }

    private func fetch<T: Decodable>(_ url: URL) async throws -> T {
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 20)
        if let cached = cache.cachedResponse(for: request) {
            return try decoder.decode(T.self, from: cached.data)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        cache.storeCachedResponse(CachedURLResponse(response: response, data: data), for: request)
        return try decoder.decode(T.self, from: data)
    }

    private func mapSummary(show: TVMazeShow) -> CatalogShowSummary {
        CatalogShowSummary(
            source: .tvmaze,
            sourceId: String(show.id),
            canonicalSeriesId: nil,
            title: show.name,
            year: year(from: show.premiered),
            imageURL: URL(string: show.image?.medium ?? show.image?.original ?? ""),
            summary: stripHTML(show.summary),
            genres: show.genres
        )
    }

    private func mapSnapshot(show: TVMazeShow) -> ShowSnapshot {
        let sortedEpisodes = (show.embedded?.episodes ?? []).sorted {
            if $0.season != $1.season {
                return $0.season < $1.season
            }
            return ($0.number ?? 0) < ($1.number ?? 0)
        }

        var aired: [String: Int] = [:]
        var total: [String: Int] = [:]
        var seasons: [String: [EpisodeSnapshot]] = [:]
        var nextEpisode: UpcomingEpisode?
        let now = Date()

        for episode in sortedEpisodes {
            guard let number = episode.number else { continue }
            let seasonKey = String(episode.season)
            let episodeIsAired = isEpisodeAired(episode, now: now)
            let snapshot = EpisodeSnapshot(
                id: String(episode.id ?? episode.season * 10_000 + number),
                season: episode.season,
                episode: number,
                title: episode.name?.isEmpty == false ? episode.name! : "Episode \(number)",
                summary: stripHTML(episode.summary),
                imageURL: URL(string: episode.image?.medium ?? episode.image?.original ?? show.image?.medium ?? show.image?.original ?? ""),
                airdate: episode.airdate,
                isAired: episodeIsAired
            )
            seasons[seasonKey, default: []].append(snapshot)
            total[seasonKey] = max(total[seasonKey] ?? 0, number)
            if episodeIsAired {
                aired[seasonKey] = max(aired[seasonKey] ?? 0, number)
            } else if nextEpisode == nil {
                nextEpisode = UpcomingEpisode(season: episode.season, episode: number, airdate: episode.airdate)
            }
        }

        let summary = mapSummary(show: show)
        return ShowSnapshot(
            source: summary.source,
            sourceId: summary.sourceId,
            canonicalSeriesId: summary.canonicalSeriesId,
            title: summary.title,
            year: summary.year,
            imageURL: summary.imageURL,
            summary: summary.summary,
            genres: summary.genres,
            episodeCountBySeason: aired,
            totalEpisodeCountBySeason: total,
            episodesBySeason: seasons,
            nextEpisode: nextEpisode
        )
    }

    private func stripHTML(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func year(from value: String?) -> Int? {
        guard let value, value.count >= 4 else { return nil }
        return Int(value.prefix(4))
    }

    private func score(_ show: CatalogShowSummary) -> Double {
        Double(show.imageURL != nil ? 8 : 0)
            + Double(show.summary != nil ? 4 : 0)
            + Double(show.year.map { max(0, $0 - 1990) } ?? 0) / 10
            + Double(min(show.genres.count, 3))
    }

    private func rotatingFeaturedShows(
        from shows: [CatalogShowSummary],
        collection: SeriesBrowseCollection,
        now: Date = Date()
    ) -> [CatalogShowSummary] {
        let candidatePool = Array(shows.prefix(90))
        let rotationBucket = Int(now.timeIntervalSince1970 / (6 * 60 * 60))
        let selected = candidatePool
            .sorted {
                rotationRank(for: $0, collection: collection, bucket: rotationBucket) <
                    rotationRank(for: $1, collection: collection, bucket: rotationBucket)
            }
            .prefix(18)
        return selected.sorted {
            let leftScore = score($0)
            let rightScore = score($1)
            if leftScore == rightScore {
                return $0.title < $1.title
            }
            return leftScore > rightScore
        }
    }

    private func rotationRank(
        for show: CatalogShowSummary,
        collection: SeriesBrowseCollection,
        bucket: Int
    ) -> UInt64 {
        stableHash("\(collection.rawValue)|\(bucket)|\(show.source.rawValue)|\(show.sourceId)")
    }

    private func stableHash(_ value: String) -> UInt64 {
        value.utf8.reduce(14_695_981_039_346_656_037) { hash, byte in
            (hash ^ UInt64(byte)).multipliedReportingOverflow(by: 1_099_511_628_211).partialValue
        }
    }

    private func isEpisodeAired(_ episode: TVMazeEpisode, now: Date) -> Bool {
        if let airstamp = episode.airstamp, let date = ISO8601DateFormatter().date(from: airstamp) {
            return date <= now
        }
        if let airdate = episode.airdate {
            return airdate <= ISO8601DateFormatter().string(from: now).prefix(10)
        }
        return true
    }
}

private struct TVMazeSearchResult: Decodable {
    let show: TVMazeShow
}

private struct TVMazeShow: Decodable {
    let id: Int
    let name: String
    let premiered: String?
    let summary: String?
    let genres: [String]
    let image: TVMazeImage?
    let embedded: TVMazeEmbeddedEpisodes?

    enum CodingKeys: String, CodingKey {
        case id, name, premiered, summary, genres, image
        case embedded = "_embedded"
    }
}

private struct TVMazeEmbeddedEpisodes: Decodable {
    let episodes: [TVMazeEpisode]
}

private struct TVMazeEpisode: Decodable {
    let id: Int?
    let season: Int
    let number: Int?
    let name: String?
    let summary: String?
    let image: TVMazeImage?
    let airdate: String?
    let airstamp: String?
}

private struct TVMazeImage: Decodable {
    let medium: String?
    let original: String?
}
