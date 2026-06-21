import { AppRowsSkeleton, AppSearchField, AppSegmentedControl, CompactSyncStatus, EmptyState, useAppsAvLocale } from "@avalsys/apps-av-web";
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
              <AppSearchField placeholder={labels.searchPlaceholder} value={query} onValueChange={setQuery} />
              <AppSegmentedControl ariaLabel={labels.filters} options={filterOptions(text.library.filters)} value={filter} onValueChange={setFilter} />
            </div>
          </Card>

          {isInitialSyncing ? <AppRowsSkeleton /> : null}

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
  ca: { active: "Actives", activeLower: "actives", filters: "Filtres de biblioteca", searchPlaceholder: "Cerca a la biblioteca", syncStatus: { disabled: "Local", failed: "Error", idle: "Al dia", syncing: "Sincronitzant" } },
  de: { active: "Aktiv", activeLower: "aktiv", filters: "Bibliotheksfilter", searchPlaceholder: "Bibliothek durchsuchen", syncStatus: { disabled: "Lokal", failed: "Fehler", idle: "Aktuell", syncing: "Sync läuft" } },
  en: { active: "Active", activeLower: "active", filters: "Library filters", searchPlaceholder: "Search your library", syncStatus: { disabled: "Local", failed: "Error", idle: "Current", syncing: "Syncing" } },
  es: { active: "Activas", activeLower: "activas", filters: "Filtros de biblioteca", searchPlaceholder: "Buscar en tu biblioteca", syncStatus: { disabled: "Local", failed: "Error", idle: "Al día", syncing: "Sincronizando" } },
  fr: { active: "Actives", activeLower: "actives", filters: "Filtres de bibliothèque", searchPlaceholder: "Rechercher dans la bibliothèque", syncStatus: { disabled: "Local", failed: "Erreur", idle: "À jour", syncing: "Sync" } }
} as const;

const filters: Filter[] = ["all", "watching", "wantToWatch", "watched", "archived"];

function filterOptions(labels: readonly string[]) {
  return filters.map((value, index) => ({ label: labels[index] ?? value, value }));
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
