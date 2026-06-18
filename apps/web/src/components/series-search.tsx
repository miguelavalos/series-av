import { EmptyState, ErrorState } from "@avalsys/apps-av-web";
import { useQuery } from "@tanstack/react-query";
import { Calendar, Search } from "lucide-react";
import { useMemo, useState } from "react";
import { SeriesApiClient } from "@/lib/series-api-client";
import { getSeriesApiBaseUrl } from "@/lib/series-config";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { useSeriesApiLocale, useSeriesText } from "@/lib/series-i18n";

export function SeriesSearch() {
  const apiLocale = useSeriesApiLocale();
  const text = useSeriesText();
  const [query, setQuery] = useState("The Bear");
  const client = useMemo(() => new SeriesApiClient(getSeriesApiBaseUrl()), []);
  const trimmedQuery = query.trim();
  const search = useQuery({
    enabled: trimmedQuery.length > 1,
    queryFn: () => client.searchSeries({ query: trimmedQuery, locale: apiLocale, limit: 12 }),
    queryKey: ["series-av", "search", apiLocale, trimmedQuery]
  });

  return (
    <section className="flex flex-col gap-6">
      <div className="series-paper rounded-[1.5rem] border border-[#d7c494] p-5 shadow-lg shadow-[#172f5c]/8 sm:p-6">
        <div className="mb-5">
          <h1 className="text-3xl font-semibold text-[#112a55]">{text.search.title}</h1>
          <p className="mt-2 max-w-2xl text-sm leading-6 text-[#53617a]">
            {text.search.description}
          </p>
        </div>
        <label className="relative flex-1">
          <span className="sr-only">{text.search.inputLabel}</span>
          <Search className="pointer-events-none absolute left-4 top-1/2 size-5 -translate-y-1/2 text-[#5a8f2f]" aria-hidden="true" />
          <Input
            className="h-13 rounded-full border-[#d7c494] bg-[#fff8df] pl-12 pr-4 text-base text-[#112a55] shadow-sm placeholder:text-[#748098]"
            onChange={(event) => setQuery(event.target.value)}
            placeholder={text.search.placeholder}
            value={query}
          />
        </label>
      </div>

      {search.isLoading ? <SearchGridSkeleton /> : null}
      {search.isError ? <ErrorState className="border-[#d7c494] bg-[#fff8df]" description={search.error.message} title={text.search.errorTitle} /> : null}
      {search.data && search.data.results.length === 0 ? <EmptyState className="border-[#d7c494] bg-[#fff8df]" description={text.search.emptyBody} title={text.search.emptyTitle} /> : null}

      {search.data && search.data.results.length > 0 ? (
        <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
          {search.data.results.map((result) => (
            <Card key={result.id} className="gap-0 overflow-hidden rounded-[1.35rem] border-[#d7c494] bg-[#fff8df] py-0 shadow-sm shadow-[#172f5c]/8">
              <div className="aspect-[16/10] bg-[#ead6a5]">
                {result.posterUrl ? (
                  <img alt="" className="h-full w-full object-cover" loading="lazy" src={result.posterUrl} />
                ) : (
                  <div className="flex h-full items-center justify-center text-sm font-medium text-[#748098]">{text.search.noArtwork}</div>
                )}
              </div>
              <CardContent className="flex min-h-56 flex-col gap-3 p-4">
                <div>
                  <h2 className="line-clamp-2 text-base font-semibold text-[#112a55]">{result.title}</h2>
                  <p className="mt-2 flex items-center gap-2 text-xs font-medium uppercase tracking-[0.12em] text-[#5a8f2f]">
                    <Calendar className="size-3.5" aria-hidden="true" />
                    {result.firstAirDate ?? text.search.dateUnknown}
                  </p>
                </div>
                <p className="line-clamp-4 text-sm leading-6 text-[#53617a]">
                  {result.overview || text.search.noOverview}
                </p>
              </CardContent>
            </Card>
          ))}
        </div>
      ) : null}
    </section>
  );
}

function SearchGridSkeleton() {
  return (
    <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3">
      {Array.from({ length: 6 }).map((_, index) => (
        <div key={index} className="h-72 animate-pulse rounded-[1.35rem] border border-[#d7c494] bg-[#fff8df]" />
      ))}
    </div>
  );
}
