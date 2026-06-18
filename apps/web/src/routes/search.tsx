import { AccountUserButton } from "@avalsys/account-av-web";
import { AppShell } from "@avalsys/apps-av-web";
import { createFileRoute } from "@tanstack/react-router";
import { ProtectedRoute } from "@/components/protected-route";
import { SeriesSearch } from "@/components/series-search";
import { seriesNavLinks, seriesProductConfig } from "@/lib/series-config";
import { useSeriesText } from "@/lib/series-i18n";

export const Route = createFileRoute("/search")({
  component: SearchRoute
});

function SearchRoute() {
  const text = useSeriesText();

  return (
    <ProtectedRoute>
      <AppShell accountArea={<AccountUserButton />} footerLabels={text.footer} navLinks={seriesNavLinks} product={seriesProductConfig}>
        <SeriesSearch />
      </AppShell>
    </ProtectedRoute>
  );
}
