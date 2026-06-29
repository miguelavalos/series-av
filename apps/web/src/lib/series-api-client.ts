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
  providerRef?: SeriesProviderRef | null;
  providerId?: string | null;
  providerRefs?: SeriesProviderRef[];
  externalLinks?: SeriesExternalLink[];
  seriesId?: string;
  knownEpisodeCount?: number | null;
  latestKnownEpisodeCursor?: {
    episodeNumber: number;
    seasonNumber: number;
  } | null;
  startYear?: number | null;
  statusText?: string | null;
  summary?: string | null;
  title: string;
}

export interface SeriesProviderRef {
  provider: string;
  providerSeriesId: string;
  providerUrl?: string | null;
}

export interface SeriesExternalLink {
  kind: "source" | "imdb" | "wikipedia" | "web";
  label: string;
  url: string;
}

export interface SeriesSearchResponse {
  generatedAt: string;
  results: SeriesSearchResult[];
  source: "d1" | "provider" | "mixed";
}

export interface SeriesDetailResponse {
  episodeGuide?: {
    generatedAt: string;
    items: SeriesEpisodeGuideItem[];
  };
  generatedAt: string;
  guideReliability?: "available" | "partial" | "unavailable" | "unknown";
  summary: SeriesSearchResult;
}

export interface SeriesShareInvitePreview {
  createdAt: string;
  expiresAt: string;
  id: string;
  kind: "recommendation";
  message?: string | null;
  senderDisplayName?: string | null;
  series: {
    displayArtwork?: SeriesSearchResult["displayArtwork"];
    startYear?: number | null;
    summary?: string | null;
    title: string;
  } | null;
  seriesId: string;
  status: "active" | "accepted" | "revoked" | "expired";
}

export interface SeriesShareInviteResponse {
  generatedAt: string;
  invite: SeriesShareInvitePreview;
}

export interface SeriesShareInviteCreateResponse extends SeriesShareInviteResponse {
  token: string;
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

export interface SeriesGuideFeedbackRequest {
  appLocale?: string;
  knownEpisodeCount?: number | null;
  latestKnownEpisodeCursor?: {
    episodeNumber: number;
    seasonNumber: number;
  } | null;
  note?: string | null;
  reason: "missingEpisodes" | "wrongNumbering" | "wrongDates" | "duplicateEpisodes" | "other";
  seriesId: string;
  title?: string | null;
  userCursor?: {
    episodeNumber: number;
    seasonNumber: number;
  } | null;
}

export interface SeriesGuideFeedbackResponse {
  generatedAt: string;
  reportId: string;
  status: "received";
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

  async series({ locale = "en-US", seriesId, token }: { locale?: string; seriesId: string; token?: string | null }): Promise<SeriesDetailResponse> {
    const url = new URL(`${this.baseUrl}/v1/series/${encodeURIComponent(seriesId)}`);
    url.searchParams.set("locale", locale);

    const response = await fetch(url, {
      headers: token ? { Authorization: `Bearer ${token}` } : undefined
    });
    if (!response.ok) {
      throw new Error(`Series detail failed with ${response.status}.`);
    }

    const payload = (await response.json()) as unknown;
    return normalizeSeriesDetailResponse(payload, seriesId);
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

  async createShareInvite({
    message,
    seriesId,
    token
  }: {
    message?: string | null;
    seriesId: string;
    token: string;
  }): Promise<SeriesShareInviteCreateResponse> {
    const response = await fetch(`${this.baseUrl}/v1/series/share-invites`, {
      body: JSON.stringify({ message, seriesId }),
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json"
      },
      method: "POST"
    });
    if (!response.ok) {
      throw new Error(`Series share invite creation failed with ${response.status}.`);
    }
    return response.json() as Promise<SeriesShareInviteCreateResponse>;
  }

  async reportGuideFeedback(input: SeriesGuideFeedbackRequest): Promise<SeriesGuideFeedbackResponse> {
    const response = await fetch(`${this.baseUrl}/v1/series/guide-feedback`, {
      body: JSON.stringify({
        appLocale: input.appLocale,
        knownEpisodeCount: input.knownEpisodeCount ?? undefined,
        latestKnownEpisodeCursor: input.latestKnownEpisodeCursor ?? undefined,
        note: input.note ?? undefined,
        reason: input.reason,
        seriesId: input.seriesId,
        title: input.title ?? undefined,
        userCursor: input.userCursor ?? undefined
      }),
      headers: {
        "Content-Type": "application/json"
      },
      method: "POST"
    });
    if (!response.ok) {
      throw new Error(`Series guide feedback failed with ${response.status}.`);
    }
    return response.json() as Promise<SeriesGuideFeedbackResponse>;
  }

  async shareInvite(token: string): Promise<SeriesShareInviteResponse> {
    const response = await fetch(`${this.baseUrl}/v1/series/share-invites/${encodeURIComponent(token)}`);
    if (!response.ok) {
      throw new Error(`Series share invite failed with ${response.status}.`);
    }
    return response.json() as Promise<SeriesShareInviteResponse>;
  }

  async acceptShareInvite({ authToken, token }: { authToken: string; token: string }): Promise<SeriesShareInviteResponse> {
    const response = await fetch(`${this.baseUrl}/v1/series/share-invites/${encodeURIComponent(token)}/accept`, {
      body: JSON.stringify({}),
      headers: {
        Authorization: `Bearer ${authToken}`,
        "Content-Type": "application/json"
      },
      method: "POST"
    });
    if (!response.ok) {
      throw new Error(`Series share invite accept failed with ${response.status}.`);
    }
    return response.json() as Promise<SeriesShareInviteResponse>;
  }

  async pullLibrary(token: string): Promise<{ document: SeriesLibrarySyncDocument; etag: string | null }> {
    const response = await fetch(`${this.baseUrl}/v1/apps/seriesav/data/seriesLibrary`, {
      headers: {
        Authorization: `Bearer ${token}`,
        "x-appsav-app-id": "seriesav"
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
        "x-appsav-app-id": "seriesav",
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

const rememberedSeriesCatalogKey = "seriesav.web.rememberedCatalog.v1";

export function rememberSeriesCatalogItem(item: SeriesSearchResult) {
  if (typeof window === "undefined") {
    return;
  }

  const seriesId = (item.seriesId ?? item.id).trim();
  if (!seriesId) {
    return;
  }

  try {
    const current = readRememberedSeriesCatalogMap();
    current[seriesId.toLocaleLowerCase()] = item;
    window.sessionStorage.setItem(rememberedSeriesCatalogKey, JSON.stringify(current));
  } catch {
    // Detail hydration is best-effort; storage failures should not block navigation.
  }
}

export function readRememberedSeriesCatalogItem(seriesId: string): SeriesSearchResult | null {
  if (typeof window === "undefined") {
    return null;
  }

  const normalizedSeriesId = seriesId.trim().toLocaleLowerCase();
  if (!normalizedSeriesId) {
    return null;
  }

  try {
    return readRememberedSeriesCatalogMap()[normalizedSeriesId] ?? null;
  } catch {
    return null;
  }
}

function readRememberedSeriesCatalogMap(): Record<string, SeriesSearchResult> {
  const raw = window.sessionStorage.getItem(rememberedSeriesCatalogKey);
  if (!raw) {
    return {};
  }

  const parsed = JSON.parse(raw) as unknown;
  if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
    return {};
  }
  return parsed as Record<string, SeriesSearchResult>;
}

function normalizeSeriesDetailResponse(payload: unknown, seriesId: string): SeriesDetailResponse {
  if (isSeriesDetailResponse(payload)) {
    return payload;
  }

  if (isLegacySeriesCatalogRecord(payload)) {
    return {
      generatedAt: new Date().toISOString(),
      guideReliability: payload.episodes.length > 0 ? "available" : "partial",
      summary: catalogItemFromLegacyRecord(payload)
    };
  }

  const summary = payload as Partial<SeriesSearchResult>;
  return {
    generatedAt: new Date().toISOString(),
    summary: {
      ...summary,
      id: summary.id || seriesId,
      seriesId: summary.seriesId ?? seriesId,
      title: summary.title ?? seriesId
    }
  };
}

function isSeriesDetailResponse(payload: unknown): payload is SeriesDetailResponse {
  return Boolean(
    payload &&
      typeof payload === "object" &&
      "summary" in payload &&
      payload.summary &&
      typeof payload.summary === "object" &&
      "title" in payload.summary
  );
}

type LegacySeriesCatalogRecord = {
  episodes: unknown[];
  series: {
    backdropUrl?: string | null;
    genres?: string[];
    id: string;
    posterUrl?: string | null;
    providerRefs?: unknown[];
    status?: string | null;
    summary?: string | null;
    title: string;
    updatedAt?: string;
    year?: number | null;
  };
};

function isLegacySeriesCatalogRecord(payload: unknown): payload is LegacySeriesCatalogRecord {
  return Boolean(
    payload &&
      typeof payload === "object" &&
      "series" in payload &&
      "episodes" in payload &&
      Array.isArray((payload as { episodes?: unknown }).episodes) &&
      (payload as { series?: unknown }).series &&
      typeof (payload as { series: { title?: unknown } }).series.title === "string"
  );
}

function catalogItemFromLegacyRecord(record: LegacySeriesCatalogRecord): SeriesSearchResult {
  const posterUrl = record.series.posterUrl ?? undefined;
  return {
    displayArtwork: {
      fallbackSeed: posterUrl ? undefined : record.series.title,
      kind: posterUrl ? "poster" : "initialsFallback",
      url: posterUrl
    },
    genres: record.series.genres ?? [],
    id: record.series.id,
    posterUrl,
    seriesId: record.series.id,
    startYear: record.series.year ?? undefined,
    statusText: record.series.status ?? undefined,
    summary: record.series.summary ?? undefined,
    title: record.series.title
  };
}
