import { AuthLoading, SignedIn, SignedOut } from "@avalsys/account-av-web";
import { AuthSkeleton, useAppsAvLocale } from "@avalsys/apps-av-web";
import { ProtectedAppGate } from "@avalsys/apps-av-web/src/components/protected-app-gate";
import type { ReactNode } from "react";
import { seriesBrandAssets } from "@/lib/series-config";
import { localizedSeriesPath, useSeriesProductConfig, useSeriesText } from "@/lib/series-i18n";

export function ProtectedRoute({ children }: { children: ReactNode }) {
  const text = useSeriesText();
  const locale = useAppsAvLocale();
  const productConfig = useSeriesProductConfig();
  const signInHref = localizedSeriesPath("/sign-in", locale);

  return (
    <>
      <AuthLoading>
        <AuthSkeleton />
      </AuthLoading>
      <SignedIn>{children}</SignedIn>
      <SignedOut>
        <ProtectedAppGate
          body={text.protected.body}
          cta={text.protected.cta}
          footerLabels={text.footer}
          logoAlt="Series AV"
          logoSrc={seriesBrandAssets.logo}
          mascotAlt="Avi"
          mascotSrc={seriesBrandAssets.aviFullBody}
          product={productConfig}
          signInHref={signInHref}
          title={text.protected.title}
        />
      </SignedOut>
    </>
  );
}
