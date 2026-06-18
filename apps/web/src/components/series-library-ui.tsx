import { Link } from "@tanstack/react-router";
import { Archive, ArrowLeft, Check, Pin, PinOff, RotateCcw, StepBack, StepForward, Trash2 } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { useSeriesLibrary } from "@/lib/series-library-provider";
import { cursorLabel, nextEpisodeCursor, progressLabel, type SeriesLibraryEntry, type SeriesLibraryEntryStatus } from "@/lib/series-library";
import { localizedSeriesPath } from "@/lib/series-i18n";
import type { AppsAvLocale } from "@avalsys/apps-av-web";

export const statusLabels: Record<SeriesLibraryEntryStatus, string> = {
  wantToWatch: "Want",
  watched: "Watched",
  watching: "Watching"
};

export function SeriesArtwork({ entry, size = "md" }: { entry: Pick<SeriesLibraryEntry, "displayArtworkRef" | "fallbackVisualSeed" | "title">; size?: "sm" | "md" | "lg" }) {
  const classes = {
    lg: "h-48 w-34",
    md: "h-28 w-20",
    sm: "h-20 w-14"
  }[size];

  return entry.displayArtworkRef ? (
    <img alt="" className={`${classes} shrink-0 rounded-lg border border-[#d7c494] object-cover`} src={entry.displayArtworkRef} />
  ) : (
    <div className={`${classes} flex shrink-0 items-center justify-center rounded-lg border border-[#d7c494] bg-[#ead6a5] px-2 text-center text-xs font-semibold text-[#112a55]`}>
      {(entry.fallbackVisualSeed ?? entry.title).slice(0, 18)}
    </div>
  );
}

export function SeriesEntryRow({ entry, locale, showArchive = true }: { entry: SeriesLibraryEntry; locale: AppsAvLocale; showArchive?: boolean }) {
  const library = useSeriesLibrary();
  const next = nextEpisodeCursor(entry.lastWatchedEpisodeCursor);

  return (
    <Card className="gap-0 rounded-lg border-[#d7c494] bg-[#fff8df]/88 p-4 py-4 shadow-sm shadow-[#172f5c]/6">
      <div className="flex gap-4">
        <SeriesArtwork entry={entry} size="sm" />
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-start justify-between gap-3">
            <div className="min-w-0">
              <Link className="line-clamp-2 text-base font-semibold text-[#112a55] hover:underline" to={localizedSeriesPath(`/series/${encodeURIComponent(entry.seriesId)}`, locale)}>
                {entry.title}
              </Link>
              <p className="mt-1 text-sm text-[#53617a]">
                {statusLabels[entry.status]} · {progressLabel(entry, "Not started", "No episode set")} · Next {cursorLabel(next)}
              </p>
            </div>
            {entry.isPinnedHomeSeries ? <Pin className="size-4 text-[#5a8f2f]" aria-label="Pinned" /> : null}
          </div>
          <div className="mt-4 flex flex-wrap gap-2">
            <Button size="sm" className="rounded-full bg-[#112a55] text-white hover:bg-[#19396f]" onClick={() => library.markNextEpisodeWatched(entry.entryId)}>
              <StepForward className="size-4" /> Next
            </Button>
            {entry.lastWatchedEpisodeCursor ? (
              <Button size="sm" variant="outline" className="rounded-full border-[#c8ad72] bg-white/60" onClick={() => library.markPreviousEpisodeWatched(entry.entryId)}>
                <StepBack className="size-4" /> Previous
              </Button>
            ) : null}
            <StatusButtons entry={entry} />
            <Button size="sm" variant="outline" className="rounded-full border-[#c8ad72] bg-white/60" onClick={() => library.setPinned(entry.entryId, entry.isPinnedHomeSeries !== true)}>
              {entry.isPinnedHomeSeries ? <PinOff className="size-4" /> : <Pin className="size-4" />} {entry.isPinnedHomeSeries ? "Unpin" : "Pin"}
            </Button>
            {entry.archivedAt ? (
              <Button size="sm" variant="outline" className="rounded-full border-[#c8ad72] bg-white/60" onClick={() => library.restore(entry.entryId)}>
                <RotateCcw className="size-4" /> Restore
              </Button>
            ) : showArchive ? (
              <Button size="sm" variant="outline" className="rounded-full border-[#c8ad72] bg-white/60" onClick={() => library.archive(entry.entryId)}>
                <Archive className="size-4" /> Archive
              </Button>
            ) : null}
            <Button size="sm" variant="outline" className="rounded-full border-red-200 bg-white/60 text-red-700" onClick={() => library.deleteEntry(entry.entryId)}>
              <Trash2 className="size-4" /> Delete
            </Button>
          </div>
        </div>
      </div>
    </Card>
  );
}

export function StatusButtons({ entry }: { entry: SeriesLibraryEntry }) {
  const library = useSeriesLibrary();
  const statuses: SeriesLibraryEntryStatus[] = ["wantToWatch", "watching", "watched"];
  return (
    <>
      {statuses.map((status) => (
        <Button
          key={status}
          size="sm"
          variant={entry.status === status ? "default" : "outline"}
          className={entry.status === status ? "rounded-full bg-[#5a8f2f] text-white hover:bg-[#4c7d29]" : "rounded-full border-[#c8ad72] bg-white/60"}
          onClick={() => library.setStatus(entry.entryId, status)}
        >
          <Check className="size-4" /> {statusLabels[status]}
        </Button>
      ))}
    </>
  );
}

export function ProgressEditor({ entry }: { entry: SeriesLibraryEntry }) {
  const library = useSeriesLibrary();
  const current = entry.lastWatchedEpisodeCursor ?? { episodeNumber: 1, seasonNumber: 1 };

  return (
    <div className="grid gap-3 rounded-lg border border-[#d7c494] bg-[#fff8df]/72 p-4 sm:grid-cols-[1fr_1fr_auto]">
      <label className="text-sm font-semibold text-[#112a55]">
        Season
        <input className="mt-1 h-10 w-full rounded-md border border-[#c8ad72] bg-white px-3" min={1} type="number" defaultValue={current.seasonNumber} id={`season-${entry.entryId}`} />
      </label>
      <label className="text-sm font-semibold text-[#112a55]">
        Episode
        <input className="mt-1 h-10 w-full rounded-md border border-[#c8ad72] bg-white px-3" min={1} type="number" defaultValue={current.episodeNumber} id={`episode-${entry.entryId}`} />
      </label>
      <div className="flex items-end gap-2">
        <Button
          className="rounded-full bg-[#112a55] text-white hover:bg-[#19396f]"
          onClick={() => {
            const season = Number((document.getElementById(`season-${entry.entryId}`) as HTMLInputElement | null)?.value ?? 1);
            const episode = Number((document.getElementById(`episode-${entry.entryId}`) as HTMLInputElement | null)?.value ?? 1);
            library.markWatchedThrough(entry.entryId, { episodeNumber: episode, seasonNumber: season });
          }}
        >
          Save
        </Button>
        <Button variant="outline" className="rounded-full border-[#c8ad72] bg-white/60" onClick={() => library.clearProgress(entry.entryId)}>
          <ArrowLeft className="size-4" /> Clear
        </Button>
      </div>
    </div>
  );
}
