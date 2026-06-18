import { AccountUserButton } from "@avalsys/account-av-web";
import { AppShell } from "@avalsys/apps-av-web";
import type { ReactNode } from "react";
import { useSeriesNavLinks, useSeriesProductConfig, useSeriesShellLabels, useSeriesText } from "@/lib/series-i18n";

export function SeriesAppShell({ children }: { children: ReactNode }) {
  const text = useSeriesText();
  const navLinks = useSeriesNavLinks();
  const productConfig = useSeriesProductConfig();
  const shellLabels = useSeriesShellLabels();

  return (
    <AppShell accountArea={<AccountUserButton />} footerLabels={text.footer} labels={shellLabels} navLinks={navLinks} product={productConfig}>
      {children}
    </AppShell>
  );
}
