import { AccountAvProvider } from "@avalsys/account-av-web";
import { AppsAvWebProvider } from "@avalsys/apps-av-web";
import { HeadContent, Outlet, Scripts, createRootRoute } from "@tanstack/react-router";
import type { ReactNode } from "react";
import { getAccountApiBaseUrl, getAccountPublishableKey } from "@/lib/series-config";
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

  return (
    <html lang="en">
      <head>
        <HeadContent />
      </head>
      <body>
        <AppsAvWebProvider>
          {publishableKey ? (
            <AccountAvProvider
              accountApiBaseUrl={getAccountApiBaseUrl()}
              afterSignOutUrl="/"
              appDisplayName="Series AV"
              appId="seriesav"
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
  return (
    <main className="mx-auto flex min-h-screen max-w-3xl flex-col justify-center px-6">
      <div className="rounded-lg border bg-card p-6 text-card-foreground shadow-sm">
        <p className="text-sm font-semibold uppercase tracking-[0.18em] text-muted-foreground">Configuration required</p>
        <h1 className="mt-4 text-3xl font-semibold text-foreground">Series AV Web needs Clerk configuration.</h1>
        <p className="mt-3 text-sm leading-6 text-muted-foreground">Run the web app through the Varlock wrapper so Account AV configuration is available. Web access is always login-first.</p>
      </div>
    </main>
  );
}
