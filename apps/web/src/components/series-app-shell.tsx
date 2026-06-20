import { AccountUserButton } from "@avalsys/account-av-web";
import { AppShell } from "@avalsys/apps-av-web";
import { useRouterState } from "@tanstack/react-router";
import type { ReactNode } from "react";
import { useSeriesNavLinks, useSeriesProductConfig, useSeriesShellLabels, useSeriesText } from "@/lib/series-i18n";

export function SeriesAppShell({ children, showAssistant = true }: { children: ReactNode; showAssistant?: boolean }) {
  const text = useSeriesText();
  const navLinks = useSeriesNavLinks();
  const productConfig = useSeriesProductConfig();
  const product = showAssistant ? productConfig : { ...productConfig, assistant: undefined };
  const shellLabels = useSeriesShellLabels();
  const currentPath = useRouterState({ select: (state) => state.location.pathname });

  return (
    <AppShell accountArea={<AccountUserButton />} currentPath={currentPath} footerLabels={text.footer} labels={shellLabels} navLinks={navLinks} product={product}>
      {children}
    </AppShell>
  );
}
