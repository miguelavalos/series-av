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
});
