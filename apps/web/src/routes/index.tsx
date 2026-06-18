import { SignedIn, SignedOut } from "@avalsys/account-av-web";
import { useAppsAvLocale } from "@avalsys/apps-av-web";
import { CompactSyncStatus } from "@avalsys/apps-av-web/src/components/compact-sync-status";
import { AppSurfaceState } from "@avalsys/apps-av-web/src/components/protected-app-gate";
import { Link, createFileRoute } from "@tanstack/react-router";
import { ArrowRight, BookOpenCheck, Search, Sparkles, StepForward } from "lucide-react";
import { ProtectedRoute } from "@/components/protected-route";
import { SeriesAppShell } from "@/components/series-app-shell";
import { SeriesArtwork, seriesLibraryUiText } from "@/components/series-library-ui";
import { SeriesLoginPage } from "@/components/series-login-page";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { useSeriesLibrary } from "@/lib/series-library-provider";
import { cursorLabel, nextEpisodeCursor, progressLabel } from "@/lib/series-library";
import { localizedSeriesPath, useSeriesText } from "@/lib/series-i18n";

export const Route = createFileRoute("/")({
  component: IndexRoute
});

function IndexRoute() {
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
  const text = useSeriesText();
  const library = useSeriesLibrary();
  const current = library.snapshot.homeEntries[0] ?? null;
  const next = current ? nextEpisodeCursor(current.lastWatchedEpisodeCursor) : null;
  const labels = homeLabels[locale];
  const libraryLabels = seriesLibraryUiText(locale);

  return (
    <section className="grid gap-6 lg:grid-cols-[1fr_22rem]">
      <Card className="series-paper gap-0 rounded-lg border-[#d7c494] p-6 py-6 shadow-lg shadow-[#172f5c]/8 sm:p-8 sm:py-8">
        <div className="flex flex-col gap-6 lg:flex-row lg:items-start lg:justify-between">
          <div>
            <h1 className="max-w-2xl text-4xl font-semibold leading-tight text-[#112a55]">{current ? labels.continueWatching : text.home.title}</h1>
            <p className="mt-4 max-w-2xl text-base leading-7 text-[#334766]">{current ? labels.ready(current.title, cursorLabel(next ?? { episodeNumber: 1, seasonNumber: 1 })) : text.home.body}</p>
          </div>
          <Button asChild className="rounded-full bg-[#112a55] text-white hover:bg-[#19396f]">
            <Link to={localizedSeriesPath(current ? `/series/${encodeURIComponent(current.seriesId)}` : "/search", locale)}>
              {current ? labels.openDetail : text.home.cta}
              <ArrowRight className="size-4" aria-hidden="true" />
            </Link>
          </Button>
        </div>

        {current ? (
          <div className="mt-8 flex flex-col gap-5 rounded-lg border border-[#d7c494] bg-[#fff8df]/78 p-4 sm:flex-row">
            <SeriesArtwork entry={current} size="md" />
            <div className="flex-1">
              <h2 className="text-2xl font-semibold text-[#112a55]">{current.title}</h2>
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
          <Metric icon={<BookOpenCheck className="size-4" />} label={labels.active} value={String(library.snapshot.activeEntries.length)} />
          <Metric icon={<StepForward className="size-4" />} label={libraryLabels.status.watching} value={String(library.snapshot.watchingEntries.length)} />
          <Metric icon={<Sparkles className="size-4" />} label={labels.sync} value={<CompactSyncStatus labels={labels.syncStatus} syncState={library.syncState} />} />
        </div>
      </Card>
      <Card className="gap-0 rounded-lg border-[#d7c494] bg-[#10284f] p-5 py-5 text-white shadow-lg shadow-[#172f5c]/14">
        <div className="flex items-center gap-2 text-sm font-semibold text-[#b6dd89]">
          <Sparkles className="size-4" aria-hidden="true" />
          {text.home.aviTitle}
        </div>
        <p className="mt-4 text-sm leading-6 text-white/74">{current ? labels.avi(current.title) : text.home.aviBody[0]}</p>
        <Button asChild className="mt-5 rounded-full bg-white text-[#10284f] hover:bg-white/90">
          <Link to={localizedSeriesPath("/avi", locale)}>{text.nav.avi}</Link>
        </Button>
      </Card>
    </section>
  );
}

const homeLabels = {
  ca: {
    active: "Actives",
    avi: (title: string) => `Avi pot mantenir ${title} a mà i ajustar el progrés quan calgui.`,
    continueWatching: "Continua mirant",
    markNext: "Marcar següent",
    openDetail: "Obrir detall",
    ready: (title: string, cursor: string) => `${title} està preparada per ${cursor}.`,
    sync: "Sync",
    syncStatus: { disabled: "Local", failed: "Error", idle: "Al dia", syncing: "Sincronitzant" }
  },
  de: {
    active: "Aktiv",
    avi: (title: string) => `Avi kann ${title} griffbereit halten und den Fortschritt bei Bedarf anpassen.`,
    continueWatching: "Weiterschauen",
    markNext: "Nächste markieren",
    openDetail: "Detail öffnen",
    ready: (title: string, cursor: string) => `${title} ist bereit für ${cursor}.`,
    sync: "Sync",
    syncStatus: { disabled: "Lokal", failed: "Fehler", idle: "Aktuell", syncing: "Sync läuft" }
  },
  en: {
    active: "Active",
    avi: (title: string) => `Avi can keep ${title} close and adjust progress when needed.`,
    continueWatching: "Continue watching",
    markNext: "Mark next",
    openDetail: "Open detail",
    ready: (title: string, cursor: string) => `${title} is ready for ${cursor}.`,
    sync: "Sync",
    syncStatus: { disabled: "Local", failed: "Error", idle: "Current", syncing: "Syncing" }
  },
  es: {
    active: "Activas",
    avi: (title: string) => `Avi puede mantener ${title} a mano y ajustar el progreso cuando haga falta.`,
    continueWatching: "Sigue viendo",
    markNext: "Marcar siguiente",
    openDetail: "Abrir detalle",
    ready: (title: string, cursor: string) => `${title} está lista para ${cursor}.`,
    sync: "Sync",
    syncStatus: { disabled: "Local", failed: "Error", idle: "Al día", syncing: "Sincronizando" }
  },
  fr: {
    active: "Actives",
    avi: (title: string) => `Avi peut garder ${title} à portée et ajuster la progression si besoin.`,
    continueWatching: "Continuer",
    markNext: "Marquer la suite",
    openDetail: "Ouvrir le détail",
    ready: (title: string, cursor: string) => `${title} est prête pour ${cursor}.`,
    sync: "Sync",
    syncStatus: { disabled: "Local", failed: "Erreur", idle: "À jour", syncing: "Sync" }
  }
} as const;

function Metric({ icon, label, value }: { icon: React.ReactNode; label: string; value: React.ReactNode }) {
  return (
    <div className="rounded-lg border border-[#d7c494] bg-[#fff8df]/72 p-4 text-[#112a55]">
      <div className="flex items-center gap-2 text-sm font-semibold">
        <span className="text-[#5a8f2f]">{icon}</span>
        {label}
      </div>
      <div className="mt-2 text-lg font-semibold text-[#112a55]">{value}</div>
    </div>
  );
}
