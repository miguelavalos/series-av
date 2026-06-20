import { normalizeAppsAvExternalSearchEngine, type AppsAvExternalSearchEngine } from "@avalsys/apps-av-web";

export const seriesExternalSearchEngineStorageKey = "series-av.externalSearchEngine";
export const defaultSeriesExternalSearchEngine: AppsAvExternalSearchEngine = "duckduckgo";

export function readSeriesExternalSearchEngine(): AppsAvExternalSearchEngine {
  if (typeof window === "undefined") {
    return defaultSeriesExternalSearchEngine;
  }
  const storedEngine = window.localStorage.getItem(seriesExternalSearchEngineStorageKey);
  return storedEngine === null ? defaultSeriesExternalSearchEngine : normalizeAppsAvExternalSearchEngine(storedEngine);
}

export function writeSeriesExternalSearchEngine(engine: AppsAvExternalSearchEngine) {
  if (typeof window === "undefined") {
    return;
  }
  const normalizedEngine = normalizeAppsAvExternalSearchEngine(engine);
  if (normalizedEngine === defaultSeriesExternalSearchEngine) {
    window.localStorage.removeItem(seriesExternalSearchEngineStorageKey);
    return;
  }
  window.localStorage.setItem(seriesExternalSearchEngineStorageKey, normalizedEngine);
}
