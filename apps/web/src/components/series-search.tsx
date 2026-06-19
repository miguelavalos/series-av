import { EmptyState, ErrorState } from "@avalsys/apps-av-web";
import { useQuery } from "@tanstack/react-query";
import { Link } from "@tanstack/react-router";
import { Calendar, Check, Plus, Search } from "lucide-react";
import { useMemo, useState } from "react";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { SeriesApiClient, rememberSeriesCatalogItem, type SeriesSearchResult } from "@/lib/series-api-client";
import { getSeriesApiBaseUrl } from "@/lib/series-config";
import { useSeriesLibrary } from "@/lib/series-library-provider";
import { normalizeSearchText } from "@/lib/series-library";
import { localizedSeriesPath, useSeriesApiLocale, useSeriesText } from "@/lib/series-i18n";
import { useAppsAvLocale } from "@avalsys/apps-av-web";

export function SeriesSearch() {
  const apiLocale = useSeriesApiLocale();
  const locale = useAppsAvLocale();
  const text = useSeriesText();
  const labels = searchLabels[locale];
  const library = useSeriesLibrary();
  const [query, setQuery] = useState("");
  const client = useMemo(() => new SeriesApiClient(getSeriesApiBaseUrl()), []);
  const trimmedQuery = query.trim();
  const catalog = useQuery({
    enabled: trimmedQuery.length > 1,
    queryFn: () => client.searchSeries({ query: trimmedQuery, locale: apiLocale, limit: 12 }),
    queryKey: ["series-av", "search", apiLocale, trimmedQuery]
  });
  const popular = useQuery({
    enabled: trimmedQuery.length === 0,
    queryFn: () => client.popularSeries({ locale: apiLocale, limit: 12, surface: "search" }),
    queryKey: ["series-av", "popular", apiLocale, "search"],
    retry: false
  });
  const localMatches = trimmedQuery.length > 1 ? library.searchEntries(trimmedQuery) : [];
  const localTitles = new Set(localMatches.map((entry) => normalizeSearchText(entry.title)));
  const catalogResults = (trimmedQuery ? catalog.data?.results : popular.data?.results)?.filter((result) => !localTitles.has(normalizeSearchText(result.title))) ?? [];
  const isLoading = trimmedQuery ? catalog.isLoading : popular.isLoading;
  const isError = trimmedQuery ? catalog.isError : false;

  return (
    <section className="flex flex-col gap-6">
      <div className="series-paper rounded-lg border border-[#d7c494] p-5 shadow-lg shadow-[#172f5c]/8 sm:p-6">
        <div className="mb-5">
          <h1 className="text-3xl font-semibold text-[#112a55]">{text.search.title}</h1>
          <p className="mt-2 max-w-2xl text-sm leading-6 text-[#53617a]">{text.search.description}</p>
          <p className="mt-2 text-sm font-semibold text-[#5a8f2f]">
            {library.limit.activeCount}/{library.limit.activeLimit} {labels.activeLower}
          </p>
        </div>
        <label className="relative flex-1">
          <span className="sr-only">{text.search.inputLabel}</span>
          <Search className="pointer-events-none absolute left-4 top-1/2 size-5 -translate-y-1/2 text-[#5a8f2f]" aria-hidden="true" />
          <input
            className="h-13 w-full rounded-full border border-[#d7c494] bg-[#fff8df] pl-12 pr-4 text-base text-[#112a55] shadow-sm placeholder:text-[#748098]"
            onChange={(event) => setQuery(event.target.value)}
            placeholder={text.search.placeholder}
            value={query}
          />
        </label>
      </div>

      {localMatches.length > 0 ? (
        <section>
          <h2 className="mb-3 text-sm font-bold uppercase text-[#53617a]">{labels.inLibrary}</h2>
          <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
            {localMatches.map((entry) => (
              <Card key={entry.entryId} className="gap-3 rounded-lg border-[#d7c494] bg-[#fff8df] p-4 py-4">
                <h3 className="font-semibold text-[#112a55]">{entry.title}</h3>
                <p className="text-sm text-[#53617a]">{entry.status}</p>
                <Button asChild size="sm" variant="outline" className="rounded-full border-[#c8ad72] bg-white/60">
                  <Link to={localizedSeriesPath(`/series/${encodeURIComponent(entry.seriesId)}`, locale)}>{labels.detail}</Link>
                </Button>
              </Card>
            ))}
          </div>
        </section>
      ) : null}

      {isLoading ? <SearchGridSkeleton /> : null}
      {isError ? <ErrorState className="border-[#d7c494] bg-[#fff8df]" description={catalog.error?.message ?? ""} title={text.search.errorTitle} /> : null}
      {!isLoading && trimmedQuery && catalog.data?.results.length === 0 ? <EmptyState className="border-[#d7c494] bg-[#fff8df]" description={text.search.emptyBody} title={text.search.emptyTitle} /> : null}

      {catalogResults.length > 0 ? (
        <section>
          <h2 className="mb-3 text-sm font-bold uppercase text-[#53617a]">{trimmedQuery ? labels.catalog : labels.popular}</h2>
          <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
            {catalogResults.map((result) => (
              <SearchResultCard key={seriesIdFor(result)} locale={locale} result={result} />
            ))}
          </div>
        </section>
      ) : null}
    </section>
  );
}

function SearchResultCard({ locale, result }: { locale: ReturnType<typeof useAppsAvLocale>; result: SeriesSearchResult }) {
  const text = useSeriesText();
  const labels = searchLabels[locale];
  const library = useSeriesLibrary();
  const seriesId = seriesIdFor(result);
  const existing = library.findEntryBySeriesId(seriesId);
  const artwork = artworkFor(result);

  return (
    <Card className="gap-0 overflow-hidden rounded-lg border-[#d7c494] bg-[#fff8df] py-0 shadow-sm shadow-[#172f5c]/8">
      <Link
        to={localizedSeriesPath(`/series/${encodeURIComponent(seriesId)}`, locale)}
        className="block aspect-[16/10] bg-[#ead6a5]"
        onClick={() => rememberSeriesCatalogItem(result)}
      >
        {artwork ? <img alt="" className="h-full w-full object-cover" loading="lazy" src={artwork} /> : <div className="flex h-full items-center justify-center text-sm font-medium text-[#748098]">{text.search.noArtwork}</div>}
      </Link>
      <CardContent className="flex min-h-56 flex-col gap-3 p-4">
        <div>
          <h2 className="line-clamp-2 text-base font-semibold text-[#112a55]">{result.title}</h2>
          <p className="mt-2 flex items-center gap-2 text-xs font-medium uppercase tracking-[0.12em] text-[#5a8f2f]">
            <Calendar className="size-3.5" aria-hidden="true" />
            {result.firstAirDate ?? result.startYear ?? text.search.dateUnknown}
          </p>
        </div>
        <p className="line-clamp-4 text-sm leading-6 text-[#53617a]">{result.overview ?? result.summary ?? text.search.noOverview}</p>
        <div className="mt-auto flex gap-2">
          <Button
            size="sm"
            className="rounded-full bg-[#112a55] text-white hover:bg-[#19396f]"
            disabled={Boolean(existing) || !library.canAddSeries}
            onClick={() => {
              library.addCatalogSeries({
                displayArtworkRef: artwork,
                fallbackVisualSeed: result.title,
                seriesId,
                title: result.title
              });
            }}
          >
            {existing ? <Check className="size-4" /> : <Plus className="size-4" />}
            {existing ? labels.following : library.canAddSeries ? labels.follow : labels.limitReached}
          </Button>
          <Button asChild size="sm" variant="outline" className="rounded-full border-[#c8ad72] bg-white/60">
            <Link to={localizedSeriesPath(`/series/${encodeURIComponent(seriesId)}`, locale)} onClick={() => rememberSeriesCatalogItem(result)}>
              {labels.detail}
            </Link>
          </Button>
        </div>
      </CardContent>
    </Card>
  );
}

const searchLabels = {
  ca: { activeLower: "actives", catalog: "Catàleg", detail: "Detall", follow: "Seguir", following: "Seguint", inLibrary: "A la biblioteca", limitReached: "Límit assolit", popular: "Popular" },
  de: { activeLower: "aktiv", catalog: "Katalog", detail: "Detail", follow: "Folgen", following: "Gespeichert", inLibrary: "In deiner Bibliothek", limitReached: "Limit erreicht", popular: "Beliebt" },
  en: { activeLower: "active", catalog: "Catalog", detail: "Detail", follow: "Follow", following: "Following", inLibrary: "In your library", limitReached: "Limit reached", popular: "Popular" },
  es: { activeLower: "activas", catalog: "Catálogo", detail: "Detalle", follow: "Seguir", following: "Siguiendo", inLibrary: "En tu biblioteca", limitReached: "Límite alcanzado", popular: "Popular" },
  fr: { activeLower: "actives", catalog: "Catalogue", detail: "Détail", follow: "Suivre", following: "Suivi", inLibrary: "Dans votre bibliothèque", limitReached: "Limite atteinte", popular: "Populaire" }
} as const;

function SearchGridSkeleton() {
  return (
    <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
      {Array.from({ length: 6 }).map((_, index) => (
        <div key={index} className="h-72 animate-pulse rounded-lg border border-[#d7c494] bg-[#fff8df]" />
      ))}
    </div>
  );
}

function seriesIdFor(result: SeriesSearchResult) {
  return result.seriesId ?? result.id;
}

function artworkFor(result: SeriesSearchResult) {
  return result.posterUrl ?? result.displayArtwork?.url ?? result.displayArtwork?.assetName ?? null;
}
