import { useAccountSession, useAccountToken } from "@avalsys/account-av-web";
import { ErrorState, useAppsAvLocale } from "@avalsys/apps-av-web";
import { useMutation, useQuery } from "@tanstack/react-query";
import { Link, createFileRoute } from "@tanstack/react-router";
import { ArrowLeft, CheckCircle2, Clock, Plus, UserRound } from "lucide-react";
import { useMemo } from "react";

import { SeriesAppShell } from "@/components/series-app-shell";
import { SeriesArtwork } from "@/components/series-library-ui";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { SeriesApiClient } from "@/lib/series-api-client";
import { getSeriesApiBaseUrl } from "@/lib/series-config";
import { useSeriesLibrary } from "@/lib/series-library-provider";
import { localizedSeriesPath, useSeriesText } from "@/lib/series-i18n";

export const Route = createFileRoute("/i/r/$token")({
  component: ShareInviteRoute
});

function ShareInviteRoute() {
  const { token } = Route.useParams();
  const locale = useAppsAvLocale();
  const text = useSeriesText();
  const accountSession = useAccountSession();
  const getToken = useAccountToken();
  const library = useSeriesLibrary();
  const client = useMemo(() => new SeriesApiClient(getSeriesApiBaseUrl()), []);
  const inviteQuery = useQuery({
    queryFn: () => client.shareInvite(token),
    queryKey: ["series-av", "share-invite", token],
    retry: false
  });
  const invite = inviteQuery.data?.invite ?? null;
  const seriesTitle = invite?.series?.title ?? invite?.seriesId ?? "Series AV";
  const artworkEntry = invite
    ? {
        displayArtworkRef: invite.series?.displayArtwork?.url ?? null,
        fallbackVisualSeed: seriesTitle,
        seriesId: invite.seriesId,
        title: seriesTitle
      }
    : null;
  const existingEntry = invite ? library.findEntryBySeriesId(invite.seriesId) : null;
  const acceptMutation = useMutation({
    mutationFn: async () => {
      const authToken = await getToken();
      if (!authToken) {
        throw new Error("Missing Account AV session token.");
      }
      return client.acceptShareInvite({ authToken, token });
    },
    onSuccess: (response) => {
      const acceptedInvite = response.invite;
      const acceptedTitle = acceptedInvite.series?.title ?? acceptedInvite.seriesId;
      library.addCatalogSeries({
        displayArtworkRef: acceptedInvite.series?.displayArtwork?.url ?? null,
        fallbackVisualSeed: acceptedTitle,
        seriesId: acceptedInvite.seriesId,
        title: acceptedTitle
      });
    }
  });
  const canAccept = Boolean(invite && invite.status === "active" && accountSession.isSignedIn && !existingEntry);

  return (
    <SeriesAppShell>
      <section className="mx-auto grid max-w-4xl gap-6">
        <Button asChild variant="ghost" className="w-fit rounded-full">
          <Link to={localizedSeriesPath("/", locale)}>
            <ArrowLeft className="size-4" /> Series AV
          </Link>
        </Button>

        {inviteQuery.isLoading ? (
          <Card className="series-paper min-h-72 animate-pulse rounded-lg border-[#d7c494] bg-[#fff8df]/90" />
        ) : null}

        {inviteQuery.isError ? (
          <ErrorState className="border-[#d7c494] bg-[#fff8df]/90" description={inviteQuery.error.message} title="Recommendation unavailable" />
        ) : null}

        {invite && artworkEntry ? (
          <Card className="series-paper rounded-lg border-[#d7c494] p-5 py-5 shadow-lg shadow-[#172f5c]/8 sm:p-8 sm:py-8">
            <div className="grid gap-6 md:grid-cols-[10rem_minmax(0,1fr)]">
              <SeriesArtwork entry={artworkEntry} size="xl" />
              <div className="min-w-0">
                <div className="flex flex-wrap items-center gap-2 text-sm font-bold text-[#5a8f2f]">
                  <UserRound className="size-4" />
                  {invite.senderDisplayName ? `${invite.senderDisplayName} recommends` : "Recommendation"}
                </div>
                <h1 className="mt-3 text-3xl font-semibold leading-tight text-[#112a55] sm:text-4xl">{seriesTitle}</h1>
                <p className="mt-3 text-sm font-semibold text-[#53617a]">
                  {invite.series?.startYear ?? text.search.dateUnknown}
                </p>
                {invite.message ? (
                  <p className="mt-5 rounded-lg border border-[#d7c494] bg-white/55 p-4 text-base leading-7 text-[#334766]">{invite.message}</p>
                ) : null}
                {invite.series?.summary ? (
                  <p className="mt-5 text-base leading-7 text-[#334766]">{invite.series.summary}</p>
                ) : null}

                <div className="mt-6 flex flex-wrap gap-2">
                  {existingEntry ? (
                    <Button asChild className="rounded-full bg-[#112a55] text-white hover:bg-[#19396f]">
                      <Link to={localizedSeriesPath("/library", locale)}>
                        <CheckCircle2 className="size-4" /> In library
                      </Link>
                    </Button>
                  ) : accountSession.isSignedIn ? (
                    <Button className="rounded-full bg-[#112a55] text-white hover:bg-[#19396f]" disabled={!canAccept || acceptMutation.isPending || !library.canAddSeries} onClick={() => acceptMutation.mutate()}>
                      <Plus className="size-4" /> {library.canAddSeries ? "Add to library" : "Library limit reached"}
                    </Button>
                  ) : (
                    <Button asChild className="rounded-full bg-[#112a55] text-white hover:bg-[#19396f]">
                      <Link to={localizedSeriesPath("/sign-in", locale)}>
                        <Plus className="size-4" /> Sign in to add
                      </Link>
                    </Button>
                  )}
                  <span className="inline-flex min-h-10 items-center gap-2 rounded-full border border-[#d7c494] bg-white/55 px-4 text-sm font-bold text-[#53617a]">
                    <Clock className="size-4" /> {invite.status}
                  </span>
                </div>

                {acceptMutation.isError ? <p className="mt-4 text-sm font-semibold text-[#b15b22]">{acceptMutation.error.message}</p> : null}
              </div>
            </div>
          </Card>
        ) : null}
      </section>
    </SeriesAppShell>
  );
}
