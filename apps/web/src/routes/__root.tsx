import { AccountAvProvider } from "@avalsys/account-av-web";
import { AppsAvWebProvider, useAppsAvLocale } from "@avalsys/apps-av-web";
import { HeadContent, Outlet, Scripts, createRootRoute } from "@tanstack/react-router";
import type { ReactNode } from "react";
import { getAccountApiBaseUrl, getAccountPublishableKey } from "@/lib/series-config";
import { useSeriesAccountLocalization, useSeriesText } from "@/lib/series-i18n";
import "../styles.css";

export const Route = createRootRoute({
  component: RootComponent,
  head: () => ({
    meta: [
      { charSet: "utf-8" },
      { name: "viewport", content: "width=device-width, initial-scale=1" },
      { title: "Series AV" }
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
  const publishableKey = getAccountPublishableKey();
  const locale = useAppsAvLocale();
  const localization = useSeriesAccountLocalization();

  return (
    <html lang={locale}>
      <head>
        <HeadContent />
      </head>
      <body>
        <AppsAvWebProvider>
          {publishableKey ? (
            <AccountAvProvider
              accountApiBaseUrl={getAccountApiBaseUrl()}
              afterSignOutUrl="/sign-in"
              appDisplayName="Series AV"
              appId="seriesav"
              localization={localization}
              publishableKey={publishableKey}
              signInUrl="/sign-in"
              signUpUrl="/sign-in"
            >
              {children}
            </AccountAvProvider>
          ) : (
            <MissingAuthConfiguration />
          )}
        </AppsAvWebProvider>
        <Scripts />
      </body>
    </html>
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
