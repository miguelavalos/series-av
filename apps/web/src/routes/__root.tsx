import { AccountAvProvider } from "@avalsys/account-av-web";
import { AppsAvWebProvider, getAppsAvLocaleFromSearch, useAppsAvLocale } from "@avalsys/apps-av-web";
import { applyAppsAvThemePreference, normalizeAppsAvThemePreference, readAppsAvThemePreference } from "@avalsys/apps-av-web/src/lib/theme-preference";
import { HeadContent, Outlet, Scripts, createRootRoute, useRouterState } from "@tanstack/react-router";
import { useEffect, type ReactNode } from "react";
import { getAccountApiBaseUrl, getAccountPublishableKey } from "@/lib/series-config";
import { localizedSeriesPath, useSeriesAccountLocalization, useSeriesText } from "@/lib/series-i18n";
import { SeriesLibraryProvider } from "@/lib/series-library-provider";
import "../styles.css";

const faviconUrl = "https://cdn.avalsys.com/apps-av/series-av/web-v3/favicon-32x32.png?v=20260619";
const appleTouchIconUrl = "https://cdn.avalsys.com/apps-av/series-av/web-v3/apple-touch-icon.png?v=20260619";

export const Route = createRootRoute({
  component: RootComponent,
  head: () => ({
    meta: [
      { charSet: "utf-8" },
      { name: "viewport", content: "width=device-width, initial-scale=1" },
      { title: "Series AV" }
    ],
    links: [
      { rel: "icon", type: "image/png", sizes: "32x32", href: faviconUrl },
      { rel: "apple-touch-icon", href: appleTouchIconUrl }
    ]
  })
});

function RootComponent() {
  return (
    <RootDocument>
      <Outlet />
    </RootDocument>
  );
}

function RootDocument({ children }: Readonly<{ children: ReactNode }>) {
  const search = useRouterState({ select: (state) => state.location.searchStr });
  const initialLocale = getAppsAvLocaleFromSearch(search);

  useEffect(() => {
    applyAppsAvThemePreference({
      attributeName: "seriesTheme",
      storageKey: seriesThemeStorageKey,
      theme: normalizeAppsAvThemePreference(readAppsAvThemePreference(seriesThemeStorageKey))
    });
  }, []);

  return (
    <html lang={initialLocale}>
      <head>
        <HeadContent />
      </head>
      <body>
        <AppsAvWebProvider initialLocale={initialLocale}>
          <AccountBoundary>{children}</AccountBoundary>
        </AppsAvWebProvider>
        <Scripts />
      </body>
    </html>
  );
}

const seriesThemeStorageKey = "series-av.theme";

function AccountBoundary({ children }: Readonly<{ children: ReactNode }>) {
  const publishableKey = getAccountPublishableKey();
  const locale = useAppsAvLocale();
  const localization = useSeriesAccountLocalization();

  if (!publishableKey) {
    return <MissingAuthConfiguration />;
  }

  return (
    <AccountAvProvider
      accountApiBaseUrl={getAccountApiBaseUrl()}
      afterSignOutUrl={localizedSeriesPath("/sign-in", locale)}
      appDisplayName="Series AV"
      appId="seriesav"
      localization={localization}
      publishableKey={publishableKey}
      signInUrl={localizedSeriesPath("/sign-in", locale)}
      signUpUrl={localizedSeriesPath("/sign-in", locale)}
    >
      <SeriesLibraryProvider>{children}</SeriesLibraryProvider>
    </AccountAvProvider>
  );
}

function MissingAuthConfiguration() {
  const text = useSeriesText();

  return (
    <main className="mx-auto flex min-h-screen max-w-3xl flex-col justify-center px-6">
      <div className="rounded-lg border bg-card p-6 text-card-foreground shadow-sm">
        <p className="text-sm font-semibold uppercase tracking-[0.18em] text-muted-foreground">{text.config.eyebrow}</p>
        <h1 className="mt-4 text-3xl font-semibold text-foreground">{text.config.title}</h1>
        <p className="mt-3 text-sm leading-6 text-muted-foreground">{text.config.body}</p>
      </div>
    </main>
  );
}
