import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";

describe("Series detail library actions", () => {
  it("exposes archive, restore, and delete actions for followed entries", () => {
    const source = readFileSync(fileURLToPath(new URL("./series.$seriesId.tsx", import.meta.url)), "utf8");

    expect(source).toContain("library.archive(entry.entryId)");
    expect(source).toContain("library.restore(entry.entryId)");
    expect(source).toContain("library.deleteEntry(entry.entryId)");
    expect(source).toContain("libraryLabels.archive");
    expect(source).toContain("window.confirm(libraryLabels.confirmTrash)");
    expect(source).toContain("libraryLabels.trash");
  });

  it("keeps the episode guide feedback action wired to the public feedback endpoint", () => {
    const source = readFileSync(fileURLToPath(new URL("./series.$seriesId.tsx", import.meta.url)), "utf8");

    expect(source).toContain("client.reportGuideFeedback({");
    expect(source).toContain('reason: "missingEpisodes"');
    expect(source).toContain("knownEpisodeCount: catalog?.knownEpisodeCount ?? entry?.knownEpisodeCount ?? null");
    expect(source).toContain("latestKnownEpisodeCursor: catalog?.latestKnownEpisodeCursor ?? entry?.latestKnownEpisodeCursor ?? null");
    expect(source).toContain("userCursor: entry?.lastWatchedEpisodeCursor ?? null");
    expect(source).toContain("labels.guideFeedbackAction");
  });
});
