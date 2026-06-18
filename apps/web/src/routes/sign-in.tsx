import { AccountSignIn, SignedIn, SignedOut } from "@avalsys/account-av-web";
import { AvAppFooter } from "@avalsys/apps-av-web";
import { Link, createFileRoute } from "@tanstack/react-router";
import { ArrowLeft } from "lucide-react";
import { seriesBrandAssets, seriesProductConfig } from "@/lib/series-config";
import { useSeriesText } from "@/lib/series-i18n";

export const Route = createFileRoute("/sign-in")({
  component: SignInRoute
});

function SignInRoute() {
  const text = useSeriesText();

  return (
    <div className="series-paper flex min-h-screen flex-col bg-[#fff3cf]">
      <main className="grid flex-1 lg:grid-cols-[0.92fr_1.08fr]">
        <section className="relative hidden min-h-screen overflow-hidden bg-[#10284f] p-10 text-white lg:flex lg:flex-col lg:justify-between">
          <div className="absolute inset-0 bg-[radial-gradient(circle_at_72%_25%,rgba(109,190,69,0.2),transparent_28%),linear-gradient(160deg,#17386c_0%,#10284f_54%,#07162e_100%)]" />
          <Link className="relative inline-flex items-center gap-2 text-sm font-medium text-white/76 transition hover:text-white" to="/">
            <ArrowLeft className="size-4" aria-hidden="true" />
            Series AV
          </Link>
          <div className="relative max-w-md">
            <img className="mb-10 h-auto w-64 brightness-0 invert" src={seriesBrandAssets.logo} alt="Series AV" />
            <h1 className="text-4xl font-semibold leading-tight">{text.signIn.title}</h1>
            <p className="mt-5 text-base leading-7 text-white/70">
              {text.signIn.body}
            </p>
          </div>
          <div className="relative overflow-hidden rounded-[1.5rem] border border-white/12 bg-[#fff0c7] p-5 pb-0 text-[#112a55] shadow-2xl shadow-black/22">
            <div className="relative z-10 max-w-xs pb-28">
              <p className="text-sm font-semibold text-[#5a8f2f]">Avi</p>
              <p className="mt-2 font-serif text-3xl leading-tight">{text.signIn.aviPanelBody}</p>
            </div>
            <img
              className="absolute bottom-0 right-6 w-52 translate-y-8 drop-shadow-2xl"
              src={seriesBrandAssets.aviLoginSheetPeek}
              alt="Avi"
            />
          </div>
        </section>

        <section className="flex min-h-screen items-center justify-center px-5 py-10">
          <div className="w-full max-w-md">
            <Link className="mb-8 inline-flex items-center gap-2 text-sm font-medium text-[#334766] transition hover:text-[#112a55] lg:hidden" to="/">
              <ArrowLeft className="size-4" aria-hidden="true" />
              Series AV
            </Link>
            <img className="mb-8 h-auto w-64 lg:hidden" src={seriesBrandAssets.logo} alt="Series AV" />
            <SignedIn>
              <div className="rounded-2xl border border-[#d7c494] bg-[#fff8df] p-6 text-center shadow-lg shadow-[#172f5c]/10">
                <p className="text-sm font-semibold text-[#112a55]">{text.signIn.signedIn}</p>
                <Link className="mt-4 inline-flex h-10 items-center justify-center rounded-full bg-[#112a55] px-4 text-sm font-semibold text-white" to="/">
                  {text.signIn.continue}
                </Link>
              </div>
            </SignedIn>
            <SignedOut>
              <AccountSignIn fallbackRedirectUrl="/" path="/sign-in" />
            </SignedOut>
          </div>
        </section>
      </main>
      <AvAppFooter labels={text.footer} product={seriesProductConfig} />
    </div>
  );
}
