import { afterEach, describe, expect, it, vi } from "vitest";

import { SeriesApiClient } from "@/lib/series-api-client";

describe("SeriesApiClient", () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("posts episode guide feedback with compact no-spoiler guide context", async () => {
    const fetchMock = vi.spyOn(globalThis, "fetch").mockResolvedValue(
      new Response(
        JSON.stringify({
          generatedAt: "2026-06-29T00:00:00.000Z",
          reportId: "report-1",
          status: "received"
        }),
        {
          headers: { "Content-Type": "application/json" },
          status: 202
        }
      )
    );
    const client = new SeriesApiClient("https://api.example.test");

    const response = await client.reportGuideFeedback({
      appLocale: "es",
      knownEpisodeCount: 1168,
      latestKnownEpisodeCursor: { episodeNumber: 14, seasonNumber: 23 },
      note: "Web report: episode guide may be incomplete.",
      reason: "missingEpisodes",
      seriesId: "thetvdb:81797",
      title: "One Piece",
      userCursor: { episodeNumber: 14, seasonNumber: 23 }
    });

    expect(response).toEqual({
      generatedAt: "2026-06-29T00:00:00.000Z",
      reportId: "report-1",
      status: "received"
    });
    expect(fetchMock).toHaveBeenCalledWith("https://api.example.test/v1/series/guide-feedback", {
      body: JSON.stringify({
        appLocale: "es",
        knownEpisodeCount: 1168,
        latestKnownEpisodeCursor: { episodeNumber: 14, seasonNumber: 23 },
        note: "Web report: episode guide may be incomplete.",
        reason: "missingEpisodes",
        seriesId: "thetvdb:81797",
        title: "One Piece",
        userCursor: { episodeNumber: 14, seasonNumber: 23 }
      }),
      headers: {
        "Content-Type": "application/json"
      },
      method: "POST"
    });
  });
});
