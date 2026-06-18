import { AccountUserButton } from "@avalsys/account-av-web";
import { AppShell } from "@avalsys/apps-av-web";
import { Link, createFileRoute } from "@tanstack/react-router";
import { BookOpenCheck, CalendarDays, Compass, Search, Sparkles } from "lucide-react";
import type { ReactNode } from "react";
import { ProtectedRoute } from "@/components/protected-route";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { seriesBrandAssets, seriesNavLinks, seriesProductConfig } from "@/lib/series-config";
import { useSeriesText } from "@/lib/series-i18n";

export const Route = createFileRoute("/avi")({
  component: AviRoute
});

function AviRoute() {
  const text = useSeriesText();

  return (
    <ProtectedRoute>
      <AppShell accountArea={<AccountUserButton />} footerLabels={text.footer} navLinks={seriesNavLinks} product={seriesProductConfig}>
        <section className="grid gap-6 lg:grid-cols-[1.05fr_0.95fr]">
          <Card className="series-paper gap-0 overflow-hidden rounded-[1.5rem] border-[#d7c494] p-0 text-[#112a55] shadow-lg shadow-[#172f5c]/8">
            <div className="grid min-h-[32rem] lg:grid-cols-[0.95fr_1.05fr]">
              <div className="flex flex-col justify-between gap-8 p-6 sm:p-8">
                <div>
                  <p className="flex items-center gap-2 text-sm font-semibold text-[#5a8f2f]">
                    <Sparkles className="size-4" aria-hidden="true" />
                    Avi
                  </p>
                  <h1 className="mt-3 text-4xl font-semibold leading-tight">A calm guide for your next episode.</h1>
                  <p className="mt-4 text-base leading-7 text-[#334766]">
                    Avi helps turn a messy watch list into a clear next step: continue, save, catch up, or discover something that fits your habits.
                  </p>
                </div>
                <div className="flex flex-wrap gap-3">
                  <Button asChild className="rounded-full bg-[#112a55] text-white hover:bg-[#19396f]">
                    <Link to="/search">
                      <Search className="size-4" aria-hidden="true" />
                      Find a series
                    </Link>
                  </Button>
                  <Button asChild variant="outline" className="rounded-full border-[#c8ad72] bg-[#fff8df]/76">
                    <Link to="/library">Open library</Link>
                  </Button>
                </div>
              </div>
              <div className="relative min-h-80 overflow-hidden bg-[#10284f]">
                <div className="absolute inset-0 bg-[linear-gradient(160deg,#17386c_0%,#10284f_56%,#07162e_100%)]" />
                <img className="relative h-full w-full object-cover object-bottom" src={seriesBrandAssets.aviLoginPeek} alt="" />
              </div>
            </div>
          </Card>

          <div className="grid gap-4">
            <AviCard icon={<BookOpenCheck className="size-4" />} title="Prepare the notebook" text="Avi can point out which shows need a saved status, a next episode, or a cleaner progress note." />
            <AviCard icon={<CalendarDays className="size-4" />} title="Choose what is next" text="Upcoming episodes and active shows stay readable, so the next action does not get buried." />
            <AviCard icon={<Compass className="size-4" />} title="Discover with context" text="Recommendations can grow from what you actually watch instead of starting from a blank catalog." />
          </div>
        </section>
      </AppShell>
    </ProtectedRoute>
  );
}

function AviCard({ icon, text, title }: { icon: ReactNode; text: string; title: string }) {
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
