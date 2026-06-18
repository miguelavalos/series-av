import { SignedIn, SignedOut } from "@avalsys/account-av-web";
import { useAppsAvLocale } from "@avalsys/apps-av-web";
import { Link, createFileRoute } from "@tanstack/react-router";
import { ArrowRight, BookOpenCheck, Search, Sparkles, StepForward } from "lucide-react";
import { ProtectedRoute } from "@/components/protected-route";
import { SeriesAppShell } from "@/components/series-app-shell";
import { SeriesArtwork } from "@/components/series-library-ui";
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

  return (
    <section className="grid gap-6 lg:grid-cols-[1fr_22rem]">
      <Card className="series-paper gap-0 rounded-lg border-[#d7c494] p-6 py-6 shadow-lg shadow-[#172f5c]/8 sm:p-8 sm:py-8">
        <div className="flex flex-col gap-6 lg:flex-row lg:items-start lg:justify-between">
          <div>
            <h1 className="max-w-2xl text-4xl font-semibold leading-tight text-[#112a55]">{current ? "Continue watching" : text.home.title}</h1>
            <p className="mt-4 max-w-2xl text-base leading-7 text-[#334766]">{current ? `${current.title} is ready for ${cursorLabel(next ?? { episodeNumber: 1, seasonNumber: 1 })}.` : text.home.body}</p>
          </div>
          <Button asChild className="rounded-full bg-[#112a55] text-white hover:bg-[#19396f]">
            <Link to={localizedSeriesPath(current ? `/series/${encodeURIComponent(current.seriesId)}` : "/search", locale)}>
              {current ? "Open detail" : text.home.cta}
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
                {progressLabel(current, "Not started", "No episode set")} · Next {cursorLabel(next ?? { episodeNumber: 1, seasonNumber: 1 })}
              </p>
              <div className="mt-4 flex flex-wrap gap-2">
                <Button className="rounded-full bg-[#112a55] text-white hover:bg-[#19396f]" onClick={() => library.markNextEpisodeWatched(current.entryId)}>
                  <StepForward className="size-4" /> Mark next
                </Button>
                <Button asChild variant="outline" className="rounded-full border-[#c8ad72] bg-white/60">
                  <Link to={localizedSeriesPath("/library", locale)}>Open library</Link>
                </Button>
              </div>
            </div>
          </div>
        ) : (
          <div className="mt-8 rounded-lg border border-dashed border-[#c8ad72] bg-[#fff8df]/70 p-8 text-center">
            <Search className="mx-auto size-10 text-[#5a8f2f]" aria-hidden="true" />
            <h2 className="mt-4 text-2xl font-semibold text-[#112a55]">{text.library.emptyTitle}</h2>
            <p className="mx-auto mt-3 max-w-lg text-sm leading-6 text-[#53617a]">{text.library.emptyBody}</p>
          </div>
        )}

        <div className="mt-8 grid gap-3 sm:grid-cols-3">
          <Metric icon={<BookOpenCheck className="size-4" />} label="Active" value={String(library.snapshot.activeEntries.length)} />
          <Metric icon={<StepForward className="size-4" />} label="Watching" value={String(library.snapshot.watchingEntries.length)} />
          <Metric icon={<Sparkles className="size-4" />} label="Sync" value={library.syncState} />
        </div>
      </Card>
      <Card className="gap-0 rounded-lg border-[#d7c494] bg-[#10284f] p-5 py-5 text-white shadow-lg shadow-[#172f5c]/14">
        <div className="flex items-center gap-2 text-sm font-semibold text-[#b6dd89]">
          <Sparkles className="size-4" aria-hidden="true" />
          {text.home.aviTitle}
        </div>
        <p className="mt-4 text-sm leading-6 text-white/74">{current ? `Avi can keep ${current.title} pinned, adjust progress, or move you back one episode.` : text.home.aviBody[0]}</p>
        <Button asChild className="mt-5 rounded-full bg-white text-[#10284f] hover:bg-white/90">
          <Link to={localizedSeriesPath("/avi", locale)}>Open Avi</Link>
        </Button>
      </Card>
    </section>
  );
}

function Metric({ icon, label, value }: { icon: React.ReactNode; label: string; value: string }) {
  return (
    <div className="rounded-lg border border-[#d7c494] bg-[#fff8df]/72 p-4 text-[#112a55]">
      <div className="flex items-center gap-2 text-sm font-semibold">
        <span className="text-[#5a8f2f]">{icon}</span>
        {label}
      </div>
      <p className="mt-2 text-lg font-semibold text-[#112a55]">{value}</p>
    </div>
  );
}
