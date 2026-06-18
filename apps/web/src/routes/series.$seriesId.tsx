import { ErrorState, useAppsAvLocale } from "@avalsys/apps-av-web";
import { useQuery } from "@tanstack/react-query";
import { Link, createFileRoute } from "@tanstack/react-router";
import { ArrowLeft, Plus, StepForward } from "lucide-react";
import { useMemo } from "react";
import { ProtectedRoute } from "@/components/protected-route";
import { SeriesAppShell } from "@/components/series-app-shell";
import { ProgressEditor, SeriesArtwork, StatusButtons } from "@/components/series-library-ui";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { SeriesApiClient } from "@/lib/series-api-client";
import { getSeriesApiBaseUrl } from "@/lib/series-config";
import { useSeriesLibrary } from "@/lib/series-library-provider";
import { cursorLabel, nextEpisodeCursor, progressLabel } from "@/lib/series-library";
import { localizedSeriesPath, useSeriesApiLocale, useSeriesText } from "@/lib/series-i18n";

export const Route = createFileRoute("/series/$seriesId")({
  component: SeriesDetailRoute
});

function SeriesDetailRoute() {
  const { seriesId } = Route.useParams();
  const locale = useAppsAvLocale();
  const apiLocale = useSeriesApiLocale();
  const text = useSeriesText();
  const library = useSeriesLibrary();
  const entry = library.findEntryBySeriesId(seriesId);
  const client = useMemo(() => new SeriesApiClient(getSeriesApiBaseUrl()), []);
  const search = useQuery({
    enabled: !entry,
    queryFn: () => client.searchSeries({ query: decodeURIComponent(seriesId), locale: apiLocale, limit: 1 }),
    queryKey: ["series-av", "detail-search", apiLocale, seriesId]
  });
  const catalog = search.data?.results[0] ?? null;
  const episodes = useQuery({
    queryFn: () =>
      client.episodes({
        lastWatchedEpisode: entry?.lastWatchedEpisodeCursor?.episodeNumber,
        lastWatchedSeason: entry?.lastWatchedEpisodeCursor?.seasonNumber,
        seriesId
      }),
    queryKey: ["series-av", "episodes", seriesId, entry?.lastWatchedEpisodeCursor?.seasonNumber, entry?.lastWatchedEpisodeCursor?.episodeNumber]
  });
  const title = entry?.title ?? catalog?.title ?? decodeURIComponent(seriesId);
  const artwork = entry ?? {
    displayArtworkRef: catalog?.posterUrl ?? catalog?.displayArtwork?.url ?? null,
    fallbackVisualSeed: title,
    title
  };

  return (
    <ProtectedRoute>
      <SeriesAppShell>
        <section className="grid gap-6 lg:grid-cols-[1fr_22rem]">
          <Card className="series-paper gap-0 rounded-lg border-[#d7c494] p-6 py-6 shadow-lg shadow-[#172f5c]/8 sm:p-8 sm:py-8">
            <Button asChild variant="ghost" className="mb-5 w-fit rounded-full">
              <Link to={localizedSeriesPath("/library", locale)}>
                <ArrowLeft className="size-4" /> Library
              </Link>
            </Button>
            <div className="flex flex-col gap-5 sm:flex-row">
              <SeriesArtwork entry={artwork} size="lg" />
              <div className="min-w-0 flex-1">
                <h1 className="text-4xl font-semibold leading-tight text-[#112a55]">{title}</h1>
                <p className="mt-3 text-sm font-semibold text-[#5a8f2f]">
                  {catalog?.startYear ?? catalog?.firstAirDate ?? text.search.dateUnknown}
                  {catalog?.genres?.length ? ` · ${catalog.genres.slice(0, 2).join(" · ")}` : ""}
                </p>
                <p className="mt-4 max-w-2xl text-base leading-7 text-[#334766]">{catalog?.summary ?? catalog?.overview ?? text.search.noOverview}</p>
                {entry ? (
                  <div className="mt-5 grid gap-4">
                    <p className="text-sm font-semibold text-[#53617a]">
                      {entry.status} · {progressLabel(entry, "Not started", "No episode set")} · Next {cursorLabel(nextEpisodeCursor(entry.lastWatchedEpisodeCursor))}
                    </p>
                    <div className="flex flex-wrap gap-2">
                      <Button className="rounded-full bg-[#112a55] text-white hover:bg-[#19396f]" onClick={() => library.markNextEpisodeWatched(entry.entryId)}>
                        <StepForward className="size-4" /> Mark next
                      </Button>
                      <StatusButtons entry={entry} />
                    </div>
                    <ProgressEditor entry={entry} />
                  </div>
                ) : (
                  <Button
                    className="mt-5 rounded-full bg-[#112a55] text-white hover:bg-[#19396f]"
                    disabled={!library.canAddSeries}
                    onClick={() =>
                      library.addCatalogSeries({
                        displayArtworkRef: catalog?.posterUrl ?? catalog?.displayArtwork?.url,
                        fallbackVisualSeed: title,
                        seriesId,
                        title
                      })
                    }
                  >
                    <Plus className="size-4" /> {library.canAddSeries ? "Follow" : "Limit reached"}
                  </Button>
                )}
              </div>
            </div>
          </Card>

          <Card className="gap-3 rounded-lg border-[#d7c494] bg-[#fff8df]/88 p-5 py-5 text-[#112a55] shadow-sm shadow-[#172f5c]/6">
            <h2 className="text-lg font-semibold">Episode guide</h2>
            {episodes.isLoading ? <div className="h-40 animate-pulse rounded-lg bg-[#ead6a5]" /> : null}
            {episodes.isError ? <ErrorState className="border-[#d7c494] bg-white/70" description={episodes.error.message} title="Episodes unavailable" /> : null}
            {episodes.data?.items.length === 0 ? <p className="text-sm text-[#53617a]">No compact guide is available yet.</p> : null}
            <div className="grid gap-2">
              {episodes.data?.items.slice(0, 12).map((episode) => (
                <div key={`${episode.seasonNumber}-${episode.episodeNumber}`} className="rounded-lg border border-[#d7c494] bg-white/60 p-3">
                  <p className="text-sm font-bold text-[#112a55]">
                    {cursorLabel({ episodeNumber: episode.episodeNumber, seasonNumber: episode.seasonNumber })} · {episode.title ?? "Episode"}
                  </p>
                  <p className="mt-1 text-xs text-[#53617a]">{episode.airDate ?? episode.relativeState}</p>
                </div>
              ))}
            </div>
          </Card>
        </section>
      </SeriesAppShell>
    </ProtectedRoute>
  );
}
