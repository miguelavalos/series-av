import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vite-plus/test";

const source = readFileSync(resolve(dirname(fileURLToPath(import.meta.url)), "series-search.tsx"), "utf8");

describe("Series search follow action", () => {
  it("remembers the catalog item before following from search results", () => {
    const followHandler = source.match(/onClick=\{\(\) => \{[\s\S]*?library\.addCatalogSeries\(/)?.[0] ?? "";

    expect(followHandler).toContain("rememberSeriesCatalogItem(result);");
    expect(followHandler.indexOf("rememberSeriesCatalogItem(result);")).toBeLessThan(followHandler.indexOf("library.addCatalogSeries("));
  });
});
