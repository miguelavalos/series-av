import { useAppsAvLocale } from "@avalsys/apps-av-web";
import { Link, createFileRoute } from "@tanstack/react-router";
import { Globe, HelpCircle, Trash2 } from "lucide-react";
import { ProtectedRoute } from "@/components/protected-route";
import { SeriesAppShell } from "@/components/series-app-shell";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { seriesProductConfig } from "@/lib/series-config";
import { useSeriesLibrary } from "@/lib/series-library-provider";
import { localizedSeriesPath } from "@/lib/series-i18n";

export const Route = createFileRoute("/settings")({
  component: SettingsRoute
});

function SettingsRoute() {
  const locale = useAppsAvLocale();
  const library = useSeriesLibrary();
  const locales = ["en", "es", "fr", "de", "ca"] as const;

  return (
    <ProtectedRoute>
      <SeriesAppShell>
        <section className="grid gap-6 lg:grid-cols-[1fr_22rem]">
          <Card className="series-paper gap-5 rounded-lg border-[#d7c494] p-6 py-6 shadow-lg shadow-[#172f5c]/8 sm:p-8 sm:py-8">
            <div>
              <p className="text-sm font-semibold text-[#5a8f2f]">Settings</p>
              <h1 className="mt-2 text-4xl font-semibold leading-tight text-[#112a55]">Series preferences</h1>
              <p className="mt-3 max-w-2xl text-sm leading-6 text-[#53617a]">Keep language, local library state, support, and legal surfaces close to the signed-in app.</p>
            </div>
            <section className="rounded-lg border border-[#d7c494] bg-[#fff8df]/72 p-4">
              <h2 className="flex items-center gap-2 font-semibold text-[#112a55]">
                <Globe className="size-4 text-[#5a8f2f]" /> Language
              </h2>
              <div className="mt-3 flex flex-wrap gap-2">
                {locales.map((item) => (
                  <Button key={item} asChild variant={locale === item ? "default" : "outline"} className={locale === item ? "rounded-full bg-[#112a55] text-white" : "rounded-full border-[#c8ad72] bg-white/60"}>
                    <Link to={localizedSeriesPath("/settings", item)}>{item.toUpperCase()}</Link>
                  </Button>
                ))}
              </div>
            </section>
            <section className="rounded-lg border border-[#d7c494] bg-[#fff8df]/72 p-4">
              <h2 className="flex items-center gap-2 font-semibold text-[#112a55]">
                <Trash2 className="size-4 text-[#5a8f2f]" /> On this browser
              </h2>
              <p className="mt-2 text-sm leading-6 text-[#53617a]">Clear the local browser copy. Cloud state remains account-owned and will sync again when available.</p>
              <Button variant="outline" className="mt-3 rounded-full border-red-200 bg-white/60 text-red-700" disabled={library.entries.length === 0} onClick={() => library.clearLocalData()}>
                Clear local library
              </Button>
            </section>
          </Card>
          <Card className="gap-3 rounded-lg border-[#d7c494] bg-[#fff8df]/88 p-5 py-5 text-[#112a55] shadow-sm shadow-[#172f5c]/6">
            <h2 className="flex items-center gap-2 font-semibold">
              <HelpCircle className="size-4 text-[#5a8f2f]" /> Help and legal
            </h2>
            <a className="text-sm font-semibold text-[#112a55] underline" href={seriesProductConfig.links.support?.href}>Support</a>
            <a className="text-sm font-semibold text-[#112a55] underline" href={seriesProductConfig.links.privacy?.href}>Privacy</a>
            <a className="text-sm font-semibold text-[#112a55] underline" href={seriesProductConfig.links.terms?.href}>Terms</a>
            <a className="text-sm font-semibold text-[#112a55] underline" href={seriesProductConfig.links.deleteAccount?.href}>Delete account</a>
          </Card>
        </section>
      </SeriesAppShell>
    </ProtectedRoute>
  );
}
