import { Link } from "@tanstack/react-router";
import { ArrowRight, BookOpenCheck, Search, Sparkles } from "lucide-react";
import type { ReactNode } from "react";
import { AvAppFooter, useAppsAvLocale } from "@avalsys/apps-av-web";
import { Button } from "@/components/ui/button";
import { seriesBrandAssets } from "@/lib/series-config";
import { localizedSeriesPath, useSeriesProductConfig, useSeriesText } from "@/lib/series-i18n";

export function SeriesLoginPage({ comingSoon = false }: { comingSoon?: boolean }) {
  const locale = useAppsAvLocale();
  const text = useSeriesText();
  const productConfig = useSeriesProductConfig();

  return (
    <div className="series-paper min-h-screen overflow-hidden px-4 pt-4 sm:px-6">
      <main className="series-guest-shell mx-auto min-h-[31rem] w-full max-w-6xl overflow-hidden rounded-lg border border-[#d7c494] bg-[#fff6da]/88 shadow-2xl shadow-[#172f5c]/16 backdrop-blur">
        <img className="series-guest-backdrop" src={seriesBrandAssets.guestHomeShelf} alt="" />
        <div className="series-guest-overlay" />

        <section className="series-guest-copy relative z-10">
          <div className="flex flex-wrap items-center justify-between gap-4">
            <img className="h-auto w-48 sm:w-64" src={seriesBrandAssets.logo} alt="Series AV" />
            {!comingSoon ? (
              <Button asChild className="h-11 rounded-full bg-[#112a55] px-5 text-white shadow-lg shadow-[#112a55]/18 hover:bg-[#19396f]">
                <Link to={localizedSeriesPath("/sign-in", locale)}>
                  {text.login.cta}
                  <ArrowRight className="size-4" aria-hidden="true" />
                </Link>
              </Button>
            ) : null}
          </div>

          <div className="max-w-2xl">
            <p className="mb-4 max-w-sm text-sm font-semibold leading-6 text-[#5a8f2f]">
              {text.login.intro}
            </p>
            <h1 className="series-guest-title max-w-full text-[2.35rem] font-semibold leading-[1.03] text-[#112a55] sm:text-5xl xl:text-6xl">
              {text.login.heroTitle}
            </h1>
            <p className="series-guest-body mt-5 max-w-xl text-base leading-7 text-[#334766]">
              {text.login.heroBody}
            </p>
            {comingSoon ? (
              <div className="mt-6 flex flex-wrap gap-3">
                <Button disabled className="h-12 rounded-full bg-[#112a55] px-5 text-white shadow-lg shadow-[#112a55]/18 disabled:opacity-100">
                  {comingSoonLabel(locale)}
                </Button>
              </div>
            ) : null}
          </div>

          <div className="rounded-lg border border-[#d7c494] bg-[#fff8df]/74 p-4 shadow-sm shadow-[#172f5c]/5">
            <p className="text-sm font-bold text-[#112a55]">{text.login.cardTitle}</p>
            <p className="mt-2 text-sm leading-6 text-[#334766]">{text.login.cardBody}</p>
            <div className="mt-4 grid gap-2 text-sm text-[#334766] sm:grid-cols-3 lg:grid-cols-1 xl:grid-cols-3">
              <LoginMetric icon={<Search className="size-4" aria-hidden="true" />} label={text.login.search} />
              <LoginMetric icon={<Sparkles className="size-4" aria-hidden="true" />} label={text.login.aviGuidance} />
              <LoginMetric icon={<BookOpenCheck className="size-4" aria-hidden="true" />} label={text.login.notebook} />
            </div>
          </div>
        </section>

        <div className="series-guest-gallery" aria-hidden="true">
          <img className="series-guest-gallery-image" src={seriesBrandAssets.guestHomePlanning} alt="" />
          <div className="series-guest-caption">
            <p className="font-serif text-3xl leading-tight">{text.login.mapTitle}</p>
            <p className="mt-4 text-sm leading-6 text-[#3d4e68]">{text.login.mapBody}</p>
          </div>
        </div>
      </main>
      <AvAppFooter className="mt-4 border-transparent bg-transparent px-0 pb-4 pt-2" labels={text.footer} product={productConfig} />
    </div>
  );
}

function comingSoonLabel(locale: ReturnType<typeof useAppsAvLocale>) {
  return ({ ca: "Properament", de: "Demnächst", en: "Coming soon", es: "Próximamente", fr: "Prochainement" } as const)[locale] ?? "Coming soon";
}

function LoginMetric({ icon, label }: { icon: ReactNode; label: string }) {
  return (
    <div className="flex min-h-12 items-center gap-2 rounded-xl border border-[#d7c494] bg-[#fff8df]/72 px-3 shadow-sm shadow-[#172f5c]/5">
      <span className="text-[#5a8f2f]">{icon}</span>
      <span className="font-medium text-[#334766]">{label}</span>
    </div>
  );
}
