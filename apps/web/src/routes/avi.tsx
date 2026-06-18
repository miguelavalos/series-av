import { useAppsAvLocale } from "@avalsys/apps-av-web";
import { Link, createFileRoute } from "@tanstack/react-router";
import { BookOpenCheck, Pin, Search, Sparkles, StepBack, StepForward } from "lucide-react";
import { ProtectedRoute } from "@/components/protected-route";
import { SeriesAppShell } from "@/components/series-app-shell";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { seriesBrandAssets } from "@/lib/series-config";
import { useSeriesLibrary } from "@/lib/series-library-provider";
import { cursorLabel, nextEpisodeCursor, progressLabel } from "@/lib/series-library";
import { localizedSeriesPath, useSeriesText } from "@/lib/series-i18n";

export const Route = createFileRoute("/avi")({
  component: AviRoute
});

function AviRoute() {
  const locale = useAppsAvLocale();
  const text = useSeriesText();
  const library = useSeriesLibrary();
  const current = library.snapshot.homeEntries[0] ?? null;
  const next = current ? nextEpisodeCursor(current.lastWatchedEpisodeCursor) : null;

  return (
    <ProtectedRoute>
      <SeriesAppShell>
        <section className="grid gap-6 lg:grid-cols-[1.05fr_0.95fr]">
          <Card className="series-paper gap-0 overflow-hidden rounded-lg border-[#d7c494] p-0 text-[#112a55] shadow-lg shadow-[#172f5c]/8">
            <div className="grid min-h-[32rem] lg:grid-cols-[0.95fr_1.05fr]">
              <div className="flex flex-col justify-between gap-8 p-6 sm:p-8">
                <div>
                  <p className="flex items-center gap-2 text-sm font-semibold text-[#5a8f2f]">
                    <Sparkles className="size-4" aria-hidden="true" />
                    Avi
                  </p>
                  <h1 className="mt-3 text-4xl font-semibold leading-tight">{current ? `Focus on ${current.title}` : text.avi.title}</h1>
                  <p className="mt-4 text-base leading-7 text-[#334766]">
                    {current ? `${progressLabel(current, "Not started", "No episode set")} saved. The next useful step is ${cursorLabel(next ?? { episodeNumber: 1, seasonNumber: 1 })}.` : text.avi.body}
                  </p>
                </div>
                <div className="flex flex-wrap gap-3">
                  {current ? (
                    <>
                      <Button className="rounded-full bg-[#112a55] text-white hover:bg-[#19396f]" onClick={() => library.markNextEpisodeWatched(current.entryId)}>
                        <StepForward className="size-4" /> Mark next
                      </Button>
                      {current.lastWatchedEpisodeCursor ? (
                        <Button variant="outline" className="rounded-full border-[#c8ad72] bg-[#fff8df]/76" onClick={() => library.markPreviousEpisodeWatched(current.entryId)}>
                          <StepBack className="size-4" /> Previous
                        </Button>
                      ) : null}
                      <Button variant="outline" className="rounded-full border-[#c8ad72] bg-[#fff8df]/76" onClick={() => library.setPinned(current.entryId, current.isPinnedHomeSeries !== true)}>
                        <Pin className="size-4" /> {current.isPinnedHomeSeries ? "Unpin" : "Pin"}
                      </Button>
                    </>
                  ) : (
                    <Button asChild className="rounded-full bg-[#112a55] text-white hover:bg-[#19396f]">
                      <Link to={localizedSeriesPath("/search", locale)}>
                        <Search className="size-4" aria-hidden="true" />
                        {text.avi.searchCta}
                      </Link>
                    </Button>
                  )}
                  <Button asChild variant="outline" className="rounded-full border-[#c8ad72] bg-[#fff8df]/76">
                    <Link to={localizedSeriesPath("/library", locale)}>{text.avi.libraryCta}</Link>
                  </Button>
                </div>
              </div>
              <div className="relative min-h-80 overflow-hidden bg-[#10284f]">
                <div className="absolute inset-0 bg-[linear-gradient(160deg,#17386c_0%,#10284f_56%,#07162e_100%)]" />
                <img className="relative h-full w-full object-cover object-bottom" src={seriesBrandAssets.aviLoginPeek} alt="" />
              </div>
            </div>
          </Card>

          <div className="grid gap-4">
            <AviMetric title="Watching" value={String(library.snapshot.watchingEntries.length)} icon={<StepForward className="size-4" />} />
            <AviMetric title="Active" value={String(library.snapshot.activeEntries.length)} icon={<BookOpenCheck className="size-4" />} />
            <AviMetric title="Archived" value={String(library.snapshot.archivedEntries.length)} icon={<BookOpenCheck className="size-4" />} />
          </div>
        </section>
      </SeriesAppShell>
    </ProtectedRoute>
  );
}

function AviMetric({ icon, title, value }: { icon: React.ReactNode; title: string; value: string }) {
  return (
    <Card className="gap-2 rounded-lg border-[#d7c494] bg-[#fff8df]/88 p-5 py-5 text-[#112a55] shadow-sm shadow-[#172f5c]/6">
      <div className="flex items-center gap-2 text-sm font-semibold">
        <span className="text-[#5a8f2f]">{icon}</span>
        {title}
      </div>
      <p className="text-2xl font-semibold">{value}</p>
    </Card>
  );
}
