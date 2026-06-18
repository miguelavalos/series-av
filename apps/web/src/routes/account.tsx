import { AccountSignOutButton, useAccountUser } from "@avalsys/account-av-web";
import { createFileRoute } from "@tanstack/react-router";
import { RefreshCw, Shield, Sparkles } from "lucide-react";
import { ProtectedRoute } from "@/components/protected-route";
import { SeriesAppShell } from "@/components/series-app-shell";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { seriesProductConfig } from "@/lib/series-config";
import { useSeriesLibrary } from "@/lib/series-library-provider";

export const Route = createFileRoute("/account")({
  component: AccountRoute
});

function AccountRoute() {
  const account = useAccountUser();
  const library = useSeriesLibrary();
  const plan = library.access?.planTier ?? "free";

  return (
    <ProtectedRoute>
      <SeriesAppShell>
        <section className="grid gap-6 lg:grid-cols-[1fr_22rem]">
          <Card className="series-paper gap-5 rounded-lg border-[#d7c494] p-6 py-6 shadow-lg shadow-[#172f5c]/8 sm:p-8 sm:py-8">
            <div>
              <p className="text-sm font-semibold text-[#5a8f2f]">Account</p>
              <h1 className="mt-2 text-4xl font-semibold leading-tight text-[#112a55]">{account.data?.displayName ?? "Series AV"}</h1>
              <p className="mt-3 text-sm text-[#53617a]">{account.data?.email ?? "Signed in"}</p>
            </div>
            <div className="grid gap-3 sm:grid-cols-3">
              <Metric label="Plan" value={plan === "pro" ? "Pro" : "Free"} />
              <Metric label="Active limit" value={String(library.limit.activeLimit)} />
              <Metric label="Sync" value={library.syncState} />
            </div>
            <div className="flex flex-wrap gap-2">
              <Button className="rounded-full bg-[#112a55] text-white hover:bg-[#19396f]" onClick={() => void library.refreshSync()} disabled={library.syncState === "syncing"}>
                <RefreshCw className="size-4" /> Sync now
              </Button>
              <Button asChild variant="outline" className="rounded-full border-[#c8ad72] bg-white/60">
                <a href={seriesProductConfig.links.suite?.href}>Manage plan</a>
              </Button>
              <Button asChild variant="outline" className="rounded-full border-red-200 bg-white/60 text-red-700">
                <a href={seriesProductConfig.links.deleteAccount?.href}>Delete account</a>
              </Button>
              <AccountSignOutButton>
                <Button variant="outline" className="rounded-full border-[#c8ad72] bg-white/60">Sign out</Button>
              </AccountSignOutButton>
            </div>
            {library.syncError ? <p className="text-sm font-semibold text-red-700">{library.syncError}</p> : null}
          </Card>
          <Card className="gap-3 rounded-lg border-[#d7c494] bg-[#fff8df]/88 p-5 py-5 text-[#112a55] shadow-sm shadow-[#172f5c]/6">
            <div className="flex items-center gap-2 font-semibold">
              <Sparkles className="size-4 text-[#5a8f2f]" /> Pro access
            </div>
            <p className="text-sm leading-6 text-[#53617a]">Free accounts can keep 75 active series. Pro accounts can keep 1000 active series and cloud sync enabled when Account AV reports access.</p>
            <div className="flex items-center gap-2 font-semibold">
              <Shield className="size-4 text-[#5a8f2f]" /> Account safety
            </div>
            <p className="text-sm leading-6 text-[#53617a]">Account deletion is handled by Account AV so product data and identity cleanup use the existing account contract.</p>
          </Card>
        </section>
      </SeriesAppShell>
    </ProtectedRoute>
  );
}

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-[#d7c494] bg-[#fff8df]/72 p-4">
      <p className="text-sm font-semibold text-[#53617a]">{label}</p>
      <p className="mt-1 text-xl font-semibold text-[#112a55]">{value}</p>
    </div>
  );
}
