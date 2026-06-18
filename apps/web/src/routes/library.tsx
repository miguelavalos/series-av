import { AccountUserButton } from "@avalsys/account-av-web";
import { AppShell } from "@avalsys/apps-av-web";
import { Link, createFileRoute } from "@tanstack/react-router";
import { Archive, BookOpenCheck, CalendarDays, ListChecks, Search } from "lucide-react";
import type { ReactNode } from "react";
import { ProtectedRoute } from "@/components/protected-route";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { seriesNavLinks, seriesProductConfig } from "@/lib/series-config";

export const Route = createFileRoute("/library")({
  component: LibraryRoute
});

const filters = ["All", "Watching", "Want to watch", "Watched", "Archived"];

function LibraryRoute() {
  return (
    <ProtectedRoute>
      <AppShell accountArea={<AccountUserButton />} navLinks={seriesNavLinks} product={seriesProductConfig}>
        <section className="grid gap-6 lg:grid-cols-[1fr_22rem]">
          <Card className="series-paper gap-0 rounded-[1.5rem] border-[#d7c494] p-6 py-6 shadow-lg shadow-[#172f5c]/8 sm:p-8 sm:py-8">
            <div className="flex flex-col gap-5 sm:flex-row sm:items-start sm:justify-between">
              <div>
                <p className="text-sm font-semibold text-[#5a8f2f]">Library</p>
                <h1 className="mt-2 text-4xl font-semibold leading-tight text-[#112a55]">Your saved series, ordered for the next episode.</h1>
                <p className="mt-4 max-w-2xl text-base leading-7 text-[#334766]">
                  Keep watching, plan what comes next, and move finished shows out of the way without losing them.
                </p>
              </div>
              <Button asChild className="rounded-full bg-[#112a55] text-white hover:bg-[#19396f]">
                <Link to="/search">
                  <Search className="size-4" aria-hidden="true" />
                  Add series
                </Link>
              </Button>
            </div>

            <div className="mt-8 flex flex-wrap gap-2">
              {filters.map((filter, index) => (
                <button
                  key={filter}
                  className={index === 0 ? "rounded-full bg-[#112a55] px-3 py-2 text-sm font-semibold text-white" : "rounded-full border border-[#d7c494] bg-[#fff8df]/80 px-3 py-2 text-sm font-semibold text-[#334766] transition hover:border-[#8bc342] hover:text-[#112a55]"}
                  type="button"
                >
                  {filter}
                </button>
              ))}
            </div>

            <div className="mt-8 rounded-2xl border border-dashed border-[#c8ad72] bg-[#fff8df]/70 p-8 text-center">
              <BookOpenCheck className="mx-auto size-10 text-[#5a8f2f]" aria-hidden="true" />
              <h2 className="mt-4 text-2xl font-semibold text-[#112a55]">Start by saving a series.</h2>
              <p className="mx-auto mt-3 max-w-lg text-sm leading-6 text-[#53617a]">
                Search the catalog, choose a show, and Series AV will keep the next episode and progress notes together here.
              </p>
            </div>
          </Card>

          <aside className="grid gap-4">
            <LibraryHint icon={<ListChecks className="size-4" />} title="Watching" text="Active shows stay at the top so the next step is easy to find." />
            <LibraryHint icon={<CalendarDays className="size-4" />} title="Upcoming" text="New episodes can surface beside the shows you already follow." />
            <LibraryHint icon={<Archive className="size-4" />} title="Archive" text="Finished or paused series stay available without crowding the main list." />
          </aside>
        </section>
      </AppShell>
    </ProtectedRoute>
  );
}

function LibraryHint({ icon, text, title }: { icon: ReactNode; text: string; title: string }) {
  return (
    <Card className="gap-2 rounded-[1.25rem] border-[#d7c494] bg-[#fff8df]/88 p-5 py-5 text-[#112a55] shadow-sm shadow-[#172f5c]/6">
      <div className="flex items-center gap-2 text-sm font-semibold">
        <span className="text-[#5a8f2f]">{icon}</span>
        {title}
      </div>
      <p className="text-sm leading-6 text-[#53617a]">{text}</p>
    </Card>
  );
}
