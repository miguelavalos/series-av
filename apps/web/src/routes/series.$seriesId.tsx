import { appsAvExternalSearchUrl, appsAvImdbSearchUrl, ErrorState, useAppsAvLocale } from "@avalsys/apps-av-web";
import { useAccountSession, useAccountToken } from "@avalsys/account-av-web";
import { useQuery } from "@tanstack/react-query";
import { Link, createFileRoute } from "@tanstack/react-router";
import { ArrowLeft, CheckCircle2, ChevronLeft, ChevronRight, Database, ExternalLink, Plus, RotateCcw, Search, StepBack, StepForward } from "lucide-react";
import type { ReactNode } from "react";
import { useEffect, useMemo, useState } from "react";
import { ProtectedRoute } from "@/components/protected-route";
import { SeriesAppShell } from "@/components/series-app-shell";
import { SeriesArtwork, StatusButtons, seriesLibraryUiText } from "@/components/series-library-ui";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { SeriesApiClient, readRememberedSeriesCatalogItem, type SeriesEpisodeGuideItem } from "@/lib/series-api-client";
import { getSeriesApiBaseUrl } from "@/lib/series-config";
import { readSeriesExternalSearchEngine } from "@/lib/series-external-preferences";
import { useSeriesLibrary } from "@/lib/series-library-provider";
import { compareEpisodeCursors, cursorLabel, nextEpisodeCursor, progressLabel, type SeriesEpisodeCursor, type SeriesLibraryEntry } from "@/lib/series-library";
import { localizedSeriesPath, useSeriesApiLocale, useSeriesText } from "@/lib/series-i18n";

export const Route = createFileRoute("/series/$seriesId")({
  component: SeriesDetailRoute
});

function SeriesDetailRoute() {
  const { seriesId } = Route.useParams();
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
  const externalQuery = [title, catalog?.startYear ?? catalog?.firstAirDate].filter(Boolean).join(" ");
  const sourceLinks = sourceLinksForSeries({ engine: externalSearchEngine, labels, query: externalQuery, seriesId });

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

            <div className="grid gap-6 lg:grid-cols-[12rem_minmax(0,1fr)] xl:grid-cols-[13.5rem_minmax(0,1fr)]">
              <SeriesArtwork entry={artwork} size="xl" />
              <div className="min-w-0">
                <div className="max-w-4xl">
                  <h1 className="text-3xl font-semibold leading-tight text-[#112a55] sm:text-4xl">{title}</h1>
                  <p className="mt-3 text-sm font-semibold text-[#5a8f2f]">
                    {catalog?.startYear ?? catalog?.firstAirDate ?? text.search.dateUnknown}
                    {catalog?.genres?.length ? ` · ${catalog.genres.slice(0, 3).join(" · ")}` : ""}
                  </p>
                  {detail.isError ? <p className="mt-3 text-sm font-semibold text-[#b15b22]">{labels.detailUnavailable}</p> : null}
                  <p className="mt-4 text-base leading-7 text-[#334766]">{catalog?.summary ?? catalog?.overview ?? text.search.noOverview}</p>
                </div>

                {sourceLinks.length > 0 ? (
                  <div className="mt-5 rounded-lg border border-[#d7c494] bg-white/45 p-4">
                    <p className="text-sm font-bold text-[#112a55]">{labels.sourcesTitle}</p>
                    <div className="mt-3 flex flex-wrap gap-2">
                      {sourceLinks.map((source) => (
                        <a
                          key={source.href}
                          className="inline-flex min-h-10 items-center gap-2 rounded-full border border-[#c8ad72] bg-[#fff8df]/80 px-4 text-sm font-bold text-[#112a55] hover:bg-white"
                          href={source.href}
                          rel="noreferrer"
                          target="_blank"
                        >
                          {source.icon}
                          {source.label}
                          <ExternalLink className="size-3.5" aria-hidden="true" />
                        </a>
                      ))}
                    </div>
                  </div>
                ) : null}

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

        <div className="mt-3 flex gap-2 overflow-x-auto pb-1 [scrollbar-width:none] sm:flex-wrap sm:overflow-visible [&::-webkit-scrollbar]:hidden">
          {guide.seasons.map((season) => (
            <button
              key={season}
              type="button"
              aria-current={selectedSeason === season ? "true" : undefined}
              className={
                selectedSeason === season
                  ? "min-h-10 shrink-0 rounded-lg bg-[#112a55] px-4 text-sm font-bold text-white shadow-sm shadow-[#172f5c]/15"
                  : "min-h-10 shrink-0 rounded-lg border border-[#d7c494] bg-white/70 px-4 text-sm font-bold text-[#112a55] hover:bg-white"
              }
              onClick={() => setSelectedSeason(season)}
            >
              {labels.seasonShort} {season}
            </button>
          ))}
        </div>
      </div>

      <div className="grid gap-2 md:grid-cols-2 xl:grid-cols-3">
        {selectedEpisodes.map((episode) => {
          const cursor = { episodeNumber: episode.episodeNumber, seasonNumber: episode.seasonNumber };
          const isWatched = progress ? compareEpisodeCursors(cursor, progress) <= 0 : false;
          const isCurrent = progress ? compareEpisodeCursors(cursor, nextEpisodeCursor(progress)) === 0 : episode.seasonNumber === 1 && episode.episodeNumber === 1;
          return (
            <div key={`${episode.seasonNumber}-${episode.episodeNumber}`} className={isWatched ? "rounded-lg border border-[#9ac76f] bg-[#f2fadf] p-3" : "rounded-lg border border-[#d7c494] bg-white/60 p-3"}>
              <div className="flex items-start gap-3">
                <div className={isWatched ? "flex h-10 w-12 shrink-0 items-center justify-center rounded-lg bg-[#5a8f2f] text-sm font-black text-white" : "flex h-10 w-12 shrink-0 items-center justify-center rounded-lg bg-[#ead6a5] text-sm font-black text-[#112a55]"}>
                  E{episode.episodeNumber}
                </div>
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-bold text-[#112a55]">
                    {cursorLabel(cursor)} · {episode.title?.trim() || libraryLabels.episode}
                  </p>
                  <p className="mt-1 text-xs font-medium text-[#53617a]">
                    {episode.airDate ?? episode.relativeState}
                    {isCurrent ? ` · ${labels.nextEpisode}` : ""}
                  </p>
                  {entry ? (
                    <Button
                      size="sm"
                      variant={isWatched ? "ghost" : "outline"}
                      className="mt-3 rounded-full border-[#c8ad72] bg-[#fff8df]/80 text-[#112a55]"
                      onClick={() => markWatchedThrough(entry.entryId, cursor)}
                    >
                      <CheckCircle2 className="size-4" /> {labels.markWatchedThrough} {cursorLabel(cursor)}
                    </Button>
                  ) : null}
                </div>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
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
  engine,
  labels,
  query,
  seriesId
}: {
  engine: string;
  labels: (typeof detailLabels)[keyof typeof detailLabels];
  query: string;
  seriesId: string;
}): Array<{ href: string; icon: ReactNode; label: string }> {
  const links: Array<{ href: string; icon: ReactNode; label: string }> = [];
  const theTvdbId = theTvdbIdFromSeriesId(seriesId);
  if (theTvdbId) {
    links.push({
      href: `https://thetvdb.com/series/${encodeURIComponent(theTvdbId)}`,
      icon: <Database className="size-4" aria-hidden="true" />,
      label: labels.sourceTheTvdb
    });
  }

  const imdbUrl = appsAvImdbSearchUrl(query);
  if (imdbUrl) {
    links.push({
      href: imdbUrl,
      icon: <Search className="size-4" aria-hidden="true" />,
      label: labels.sourceImdb
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

function theTvdbIdFromSeriesId(seriesId: string) {
  const normalizedSeriesId = decodeURIComponent(seriesId).trim();
  return normalizedSeriesId.toLocaleLowerCase().startsWith("thetvdb:") ? normalizedSeriesId.slice("thetvdb:".length) : null;
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
    markNext: "Marcar següent",
    markWatchedThrough: "Marcar fins a",
    nextEpisode: "Següent",
    nextSeason: "Temporada següent",
    noGuide: "Encara no hi ha guia compacta.",
    previousSeason: "Temporada anterior",
    season: "Temporada",
    seasonShort: "T",
    sourceImdb: "IMDb",
    sourceTheTvdb: "TheTVDB",
    sourceWeb: "Cerca web",
    sourcesTitle: "Fonts",
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
    markNext: "Nächste markieren",
    markWatchedThrough: "Gesehen bis",
    nextEpisode: "Nächste",
    nextSeason: "Nächste Staffel",
    noGuide: "Noch keine kompakte Übersicht verfügbar.",
    previousSeason: "Vorherige Staffel",
    season: "Staffel",
    seasonShort: "S",
    sourceImdb: "IMDb",
    sourceTheTvdb: "TheTVDB",
    sourceWeb: "Websuche",
    sourcesTitle: "Quellen",
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
    markNext: "Mark next",
    markWatchedThrough: "Watched through",
    nextEpisode: "Next",
    nextSeason: "Next season",
    noGuide: "No compact guide is available yet.",
    previousSeason: "Previous season",
    season: "Season",
    seasonShort: "S",
    sourceImdb: "IMDb",
    sourceTheTvdb: "TheTVDB",
    sourceWeb: "Web search",
    sourcesTitle: "Sources",
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
    markNext: "Marcar siguiente",
    markWatchedThrough: "Visto hasta",
    nextEpisode: "Siguiente",
    nextSeason: "Temporada siguiente",
    noGuide: "Todavía no hay guía compacta.",
    previousSeason: "Temporada anterior",
    season: "Temporada",
    seasonShort: "T",
    sourceImdb: "IMDb",
    sourceTheTvdb: "TheTVDB",
    sourceWeb: "Buscar en web",
    sourcesTitle: "Fuentes",
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
    markNext: "Marquer la suite",
    markWatchedThrough: "Vu jusqu'à",
    nextEpisode: "Suivant",
    nextSeason: "Saison suivante",
    noGuide: "Aucun guide compact pour le moment.",
    previousSeason: "Saison précédente",
    season: "Saison",
    seasonShort: "S",
    sourceImdb: "IMDb",
    sourceTheTvdb: "TheTVDB",
    sourceWeb: "Recherche web",
    sourcesTitle: "Sources",
    watchedThrough: "Vu jusqu'à"
  }
} as const;

function isPlaceholderCatalogTitle(title: string | null | undefined, seriesId: string) {
  const normalizedTitle = title?.trim().toLocaleLowerCase();
  const normalizedSeriesId = seriesId.trim().toLocaleLowerCase();
  return !normalizedTitle || normalizedTitle === normalizedSeriesId || normalizedTitle === decodeURIComponent(seriesId).trim().toLocaleLowerCase();
}
