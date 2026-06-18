export type SeriesLibraryEntryStatus = "wantToWatch" | "watching" | "watched";

export interface SeriesEpisodeCursor {
  episodeNumber: number;
  seasonNumber: number;
}

export interface SeriesLibraryEntry {
  addedAt: string;
  archivedAt?: string | null;
  deletedAt?: string | null;
  displayArtworkRef?: string | null;
  entryId: string;
  fallbackVisualSeed?: string | null;
  isPinnedHomeSeries?: boolean | null;
  lastInteractedAt: string;
  lastWatchedEpisodeCursor?: SeriesEpisodeCursor | null;
  seriesId: string;
  status: SeriesLibraryEntryStatus;
  title: string;
  updatedAt: string;
}

export interface SeriesLibraryEnvelope {
  appId: "seriesav";
  deviceId: string;
  entries: SeriesLibraryEntry[];
  resource: "seriesLibrary";
  sentAt: string;
}

export interface SeriesLibraryDocument {
  data: SeriesLibraryEnvelope;
  etag?: string | null;
  revision: number;
  updatedAt: string;
}

export interface SeriesCatalogLibraryInput {
  displayArtworkRef?: string | null;
  fallbackVisualSeed?: string | null;
  seriesId: string;
  title: string;
}

export interface SeriesLibraryLimitPolicy {
  activeCount: number;
  activeLimit: number;
  canAddSeries: boolean;
  remainingSeriesCount: number;
}

export interface SeriesLibrarySnapshot {
  activeEntries: SeriesLibraryEntry[];
  archivedEntries: SeriesLibraryEntry[];
  deletedEntries: SeriesLibraryEntry[];
  homeEntries: SeriesLibraryEntry[];
  watchingEntries: SeriesLibraryEntry[];
}

const FREE_ACTIVE_LIMIT = 75;
const PRO_ACTIVE_LIMIT = 1000;

export function createEpisodeCursor(cursor: SeriesEpisodeCursor): SeriesEpisodeCursor {
  return {
    episodeNumber: Math.max(1, Math.trunc(cursor.episodeNumber)),
    seasonNumber: Math.max(1, Math.trunc(cursor.seasonNumber))
  };
}

export function compareEpisodeCursors(first: SeriesEpisodeCursor, second: SeriesEpisodeCursor): number {
  if (first.seasonNumber !== second.seasonNumber) {
    return first.seasonNumber - second.seasonNumber;
  }
  return first.episodeNumber - second.episodeNumber;
}

export function nextEpisodeCursor(cursor?: SeriesEpisodeCursor | null): SeriesEpisodeCursor {
  if (!cursor) {
    return { episodeNumber: 1, seasonNumber: 1 };
  }
  const normalized = createEpisodeCursor(cursor);
  return { episodeNumber: normalized.episodeNumber + 1, seasonNumber: normalized.seasonNumber };
}

export function previousEpisodeCursor(cursor?: SeriesEpisodeCursor | null): SeriesEpisodeCursor | null {
  if (!cursor) {
    return null;
  }
  const normalized = createEpisodeCursor(cursor);
  if (normalized.episodeNumber > 1) {
    return { episodeNumber: normalized.episodeNumber - 1, seasonNumber: normalized.seasonNumber };
  }
  return null;
}

export function canStepBackQuickly(cursor?: SeriesEpisodeCursor | null): boolean {
  if (!cursor) {
    return false;
  }
  const normalized = createEpisodeCursor(cursor);
  return normalized.episodeNumber > 1 || (normalized.seasonNumber === 1 && normalized.episodeNumber === 1);
}

export function cursorLabel(cursor: SeriesEpisodeCursor): string {
  const normalized = createEpisodeCursor(cursor);
  return `S${normalized.seasonNumber} E${normalized.episodeNumber}`;
}

export function progressLabel(entry: SeriesLibraryEntry, notStarted: string, noEpisodeSet: string): string {
  if (!entry.lastWatchedEpisodeCursor) {
    return entry.status === "wantToWatch" ? notStarted : noEpisodeSet;
  }
  return cursorLabel(entry.lastWatchedEpisodeCursor);
}

export function normalizeSearchText(value: string): string {
  return value.trim().toLocaleLowerCase().normalize("NFKD").replace(/[\u0300-\u036f]/g, "");
}

export function sameSeries(first: Pick<SeriesLibraryEntry, "seriesId">, second: Pick<SeriesLibraryEntry, "seriesId">): boolean {
  return identityKey(first) === identityKey(second);
}

export function createLibraryEntry(input: SeriesCatalogLibraryInput, at = new Date()): SeriesLibraryEntry | null {
  const title = input.title.trim();
  const seriesId = input.seriesId.trim();
  if (!title || !seriesId) {
    return null;
  }
  const timestamp = at.toISOString();
  return {
    addedAt: timestamp,
    archivedAt: null,
    deletedAt: null,
    displayArtworkRef: normalizeOptionalString(input.displayArtworkRef),
    entryId: seriesId,
    fallbackVisualSeed: normalizeOptionalString(input.fallbackVisualSeed) ?? title,
    isPinnedHomeSeries: false,
    lastInteractedAt: timestamp,
    lastWatchedEpisodeCursor: null,
    seriesId,
    status: "wantToWatch",
    title,
    updatedAt: timestamp
  };
}

export function upsertLibraryEntry(entries: SeriesLibraryEntry[], entry: SeriesLibraryEntry): SeriesLibraryEntry[] {
  const index = entries.findIndex((candidate) => sameSeries(candidate, entry));
  if (index === -1) {
    return [...entries, entry];
  }
  return entries.map((candidate, candidateIndex) => (candidateIndex === index ? entry : candidate));
}

export function markWatchedThrough(entry: SeriesLibraryEntry, cursor: SeriesEpisodeCursor, at = new Date()): SeriesLibraryEntry {
  const timestamp = at.toISOString();
  return {
    ...entry,
    lastInteractedAt: timestamp,
    lastWatchedEpisodeCursor: createEpisodeCursor(cursor),
    status: "watching",
    updatedAt: timestamp
  };
}

export function clearProgress(entry: SeriesLibraryEntry, at = new Date()): SeriesLibraryEntry {
  const timestamp = at.toISOString();
  return {
    ...entry,
    lastInteractedAt: timestamp,
    lastWatchedEpisodeCursor: null,
    status: "wantToWatch",
    updatedAt: timestamp
  };
}

export function markNextEpisodeWatched(entry: SeriesLibraryEntry, at = new Date()): SeriesLibraryEntry {
  return markWatchedThrough(entry, nextEpisodeCursor(entry.lastWatchedEpisodeCursor), at);
}

export function markPreviousEpisodeWatched(entry: SeriesLibraryEntry, at = new Date()): SeriesLibraryEntry {
  if (!entry.lastWatchedEpisodeCursor) {
    return entry;
  }
  const previous = previousEpisodeCursor(entry.lastWatchedEpisodeCursor);
  if (previous) {
    return markWatchedThrough(entry, previous, at);
  }
  if (canStepBackQuickly(entry.lastWatchedEpisodeCursor) && entry.lastWatchedEpisodeCursor.seasonNumber === 1 && entry.lastWatchedEpisodeCursor.episodeNumber === 1) {
    return clearProgress(entry, at);
  }
  return entry;
}

export function restoreProgress(
  entry: SeriesLibraryEntry,
  status: SeriesLibraryEntryStatus,
  lastWatchedEpisodeCursor: SeriesEpisodeCursor | null | undefined,
  at = new Date()
): SeriesLibraryEntry {
  const timestamp = at.toISOString();
  return {
    ...entry,
    lastInteractedAt: timestamp,
    lastWatchedEpisodeCursor: lastWatchedEpisodeCursor ? createEpisodeCursor(lastWatchedEpisodeCursor) : null,
    status,
    updatedAt: timestamp
  };
}

export function setStatus(entry: SeriesLibraryEntry, status: SeriesLibraryEntryStatus, at = new Date()): SeriesLibraryEntry {
  const timestamp = at.toISOString();
  return {
    ...entry,
    isPinnedHomeSeries: status === "watched" ? false : entry.isPinnedHomeSeries,
    lastInteractedAt: timestamp,
    lastWatchedEpisodeCursor: status === "wantToWatch" ? null : entry.lastWatchedEpisodeCursor,
    status,
    updatedAt: timestamp
  };
}

export function setPinned(entry: SeriesLibraryEntry, isPinned: boolean, at = new Date()): SeriesLibraryEntry {
  const timestamp = at.toISOString();
  return {
    ...entry,
    isPinnedHomeSeries: isPinned,
    lastInteractedAt: timestamp,
    updatedAt: timestamp
  };
}

export function archiveEntry(entry: SeriesLibraryEntry, at = new Date()): SeriesLibraryEntry {
  const timestamp = at.toISOString();
  return {
    ...entry,
    archivedAt: timestamp,
    isPinnedHomeSeries: false,
    lastInteractedAt: timestamp,
    updatedAt: timestamp
  };
}

export function restoreEntry(entry: SeriesLibraryEntry, at = new Date()): SeriesLibraryEntry {
  const timestamp = at.toISOString();
  return {
    ...entry,
    archivedAt: null,
    deletedAt: null,
    lastInteractedAt: timestamp,
    updatedAt: timestamp
  };
}

export function deleteEntry(entry: SeriesLibraryEntry, at = new Date()): SeriesLibraryEntry {
  const timestamp = at.toISOString();
  return {
    ...entry,
    archivedAt: null,
    deletedAt: timestamp,
    isPinnedHomeSeries: false,
    lastInteractedAt: timestamp,
    updatedAt: timestamp
  };
}

export function updateArtworkIfMissing(
  entry: SeriesLibraryEntry,
  displayArtworkRef?: string | null,
  fallbackVisualSeed?: string | null,
  at = new Date()
): SeriesLibraryEntry {
  if (entry.displayArtworkRef?.trim()) {
    return entry;
  }
  const normalizedArtwork = normalizeOptionalString(displayArtworkRef);
  if (!normalizedArtwork) {
    return entry;
  }
  return {
    ...entry,
    displayArtworkRef: normalizedArtwork,
    fallbackVisualSeed: entry.fallbackVisualSeed?.trim() ? entry.fallbackVisualSeed : normalizeOptionalString(fallbackVisualSeed),
    updatedAt: at.toISOString()
  };
}

export function updateCatalogMetadataIfPlaceholder(
  entry: SeriesLibraryEntry,
  input: SeriesCatalogLibraryInput,
  at = new Date()
): SeriesLibraryEntry {
  const title = normalizeOptionalString(input.title);
  const shouldUpdateTitle = Boolean(title) && isPlaceholderTitle(entry.title, entry.seriesId);
  const nextArtwork = entry.displayArtworkRef?.trim() ? entry.displayArtworkRef : normalizeOptionalString(input.displayArtworkRef);
  const nextFallback = entry.fallbackVisualSeed?.trim() && !isPlaceholderTitle(entry.fallbackVisualSeed, entry.seriesId) ? entry.fallbackVisualSeed : normalizeOptionalString(input.fallbackVisualSeed) ?? title;

  if (!shouldUpdateTitle && nextArtwork === entry.displayArtworkRef && nextFallback === entry.fallbackVisualSeed) {
    return entry;
  }

  return {
    ...entry,
    displayArtworkRef: nextArtwork,
    fallbackVisualSeed: nextFallback,
    title: shouldUpdateTitle && title ? title : entry.title,
    updatedAt: at.toISOString()
  };
}

export function replaceEntry(entries: SeriesLibraryEntry[], entryId: string, update: (entry: SeriesLibraryEntry) => SeriesLibraryEntry): SeriesLibraryEntry[] {
  return entries.map((entry) => (entry.entryId === entryId ? update(entry) : entry));
}

export function getLibrarySnapshot(entries: SeriesLibraryEntry[]): SeriesLibrarySnapshot {
  const activeEntries = entries
    .filter((entry) => !entry.deletedAt && !entry.archivedAt)
    .toSorted((first, second) => {
      if (first.isPinnedHomeSeries === true && second.isPinnedHomeSeries !== true) {
        return -1;
      }
      if (first.isPinnedHomeSeries !== true && second.isPinnedHomeSeries === true) {
        return 1;
      }
      return compareEntryRecency(first, second);
    });
  const archivedEntries = entries.filter((entry) => !entry.deletedAt && entry.archivedAt).toSorted(compareEntryRecency);
  const deletedEntries = entries.filter((entry) => entry.deletedAt).toSorted(compareEntryRecency);
  const watchingEntries = activeEntries.filter((entry) => entry.status === "watching");
  const wantToWatchEntries = activeEntries.filter((entry) => entry.status === "wantToWatch");

  return {
    activeEntries,
    archivedEntries,
    deletedEntries,
    homeEntries: watchingEntries.length > 0 ? watchingEntries : wantToWatchEntries.length > 0 ? wantToWatchEntries : activeEntries,
    watchingEntries
  };
}

export function searchLibraryEntries(entries: SeriesLibraryEntry[], query: string): SeriesLibraryEntry[] {
  const normalizedQuery = normalizeSearchText(query);
  const { activeEntries } = getLibrarySnapshot(entries);
  if (!normalizedQuery) {
    return activeEntries;
  }
  return activeEntries.filter((entry) => normalizeSearchText(entry.title).includes(normalizedQuery));
}

export function mergeLibraryEntries(localEntries: SeriesLibraryEntry[], remoteEntries: SeriesLibraryEntry[]): SeriesLibraryEntry[] {
  const merged = new Map<string, SeriesLibraryEntry>();
  const order: string[] = [];

  for (const entry of [...remoteEntries, ...localEntries]) {
    const key = identityKey(entry);
    const existing = merged.get(key);
    if (!existing) {
      order.push(key);
      merged.set(key, entry);
      continue;
    }
    if (Date.parse(entry.updatedAt) >= Date.parse(existing.updatedAt)) {
      merged.set(key, entry);
    }
  }

  return order
    .map((key) => merged.get(key))
    .filter((entry): entry is SeriesLibraryEntry => Boolean(entry))
    .toSorted((first, second) => {
      const recency = compareEntryRecency(first, second);
      if (recency !== 0) {
        return recency;
      }
      return first.title.localeCompare(second.title, undefined, { sensitivity: "accent" });
    });
}

export function activeLibraryLimitPolicy(activeCount: number, plan: "free" | "pro" | string | null | undefined): SeriesLibraryLimitPolicy {
  const activeLimit = plan === "pro" ? PRO_ACTIVE_LIMIT : FREE_ACTIVE_LIMIT;
  return {
    activeCount,
    activeLimit,
    canAddSeries: activeCount < activeLimit,
    remainingSeriesCount: Math.max(0, activeLimit - activeCount)
  };
}

function identityKey(entry: Pick<SeriesLibraryEntry, "seriesId">): string {
  return `series:${entry.seriesId.trim().toLocaleLowerCase()}`;
}

function compareEntryRecency(first: SeriesLibraryEntry, second: SeriesLibraryEntry): number {
  return Date.parse(second.lastInteractedAt) - Date.parse(first.lastInteractedAt);
}

function normalizeOptionalString(value?: string | null): string | null {
  const trimmed = value?.trim();
  return trimmed ? trimmed : null;
}

function isPlaceholderTitle(title: string | null | undefined, seriesId: string): boolean {
  const normalizedTitle = title?.trim().toLocaleLowerCase();
  const normalizedSeriesId = seriesId.trim().toLocaleLowerCase();
  return !normalizedTitle || normalizedTitle === normalizedSeriesId || normalizedTitle === decodeURIComponent(seriesId).trim().toLocaleLowerCase();
}
