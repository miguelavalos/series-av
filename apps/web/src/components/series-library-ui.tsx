import { Link } from "@tanstack/react-router";
import { Archive, ArrowLeft, Check, MoreHorizontal, Pin, PinOff, RotateCcw, StepBack, StepForward, Trash2 } from "lucide-react";
import type { ReactNode } from "react";
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

const uiText = {
  ca: {
    archive: "Arxiva",
    clear: "Neteja",
    episode: "Episodi",
    more: "Més",
    next: "Següent",
    noEpisodeSet: "Cap episodi fixat",
    notStarted: "No iniciada",
    pin: "Fixa",
    pinned: "Fixada",
    previous: "Anterior",
    restore: "Restaura",
    save: "Desa",
    season: "Temporada",
    status: { wantToWatch: "Vull mirar", watched: "Vista", watching: "Veient" },
    trash: "Elimina",
    unpin: "Desfixa"
  },
  de: {
    archive: "Archivieren",
    clear: "Leeren",
    episode: "Folge",
    more: "Mehr",
    next: "Weiter",
    noEpisodeSet: "Keine Folge gesetzt",
    notStarted: "Nicht begonnen",
    pin: "Anheften",
    pinned: "Angeheftet",
    previous: "Zurück",
    restore: "Wiederherstellen",
    save: "Speichern",
    season: "Staffel",
    status: { wantToWatch: "Ansehen", watched: "Gesehen", watching: "Aktuell" },
    trash: "Löschen",
    unpin: "Lösen"
  },
  en: {
    archive: "Archive",
    clear: "Clear",
    episode: "Episode",
    more: "More",
    next: "Next",
    noEpisodeSet: "No episode set",
    notStarted: "Not started",
    pin: "Pin",
    pinned: "Pinned",
    previous: "Previous",
    restore: "Restore",
    save: "Save",
    season: "Season",
    status: statusLabels,
    trash: "Delete",
    unpin: "Unpin"
  },
  es: {
    archive: "Archivar",
    clear: "Borrar",
    episode: "Episodio",
    more: "Más",
    next: "Siguiente",
    noEpisodeSet: "Sin episodio",
    notStarted: "No iniciada",
    pin: "Fijar",
    pinned: "Fijada",
    previous: "Anterior",
    restore: "Restaurar",
    save: "Guardar",
    season: "Temporada",
    status: { wantToWatch: "Quiero ver", watched: "Vista", watching: "Viendo" },
    trash: "Eliminar",
    unpin: "Quitar"
  },
  fr: {
    archive: "Archiver",
    clear: "Effacer",
    episode: "Épisode",
    more: "Plus",
    next: "Suivant",
    noEpisodeSet: "Aucun épisode",
    notStarted: "Pas commencée",
    pin: "Épingler",
    pinned: "Épinglée",
    previous: "Précédent",
    restore: "Restaurer",
    save: "Enregistrer",
    season: "Saison",
    status: { wantToWatch: "À regarder", watched: "Vue", watching: "En cours" },
    trash: "Supprimer",
    unpin: "Désépingler"
  }
} satisfies Record<AppsAvLocale, { archive: string; clear: string; episode: string; more: string; next: string; noEpisodeSet: string; notStarted: string; pin: string; pinned: string; previous: string; restore: string; save: string; season: string; status: Record<SeriesLibraryEntryStatus, string>; trash: string; unpin: string }>;

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
  const labels = uiText[locale];

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
                {labels.status[entry.status]} · {progressLabel(entry, labels.notStarted, labels.noEpisodeSet)} · {labels.next} {cursorLabel(next)}
              </p>
            </div>
            {entry.isPinnedHomeSeries ? <Pin className="size-4 text-[#5a8f2f]" aria-label={labels.pinned} /> : null}
          </div>
          <div className="mt-4 flex flex-wrap items-center gap-2">
            <Button size="sm" className="rounded-full bg-[#112a55] text-white hover:bg-[#19396f]" onClick={() => library.markNextEpisodeWatched(entry.entryId)}>
              <StepForward className="size-4" /> {labels.next}
            </Button>
            <details className="group relative">
              <summary className="flex h-9 cursor-pointer list-none items-center gap-2 rounded-full border border-[#c8ad72] bg-white/70 px-3 text-sm font-medium text-[#112a55] hover:bg-white [&::-webkit-details-marker]:hidden">
                <MoreHorizontal className="size-4" /> {labels.more}
              </summary>
              <div className="absolute right-0 z-20 mt-2 grid w-56 gap-1 rounded-lg border border-[#d7c494] bg-[#fff8df] p-2 shadow-xl shadow-[#172f5c]/15">
                {entry.lastWatchedEpisodeCursor ? (
                  <MenuButton onClick={() => library.markPreviousEpisodeWatched(entry.entryId)}>
                    <StepBack className="size-4" /> {labels.previous}
                  </MenuButton>
                ) : null}
                {(["wantToWatch", "watching", "watched"] as SeriesLibraryEntryStatus[]).map((status) => (
                  <MenuButton key={status} onClick={() => library.setStatus(entry.entryId, status)}>
                    <Check className="size-4" /> {labels.status[status]}
                  </MenuButton>
                ))}
                <MenuButton onClick={() => library.setPinned(entry.entryId, entry.isPinnedHomeSeries !== true)}>
                  {entry.isPinnedHomeSeries ? <PinOff className="size-4" /> : <Pin className="size-4" />} {entry.isPinnedHomeSeries ? labels.unpin : labels.pin}
                </MenuButton>
                {entry.archivedAt ? (
                  <MenuButton onClick={() => library.restore(entry.entryId)}>
                    <RotateCcw className="size-4" /> {labels.restore}
                  </MenuButton>
                ) : showArchive ? (
                  <MenuButton onClick={() => library.archive(entry.entryId)}>
                    <Archive className="size-4" /> {labels.archive}
                  </MenuButton>
                ) : null}
                <MenuButton danger onClick={() => library.deleteEntry(entry.entryId)}>
                  <Trash2 className="size-4" /> {labels.trash}
                </MenuButton>
              </div>
            </details>
          </div>
        </div>
      </div>
    </Card>
  );
}

export function StatusButtons({ entry, locale = "en" }: { entry: SeriesLibraryEntry; locale?: AppsAvLocale }) {
  const library = useSeriesLibrary();
  const statuses: SeriesLibraryEntryStatus[] = ["wantToWatch", "watching", "watched"];
  const labels = uiText[locale];
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
          <Check className="size-4" /> {labels.status[status]}
        </Button>
      ))}
    </>
  );
}

function MenuButton({ children, danger = false, onClick }: { children: ReactNode; danger?: boolean; onClick: () => void }) {
  return (
    <button
      type="button"
      className={`flex w-full items-center gap-2 rounded-md px-3 py-2 text-left text-sm font-medium hover:bg-white/70 ${danger ? "text-red-700" : "text-[#112a55]"}`}
      onClick={(event) => {
        event.currentTarget.closest("details")?.removeAttribute("open");
        onClick();
      }}
    >
      {children}
    </button>
  );
}

export function ProgressEditor({ entry, locale = "en" }: { entry: SeriesLibraryEntry; locale?: AppsAvLocale }) {
  const library = useSeriesLibrary();
  const current = entry.lastWatchedEpisodeCursor ?? { episodeNumber: 1, seasonNumber: 1 };
  const labels = uiText[locale];

  return (
    <div className="grid gap-3 rounded-lg border border-[#d7c494] bg-[#fff8df]/72 p-4 sm:grid-cols-[1fr_1fr_auto]">
      <label className="text-sm font-semibold text-[#112a55]">
        {labels.season}
        <input className="mt-1 h-10 w-full rounded-md border border-[#c8ad72] bg-white px-3" min={1} type="number" defaultValue={current.seasonNumber} id={`season-${entry.entryId}`} />
      </label>
      <label className="text-sm font-semibold text-[#112a55]">
        {labels.episode}
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
          {labels.save}
        </Button>
        <Button variant="outline" className="rounded-full border-[#c8ad72] bg-white/60" onClick={() => library.clearProgress(entry.entryId)}>
          <ArrowLeft className="size-4" /> {labels.clear}
        </Button>
      </div>
    </div>
  );
}

export function seriesLibraryUiText(locale: AppsAvLocale) {
  return uiText[locale];
}
