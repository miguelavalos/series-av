import { createFileRoute } from "@tanstack/react-router";
import { ProtectedRoute } from "@/components/protected-route";
import { SeriesAppShell } from "@/components/series-app-shell";
import { SeriesSearch } from "@/components/series-search";

export const Route = createFileRoute("/search")({
  component: SearchRoute
});

function SearchRoute() {
  return (
    <ProtectedRoute>
      <SeriesAppShell>
        <SeriesSearch />
      </SeriesAppShell>
    </ProtectedRoute>
  );
}
