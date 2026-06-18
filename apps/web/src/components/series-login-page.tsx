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

  return (
    <div className="series-paper min-h-screen overflow-hidden px-5 pt-5 sm:px-8">
      <main className="mx-auto grid min-h-[calc(100vh-6rem)] max-w-6xl overflow-hidden rounded-[1.75rem] border border-[#d7c494] bg-[#fff6da]/88 shadow-2xl shadow-[#172f5c]/16 backdrop-blur md:grid-cols-[0.95fr_1.05fr]">
        <section className="flex flex-col justify-between gap-10 p-7 sm:p-10 lg:p-12">
          <div>
            <img className="h-auto w-56 sm:w-64" src={seriesBrandAssets.logo} alt="Series AV" />
            <p className="mt-4 max-w-sm text-sm leading-6 text-[#314568]">
              {text.login.intro}
            </p>
          </div>

          <div className="max-w-xl">
            <h1 className="text-5xl font-semibold leading-[1.02] text-[#112a55] sm:text-6xl">
              {text.login.heroTitle}
            </h1>
            <p className="mt-6 max-w-lg text-base leading-7 text-[#334766]">
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

          <div className="grid gap-3 text-sm text-[#334766] sm:grid-cols-3">
            <LoginMetric icon={<Search className="size-4" aria-hidden="true" />} label={text.login.search} />
            <LoginMetric icon={<Sparkles className="size-4" aria-hidden="true" />} label={text.login.aviGuidance} />
            <LoginMetric icon={<BookOpenCheck className="size-4" aria-hidden="true" />} label={text.login.notebook} />
          </div>
        </section>

        <section className="relative min-h-[32rem] overflow-hidden bg-[#10284f] p-6 text-white lg:min-h-full">
          <div className="absolute inset-0 bg-[radial-gradient(circle_at_78%_18%,rgba(109,190,69,0.24),transparent_30%),linear-gradient(160deg,#17386c_0%,#10284f_50%,#08172f_100%)]" />
          <div className="relative flex h-full flex-col justify-between gap-6 overflow-hidden rounded-[1.4rem] border border-white/14 bg-[#fff0c7] p-5 text-[#112a55] shadow-2xl shadow-black/24">
            <img className="absolute inset-y-0 right-0 h-full w-[58%] object-cover object-bottom opacity-95 sm:w-[56%]" src={seriesBrandAssets.onboarding} alt="" />
            <div className="relative max-w-xs">
              <p className="font-serif text-3xl leading-tight text-[#112a55]">{text.login.mapTitle}</p>
              <p className="mt-4 text-sm leading-6 text-[#3d4e68]">
                {text.login.mapBody}
              </p>
            </div>
            <Card className="relative mt-auto max-w-sm gap-2 rounded-2xl border-[#d4bf88] bg-[#fff8df]/88 p-5 py-5 text-[#112a55] shadow-xl shadow-[#112a55]/12">
              <p className="flex items-center gap-2 text-sm font-semibold">
                <ListChecks className="size-4 text-[#6DBE45]" aria-hidden="true" />
                {text.login.cardTitle}
              </p>
              <p className="mt-2 text-sm leading-6 text-[#47566f]">
                {text.login.cardBody}
              </p>
            </Card>
            <img
              className="absolute bottom-0 right-4 w-44 translate-y-8 drop-shadow-2xl sm:right-8 sm:w-52 lg:w-60"
              src={seriesBrandAssets.aviLoginSheetPeek}
              alt="Avi"
            />
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
