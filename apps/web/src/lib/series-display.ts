export function normalizeSeriesId(value: string) {
  try {
    return decodeURIComponent(value).trim();
  } catch {
    return value.trim();
  }
}

export function isPlaceholderSeriesTitle(title: string | null | undefined, seriesId: string) {
  const normalizedTitle = title?.trim().toLocaleLowerCase();
  const normalizedSeriesId = normalizeSeriesId(seriesId).toLocaleLowerCase();
  return !normalizedTitle || normalizedTitle === normalizedSeriesId;
}

export function visibleSeriesTitle(title: string | null | undefined, seriesId: string) {
  return isPlaceholderSeriesTitle(title, seriesId) ? null : title?.trim() || null;
}
