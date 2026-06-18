import { useAppsAvLocale } from "@avalsys/apps-av-web";
import { AccountSignOutButton, useAccountUser } from "@avalsys/account-av-web";
import { createFileRoute } from "@tanstack/react-router";
import { RefreshCw, Shield, Sparkles } from "lucide-react";
import { ProtectedRoute } from "@/components/protected-route";
import { SeriesAppShell } from "@/components/series-app-shell";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { seriesProductConfig } from "@/lib/series-config";
import { useSeriesLibrary } from "@/lib/series-library-provider";
import { localizedExternalUrl, useSeriesText } from "@/lib/series-i18n";

export const Route = createFileRoute("/account")({
  component: AccountRoute
});

function AccountRoute() {
  const account = useAccountUser();
  const library = useSeriesLibrary();
  const locale = useAppsAvLocale();
  const text = useSeriesText();
  const labels = accountLabels[locale];
  const plan = library.access?.planTier ?? "free";

  return (
    <ProtectedRoute>
      <SeriesAppShell>
        <section className="grid gap-6 lg:grid-cols-[1fr_22rem]">
          <Card className="series-paper gap-5 rounded-lg border-[#d7c494] p-6 py-6 shadow-lg shadow-[#172f5c]/8 sm:p-8 sm:py-8">
            <div>
              <p className="text-sm font-semibold text-[#5a8f2f]">{text.nav.account}</p>
              <h1 className="mt-2 text-4xl font-semibold leading-tight text-[#112a55]">{account.data?.displayName ?? "Series AV"}</h1>
              <p className="mt-3 text-sm text-[#53617a]">{account.data?.email ?? labels.signedIn}</p>
            </div>
            <div className="grid gap-3 sm:grid-cols-3">
              <Metric label={labels.plan} value={plan === "pro" ? "Pro" : "Free"} />
              <Metric label={labels.activeLimit} value={String(library.limit.activeLimit)} />
              <Metric label={labels.sync} value={labels.syncState[library.syncState] ?? library.syncState} />
            </div>
            <div className="flex flex-wrap gap-2">
              <Button className="rounded-full bg-[#112a55] text-white hover:bg-[#19396f]" onClick={() => void library.refreshSync()} disabled={library.syncState === "syncing"}>
                <RefreshCw className="size-4" /> {labels.syncNow}
              </Button>
              <Button asChild variant="outline" className="rounded-full border-[#c8ad72] bg-white/60">
                <a href={localizedExternalUrl(seriesProductConfig.links.suite?.href, locale)}>{labels.managePlan}</a>
              </Button>
              <Button asChild variant="outline" className="rounded-full border-red-200 bg-white/60 text-red-700">
                <a href={localizedExternalUrl(seriesProductConfig.links.deleteAccount?.href, locale)}>{text.footer.deleteAccount}</a>
              </Button>
              <AccountSignOutButton>
                <Button variant="outline" className="rounded-full border-[#c8ad72] bg-white/60">{labels.signOut}</Button>
              </AccountSignOutButton>
            </div>
            {library.syncError ? <p className="text-sm font-semibold text-red-700">{library.syncError}</p> : null}
          </Card>
          <Card className="gap-3 rounded-lg border-[#d7c494] bg-[#fff8df]/88 p-5 py-5 text-[#112a55] shadow-sm shadow-[#172f5c]/6">
            <div className="flex items-center gap-2 font-semibold">
              <Sparkles className="size-4 text-[#5a8f2f]" /> {labels.proAccess}
            </div>
            <p className="text-sm leading-6 text-[#53617a]">{labels.proBody}</p>
            <div className="flex items-center gap-2 font-semibold">
              <Shield className="size-4 text-[#5a8f2f]" /> {labels.safety}
            </div>
            <p className="text-sm leading-6 text-[#53617a]">{labels.safetyBody}</p>
          </Card>
        </section>
      </SeriesAppShell>
    </ProtectedRoute>
  );
}

const accountLabels = {
  ca: {
    activeLimit: "Límit actiu",
    managePlan: "Gestiona el pla",
    plan: "Pla",
    proAccess: "Accés Pro",
    proBody: "Els comptes Free poden mantenir 75 sèries actives. Els comptes Pro poden mantenir 1000 sèries actives i sync al núvol quan Account AV ho habilita.",
    safety: "Seguretat del compte",
    safetyBody: "L'eliminació del compte es gestiona a Account AV perquè la neteja de dades i identitat segueixi el contracte existent.",
    signOut: "Tanca sessió",
    signedIn: "Sessió iniciada",
    sync: "Sync",
    syncNow: "Sincronitza",
    syncState: { disabled: "desactivat", error: "error", failed: "error", idle: "preparat", synced: "sincronitzat", syncing: "sincronitzant" }
  },
  de: {
    activeLimit: "Aktives Limit",
    managePlan: "Plan verwalten",
    plan: "Plan",
    proAccess: "Pro-Zugang",
    proBody: "Free-Konten können 75 aktive Serien behalten. Pro-Konten können 1000 aktive Serien und Cloud-Sync nutzen, wenn Account AV den Zugriff meldet.",
    safety: "Kontosicherheit",
    safetyBody: "Kontolöschung läuft über Account AV, damit Produktdaten und Identität nach dem bestehenden Vertrag bereinigt werden.",
    signOut: "Abmelden",
    signedIn: "Angemeldet",
    sync: "Sync",
    syncNow: "Synchronisieren",
    syncState: { disabled: "deaktiviert", error: "Fehler", failed: "Fehler", idle: "bereit", synced: "synchronisiert", syncing: "synchronisiert" }
  },
  en: {
    activeLimit: "Active limit",
    managePlan: "Manage plan",
    plan: "Plan",
    proAccess: "Pro access",
    proBody: "Free accounts can keep 75 active series. Pro accounts can keep 1000 active series and cloud sync enabled when Account AV reports access.",
    safety: "Account safety",
    safetyBody: "Account deletion is handled by Account AV so product data and identity cleanup use the existing account contract.",
    signOut: "Sign out",
    signedIn: "Signed in",
    sync: "Sync",
    syncNow: "Sync now",
    syncState: { disabled: "disabled", error: "error", failed: "error", idle: "ready", synced: "synced", syncing: "syncing" }
  },
  es: {
    activeLimit: "Límite activo",
    managePlan: "Gestionar plan",
    plan: "Plan",
    proAccess: "Acceso Pro",
    proBody: "Las cuentas Free pueden mantener 75 series activas. Las cuentas Pro pueden mantener 1000 series activas y sync en la nube cuando Account AV lo habilita.",
    safety: "Seguridad de cuenta",
    safetyBody: "La eliminación de cuenta se gestiona en Account AV para que datos e identidad sigan el contrato existente.",
    signOut: "Cerrar sesión",
    signedIn: "Sesión iniciada",
    sync: "Sync",
    syncNow: "Sincronizar",
    syncState: { disabled: "desactivado", error: "error", failed: "error", idle: "preparado", synced: "sincronizado", syncing: "sincronizando" }
  },
  fr: {
    activeLimit: "Limite active",
    managePlan: "Gérer le forfait",
    plan: "Forfait",
    proAccess: "Accès Pro",
    proBody: "Les comptes Free peuvent garder 75 séries actives. Les comptes Pro peuvent garder 1000 séries actives et la synchro cloud quand Account AV l'autorise.",
    safety: "Sécurité du compte",
    safetyBody: "La suppression du compte passe par Account AV afin que les données produit et l'identité suivent le contrat existant.",
    signOut: "Déconnexion",
    signedIn: "Connecté",
    sync: "Sync",
    syncNow: "Synchroniser",
    syncState: { disabled: "désactivé", error: "erreur", failed: "erreur", idle: "prêt", synced: "synchronisé", syncing: "synchronisation" }
  }
} as const;

function Metric({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-lg border border-[#d7c494] bg-[#fff8df]/72 p-4">
      <p className="text-sm font-semibold text-[#53617a]">{label}</p>
      <p className="mt-1 text-xl font-semibold text-[#112a55]">{value}</p>
    </div>
  );
}
