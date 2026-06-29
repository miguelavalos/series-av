import AVExternalLinkFoundation
import Foundation

struct SeriesDetailPresentation: Equatable {
    var title: String
    var metadataText: String
    var externalSearchQuery: String
    var sourceLinks: [SeriesExternalSourceLink]
    var detailEntry: SeriesLibraryEntry?
}

enum SeriesDetailPresentationBuilder {
    static func build(
        catalogItem: SeriesCatalogItem?,
        resolvedCatalogItem: SeriesCatalogItem?,
        entry: SeriesLibraryEntry?,
        searchEngine: AVExternalSearchEngine,
        fallbackTitle: String
    ) -> SeriesDetailPresentation {
        let effectiveCatalogItem = catalogItem ?? resolvedCatalogItem
        let title = displayTitle(entry: entry, catalogItem: effectiveCatalogItem, fallbackTitle: fallbackTitle)
        let externalSearchQuery = externalSearchQuery(title: title, catalogItem: effectiveCatalogItem)

        return SeriesDetailPresentation(
            title: title,
            metadataText: metadataText(for: effectiveCatalogItem),
            externalSearchQuery: externalSearchQuery,
            sourceLinks: sourceLinks(
                catalogItem: effectiveCatalogItem,
                externalSearchQuery: externalSearchQuery,
                searchEngine: searchEngine
            ),
            detailEntry: detailEntry(entry: entry, catalogItem: effectiveCatalogItem)
        )
    }

    static func displayTitle(
        entry: SeriesLibraryEntry?,
        catalogItem: SeriesCatalogItem?,
        fallbackTitle: String
    ) -> String {
        let seriesId = entry?.seriesId ?? catalogItem?.seriesId ?? ""
        if let entryTitle = entry?.title.trimmingCharacters(in: .whitespacesAndNewlines),
           entryTitle.isEmpty == false,
           entryTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != seriesId.lowercased() {
            return entryTitle
        }
        return catalogItem?.title ?? entry?.title ?? fallbackTitle
    }

    static func metadataText(for catalogItem: SeriesCatalogItem?) -> String {
        let year = catalogItem?.startYear.map(String.init)
        let genres = catalogItem?.genres ?? []
        return ([year] + genres.prefix(2).map(Optional.some))
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: " · ")
    }

    static func externalSearchQuery(title: String, catalogItem: SeriesCatalogItem?) -> String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let year = catalogItem?.startYear.map(String.init)
        let shouldAppendYear = year.map { trimmedTitle.hasSuffix($0) == false } ?? false
        return [trimmedTitle, shouldAppendYear ? year : nil]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
    }

    static func sourceLinks(
        catalogItem: SeriesCatalogItem?,
        externalSearchQuery: String,
        searchEngine: AVExternalSearchEngine
    ) -> [SeriesExternalSourceLink] {
        var links: [SeriesExternalSourceLink] = []

        if let imdbURL = enrichedExternalLinkURL(kind: "imdb", catalogItem: catalogItem)
            ?? AVExternalSearchURL.imdbSearch(query: externalSearchQuery) {
            links.append(SeriesExternalSourceLink(kind: .imdb, url: imdbURL))
        }

        if let wikipediaURL = enrichedExternalLinkURL(kind: "wikipedia", catalogItem: catalogItem)
            ?? wikipediaSearchURL(query: externalSearchQuery) {
            links.append(SeriesExternalSourceLink(kind: .wikipedia, url: wikipediaURL))
        }

        if let webURL = AVExternalSearchURL.webSearch(
            query: "\(externalSearchQuery) series",
            engine: searchEngine
        ) {
            links.append(SeriesExternalSourceLink(kind: .web, url: webURL))
        }

        return links
    }

    static func detailEntry(
        entry: SeriesLibraryEntry?,
        catalogItem: SeriesCatalogItem?
    ) -> SeriesLibraryEntry? {
        guard var entry else {
            return nil
        }
        guard let catalogItem else {
            return entry
        }
        if entry.displayArtworkRef?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            entry.displayArtworkRef = catalogItem.displayArtworkRef
        }
        if entry.fallbackVisualSeed?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            entry.fallbackVisualSeed = catalogItem.title
        }
        if entry.latestKnownEpisodeCursor != catalogItem.latestKnownEpisodeCursor {
            entry.latestKnownEpisodeCursor = catalogItem.latestKnownEpisodeCursor
        }
        if entry.knownEpisodeCount != catalogItem.knownEpisodeCount {
            entry.knownEpisodeCount = catalogItem.knownEpisodeCount
        }
        return entry
    }

    static func trackingDetail(for entry: SeriesLibraryEntry) -> String {
        if entry.status == .wantToWatch {
            return String(format: L10n.string("home.queue.wantToWatch.progress"), cursorLabel(entry.nextEpisodeCursor))
        }
        return "\(entry.progressLabel) · \(String(format: L10n.string("home.current.nextEpisode"), cursorLabel(entry.nextEpisodeCursor)))"
    }

    static func nextActionTitle(for entry: SeriesLibraryEntry) -> String {
        primaryProgressActionTitle(for: entry)
    }

    static func detailStatusIcon(_ status: SeriesLibraryEntryStatus) -> String {
        switch status {
        case .wantToWatch:
            return "bookmark.fill"
        case .watching:
            return "play.circle.fill"
        case .watched:
            return "checkmark.circle.fill"
        }
    }

    private static func enrichedExternalLinkURL(kind: String, catalogItem: SeriesCatalogItem?) -> URL? {
        catalogItem?.externalLinks?.first { link in
            link.kind.caseInsensitiveCompare(kind) == .orderedSame
        }?.url
    }

    private static func wikipediaSearchURL(query: String) -> URL? {
        let normalizedQuery = AVExternalSearchURL.normalizedQuery(query)
        guard normalizedQuery.isEmpty == false else { return nil }
        var components = URLComponents(string: "https://www.wikipedia.org/search-redirect.php")
        components?.queryItems = [URLQueryItem(name: "search", value: normalizedQuery)]
        return components?.url
    }
}

struct SeriesExternalSourceLink: Identifiable, Equatable {
    enum Kind: Equatable {
        case imdb
        case wikipedia
        case web
    }

    let kind: Kind
    let url: URL

    var id: URL { url }

    var title: String {
        switch kind {
        case .imdb:
            return L10n.string("detail.sources.imdb")
        case .wikipedia:
            return L10n.string("detail.sources.wikipedia")
        case .web:
            return L10n.string("detail.sources.web")
        }
    }

    var systemImage: String {
        switch kind {
        case .imdb:
            return "magnifyingglass"
        case .wikipedia:
            return "book"
        case .web:
            return "safari"
        }
    }
}
