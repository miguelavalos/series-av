import { EmptyState, useAppsAvLocale } from "@avalsys/apps-av-web";
import { CompactSyncStatus } from "@avalsys/apps-av-web/src/components/compact-sync-status";
import { Link, createFileRoute } from "@tanstack/react-router";
import { Search } from "lucide-react";
import { useMemo, useState } from "react";
import { ProtectedRoute } from "@/components/protected-route";
import { SeriesAppShell } from "@/components/series-app-shell";
import { SeriesEntryRow, seriesLibraryUiText } from "@/components/series-library-ui";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { useSeriesLibrary } from "@/lib/series-library-provider";
import { normalizeSearchText, type SeriesLibraryEntry } from "@/lib/series-library";
import { localizedSeriesPath, useSeriesText } from "@/lib/series-i18n";

export const Route = createFileRoute("/library")({
  component: LibraryRoute
});

type Filter = "all" | "watching" | "wantToWatch" | "watched" | "archived";

function LibraryRoute() {
  const locale = useAppsAvLocale();
  const text = useSeriesText();
  const labels = libraryLabels[locale];
  const uiLabels = seriesLibraryUiText(locale);
  const library = useSeriesLibrary();
  const [query, setQuery] = useState("");
  const [filter, setFilter] = useState<Filter>("all");
  const normalizedQuery = normalizeSearchText(query);
  const active = useMemo(() => filterEntries(library.snapshot.activeEntries, filter, normalizedQuery), [filter, library.snapshot.activeEntries, normalizedQuery]);
  const archived = useMemo(() => filterEntries(library.snapshot.archivedEntries, filter, normalizedQuery), [filter, library.snapshot.archivedEntries, normalizedQuery]);
  const showArchived = filter === "all" || filter === "archived";
  const isInitialSyncing = library.syncState === "syncing" && !library.isInitialSyncComplete;

  return (
    <ProtectedRoute>
      <SeriesAppShell>
        <section className="flex flex-col gap-6">
          <Card className="series-paper gap-0 rounded-lg border-[#d7c494] p-6 py-6 shadow-lg shadow-[#172f5c]/8 sm:p-8 sm:py-8">
            <div className="flex flex-col gap-5 sm:flex-row sm:items-start sm:justify-between">
              <div>
                <p className="text-sm font-semibold text-[#5a8f2f]">{text.library.kicker}</p>
                <h1 className="mt-2 text-4xl font-semibold leading-tight text-[#112a55]">{text.library.title}</h1>
                <p className="mt-4 max-w-2xl text-base leading-7 text-[#334766]">{text.library.body}</p>
                <div className="mt-3 flex flex-wrap items-center gap-2 text-sm font-semibold text-[#53617a]">
                  <span>{library.limit.activeCount}/{library.limit.activeLimit} {labels.activeLower}</span>
                  <CompactSyncStatus labels={labels.syncStatus} syncState={library.syncState} />
                </div>
              </div>
              <Button asChild className="rounded-full bg-[#112a55] text-white hover:bg-[#19396f]">
                <Link to={localizedSeriesPath("/search", locale)}>
                  <Search className="size-4" aria-hidden="true" />
                  {text.library.add}
                </Link>
              </Button>
            </div>
            <div className="mt-6 grid gap-3 lg:grid-cols-[1fr_auto]">
              <input className="h-11 rounded-full border border-[#d7c494] bg-[#fff8df] px-4 text-[#112a55]" placeholder={labels.searchPlaceholder} value={query} onChange={(event) => setQuery(event.target.value)} />
              <div className="flex flex-wrap gap-2">
                {filters.map((item, index) => (
                  <button key={item} className={filter === item ? "rounded-full bg-[#112a55] px-3 py-2 text-sm font-semibold text-white" : "rounded-full border border-[#d7c494] bg-[#fff8df]/80 px-3 py-2 text-sm font-semibold text-[#334766]"} type="button" onClick={() => setFilter(item)}>
                    {text.library.filters[index] ?? item}
                  </button>
                ))}
              </div>
            </div>
          </Card>

          {isInitialSyncing ? <LibraryRowsSkeleton /> : null}

          {!isInitialSyncing && active.length === 0 && archived.length === 0 ? (
            <EmptyState className="border-[#d7c494] bg-[#fff8df]" description={text.library.emptyBody} title={text.library.emptyTitle} />
          ) : null}

          {!isInitialSyncing && active.length > 0 ? (
            <section className="grid gap-3">
              <h2 className="text-sm font-bold uppercase text-[#53617a]">{labels.active}</h2>
              {active.map((entry) => (
                <SeriesEntryRow key={entry.entryId} entry={entry} locale={locale} />
              ))}
            </section>
          ) : null}

          {!isInitialSyncing && showArchived && archived.length > 0 ? (
            <section className="grid gap-3">
              <h2 className="text-sm font-bold uppercase text-[#53617a]">{uiLabels.archive}</h2>
              {archived.map((entry) => (
                <SeriesEntryRow key={entry.entryId} entry={entry} locale={locale} showArchive={false} />
              ))}
            </section>
          ) : null}
        </section>
      </SeriesAppShell>
    </ProtectedRoute>
  );
}

const libraryLabels = {
  ca: { active: "Actives", activeLower: "actives", searchPlaceholder: "Cerca a la biblioteca", syncStatus: { disabled: "Local", failed: "Error", idle: "Al dia", syncing: "Sincronitzant" } },
  de: { active: "Aktiv", activeLower: "aktiv", searchPlaceholder: "Bibliothek durchsuchen", syncStatus: { disabled: "Lokal", failed: "Fehler", idle: "Aktuell", syncing: "Sync läuft" } },
  en: { active: "Active", activeLower: "active", searchPlaceholder: "Search your library", syncStatus: { disabled: "Local", failed: "Error", idle: "Current", syncing: "Syncing" } },
  es: { active: "Activas", activeLower: "activas", searchPlaceholder: "Buscar en tu biblioteca", syncStatus: { disabled: "Local", failed: "Error", idle: "Al día", syncing: "Sincronizando" } },
  fr: { active: "Actives", activeLower: "actives", searchPlaceholder: "Rechercher dans la bibliothèque", syncStatus: { disabled: "Local", failed: "Erreur", idle: "À jour", syncing: "Sync" } }
} as const;

const filters: Filter[] = ["all", "watching", "wantToWatch", "watched", "archived"];

function LibraryRowsSkeleton() {
  return (
    <section className="grid gap-3" aria-hidden="true">
      <div className="h-4 w-20 animate-pulse rounded-full bg-[#d8c27d]/70" />
      {Array.from({ length: 3 }).map((_, index) => (
        <div key={index} className="rounded-lg border border-[#d7c494] bg-[#fff8df]/88 p-4 shadow-sm shadow-[#172f5c]/6">
          <div className="flex gap-4">
            <div className="h-20 w-14 shrink-0 animate-pulse rounded-lg border border-[#d7c494] bg-[#ead6a5]" />
            <div className="min-w-0 flex-1">
              <div className="h-5 w-48 max-w-full animate-pulse rounded-full bg-[#ead6a5]" />
              <div className="mt-3 h-4 w-72 max-w-full animate-pulse rounded-full bg-[#ead6a5]/70" />
              <div className="mt-4 flex gap-2">
                <div className="h-9 w-24 animate-pulse rounded-full bg-[#112a55]/25" />
                <div className="h-9 w-20 animate-pulse rounded-full bg-white/45" />
              </div>
            </div>
          </div>
        </div>
      ))}
    </section>
  );
}

function filterEntries(entries: SeriesLibraryEntry[], filter: Filter, normalizedQuery: string) {
  return entries.filter((entry) => {
    if (normalizedQuery && !normalizeSearchText(entry.title).includes(normalizedQuery)) {
      return false;
    }
    if (filter === "all" || filter === "archived") {
      return true;
    }
    return entry.status === filter;
  });
}
