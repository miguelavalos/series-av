import { afterEach, describe, expect, it, vi } from "vite-plus/test";
import {
  defaultSeriesExternalSearchEngine,
  readSeriesExternalSearchEngine,
  seriesExternalSearchEngineStorageKey,
  writeSeriesExternalSearchEngine
} from "./series-external-preferences";

describe("series external preferences", () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("uses DuckDuckGo as the implicit search engine", () => {
    expect(readSeriesExternalSearchEngine()).toBe(defaultSeriesExternalSearchEngine);

    const localStorage = memoryLocalStorage();
    vi.stubGlobal("window", { localStorage });

    expect(readSeriesExternalSearchEngine()).toBe("duckduckgo");

    writeSeriesExternalSearchEngine("google");
    expect(localStorage.getItem(seriesExternalSearchEngineStorageKey)).toBe("google");
    expect(readSeriesExternalSearchEngine()).toBe("google");

    writeSeriesExternalSearchEngine("duckduckgo");
    expect(localStorage.getItem(seriesExternalSearchEngineStorageKey)).toBeNull();
    expect(readSeriesExternalSearchEngine()).toBe("duckduckgo");
  });
});

function memoryLocalStorage(): Storage {
  const values = new Map<string, string>();
  return {
    get length() {
      return values.size;
    },
    clear() {
      values.clear();
    },
    getItem(key: string) {
      return values.get(key) ?? null;
    },
    key(index: number) {
      return Array.from(values.keys())[index] ?? null;
    },
    removeItem(key: string) {
      values.delete(key);
    },
    setItem(key: string, value: string) {
      values.set(key, value);
    }
  };
}
