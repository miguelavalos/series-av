import { normalizeAppsAvExternalSearchEngine, type AppsAvExternalSearchEngine } from "@avalsys/apps-av-web";

export const seriesExternalSearchEngineStorageKey = "series-av.externalSearchEngine";

export function readSeriesExternalSearchEngine(): AppsAvExternalSearchEngine {
  if (typeof window === "undefined") {
    return "google";
  }
  return normalizeAppsAvExternalSearchEngine(window.localStorage.getItem(seriesExternalSearchEngineStorageKey));
}

export function writeSeriesExternalSearchEngine(engine: AppsAvExternalSearchEngine) {
  if (typeof window === "undefined") {
    return;
  }
  const normalizedEngine = normalizeAppsAvExternalSearchEngine(engine);
  if (normalizedEngine === "google") {
    window.localStorage.removeItem(seriesExternalSearchEngineStorageKey);
    return;
  }
  window.localStorage.setItem(seriesExternalSearchEngineStorageKey, normalizedEngine);
}
