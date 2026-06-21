import { AppExternalLinkPanel, AppSegmentedControl, appsAvExternalSearchUrl, appsAvImdbSearchUrl, ErrorState, type AppExternalLinkItem, useAppsAvLocale } from "@avalsys/apps-av-web";
import { useAccountSession, useAccountToken } from "@avalsys/account-av-web";
import { useQuery } from "@tanstack/react-query";
import { Link, createFileRoute } from "@tanstack/react-router";
import { Archive, ArrowLeft, BookOpen, CheckCircle2, ChevronLeft, ChevronRight, Plus, RotateCcw, Search, StepBack, StepForward, Trash2 } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { ProtectedRoute } from "@/components/protected-route";
import { SeriesAppShell } from "@/components/series-app-shell";
import { SeriesArtwork, StatusButtons, seriesLibraryUiText } from "@/components/series-library-ui";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { SeriesApiClient, readRememberedSeriesCatalogItem, type SeriesEpisodeGuideItem, type SeriesSearchResult } from "@/lib/series-api-client";
import { getSeriesApiBaseUrl } from "@/lib/series-config";
import { isPlaceholderSeriesTitle, normalizeSeriesId } from "@/lib/series-display";
import { readSeriesExternalSearchEngine } from "@/lib/series-external-preferences";
import { useSeriesLibrary } from "@/lib/series-library-provider";
import { compareEpisodeCursors, cursorLabel, nextEpisodeCursor, progressLabel, type SeriesEpisodeCursor, type SeriesLibraryEntry } from "@/lib/series-library";
import { localizedSeriesPath, useSeriesApiLocale, useSeriesText } from "@/lib/series-i18n";

export const Route = createFileRoute("/series/$seriesId")({
  component: SeriesDetailRoute
});

function SeriesDetailRoute() {
  const params = Route.useParams();
  const seriesId = normalizeRouteSeriesId(params.seriesId);
  const locale = useAppsAvLocale();
  const apiLocale = useSeriesApiLocale();
  const text = useSeriesText();
  const accountSession = useAccountSession();
  const getToken = useAccountToken();
  const library = useSeriesLibrary();
  const labels = detailLabels[locale];
  const libraryLabels = seriesLibraryUiText(locale);
  const entry = library.findEntryBySeriesId(seriesId);
  const client = useMemo(() => new SeriesApiClient(getSeriesApiBaseUrl()), []);
  const rememberedCatalog = useMemo(() => readRememberedSeriesCatalogItem(seriesId), [seriesId]);
  const [externalSearchEngine, setExternalSearchEngine] = useState(readSeriesExternalSearchEngine);
  const detail = useQuery({
    enabled: accountSession.isLoaded && Boolean(accountSession.isSignedIn),
    queryFn: async () => {
      const token = await getToken();
      if (!token) {
        throw new Error("Series detail token is not available.");
      }
      return client.series({ locale: apiLocale, seriesId, token });
    },
    queryKey: ["series-av", "detail", apiLocale, seriesId, accountSession.userId],
    retry: false
  });
  const detailCatalog = detail.data?.summary ?? null;
  const fallbackCatalog = useQuery({
    enabled: !detail.isLoading && isPlaceholderCatalogTitle(detailCatalog?.title, seriesId),
    queryFn: () => client.popularSeries({ locale: apiLocale, limit: 12, surface: "search" }),
    queryKey: ["series-av", "detail-fallback-popular", apiLocale, seriesId],
    retry: false
  });
  const catalog = rememberedCatalog && isPlaceholderCatalogTitle(detailCatalog?.title, seriesId)
    ? rememberedCatalog
    : !isPlaceholderCatalogTitle(detailCatalog?.title, seriesId)
    ? detailCatalog
    : (fallbackCatalog.data?.results.find((result) => (result.seriesId ?? result.id).trim().toLocaleLowerCase() === seriesId.trim().toLocaleLowerCase()) ?? detailCatalog);
  const hasCatalogTitle = !isPlaceholderCatalogTitle(catalog?.title, seriesId);
  const isCatalogResolving = !hasCatalogTitle && (!accountSession.isLoaded || detail.isLoading || fallbackCatalog.isLoading);
  const episodes = useQuery({
    queryFn: () =>
      client.episodes({
        lastWatchedEpisode: entry?.lastWatchedEpisodeCursor?.episodeNumber,
        lastWatchedSeason: entry?.lastWatchedEpisodeCursor?.seasonNumber,
        seriesId
      }),
    queryKey: ["series-av", "episodes", seriesId, entry?.lastWatchedEpisodeCursor?.seasonNumber, entry?.lastWatchedEpisodeCursor?.episodeNumber]
  });
  const title = catalog?.title ?? entry?.title ?? decodeURIComponent(seriesId);
  const catalogArtworkRef = catalog?.posterUrl ?? catalog?.displayArtwork?.url ?? null;
  const externalQuery = seriesExternalQuery(title, catalog?.startYear ?? catalog?.firstAirDate);
  const sourceLinks = sourceLinksForSeries({ catalog, engine: externalSearchEngine, labels, query: externalQuery });

  useEffect(() => {
    setExternalSearchEngine(readSeriesExternalSearchEngine());
  }, [seriesId]);

  useEffect(() => {
    if (!entry || !catalog || !hasCatalogTitle) {
      return;
    }
    library.updateCatalogMetadataIfPlaceholder(entry.entryId, {
      displayArtworkRef: catalogArtworkRef,
      fallbackVisualSeed: catalog.title,
      seriesId,
      title: catalog.title
    });
  }, [catalog, catalogArtworkRef, entry, hasCatalogTitle, library, seriesId]);
  const artwork = entry
    ? {
        ...entry,
        displayArtworkRef: entry.displayArtworkRef ?? catalogArtworkRef,
        fallbackVisualSeed: catalog?.title ?? entry.fallbackVisualSeed ?? title,
        title
      }
    : {
        displayArtworkRef: catalogArtworkRef,
        fallbackVisualSeed: title,
        seriesId,
        title
      };

  return (
    <ProtectedRoute>
      <SeriesAppShell>
        <section className="grid gap-6">
          <Card className="series-paper gap-0 rounded-lg border-[#d7c494] p-5 py-5 shadow-lg shadow-[#172f5c]/8 sm:p-8 sm:py-8">
            <div className="mb-6 flex flex-wrap items-center justify-between gap-3">
              <Button asChild variant="ghost" className="w-fit rounded-full">
                <Link to={localizedSeriesPath("/library", locale)}>
                  <ArrowLeft className="size-4" /> {text.nav.library}
                </Link>
              </Button>
              {entry ? (
                <p className="rounded-full border border-[#d7c494] bg-white/55 px-4 py-2 text-sm font-semibold text-[#53617a]">
                  {libraryLabels.status[entry.status]} · {progressLabel(entry, libraryLabels.notStarted, libraryLabels.noEpisodeSet)}
                </p>
              ) : null}
            </div>

            {isCatalogResolving ? <SeriesDetailHeroSkeleton /> : <SeriesDetailHero artwork={artwork} catalog={catalog} catalogArtworkRef={catalogArtworkRef} detailUnavailable={detail.isError} entry={entry} labels={labels} library={library} libraryLabels={libraryLabels} locale={locale} seriesId={seriesId} sourceLinks={sourceLinks} title={title} unknownDate={text.search.dateUnknown} noOverview={text.search.noOverview} />}
          </Card>

          <Card className="gap-4 rounded-lg border-[#d7c494] bg-[#fff8df]/88 p-5 py-5 text-[#112a55] shadow-sm shadow-[#172f5c]/6 sm:p-6">
            <div className="flex flex-wrap items-center justify-between gap-3">
              <h2 className="text-lg font-semibold">{labels.episodeGuide}</h2>
            </div>
            {episodes.isLoading ? <div className="h-40 animate-pulse rounded-lg bg-[#ead6a5]" /> : null}
            {episodes.isError ? <ErrorState className="border-[#d7c494] bg-white/70" description={episodes.error.message} title={labels.episodesUnavailable} /> : null}
            {episodes.data ? <EpisodeGuide labels={labels} libraryLabels={libraryLabels} entry={entry} items={episodes.data.items} markWatchedThrough={library.markWatchedThrough} /> : null}
          </Card>
        </section>
      </SeriesAppShell>
    </ProtectedRoute>
  );
}

function SeriesDetailHero({
  artwork,
  catalog,
  catalogArtworkRef,
  detailUnavailable,
  entry,
  labels,
  library,
  libraryLabels,
  locale,
  noOverview,
  seriesId,
  sourceLinks,
  title,
  unknownDate
}: {
  artwork: Pick<SeriesLibraryEntry, "displayArtworkRef" | "fallbackVisualSeed" | "title"> & { seriesId?: string };
  catalog: SeriesSearchResult | null | undefined;
  catalogArtworkRef: string | null;
  detailUnavailable: boolean;
  entry: SeriesLibraryEntry | null;
  labels: (typeof detailLabels)[keyof typeof detailLabels];
  library: ReturnType<typeof useSeriesLibrary>;
  libraryLabels: ReturnType<typeof seriesLibraryUiText>;
  locale: ReturnType<typeof useAppsAvLocale>;
  noOverview: string;
  seriesId: string;
  sourceLinks: AppExternalLinkItem[];
  title: string;
  unknownDate: string;
}) {
  return (
    <div className="grid gap-6 lg:grid-cols-[12rem_minmax(0,1fr)] xl:grid-cols-[13.5rem_minmax(0,1fr)]">
      <SeriesArtwork entry={artwork} size="xl" />
      <div className="min-w-0">
        <div className="max-w-4xl">
          <h1 className="text-3xl font-semibold leading-tight text-[#112a55] sm:text-4xl">{title}</h1>
          <p className="mt-3 text-sm font-semibold text-[#5a8f2f]">
            {catalog?.startYear ?? catalog?.firstAirDate ?? unknownDate}
            {catalog?.genres?.length ? ` · ${catalog.genres.slice(0, 3).join(" · ")}` : ""}
          </p>
          {detailUnavailable ? <p className="mt-3 text-sm font-semibold text-[#b15b22]">{labels.detailUnavailable}</p> : null}
          <p className="mt-4 text-base leading-7 text-[#334766]">{catalog?.summary ?? catalog?.overview ?? noOverview}</p>
        </div>

        <div className="mt-5">
          <AppExternalLinkPanel links={sourceLinks} title={labels.sourcesTitle} />
        </div>

        <div className="mt-6 flex flex-wrap gap-2">
          {entry ? (
            <>
              <Button className="rounded-full bg-[#112a55] text-white hover:bg-[#19396f]" onClick={() => library.markNextEpisodeWatched(entry.entryId)}>
                <StepForward className="size-4" /> {labels.markNext} {cursorLabel(nextEpisodeCursor(entry.lastWatchedEpisodeCursor))}
              </Button>
              {entry.lastWatchedEpisodeCursor ? (
                <>
                  <Button variant="outline" className="rounded-full border-[#c8ad72] bg-white/60" onClick={() => library.markPreviousEpisodeWatched(entry.entryId)}>
                    <StepBack className="size-4" /> {libraryLabels.previous}
                  </Button>
                  <Button variant="ghost" className="rounded-full text-[#112a55]" onClick={() => library.clearProgress(entry.entryId)}>
                    <RotateCcw className="size-4" /> {libraryLabels.clear}
                  </Button>
                </>
              ) : null}
              <StatusButtons entry={entry} locale={locale} />
              {!entry.archivedAt ? (
                <Button variant="outline" className="rounded-full border-[#c8ad72] bg-white/60" onClick={() => library.archive(entry.entryId)}>
                  <Archive className="size-4" /> {libraryLabels.archive}
                </Button>
              ) : (
                <Button variant="outline" className="rounded-full border-[#c8ad72] bg-white/60" onClick={() => library.restore(entry.entryId)}>
                  <RotateCcw className="size-4" /> {libraryLabels.restore}
                </Button>
              )}
              <Button
                variant="ghost"
                className="rounded-full text-red-700 hover:bg-red-50 hover:text-red-800"
                onClick={() => {
                  if (window.confirm(libraryLabels.confirmTrash)) {
                    library.deleteEntry(entry.entryId);
                  }
                }}
              >
                <Trash2 className="size-4" /> {libraryLabels.trash}
              </Button>
            </>
          ) : (
            <Button
              className="rounded-full bg-[#112a55] text-white hover:bg-[#19396f]"
              disabled={!library.canAddSeries}
              onClick={() =>
                library.addCatalogSeries({
                  displayArtworkRef: catalogArtworkRef,
                  fallbackVisualSeed: title,
                  seriesId,
                  title
                })
              }
            >
              <Plus className="size-4" /> {library.canAddSeries ? labels.follow : labels.limitReached}
            </Button>
          )}
        </div>
      </div>
    </div>
  );
}

function EpisodeGuide({
  entry,
  items,
  labels,
  libraryLabels,
  markWatchedThrough
}: {
  entry: SeriesLibraryEntry | null;
  items: SeriesEpisodeGuideItem[];
  labels: (typeof detailLabels)[keyof typeof detailLabels];
  libraryLabels: ReturnType<typeof seriesLibraryUiText>;
  markWatchedThrough: (entryId: string, cursor: SeriesEpisodeCursor) => void;
}) {
  const guide = useMemo(() => normalizeEpisodeGuide(items), [items]);
  const initialSeason = entry?.lastWatchedEpisodeCursor?.seasonNumber ?? guide.seasons[0] ?? 1;
  const [selectedSeason, setSelectedSeason] = useState(initialSeason);

  useEffect(() => {
    if (guide.seasons.length === 0) {
      return;
    }
    if (!guide.seasons.includes(selectedSeason)) {
      setSelectedSeason(entry?.lastWatchedEpisodeCursor?.seasonNumber && guide.seasons.includes(entry.lastWatchedEpisodeCursor.seasonNumber) ? entry.lastWatchedEpisodeCursor.seasonNumber : (guide.seasons[0] ?? 1));
    }
  }, [entry?.lastWatchedEpisodeCursor?.seasonNumber, guide.seasons, selectedSeason]);

  if (guide.items.length === 0) {
    return <p className="text-sm text-[#53617a]">{labels.noGuide}</p>;
  }

  const selectedEpisodes = guide.itemsBySeason.get(selectedSeason) ?? [];
  const progress = entry?.lastWatchedEpisodeCursor ?? null;
  const selectedSeasonIndex = guide.seasons.indexOf(selectedSeason);
  const previousSeason = selectedSeasonIndex > 0 ? guide.seasons[selectedSeasonIndex - 1] : null;
  const nextSeason = selectedSeasonIndex >= 0 && selectedSeasonIndex < guide.seasons.length - 1 ? guide.seasons[selectedSeasonIndex + 1] : null;
  const episodeCount = selectedEpisodes.length;

  return (
    <div className="grid gap-4">
      <div className="rounded-lg border border-[#d7c494] bg-white/55 p-3">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <p className="text-base font-bold text-[#112a55]">
              {labels.season} {selectedSeason}
              <span className="ml-2 text-sm font-semibold text-[#53617a]">
                · {episodeCount} {episodeCount === 1 ? labels.episodeSingular : labels.episodePlural}
              </span>
            </p>
            <p className="mt-1 text-sm font-semibold text-[#53617a]">
              {entry ? `${labels.watchedThrough}: ${progress ? cursorLabel(progress) : libraryLabels.notStarted}` : labels.followToTrack}
            </p>
          </div>
          <div className="flex gap-2">
            <Button
              type="button"
              size="icon"
              variant="outline"
              className="rounded-full border-[#c8ad72] bg-[#fff8df]/80"
              disabled={!previousSeason}
              aria-label={labels.previousSeason}
              onClick={() => previousSeason && setSelectedSeason(previousSeason)}
            >
              <ChevronLeft className="size-4" />
            </Button>
            <Button
              type="button"
              size="icon"
              variant="outline"
              className="rounded-full border-[#c8ad72] bg-[#fff8df]/80"
              disabled={!nextSeason}
              aria-label={labels.nextSeason}
              onClick={() => nextSeason && setSelectedSeason(nextSeason)}
            >
              <ChevronRight className="size-4" />
            </Button>
          </div>
        </div>

        <AppSegmentedControl
          ariaLabel={labels.season}
          className="mt-3 overflow-x-auto pb-1 [scrollbar-width:none] sm:overflow-visible [&::-webkit-scrollbar]:hidden"
          options={guide.seasons.map((season) => ({ label: `${labels.seasonShort} ${season}`, value: String(season) }))}
          value={String(selectedSeason)}
          onValueChange={(season) => setSelectedSeason(Number(season))}
        />
      </div>

      <div className="grid gap-2 md:grid-cols-2 xl:grid-cols-3">
        {selectedEpisodes.map((episode) => {
          const cursor = { episodeNumber: episode.episodeNumber, seasonNumber: episode.seasonNumber };
          const isWatched = progress ? compareEpisodeCursors(cursor, progress) <= 0 : false;
          const isCurrent = progress ? compareEpisodeCursors(cursor, nextEpisodeCursor(progress)) === 0 : episode.seasonNumber === 1 && episode.episodeNumber === 1;
          const episodeContent = (
            <div className="flex items-start gap-3">
              <div className={isWatched ? "flex h-10 w-12 shrink-0 items-center justify-center rounded-lg bg-[#5a8f2f] text-sm font-black text-white" : "flex h-10 w-12 shrink-0 items-center justify-center rounded-lg bg-[#ead6a5] text-sm font-black text-[#112a55]"}>
                E{episode.episodeNumber}
              </div>
              <div className="min-w-0 flex-1">
                <div className="flex flex-wrap items-start justify-between gap-2">
                  <p className="min-w-0 flex-1 text-sm font-bold text-[#112a55]">
                    {cursorLabel(cursor)} · {episode.title?.trim() || libraryLabels.episode}
                  </p>
                  {entry ? (
                    <span className={isWatched ? "inline-flex shrink-0 items-center gap-1 rounded-full bg-[#5a8f2f] px-2 py-1 text-xs font-bold text-white" : "inline-flex shrink-0 items-center gap-1 rounded-full border border-[#c8ad72] bg-[#fff8df]/80 px-2 py-1 text-xs font-bold text-[#112a55]"}>
                      <CheckCircle2 className="size-3.5" aria-hidden="true" />
                      {isWatched ? labels.watched : labels.markHere}
                    </span>
                  ) : null}
                </div>
                <p className="mt-1 text-xs font-medium text-[#53617a]">
                  {episode.airDate ?? episode.relativeState}
                  {isCurrent ? ` · ${labels.nextEpisode}` : ""}
                </p>
              </div>
            </div>
          );

          return (
            entry ? (
              <button
                key={`${episode.seasonNumber}-${episode.episodeNumber}`}
                type="button"
                className={isWatched ? "rounded-lg border border-[#9ac76f] bg-[#f2fadf] p-3 text-left transition hover:border-[#5a8f2f] hover:bg-[#edf7d8] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#5a8f2f]" : "rounded-lg border border-[#d7c494] bg-white/60 p-3 text-left transition hover:border-[#c8ad72] hover:bg-[#fff8df] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[#5a8f2f]"}
                aria-label={`${labels.markWatchedThrough} ${cursorLabel(cursor)}`}
                onClick={() => markWatchedThrough(entry.entryId, cursor)}
              >
                {episodeContent}
              </button>
            ) : (
              <div key={`${episode.seasonNumber}-${episode.episodeNumber}`} className="rounded-lg border border-[#d7c494] bg-white/60 p-3">
                {episodeContent}
              </div>
            )
          );
        })}
      </div>
    </div>
  );
}

function SeriesDetailHeroSkeleton() {
  return (
    <div className="grid gap-6 lg:grid-cols-[12rem_minmax(0,1fr)] xl:grid-cols-[13.5rem_minmax(0,1fr)]" aria-hidden="true">
      <div className="h-[18rem] w-full max-w-48 animate-pulse rounded-lg bg-[#ead6a5]/80 lg:max-w-none" />
      <div className="min-w-0">
        <div className="max-w-4xl">
          <div className="h-10 w-72 max-w-full animate-pulse rounded-full bg-[#ead6a5]/80 sm:h-11 sm:w-96" />
          <div className="mt-4 h-4 w-36 animate-pulse rounded-full bg-[#d8c27d]/70" />
          <div className="mt-6 grid gap-3">
            <div className="h-4 w-full max-w-3xl animate-pulse rounded-full bg-[#ead6a5]/70" />
            <div className="h-4 w-full max-w-2xl animate-pulse rounded-full bg-[#ead6a5]/60" />
            <div className="h-4 w-3/5 max-w-xl animate-pulse rounded-full bg-[#ead6a5]/50" />
          </div>
        </div>

        <div className="mt-5 rounded-lg border border-[#d7c494] bg-white/35 p-4">
          <div className="h-4 w-20 animate-pulse rounded-full bg-[#d8c27d]/70" />
          <div className="mt-3 flex flex-wrap gap-2">
            <div className="h-10 w-28 animate-pulse rounded-full bg-[#ead6a5]/70" />
            <div className="h-10 w-24 animate-pulse rounded-full bg-[#ead6a5]/60" />
            <div className="h-10 w-36 animate-pulse rounded-full bg-[#ead6a5]/50" />
          </div>
        </div>

        <div className="mt-6 flex flex-wrap gap-2">
          <div className="h-10 w-36 animate-pulse rounded-full bg-[#112a55]/25" />
          <div className="h-10 w-28 animate-pulse rounded-full bg-white/45" />
          <div className="h-10 w-24 animate-pulse rounded-full bg-white/35" />
        </div>
      </div>
    </div>
  );
}

function normalizeRouteSeriesId(seriesId: string) {
  return normalizeSeriesId(seriesId);
}

function normalizeEpisodeGuide(items: SeriesEpisodeGuideItem[]) {
  const normalizedItems = items
    .filter((item) => item.seasonNumber > 0 && item.episodeNumber > 0)
    .sort((first, second) => first.seasonNumber - second.seasonNumber || first.episodeNumber - second.episodeNumber);
  const itemsBySeason = new Map<number, SeriesEpisodeGuideItem[]>();
  for (const item of normalizedItems) {
    const seasonItems = itemsBySeason.get(item.seasonNumber) ?? [];
    seasonItems.push(item);
    itemsBySeason.set(item.seasonNumber, seasonItems);
  }
  return {
    items: normalizedItems,
    itemsBySeason,
    seasons: Array.from(itemsBySeason.keys()).sort((first, second) => first - second)
  };
}

function sourceLinksForSeries({
  catalog,
  engine,
  labels,
  query
}: {
  catalog: SeriesSearchResult | null | undefined;
  engine: string;
  labels: (typeof detailLabels)[keyof typeof detailLabels];
  query: string;
}): AppExternalLinkItem[] {
  const links: AppExternalLinkItem[] = [];
  const imdbUrl = externalLinkByKind(catalog, "imdb")?.url ?? appsAvImdbSearchUrl(query);
  if (imdbUrl) {
    links.push({
      href: imdbUrl,
      icon: <Search className="size-4" aria-hidden="true" />,
      label: labels.sourceImdb
    });
  }

  const wikipediaUrl = externalLinkByKind(catalog, "wikipedia")?.url ?? wikipediaSearchUrl(query);
  if (wikipediaUrl) {
    links.push({
      href: wikipediaUrl,
      icon: <BookOpen className="size-4" aria-hidden="true" />,
      label: labels.sourceWikipedia
    });
  }

  const webUrl = appsAvExternalSearchUrl({ engine, query: `${query} series` });
  if (webUrl) {
    links.push({
      href: webUrl,
      icon: <Search className="size-4" aria-hidden="true" />,
      label: labels.sourceWeb
    });
  }

  return links;
}

export function seriesExternalQuery(title: string, yearOrDate: number | string | null | undefined): string {
  const trimmedTitle = title.trim();
  const yearText = yearOrDate === null || yearOrDate === undefined ? "" : String(yearOrDate).trim();
  if (!yearText || trimmedTitle.endsWith(yearText)) {
    return trimmedTitle;
  }
  return `${trimmedTitle} ${yearText}`.trim();
}

function externalLinkByKind(catalog: SeriesSearchResult | null | undefined, kind: "imdb" | "wikipedia") {
  return catalog?.externalLinks?.find((link) => link.kind === kind && link.url.trim());
}

function wikipediaSearchUrl(query: string) {
  const normalizedQuery = query.trim().replace(/\s+/g, " ");
  return normalizedQuery ? `https://www.wikipedia.org/search-redirect.php?search=${encodeURIComponent(normalizedQuery)}` : null;
}

const detailLabels = {
  ca: {
    episodeGuide: "Guia d'episodis",
    detailUnavailable: "Detall de catàleg no disponible",
    episodePlural: "episodis",
    episodeSingular: "episodi",
    episodesUnavailable: "Episodis no disponibles",
    followToTrack: "Segueix la sèrie per marcar progrés per episodi.",
    follow: "Seguir",
    limitReached: "Límit assolit",
    markHere: "Marcar",
    markNext: "Marcar següent",
    markWatchedThrough: "Marcar fins a",
    nextEpisode: "Següent",
    nextSeason: "Temporada següent",
    noGuide: "Encara no hi ha guia compacta.",
    previousSeason: "Temporada anterior",
    season: "Temporada",
    seasonShort: "T",
    sourceImdb: "IMDb",
    sourceWikipedia: "Viquipèdia",
    sourceWeb: "Cerca web",
    sourcesTitle: "Fonts",
    watched: "Vist",
    watchedThrough: "Vist fins a"
  },
  de: {
    episodeGuide: "Folgenübersicht",
    detailUnavailable: "Katalogdetail nicht verfügbar",
    episodePlural: "Folgen",
    episodeSingular: "Folge",
    episodesUnavailable: "Folgen nicht verfügbar",
    followToTrack: "Folge der Serie, um den Fortschritt pro Folge zu markieren.",
    follow: "Folgen",
    limitReached: "Limit erreicht",
    markHere: "Markieren",
    markNext: "Nächste markieren",
    markWatchedThrough: "Gesehen bis",
    nextEpisode: "Nächste",
    nextSeason: "Nächste Staffel",
    noGuide: "Noch keine kompakte Übersicht verfügbar.",
    previousSeason: "Vorherige Staffel",
    season: "Staffel",
    seasonShort: "S",
    sourceImdb: "IMDb",
    sourceWikipedia: "Wikipedia",
    sourceWeb: "Websuche",
    sourcesTitle: "Quellen",
    watched: "Gesehen",
    watchedThrough: "Gesehen bis"
  },
  en: {
    episodeGuide: "Episode guide",
    detailUnavailable: "Catalog detail unavailable",
    episodePlural: "episodes",
    episodeSingular: "episode",
    episodesUnavailable: "Episodes unavailable",
    followToTrack: "Follow this series to mark episode progress.",
    follow: "Follow",
    limitReached: "Limit reached",
    markHere: "Mark",
    markNext: "Mark next",
    markWatchedThrough: "Watched through",
    nextEpisode: "Next",
    nextSeason: "Next season",
    noGuide: "No compact guide is available yet.",
    previousSeason: "Previous season",
    season: "Season",
    seasonShort: "S",
    sourceImdb: "IMDb",
    sourceWikipedia: "Wikipedia",
    sourceWeb: "Web search",
    sourcesTitle: "Sources",
    watched: "Watched",
    watchedThrough: "Watched through"
  },
  es: {
    episodeGuide: "Guía de episodios",
    detailUnavailable: "Detalle de catálogo no disponible",
    episodePlural: "episodios",
    episodeSingular: "episodio",
    episodesUnavailable: "Episodios no disponibles",
    followToTrack: "Sigue esta serie para marcar el progreso por episodio.",
    follow: "Seguir",
    limitReached: "Límite alcanzado",
    markHere: "Marcar",
    markNext: "Marcar siguiente",
    markWatchedThrough: "Visto hasta",
    nextEpisode: "Siguiente",
    nextSeason: "Temporada siguiente",
    noGuide: "Todavía no hay guía compacta.",
    previousSeason: "Temporada anterior",
    season: "Temporada",
    seasonShort: "T",
    sourceImdb: "IMDb",
    sourceWikipedia: "Wikipedia",
    sourceWeb: "Buscar en web",
    sourcesTitle: "Fuentes",
    watched: "Visto",
    watchedThrough: "Visto hasta"
  },
  fr: {
    episodeGuide: "Guide des épisodes",
    detailUnavailable: "Détail du catalogue indisponible",
    episodePlural: "épisodes",
    episodeSingular: "épisode",
    episodesUnavailable: "Épisodes indisponibles",
    followToTrack: "Suivez cette série pour marquer la progression par épisode.",
    follow: "Suivre",
    limitReached: "Limite atteinte",
    markHere: "Marquer",
    markNext: "Marquer la suite",
    markWatchedThrough: "Vu jusqu'à",
    nextEpisode: "Suivant",
    nextSeason: "Saison suivante",
    noGuide: "Aucun guide compact pour le moment.",
    previousSeason: "Saison précédente",
    season: "Saison",
    seasonShort: "S",
    sourceImdb: "IMDb",
    sourceWikipedia: "Wikipédia",
    sourceWeb: "Recherche web",
    sourcesTitle: "Sources",
    watched: "Vu",
    watchedThrough: "Vu jusqu'à"
  }
} as const;

function isPlaceholderCatalogTitle(title: string | null | undefined, seriesId: string) {
  return isPlaceholderSeriesTitle(title, seriesId);
}
