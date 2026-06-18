export interface SeriesSearchResult {
  firstAirDate?: string | null;
  id: string;
  originalLanguage?: string | null;
  overview?: string | null;
  posterUrl?: string | null;
  providerId?: string | null;
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
}
