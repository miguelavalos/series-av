import { AccountUserButton, SignedIn, SignedOut } from "@avalsys/account-av-web";
import { AppShell } from "@avalsys/apps-av-web";
import { Link, createFileRoute } from "@tanstack/react-router";
import { ArrowRight, BookOpenCheck, CalendarDays, Search, Sparkles } from "lucide-react";
import type { ReactNode } from "react";
import { SeriesLoginPage } from "@/components/series-login-page";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { seriesBrandAssets, seriesNavLinks, seriesProductConfig } from "@/lib/series-config";

export const Route = createFileRoute("/")({
  component: IndexRoute
});

function IndexRoute() {
  return (
    <>
      <SignedOut>
        <SeriesLoginPage />
      </SignedOut>
      <SignedIn>
        <AppShell accountArea={<AccountUserButton />} navLinks={seriesNavLinks} product={seriesProductConfig}>
          <section className="grid gap-6 lg:grid-cols-[1fr_22rem]">
            <Card className="series-paper gap-0 overflow-hidden rounded-[1.5rem] border-[#d7c494] p-6 py-6 shadow-lg shadow-[#172f5c]/8 sm:p-8 sm:py-8">
              <div className="flex flex-col gap-6 lg:flex-row lg:items-end lg:justify-between">
                <div>
                  <h1 className="max-w-2xl text-4xl font-semibold leading-tight text-[#112a55]">Pick up your series notebook.</h1>
                  <p className="mt-4 max-w-2xl text-base leading-7 text-[#334766]">
                    Search the catalog, save progress, and keep a clear map of what to watch next.
                  </p>
                </div>
                <Link to="/search">
                  Search catalog
                  <ArrowRight className="size-4" aria-hidden="true" />
                </Link>
              </div>
              <div className="mt-8 grid gap-3 sm:grid-cols-3">
                <NotebookItem icon={<Search className="size-4" />} label="Catalog search" value="Find series by title" />
                <NotebookItem icon={<BookOpenCheck className="size-4" />} label="Library" value="Keep your saved shows together" />
                <NotebookItem icon={<CalendarDays className="size-4" />} label="Next episodes" value="Return to what is coming up" />
              </div>
            </Card>
            <Card className="gap-0 overflow-hidden rounded-[1.5rem] border-[#d7c494] bg-[#10284f] p-0 text-white shadow-lg shadow-[#172f5c]/14">
              <div className="p-5">
                <div className="flex items-center gap-2 text-sm font-semibold text-[#b6dd89]">
                  <Sparkles className="size-4" aria-hidden="true" />
                  Avi keeps watch
                </div>
                <ul className="mt-4 flex flex-col gap-3 text-sm leading-6 text-white/74">
                  <li>Start from your current shows and find the next useful action.</li>
                  <li>Spot missing progress before the queue becomes hard to read.</li>
                  <li>Keep recommendations close to your real watching habits.</li>
                </ul>
              </div>
              <img className="mt-auto h-56 w-full object-cover object-bottom" src={seriesBrandAssets.onboarding} alt="" />
            </Card>
          </section>
        </AppShell>
      </SignedIn>
    </>
  );
}

function NotebookItem({ icon, label, value }: { icon: ReactNode; label: string; value: string }) {
  return (
    <div className="rounded-2xl border border-[#d7c494] bg-[#fff8df]/72 p-4 text-[#112a55]">
      <div className="flex items-center gap-2 text-sm font-semibold">
        <span className="text-[#5a8f2f]">{icon}</span>
        {label}
      </div>
      <p className="mt-2 text-sm text-[#53617a]">{value}</p>
    </div>
  );
}
