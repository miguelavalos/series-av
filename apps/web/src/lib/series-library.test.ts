import { describe, expect, it } from "vitest";
import {
  archiveEntry,
  clearProgress,
  createEpisodeCursor,
  createLibraryEntry,
  deleteEntry,
  getLibrarySnapshot,
  markNextEpisodeWatched,
  markPreviousEpisodeWatched,
  markWatchedThrough,
  mergeLibraryEntries,
  restoreEntry,
  setPinned,
  setStatus,
  type SeriesLibraryEntry
} from "./series-library";

const t0 = new Date("2026-01-01T00:00:00.000Z");
const t1 = new Date("2026-01-02T00:00:00.000Z");
const t2 = new Date("2026-01-03T00:00:00.000Z");
const t3 = new Date("2026-01-04T00:00:00.000Z");

describe("series library model", () => {
  it("normalizes episode cursors and advances from an empty entry", () => {
    expect(createEpisodeCursor({ episodeNumber: -3, seasonNumber: 0 })).toEqual({ episodeNumber: 1, seasonNumber: 1 });

    const entry = entryFixture({ lastWatchedEpisodeCursor: null, status: "wantToWatch" });
    expect(markNextEpisodeWatched(entry, t1)).toMatchObject({
      lastWatchedEpisodeCursor: { episodeNumber: 1, seasonNumber: 1 },
      status: "watching",
      updatedAt: t1.toISOString()
    });
  });

  it("marks previous progress and clears progress from S1 E1", () => {
    const watching = markWatchedThrough(entryFixture(), { episodeNumber: 3, seasonNumber: 2 }, t1);
    expect(markPreviousEpisodeWatched(watching, t2).lastWatchedEpisodeCursor).toEqual({ episodeNumber: 2, seasonNumber: 2 });

    const firstEpisode = markWatchedThrough(entryFixture(), { episodeNumber: 1, seasonNumber: 1 }, t1);
    expect(markPreviousEpisodeWatched(firstEpisode, t2)).toMatchObject({
      lastWatchedEpisodeCursor: null,
      status: "wantToWatch"
    });
  });

  it("applies status/archive/restore/delete mutations like the iOS store", () => {
    const pinned = setPinned(entryFixture({ status: "watching" }), true, t1);
    expect(pinned.isPinnedHomeSeries).toBe(true);

    const watched = setStatus(pinned, "watched", t2);
    expect(watched.isPinnedHomeSeries).toBe(false);

    const queued = clearProgress(watched, t3);
    expect(queued).toMatchObject({ lastWatchedEpisodeCursor: null, status: "wantToWatch" });

    const archived = archiveEntry(pinned, t2);
    expect(archived).toMatchObject({ archivedAt: t2.toISOString(), isPinnedHomeSeries: false });

    const restored = restoreEntry(archived, t3);
    expect(restored.archivedAt).toBeNull();
    expect(restored.deletedAt).toBeNull();

    const deleted = deleteEntry(pinned, t2);
    expect(deleted).toMatchObject({ archivedAt: null, deletedAt: t2.toISOString(), isPinnedHomeSeries: false });
  });

  it("sorts active entries by pin and recency and separates archived/deleted", () => {
    const old = entryFixture({ entryId: "old", lastInteractedAt: t0.toISOString(), seriesId: "old", title: "Old" });
    const pinned = entryFixture({ entryId: "pin", isPinnedHomeSeries: true, lastInteractedAt: t0.toISOString(), seriesId: "pin", title: "Pinned" });
    const recent = entryFixture({ entryId: "recent", lastInteractedAt: t2.toISOString(), seriesId: "recent", title: "Recent" });
    const archived = archiveEntry(entryFixture({ entryId: "archived", seriesId: "archived", title: "Archived" }), t1);
    const deleted = deleteEntry(entryFixture({ entryId: "deleted", seriesId: "deleted", title: "Deleted" }), t1);

    const snapshot = getLibrarySnapshot([old, archived, recent, deleted, pinned]);

    expect(snapshot.activeEntries.map((entry) => entry.entryId)).toEqual(["pin", "recent", "old"]);
    expect(snapshot.archivedEntries.map((entry) => entry.entryId)).toEqual(["archived"]);
    expect(snapshot.deletedEntries.map((entry) => entry.entryId)).toEqual(["deleted"]);
  });

  it("merges local and remote entries by series identity and newest updatedAt", () => {
    const remoteOld = entryFixture({ entryId: "remote", seriesId: "Same", title: "Remote", updatedAt: t1.toISOString() });
    const localNew = entryFixture({ entryId: "local", seriesId: " same ", title: "Local", updatedAt: t2.toISOString() });
    const remoteOnly = entryFixture({ entryId: "remote-only", lastInteractedAt: t3.toISOString(), seriesId: "remote-only", title: "Remote Only" });

    const merged = mergeLibraryEntries([localNew], [remoteOld, remoteOnly]);

    expect(merged).toHaveLength(2);
    expect(merged.find((entry) => entry.seriesId.trim().toLowerCase() === "same")?.entryId).toBe("local");
    expect(merged[0]?.entryId).toBe("remote-only");
  });

  it("creates library entries from catalog input", () => {
    expect(createLibraryEntry({ seriesId: "", title: "Nope" }, t0)).toBeNull();
    expect(createLibraryEntry({ displayArtworkRef: " https://poster.test/a.jpg ", seriesId: "series-1", title: " Show " }, t0)).toMatchObject({
      addedAt: t0.toISOString(),
      displayArtworkRef: "https://poster.test/a.jpg",
      entryId: "series-1",
      fallbackVisualSeed: "Show",
      seriesId: "series-1",
      status: "wantToWatch",
      title: "Show"
    });
  });
});

function entryFixture(overrides: Partial<SeriesLibraryEntry> = {}): SeriesLibraryEntry {
  return {
    addedAt: t0.toISOString(),
    archivedAt: null,
    deletedAt: null,
    displayArtworkRef: null,
    entryId: "series-1",
    fallbackVisualSeed: "Series One",
    isPinnedHomeSeries: false,
    lastInteractedAt: t0.toISOString(),
    lastWatchedEpisodeCursor: null,
    seriesId: "series-1",
    status: "wantToWatch",
    title: "Series One",
    updatedAt: t0.toISOString(),
    ...overrides
  };
}
