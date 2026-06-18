import { useAccountAppAccess, useAccountSession, useAccountToken, useAccountUser } from "@avalsys/account-av-web";
import type { AccountAvAppAccess } from "@avalsys/account-av-web";
import type { ReactNode } from "react";
import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from "react";
import { SeriesApiClient } from "@/lib/series-api-client";
import { getAccountApiBaseUrl } from "@/lib/series-config";
import {
  activeLibraryLimitPolicy,
  archiveEntry,
  clearProgress,
  createLibraryEntry,
  deleteEntry,
  getLibrarySnapshot,
  markNextEpisodeWatched,
  markPreviousEpisodeWatched,
  markWatchedThrough,
  mergeLibraryEntries,
  replaceEntry,
  restoreEntry,
  restoreProgress,
  searchLibraryEntries,
  setPinned,
  setStatus,
  updateCatalogMetadataIfPlaceholder as applyCatalogMetadataIfPlaceholder,
  updateArtworkIfMissing,
  upsertLibraryEntry,
  type SeriesCatalogLibraryInput,
  type SeriesEpisodeCursor,
  type SeriesLibraryEntry,
  type SeriesLibraryEntryStatus
} from "@/lib/series-library";

type SyncState = "disabled" | "idle" | "syncing" | "failed";

interface SeriesLibraryContextValue {
  access: AccountAvAppAccess | null | undefined;
  addCatalogSeries: (input: SeriesCatalogLibraryInput) => SeriesLibraryEntry | null;
  archive: (entryId: string) => void;
  canAddSeries: boolean;
  clearProgress: (entryId: string) => void;
  clearLocalData: () => void;
  deleteEntry: (entryId: string) => void;
  entries: SeriesLibraryEntry[];
  findEntryBySeriesId: (seriesId: string) => SeriesLibraryEntry | null;
  isInitialSyncComplete: boolean;
  limit: ReturnType<typeof activeLibraryLimitPolicy>;
  markNextEpisodeWatched: (entryId: string) => void;
  markPreviousEpisodeWatched: (entryId: string) => void;
  markWatchedThrough: (entryId: string, cursor: SeriesEpisodeCursor) => void;
  refreshSync: () => Promise<void>;
  restore: (entryId: string) => void;
  restoreProgress: (entryId: string, status: SeriesLibraryEntryStatus, cursor?: SeriesEpisodeCursor | null) => void;
  searchEntries: (query: string) => SeriesLibraryEntry[];
  setPinned: (entryId: string, isPinned: boolean) => void;
  setStatus: (entryId: string, status: SeriesLibraryEntryStatus) => void;
  snapshot: ReturnType<typeof getLibrarySnapshot>;
  syncError: string | null;
  syncState: SyncState;
  updateCatalogMetadataIfPlaceholder: (entryId: string, input: SeriesCatalogLibraryInput) => void;
  updateArtworkIfMissing: (entryId: string, input: Pick<SeriesCatalogLibraryInput, "displayArtworkRef" | "fallbackVisualSeed">) => void;
}

const storageKeyPrefix = "seriesav.web.library.v1";
const deviceIdKey = "seriesav.web.sync.deviceId";
const SeriesLibraryContext = createContext<SeriesLibraryContextValue | null>(null);

export function SeriesLibraryProvider({ children }: { children: ReactNode }) {
  const session = useAccountSession();
  const getToken = useAccountToken();
  const accountUser = useAccountUser();
  const access = useAccountAppAccess("seriesav");
  const [entries, setEntries] = useState<SeriesLibraryEntry[]>([]);
  const [syncState, setSyncState] = useState<SyncState>("disabled");
  const [syncError, setSyncError] = useState<string | null>(null);
  const [isInitialSyncComplete, setIsInitialSyncComplete] = useState(false);
  const etagRef = useRef<string | null>(null);
  const debounceRef = useRef<number | null>(null);
  const applyingRemoteRef = useRef(false);
  const latestEntriesRef = useRef<SeriesLibraryEntry[]>([]);
  const getTokenRef = useRef(getToken);
  const client = useMemo(() => new SeriesApiClient(getAccountApiBaseUrl()), []);
  const internalUserStorageKey = accountUser.data?.id ? `${storageKeyPrefix}.${accountUser.data.id}` : null;
  const sessionStorageKey = session.userId ? `${storageKeyPrefix}.session.${session.userId}` : null;
  const userStorageKey = internalUserStorageKey ?? sessionStorageKey;
  const deviceId = useMemo(() => stableDeviceId(), []);

  latestEntriesRef.current = entries;
  getTokenRef.current = getToken;

  useEffect(() => {
    if (!userStorageKey) {
      if (session.isLoaded && !session.isSignedIn) {
        setEntries([]);
        setIsInitialSyncComplete(false);
        setSyncState("disabled");
      }
      return;
    }
    setEntries((current) => mergeLibraryEntries(current, loadEntries(userStorageKey)));
  }, [session.isLoaded, session.isSignedIn, userStorageKey]);

  useEffect(() => {
    if (!userStorageKey) {
      return;
    }
    saveEntries(userStorageKey, entries);
  }, [entries, userStorageKey]);

  const refreshSync = useCallback(async () => {
    if (!session.isLoaded || !session.isSignedIn || !access.data?.capabilities.canUseCloudSync) {
      setSyncState("disabled");
      setIsInitialSyncComplete(false);
      etagRef.current = null;
      return;
    }

    setSyncState("syncing");
    setSyncError(null);
    try {
      const token = await getTokenRef.current();
      if (!token) {
        throw new Error("Missing Account AV session token.");
      }
      const pulled = await client.pullLibrary(token);
      etagRef.current = pulled.etag ?? pulled.document.etag ?? null;
      const remoteEntries = decodeRemoteEntries(pulled.document.data.entries);
      const mergedEntries = mergeLibraryEntries(latestEntriesRef.current, remoteEntries);

      if (!sameEntries(mergedEntries, latestEntriesRef.current)) {
        applyingRemoteRef.current = true;
        setEntries(mergedEntries);
        latestEntriesRef.current = mergedEntries;
        applyingRemoteRef.current = false;
      }

      if (!sameEntries(mergedEntries, remoteEntries)) {
        const pushed = await client.pushLibrary({
          deviceId,
          entries: mergedEntries,
          expectedEtag: etagRef.current,
          token
        });
        etagRef.current = pushed.etag ?? pushed.document.etag ?? null;
        const pushedEntries = decodeRemoteEntries(pushed.document.data.entries);
        if (!sameEntries(pushedEntries, latestEntriesRef.current)) {
          applyingRemoteRef.current = true;
          setEntries(pushedEntries);
          latestEntriesRef.current = pushedEntries;
          applyingRemoteRef.current = false;
        }
      }

      setIsInitialSyncComplete(true);
      setSyncState("idle");
    } catch (error) {
      setIsInitialSyncComplete(true);
      setSyncError(error instanceof Error ? error.message : "Series library sync failed.");
      setSyncState("failed");
    }
  }, [access.data?.capabilities.canUseCloudSync, client, deviceId, session.isLoaded, session.isSignedIn]);

  useEffect(() => {
    void refreshSync();
  }, [refreshSync]);

  const schedulePush = useCallback(
    (nextEntries: SeriesLibraryEntry[]) => {
      if (!session.isLoaded || !session.isSignedIn || !access.data?.capabilities.canUseCloudSync || !isInitialSyncComplete || applyingRemoteRef.current) {
        return;
      }
      if (debounceRef.current) {
        window.clearTimeout(debounceRef.current);
      }
      debounceRef.current = window.setTimeout(() => {
        void pushEntries(client, getTokenRef.current, deviceId, etagRef, nextEntries, setSyncState, setSyncError);
      }, 800);
    },
    [access.data?.capabilities.canUseCloudSync, client, deviceId, isInitialSyncComplete, session.isLoaded, session.isSignedIn]
  );

  const mutateEntries = useCallback(
    (update: (current: SeriesLibraryEntry[]) => SeriesLibraryEntry[]) => {
      setEntries((current) => {
        const next = update(current);
        latestEntriesRef.current = next;
        schedulePush(next);
        return next;
      });
    },
    [schedulePush]
  );

  const snapshot = useMemo(() => getLibrarySnapshot(entries), [entries]);
  const limit = activeLibraryLimitPolicy(snapshot.activeEntries.length, access.data?.planTier);

  const value = useMemo<SeriesLibraryContextValue>(
    () => ({
      access: access.data,
      addCatalogSeries(input) {
        const entry = createLibraryEntry(input);
        if (!entry || !limit.canAddSeries) {
          return null;
        }
        mutateEntries((current) => upsertLibraryEntry(current, entry));
        return entry;
      },
      archive(entryId) {
        mutateEntries((current) => replaceEntry(current, entryId, archiveEntry));
      },
      canAddSeries: limit.canAddSeries,
      clearProgress(entryId) {
        mutateEntries((current) => replaceEntry(current, entryId, clearProgress));
      },
      clearLocalData() {
        latestEntriesRef.current = [];
        setEntries([]);
      },
      deleteEntry(entryId) {
        mutateEntries((current) => replaceEntry(current, entryId, deleteEntry));
      },
      entries,
      findEntryBySeriesId(seriesId) {
        return entries.find((entry) => entry.seriesId.trim().toLocaleLowerCase() === seriesId.trim().toLocaleLowerCase() && !entry.deletedAt) ?? null;
      },
      isInitialSyncComplete,
      limit,
      markNextEpisodeWatched(entryId) {
        mutateEntries((current) => replaceEntry(current, entryId, markNextEpisodeWatched));
      },
      markPreviousEpisodeWatched(entryId) {
        mutateEntries((current) => replaceEntry(current, entryId, markPreviousEpisodeWatched));
      },
      markWatchedThrough(entryId, cursor) {
        mutateEntries((current) => replaceEntry(current, entryId, (entry) => markWatchedThrough(entry, cursor)));
      },
      refreshSync,
      restore(entryId) {
        mutateEntries((current) => replaceEntry(current, entryId, restoreEntry));
      },
      restoreProgress(entryId, status, cursor) {
        mutateEntries((current) => replaceEntry(current, entryId, (entry) => restoreProgress(entry, status, cursor)));
      },
      searchEntries(query) {
        return searchLibraryEntries(entries, query);
      },
      setPinned(entryId, isPinned) {
        mutateEntries((current) => replaceEntry(current, entryId, (entry) => setPinned(entry, isPinned)));
      },
      setStatus(entryId, status) {
        mutateEntries((current) => replaceEntry(current, entryId, (entry) => setStatus(entry, status)));
      },
      snapshot,
      syncError,
      syncState,
      updateCatalogMetadataIfPlaceholder(entryId, input) {
        mutateEntries((current) => replaceEntry(current, entryId, (entry) => applyCatalogMetadataIfPlaceholder(entry, input)));
      },
      updateArtworkIfMissing(entryId, input) {
        mutateEntries((current) => replaceEntry(current, entryId, (entry) => updateArtworkIfMissing(entry, input.displayArtworkRef, input.fallbackVisualSeed)));
      }
    }),
    [access.data, entries, isInitialSyncComplete, limit, mutateEntries, refreshSync, snapshot, syncError, syncState]
  );

  return <SeriesLibraryContext.Provider value={value}>{children}</SeriesLibraryContext.Provider>;
}

export function useSeriesLibrary() {
  const context = useContext(SeriesLibraryContext);
  if (!context) {
    throw new Error("useSeriesLibrary must be used inside SeriesLibraryProvider.");
  }
  return context;
}

async function pushEntries(
  client: SeriesApiClient,
  getToken: () => Promise<string | null>,
  deviceId: string,
  etagRef: { current: string | null },
  entries: SeriesLibraryEntry[],
  setSyncState: (state: SyncState) => void,
  setSyncError: (error: string | null) => void
) {
  setSyncState("syncing");
  setSyncError(null);
  try {
    const token = await getToken();
    if (!token) {
      throw new Error("Missing Account AV session token.");
    }
    const pushed = await client.pushLibrary({
      deviceId,
      entries,
      expectedEtag: etagRef.current,
      token
    });
    etagRef.current = pushed.etag ?? pushed.document.etag ?? null;
    setSyncState("idle");
  } catch (error) {
    setSyncError(error instanceof Error ? error.message : "Series library sync failed.");
    setSyncState("failed");
  }
}

function decodeRemoteEntries(entries: unknown[]): SeriesLibraryEntry[] {
  return entries.filter(isLibraryEntry);
}

function isLibraryEntry(value: unknown): value is SeriesLibraryEntry {
  if (!value || typeof value !== "object") {
    return false;
  }
  const entry = value as Partial<SeriesLibraryEntry>;
  return typeof entry.entryId === "string" && typeof entry.seriesId === "string" && typeof entry.title === "string" && typeof entry.addedAt === "string" && typeof entry.updatedAt === "string" && typeof entry.lastInteractedAt === "string";
}

function sameEntries(first: SeriesLibraryEntry[], second: SeriesLibraryEntry[]) {
  return JSON.stringify(first) === JSON.stringify(second);
}

function loadEntries(key: string): SeriesLibraryEntry[] {
  if (typeof window === "undefined") {
    return [];
  }
  try {
    const raw = window.localStorage.getItem(key);
    if (!raw) {
      return [];
    }
    const parsed = JSON.parse(raw) as unknown;
    return Array.isArray(parsed) ? decodeRemoteEntries(parsed) : [];
  } catch {
    return [];
  }
}

function saveEntries(key: string, entries: SeriesLibraryEntry[]) {
  if (typeof window === "undefined") {
    return;
  }
  window.localStorage.setItem(key, JSON.stringify(entries));
}

function stableDeviceId() {
  if (typeof window === "undefined") {
    return "seriesav-web-ssr";
  }
  const existing = window.localStorage.getItem(deviceIdKey);
  if (existing) {
    return existing;
  }
  const created = crypto.randomUUID();
  window.localStorage.setItem(deviceIdKey, created);
  return created;
}
