export interface SeriesSearchResult {
  displayArtwork?: {
    assetName?: string | null;
    fallbackSeed?: string | null;
    kind?: string;
    url?: string | null;
  } | null;
  firstAirDate?: string | null;
  genres?: string[];
  id: string;
  originalLanguage?: string | null;
  overview?: string | null;
  posterUrl?: string | null;
  providerId?: string | null;
  seriesId?: string;
  startYear?: number | null;
  statusText?: string | null;
  summary?: string | null;
  title: string;
}

export interface SeriesSearchResponse {
  generatedAt: string;
  results: SeriesSearchResult[];
  source: "d1" | "provider" | "mixed";
}

export interface SearchSeriesInput {
  limit?: number;
  locale?: string;
  query: string;
}

export interface SeriesEpisodesResponse {
  generatedAt: string;
  items: SeriesEpisodeGuideItem[];
  seriesId: string;
}

export interface SeriesEpisodeGuideItem {
  airDate?: string | null;
  episodeNumber: number;
  reliability: "reliable" | "partial";
  relativeState: "watched" | "current" | "next" | "pending";
  seasonNumber: number;
  supportedActions: string[];
  title?: string | null;
}

export interface SeriesLibrarySyncDocument {
  data: {
    appId: "seriesav";
    deviceId: string;
    entries: unknown[];
    resource: "seriesLibrary";
    sentAt: string;
  };
  etag?: string | null;
  revision: number;
  updatedAt: string;
}

export class SeriesApiClient {
  constructor(private readonly baseUrl: string) {}

  async searchSeries({ limit = 10, locale = "en-US", query }: SearchSeriesInput): Promise<SeriesSearchResponse> {
    const url = new URL(`${this.baseUrl}/v1/series/search`);
    url.searchParams.set("q", query);
    url.searchParams.set("locale", locale);
    url.searchParams.set("limit", String(Math.min(Math.max(limit, 1), 25)));

    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Series search failed with ${response.status}.`);
    }

    return response.json() as Promise<SeriesSearchResponse>;
  }

  async popularSeries({ limit = 12, locale = "en-US", surface = "home" }: { limit?: number; locale?: string; surface?: string }): Promise<SeriesSearchResponse> {
    const url = new URL(`${this.baseUrl}/v1/series/popular`);
    url.searchParams.set("surface", surface);
    url.searchParams.set("locale", locale);
    url.searchParams.set("limit", String(Math.min(Math.max(limit, 1), 25)));

    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Series popular failed with ${response.status}.`);
    }

    return response.json() as Promise<SeriesSearchResponse>;
  }

  async episodes({
    lastWatchedEpisode,
    lastWatchedSeason,
    seriesId
  }: {
    lastWatchedEpisode?: number;
    lastWatchedSeason?: number;
    seriesId: string;
  }): Promise<SeriesEpisodesResponse> {
    const url = new URL(`${this.baseUrl}/v1/series/${encodeURIComponent(seriesId)}/episodes`);
    if (lastWatchedSeason && lastWatchedEpisode) {
      url.searchParams.set("lastWatchedSeason", String(lastWatchedSeason));
      url.searchParams.set("lastWatchedEpisode", String(lastWatchedEpisode));
    }

    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Series episodes failed with ${response.status}.`);
    }

    return response.json() as Promise<SeriesEpisodesResponse>;
  }

  async pullLibrary(token: string): Promise<{ document: SeriesLibrarySyncDocument; etag: string | null }> {
    const response = await fetch(`${this.baseUrl}/v1/apps/seriesav/data/seriesLibrary`, {
      headers: {
        Authorization: `Bearer ${token}`
      }
    });
    if (!response.ok) {
      throw new Error(`Series library pull failed with ${response.status}.`);
    }
    return {
      document: (await response.json()) as SeriesLibrarySyncDocument,
      etag: response.headers.get("ETag")
    };
  }

  async pushLibrary({
    deviceId,
    entries,
    expectedEtag,
    token
  }: {
    deviceId: string;
    entries: unknown[];
    expectedEtag?: string | null;
    token: string;
  }): Promise<{ document: SeriesLibrarySyncDocument; etag: string | null }> {
    const response = await fetch(`${this.baseUrl}/v1/apps/seriesav/data/seriesLibrary`, {
      body: JSON.stringify({
        appId: "seriesav",
        deviceId,
        entries,
        resource: "seriesLibrary",
        sentAt: new Date().toISOString()
      }),
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
        ...(expectedEtag ? { "If-Match": expectedEtag } : {})
      },
      method: "PUT"
    });
    if (!response.ok) {
      throw new Error(`Series library push failed with ${response.status}.`);
    }
    return {
      document: (await response.json()) as SeriesLibrarySyncDocument,
      etag: response.headers.get("ETag")
    };
  }
}
