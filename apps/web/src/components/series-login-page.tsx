import { Link } from "@tanstack/react-router";
import { ArrowRight, BookOpenCheck, ListChecks, Search, Sparkles } from "lucide-react";
import type { ReactNode } from "react";
import { AvAppFooter, useAppsAvLocale } from "@avalsys/apps-av-web";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { seriesBrandAssets } from "@/lib/series-config";
import { localizedSeriesPath, useSeriesProductConfig, useSeriesText } from "@/lib/series-i18n";

export function SeriesLoginPage() {
  const locale = useAppsAvLocale();
  const text = useSeriesText();
  const productConfig = useSeriesProductConfig();
  const guestHomeScenes = [
    {
      alt: "",
      className: "series-guest-scene-card series-guest-scene-card--left",
      src: seriesBrandAssets.guestHomePlanning
    },
    {
      alt: "",
      className: "series-guest-scene-card series-guest-scene-card--right",
      src: seriesBrandAssets.guestHomeAvi
    }
  ];

  return (
    <div className="series-paper min-h-screen overflow-hidden px-4 pt-4 sm:px-6">
      <header className="mx-auto mb-4 flex max-w-7xl items-center px-1">
        <div className="rounded-2xl border border-[#d7c494]/72 bg-[#fff8df]/88 px-3 py-2 shadow-sm shadow-[#172f5c]/8 backdrop-blur">
          <img className="h-8 w-auto max-w-[168px] object-contain sm:h-9 sm:max-w-[190px]" src={seriesBrandAssets.wordmark} alt="Series AV" />
        </div>
      </header>
      <main className="series-guest-shell mx-auto min-h-[calc(100vh-6rem)] w-full max-w-7xl overflow-hidden rounded-[1.75rem] border border-[#d7c494] bg-[#fff6da]/88 shadow-2xl shadow-[#172f5c]/16 backdrop-blur">
        <img className="series-guest-backdrop" src={seriesBrandAssets.guestHomeShelf} alt="" />
        <div className="series-guest-overlay" />

        <section className="relative z-10 grid min-h-[calc(100vh-6rem)] min-w-0 gap-8 p-4 sm:p-8 lg:grid-cols-[0.84fr_1.16fr] lg:p-10 xl:p-12">
          <div className="series-guest-copy flex min-w-0 flex-col justify-between gap-10 rounded-[1.35rem] border border-[#d7c494]/82 bg-[#fff8df]/86 p-5 shadow-xl shadow-[#172f5c]/12 backdrop-blur-md sm:p-8 lg:p-10">
            <div>
              <img className="h-auto w-48 sm:w-64" src={seriesBrandAssets.logo} alt="Series AV" />
              <p className="mt-4 max-w-sm text-sm leading-6 text-[#314568]">
                {text.login.intro}
              </p>
            </div>

            <div className="max-w-xl">
              <h1 className="series-guest-title max-w-full text-[2.35rem] font-semibold leading-[1.03] text-[#112a55] sm:text-5xl xl:text-6xl">
                {text.login.heroTitle}
              </h1>
              <p className="series-guest-body mt-6 text-base leading-7 text-[#334766]">
                {text.login.heroBody}
              </p>
              <div className="mt-8 flex flex-wrap gap-3">
                <Button asChild className="h-12 rounded-full bg-[#112a55] px-5 text-white shadow-lg shadow-[#112a55]/18 hover:bg-[#19396f]">
                  <Link to={localizedSeriesPath("/sign-in", locale)}>
                    {text.login.cta}
                    <ArrowRight className="size-4" aria-hidden="true" />
                  </Link>
                </Button>
              </div>
            </div>

            <div className="grid gap-3 text-sm text-[#334766] sm:grid-cols-3 lg:grid-cols-1 xl:grid-cols-3">
              <LoginMetric icon={<Search className="size-4" aria-hidden="true" />} label={text.login.search} />
              <LoginMetric icon={<Sparkles className="size-4" aria-hidden="true" />} label={text.login.aviGuidance} />
              <LoginMetric icon={<BookOpenCheck className="size-4" aria-hidden="true" />} label={text.login.notebook} />
            </div>
          </div>

          <div className="series-guest-gallery relative min-h-[32rem] min-w-0 overflow-hidden rounded-[1.35rem] border border-white/22 bg-[#10284f]/30 shadow-2xl shadow-[#172f5c]/20">
            {guestHomeScenes.map((scene) => (
              <img key={scene.src} className={scene.className} src={scene.src} alt={scene.alt} />
            ))}
            <Card className="series-guest-note relative z-10 mt-auto max-w-sm gap-2 rounded-2xl border-[#d4bf88] bg-[#fff8df]/90 p-5 py-5 text-[#112a55] shadow-xl shadow-[#112a55]/14 backdrop-blur-md">
              <p className="flex items-center gap-2 text-sm font-semibold">
                <ListChecks className="size-4 text-[#6DBE45]" aria-hidden="true" />
                {text.login.cardTitle}
              </p>
              <p className="mt-2 text-sm leading-6 text-[#47566f]">
                {text.login.cardBody}
              </p>
            </Card>
            <div className="series-guest-caption relative z-10 max-w-sm rounded-2xl border border-[#d7c494]/82 bg-[#fff8df]/86 p-5 text-[#112a55] shadow-xl shadow-[#112a55]/12 backdrop-blur-md">
              <p className="font-serif text-3xl leading-tight">{text.login.mapTitle}</p>
              <p className="mt-4 text-sm leading-6 text-[#3d4e68]">{text.login.mapBody}</p>
            </div>
          </div>
        </section>
      </main>
      <AvAppFooter className="mt-4 border-transparent bg-transparent px-0 pb-4 pt-2" labels={text.footer} product={productConfig} />
    </div>
  );
}

function LoginMetric({ icon, label }: { icon: ReactNode; label: string }) {
  return (
    <div className="flex min-h-12 items-center gap-2 rounded-xl border border-[#d7c494] bg-[#fff8df]/72 px-3 shadow-sm shadow-[#172f5c]/5">
      <span className="text-[#5a8f2f]">{icon}</span>
      <span className="font-medium text-[#334766]">{label}</span>
    </div>
  );
}
