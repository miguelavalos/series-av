import { SignedIn, SignedOut } from "@avalsys/account-av-web";
import { AppAssistantBriefCard, AppGridSkeleton, AppMetricTile, AppSurfaceState, CompactSyncStatus, useAppsAvLocale } from "@avalsys/apps-av-web";
import { useQuery } from "@tanstack/react-query";
import { Link, createFileRoute } from "@tanstack/react-router";
import { ArrowRight, BookOpenCheck, Calendar, Check, Plus, Search, Sparkles, StepForward } from "lucide-react";
import { useMemo } from "react";
import { ProtectedRoute } from "@/components/protected-route";
import { SeriesAppShell } from "@/components/series-app-shell";
import { SeriesArtwork, seriesLibraryUiText } from "@/components/series-library-ui";
import { SeriesLoginPage } from "@/components/series-login-page";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { SeriesApiClient, rememberSeriesCatalogItem, type SeriesSearchResult } from "@/lib/series-api-client";
import { getSeriesApiBaseUrl, isSeriesWebAppComingSoon } from "@/lib/series-config";
import { visibleSeriesTitle } from "@/lib/series-display";
import { useSeriesLibrary } from "@/lib/series-library-provider";
import { cursorLabel, nextEpisodeCursor, progressLabel } from "@/lib/series-library";
import { localizedSeriesPath, useSeriesApiLocale, useSeriesText } from "@/lib/series-i18n";

export const Route = createFileRoute("/")({
  component: IndexRoute
});

function IndexRoute() {
  if (isSeriesWebAppComingSoon()) {
    return <SeriesLoginPage comingSoon />;
  }

  return (
    <>
      <SignedOut>
        <SeriesLoginPage />
      </SignedOut>
      <SignedIn>
        <ProtectedRoute>
          <SeriesAppShell>
            <HomeContent />
          </SeriesAppShell>
        </ProtectedRoute>
      </SignedIn>
    </>
  );
}

function HomeContent() {
  const locale = useAppsAvLocale();
  const apiLocale = useSeriesApiLocale();
  const text = useSeriesText();
  const library = useSeriesLibrary();
  const current = library.snapshot.homeEntries[0] ?? null;
  const currentTitle = current ? visibleSeriesTitle(current.title, current.seriesId) : null;
  const shouldShowCurrentSkeleton = Boolean(current && !currentTitle && !library.isInitialSyncComplete && library.syncState === "syncing");
  const next = current ? nextEpisodeCursor(current.lastWatchedEpisodeCursor) : null;
  const labels = homeLabels[locale];
  const libraryLabels = seriesLibraryUiText(locale);
  const client = useMemo(() => new SeriesApiClient(getSeriesApiBaseUrl()), []);
  const popular = useQuery({
    queryFn: () => client.popularSeries({ locale: apiLocale, limit: 8, surface: "home" }),
    queryKey: ["series-av", "home-discovery", apiLocale, "home"],
    retry: false
  });
  const upcoming = useQuery({
    queryFn: () => client.popularSeries({ locale: apiLocale, limit: 8, surface: "upcoming" }),
    queryKey: ["series-av", "home-discovery", apiLocale, "upcoming"],
    retry: false
  });
  const recommended = useQuery({
    queryFn: () => client.popularSeries({ locale: apiLocale, limit: 8, surface: "avi" }),
    queryKey: ["series-av", "home-discovery", apiLocale, "avi"],
    retry: false
  });

  return (
    <section className="grid gap-6">
      <div className="grid gap-6 lg:grid-cols-[1fr_22rem]">
        <Card className="series-paper gap-0 rounded-lg border-[#d7c494] p-6 py-6 shadow-lg shadow-[#172f5c]/8 sm:p-8 sm:py-8">
          <div className="flex flex-col gap-6 lg:flex-row lg:items-start lg:justify-between">
            <div>
              <h1 className="max-w-2xl text-4xl font-semibold leading-tight text-[#112a55]">{current && !shouldShowCurrentSkeleton ? labels.continueWatching : text.home.title}</h1>
              <p className="mt-4 max-w-2xl text-base leading-7 text-[#334766]">{current && currentTitle && !shouldShowCurrentSkeleton ? labels.ready(currentTitle, cursorLabel(next ?? { episodeNumber: 1, seasonNumber: 1 })) : text.home.body}</p>
            </div>
            <Button asChild className="rounded-full bg-[#112a55] text-white hover:bg-[#19396f]">
              <Link to={localizedSeriesPath(current ? `/series/${encodeURIComponent(current.seriesId)}` : "/search", locale)}>
                {current ? labels.openDetail : text.home.cta}
                <ArrowRight className="size-4" aria-hidden="true" />
              </Link>
            </Button>
          </div>

          {shouldShowCurrentSkeleton ? (
            <HomeCurrentSkeleton />
          ) : current ? (
            <div className="mt-8 flex flex-col gap-5 rounded-lg border border-[#d7c494] bg-[#fff8df]/78 p-4 sm:flex-row">
              <SeriesArtwork entry={current} size="md" />
              <div className="flex-1">
                <h2 className="text-2xl font-semibold text-[#112a55]">{currentTitle ?? labels.loadingTitle}</h2>
                <p className="mt-2 text-sm text-[#53617a]">
                  {progressLabel(current, libraryLabels.notStarted, libraryLabels.noEpisodeSet)} · {libraryLabels.next} {cursorLabel(next ?? { episodeNumber: 1, seasonNumber: 1 })}
                </p>
                <div className="mt-4 flex flex-wrap gap-2">
                  <Button className="rounded-full bg-[#112a55] text-white hover:bg-[#19396f]" onClick={() => library.markNextEpisodeWatched(current.entryId)}>
                    <StepForward className="size-4" /> {labels.markNext}
                  </Button>
                  <Button asChild variant="outline" className="rounded-full border-[#c8ad72] bg-white/60">
                    <Link to={localizedSeriesPath("/library", locale)}>{text.nav.library}</Link>
                  </Button>
                </div>
              </div>
            </div>
          ) : <AppSurfaceState icon={<Search className="size-10" aria-hidden="true" />} title={text.library.emptyTitle} description={text.library.emptyBody} />}

          <div className="mt-8 grid gap-3 sm:grid-cols-3">
            <AppMetricTile icon={<BookOpenCheck className="size-4" />} label={labels.active} value={String(library.snapshot.activeEntries.length)} />
            <AppMetricTile icon={<StepForward className="size-4" />} label={libraryLabels.status.watching} value={String(library.snapshot.watchingEntries.length)} />
            <AppMetricTile icon={<Sparkles className="size-4" />} label={labels.sync} value={<CompactSyncStatus labels={labels.syncStatus} syncState={library.syncState} />} />
          </div>
        </Card>
        <AppAssistantBriefCard
          title={text.home.aviTitle}
          body={current && currentTitle && !shouldShowCurrentSkeleton ? labels.avi(currentTitle) : text.home.aviBody[0]}
          action={
            <Button asChild className="rounded-full bg-white text-[#10284f] hover:bg-white/90">
              <Link to={localizedSeriesPath("/avi", locale)}>{text.nav.avi}</Link>
            </Button>
          }
        />
      </div>

      <HomeDiscoverySection isLoading={popular.isLoading} labels={labels} locale={locale} results={popular.data?.results ?? []} title={labels.popular} />
      <HomeDiscoverySection isLoading={upcoming.isLoading} labels={labels} locale={locale} results={upcoming.data?.results ?? []} title={labels.comingSoon} />
      <HomeDiscoverySection isLoading={recommended.isLoading} labels={labels} locale={locale} results={recommended.data?.results ?? []} title={labels.recommended} />
    </section>
  );
}

const homeLabels = {
  ca: {
    active: "Actives",
    avi: (title: string) => `Avi pot mantenir ${title} a mà i ajustar el progrés quan calgui.`,
    continueWatching: "Continua mirant",
    comingSoon: "Properament",
    detail: "Detall",
    follow: "Seguir",
    following: "Seguint",
    limitReached: "Límit assolit",
    loadingTitle: "Carregant sèrie",
    markNext: "Marcar següent",
    noArtwork: "Sense imatge",
    openDetail: "Obrir detall",
    popular: "Popular",
    ready: (title: string, cursor: string) => `${title} està preparada per ${cursor}.`,
    recommended: "Més per seguir",
    sync: "Sync",
    syncStatus: { disabled: "Local", failed: "Error", idle: "Al dia", syncing: "Sincronitzant" }
  },
  de: {
    active: "Aktiv",
    avi: (title: string) => `Avi kann ${title} griffbereit halten und den Fortschritt bei Bedarf anpassen.`,
    continueWatching: "Weiterschauen",
    comingSoon: "Demnächst",
    detail: "Detail",
    follow: "Folgen",
    following: "Gespeichert",
    limitReached: "Limit erreicht",
    loadingTitle: "Serie wird geladen",
    markNext: "Nächste markieren",
    noArtwork: "Kein Bild",
    openDetail: "Detail öffnen",
    popular: "Beliebt",
    ready: (title: string, cursor: string) => `${title} ist bereit für ${cursor}.`,
    recommended: "Mehr zum Verfolgen",
    sync: "Sync",
    syncStatus: { disabled: "Lokal", failed: "Fehler", idle: "Aktuell", syncing: "Sync läuft" }
  },
  en: {
    active: "Active",
    avi: (title: string) => `Avi can keep ${title} close and adjust progress when needed.`,
    continueWatching: "Continue watching",
    comingSoon: "Coming soon",
    detail: "Detail",
    follow: "Follow",
    following: "Following",
    limitReached: "Limit reached",
    loadingTitle: "Loading series",
    markNext: "Mark next",
    noArtwork: "No artwork",
    openDetail: "Open detail",
    popular: "Popular",
    ready: (title: string, cursor: string) => `${title} is ready for ${cursor}.`,
    recommended: "More to track",
    sync: "Sync",
    syncStatus: { disabled: "Local", failed: "Error", idle: "Current", syncing: "Syncing" }
  },
  es: {
    active: "Activas",
    avi: (title: string) => `Avi puede mantener ${title} a mano y ajustar el progreso cuando haga falta.`,
    continueWatching: "Sigue viendo",
    comingSoon: "Próximamente",
    detail: "Detalle",
    follow: "Seguir",
    following: "Siguiendo",
    limitReached: "Límite alcanzado",
    loadingTitle: "Cargando serie",
    markNext: "Marcar siguiente",
    noArtwork: "Sin imagen",
    openDetail: "Abrir detalle",
    popular: "Populares",
    ready: (title: string, cursor: string) => `${title} está lista para ${cursor}.`,
    recommended: "Más para seguir",
    sync: "Sync",
    syncStatus: { disabled: "Local", failed: "Error", idle: "Al día", syncing: "Sincronizando" }
  },
  fr: {
    active: "Actives",
    avi: (title: string) => `Avi peut garder ${title} à portée et ajuster la progression si besoin.`,
    continueWatching: "Continuer",
    comingSoon: "Prochainement",
    detail: "Détail",
    follow: "Suivre",
    following: "Suivi",
    limitReached: "Limite atteinte",
    loadingTitle: "Chargement de la série",
    markNext: "Marquer la suite",
    noArtwork: "Sans image",
    openDetail: "Ouvrir le détail",
    popular: "Populaire",
    ready: (title: string, cursor: string) => `${title} est prête pour ${cursor}.`,
    recommended: "Plus à suivre",
    sync: "Sync",
    syncStatus: { disabled: "Local", failed: "Erreur", idle: "À jour", syncing: "Sync" }
  }
} as const;

function HomeCurrentSkeleton() {
  return (
    <div className="mt-8 flex flex-col gap-5 rounded-lg border border-[#d7c494] bg-[#fff8df]/78 p-4 sm:flex-row" aria-hidden="true">
      <div className="h-28 w-20 shrink-0 animate-pulse rounded-lg border border-[#d7c494] bg-[#ead6a5]" />
      <div className="flex-1">
        <div className="h-8 w-56 max-w-full animate-pulse rounded-full bg-[#ead6a5]" />
        <div className="mt-3 h-4 w-72 max-w-full animate-pulse rounded-full bg-[#ead6a5]/70" />
        <div className="mt-4 flex flex-wrap gap-2">
          <div className="h-10 w-36 animate-pulse rounded-full bg-[#112a55]/25" />
          <div className="h-10 w-28 animate-pulse rounded-full bg-white/45" />
        </div>
      </div>
    </div>
  );
}

function HomeDiscoverySection({
  isLoading,
  labels,
  locale,
  results,
  title
}: {
  isLoading: boolean;
  labels: (typeof homeLabels)[keyof typeof homeLabels];
  locale: ReturnType<typeof useAppsAvLocale>;
  results: SeriesSearchResult[];
  title: string;
}) {
  if (isLoading) {
    return (
      <section>
        <h2 className="mb-3 text-sm font-bold uppercase text-[#53617a]">{title}</h2>
        <AppGridSkeleton className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4" itemCount={4} />
      </section>
    );
  }

  if (results.length === 0) {
    return null;
  }

  return (
    <section>
      <h2 className="mb-3 text-sm font-bold uppercase text-[#53617a]">{title}</h2>
      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        {results.slice(0, 8).map((result) => (
          <HomeDiscoveryCard key={seriesIdFor(result)} labels={labels} locale={locale} result={result} />
        ))}
      </div>
    </section>
  );
}

function HomeDiscoveryCard({ labels, locale, result }: { labels: (typeof homeLabels)[keyof typeof homeLabels]; locale: ReturnType<typeof useAppsAvLocale>; result: SeriesSearchResult }) {
  const library = useSeriesLibrary();
  const text = useSeriesText();
  const seriesId = seriesIdFor(result);
  const existing = library.findEntryBySeriesId(seriesId);
  const artwork = artworkFor(result);

  return (
    <Card className="gap-0 overflow-hidden rounded-lg border-[#d7c494] bg-[#fff8df] py-0 shadow-sm shadow-[#172f5c]/8">
      <Link
        to={localizedSeriesPath(`/series/${encodeURIComponent(seriesId)}`, locale)}
        className="block aspect-[3/4] bg-[#ead6a5]"
        onClick={() => rememberSeriesCatalogItem(result)}
      >
        {artwork ? <img alt="" className="h-full w-full object-cover" loading="lazy" src={artwork} /> : <div className="flex h-full items-center justify-center text-sm font-medium text-[#748098]">{labels.noArtwork}</div>}
      </Link>
      <div className="flex min-h-48 flex-col gap-3 p-4">
        <div>
          <h3 className="line-clamp-2 text-base font-semibold text-[#112a55]">{result.title}</h3>
          <p className="mt-2 flex items-center gap-2 text-xs font-medium uppercase text-[#5a8f2f]">
            <Calendar className="size-3.5" aria-hidden="true" />
            {result.firstAirDate ?? result.startYear ?? text.search.dateUnknown}
          </p>
        </div>
        <p className="line-clamp-3 text-sm leading-6 text-[#53617a]">{result.overview ?? result.summary ?? text.search.noOverview}</p>
        <div className="mt-auto flex flex-wrap gap-2">
          <Button
            size="sm"
            className="rounded-full bg-[#112a55] text-white hover:bg-[#19396f]"
            disabled={Boolean(existing) || !library.canAddSeries}
            onClick={() =>
              library.addCatalogSeries({
                displayArtworkRef: artwork,
                fallbackVisualSeed: result.title,
                seriesId,
                title: result.title
              })
            }
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
      </div>
    </Card>
  );
}

function seriesIdFor(result: SeriesSearchResult) {
  return result.seriesId ?? result.id;
}

function artworkFor(result: SeriesSearchResult) {
  return result.posterUrl ?? result.displayArtwork?.url ?? result.displayArtwork?.assetName ?? null;
}
