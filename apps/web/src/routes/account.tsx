import { AccountSignOutButton, useAccountUser } from "@avalsys/account-av-web";
import { SettingsButton, SettingsInfoRow, SettingsProfileScaffold, SettingsSectionCard, useAppsAvLocale } from "@avalsys/apps-av-web";
import { createFileRoute } from "@tanstack/react-router";
import { BadgeCheck, Cloud, CloudOff, Cloudy, LibraryBig, Mail, ShieldAlert, Sparkles, UserCircle, XCircle } from "lucide-react";
import { ProtectedRoute } from "@/components/protected-route";
import { SeriesAppShell } from "@/components/series-app-shell";
import { seriesProductConfig } from "@/lib/series-config";
import { useSeriesLibrary } from "@/lib/series-library-provider";
import { localizedExternalUrl } from "@/lib/series-i18n";

export const Route = createFileRoute("/account")({
  component: AccountRoute
});

function AccountRoute() {
  const account = useAccountUser();
  const library = useSeriesLibrary();
  const locale = useAppsAvLocale();
  const labels = profileLabels[locale];
  const plan = library.access?.planTier ?? "free";
  const isPro = plan === "pro";
  const canUseCloudSync = library.access?.capabilities.canUseCloudSync === true;
  const email = account.data?.email ?? null;
  const displayName = account.data?.displayName ?? email ?? labels.account.signedIn;

  return (
    <ProtectedRoute>
      <SeriesAppShell>
        <SettingsProfileScaffold title={labels.accountTitle} subtitle={labels.accountSubtitle} heroClassName="series-paper">
          <SettingsSectionCard title={labels.pro.title} subtitle={isPro ? labels.pro.subtitlePro : labels.pro.subtitleFree}>
            <SettingsInfoRow icon={<BadgeCheck className="size-5" />} title={labels.pro.accountTitle} detail={labels.pro.accountDetail} />
            <SettingsInfoRow icon={<LibraryBig className="size-5" />} title={labels.pro.libraryTitle} detail={labels.pro.libraryDetail} />
            <SettingsInfoRow icon={<Sparkles className="size-5" />} title={labels.pro.aviTitle} detail={labels.pro.aviDetail} />
            <ExternalButton href={localizedExternalUrl(seriesProductConfig.links.suite?.href, locale)} tone="primary">
              {isPro ? labels.pro.manage : labels.pro.upgrade}
            </ExternalButton>
          </SettingsSectionCard>

          {canUseCloudSync ? (
            <SettingsSectionCard title={labels.sync.title} subtitle={labels.sync.subtitle}>
              <SettingsInfoRow icon={syncIcon(library.syncState)} title={syncHeadline(labels, library.syncState)} detail={syncDetail(labels, library.syncState)} />
              <SettingsButton disabled={library.syncState === "syncing"} loading={library.syncState === "syncing"} onClick={() => void library.refreshSync()}>
                {library.syncState === "syncing" ? labels.sync.retrySyncing : labels.sync.retry}
              </SettingsButton>
              {library.syncError ? <p className="text-sm font-semibold text-red-700">{library.syncError}</p> : null}
            </SettingsSectionCard>
          ) : null}

          <SettingsSectionCard title={labels.account.title} subtitle={email ?? labels.account.connected}>
            <SettingsInfoRow icon={<UserCircle className="size-5" />} title={labels.account.sessionTitle} detail={displayName} />
            {email ? <SettingsInfoRow icon={<Mail className="size-5" />} title={labels.account.emailTitle} detail={email} /> : null}
            <SettingsInfoRow icon={<Sparkles className="size-5" />} title={labels.account.planTitle} detail={isPro ? labels.account.planPro : labels.account.planFree} />
            <AccountSignOutButton>
              <SettingsButton>{labels.account.signOut}</SettingsButton>
            </AccountSignOutButton>
          </SettingsSectionCard>

          <SettingsSectionCard title={labels.safety.title} subtitle={labels.safety.subtitle} spacing="compact">
            <SettingsInfoRow
              icon={<ShieldAlert className="size-5" />}
              title={labels.safety.deleteTitle}
              detail={labels.safety.deleteDetail}
              action={
                <ExternalButton href={localizedExternalUrl(seriesProductConfig.links.deleteAccount?.href, locale)} tone="danger">
                  {labels.safety.deleteTitle}
                </ExternalButton>
              }
            />
          </SettingsSectionCard>
        </SettingsProfileScaffold>
      </SeriesAppShell>
    </ProtectedRoute>
  );
}

function ExternalButton({ children, href, tone = "secondary" }: { children: string; href: string | undefined; tone?: "primary" | "secondary" | "danger" }) {
  if (!href) {
    return null;
  }
  return (
    <a
      className={
        tone === "primary"
          ? "inline-flex h-10 items-center justify-center rounded-full bg-[#112a55] px-4 text-sm font-semibold text-white hover:bg-[#19396f]"
          : tone === "danger"
            ? "inline-flex h-10 items-center justify-center rounded-full border border-red-200 bg-white/60 px-4 text-sm font-semibold text-red-700 hover:bg-red-50"
            : "inline-flex h-10 items-center justify-center rounded-full border border-[#c8ad72] bg-white/60 px-4 text-sm font-semibold text-[#112a55] hover:bg-white"
      }
      href={href}
    >
      {children}
    </a>
  );
}

function syncIcon(syncState: string) {
  if (syncState === "syncing") {
    return <Cloudy className="size-5" />;
  }
  if (syncState === "failed" || syncState === "error") {
    return <XCircle className="size-5" />;
  }
  if (syncState === "disabled") {
    return <CloudOff className="size-5" />;
  }
  return <Cloud className="size-5" />;
}

function syncHeadline(labels: ProfileLabels, syncState: string) {
  if (syncState === "syncing") return labels.sync.headlineSyncing;
  if (syncState === "failed" || syncState === "error") return labels.sync.headlineFailed;
  if (syncState === "disabled") return labels.sync.headlineDisabled;
  return labels.sync.headlineSynced;
}

function syncDetail(labels: ProfileLabels, syncState: string) {
  if (syncState === "syncing") return labels.sync.detailSyncing;
  if (syncState === "failed" || syncState === "error") return labels.sync.detailFailed;
  if (syncState === "disabled") return labels.sync.detailDisabled;
  return labels.sync.detailSynced;
}

const syncLabels = {
  ca: { detailDisabled: "La sincronització cloud s'activa amb Series AV Pro.", detailFailed: "Series AV no ha pogut actualitzar la biblioteca del teu compte. Torna-ho a provar quan tinguis connexió.", detailSynced: "Sèries, estat i progrés d'episodis estan al dia.", detailSyncing: "Series AV està actualitzant la biblioteca del teu compte.", headlineDisabled: "Sync no disponible", headlineFailed: "La sync necessita atenció", headlineSynced: "Biblioteca sincronitzada", headlineSyncing: "Sincronitzant biblioteca", retry: "Sincronitzar ara", retrySyncing: "Sincronitzant...", subtitle: "La teva biblioteca Pro segueix el teu compte d'Apps AV.", title: "Sincronització cloud" },
  de: { detailDisabled: "Cloud-Sync wird mit Series AV Pro aktiviert.", detailFailed: "Series AV konnte deine Kontobibliothek nicht aktualisieren. Versuche es erneut, wenn du online bist.", detailSynced: "Serien, Status und Folgenfortschritt sind aktuell.", detailSyncing: "Series AV aktualisiert deine Kontobibliothek.", headlineDisabled: "Sync nicht verfügbar", headlineFailed: "Sync braucht Aufmerksamkeit", headlineSynced: "Bibliothek synchronisiert", headlineSyncing: "Bibliothek wird synchronisiert", retry: "Jetzt synchronisieren", retrySyncing: "Synchronisiert...", subtitle: "Deine Pro-Bibliothek folgt deinem Apps AV-Konto.", title: "Cloud-Sync" },
  en: { detailDisabled: "Cloud sync turns on with Series AV Pro.", detailFailed: "Series AV could not update your account library. Try again when you are online.", detailSynced: "Series, status, and episode progress are up to date.", detailSyncing: "Series AV is updating your account library.", headlineDisabled: "Sync unavailable", headlineFailed: "Sync needs attention", headlineSynced: "Library synced", headlineSyncing: "Syncing library", retry: "Sync now", retrySyncing: "Syncing...", subtitle: "Your Pro library follows your Apps AV account.", title: "Cloud sync" },
  es: { detailDisabled: "La sincronización cloud se activa con Series AV Pro.", detailFailed: "Series AV no ha podido actualizar la biblioteca de tu cuenta. Inténtalo de nuevo cuando tengas conexión.", detailSynced: "Series, estado y progreso de episodios están al día.", detailSyncing: "Series AV está actualizando la biblioteca de tu cuenta.", headlineDisabled: "Sync no disponible", headlineFailed: "La sync necesita atención", headlineSynced: "Biblioteca sincronizada", headlineSyncing: "Sincronizando biblioteca", retry: "Sincronizar ahora", retrySyncing: "Sincronizando...", subtitle: "Tu biblioteca Pro sigue tu cuenta de Apps AV.", title: "Sincronización cloud" },
  fr: { detailDisabled: "La sync cloud s'active avec Series AV Pro.", detailFailed: "Series AV n'a pas pu mettre à jour la bibliothèque de votre compte. Réessayez quand vous êtes en ligne.", detailSynced: "Séries, état et progression des épisodes sont à jour.", detailSyncing: "Series AV met à jour la bibliothèque de votre compte.", headlineDisabled: "Sync indisponible", headlineFailed: "La sync demande votre attention", headlineSynced: "Bibliothèque synchronisée", headlineSyncing: "Synchronisation de la bibliothèque", retry: "Synchroniser maintenant", retrySyncing: "Synchronisation...", subtitle: "Votre bibliothèque Pro suit votre compte Apps AV.", title: "Sync cloud" }
} as const;

const accountLabels = {
  ca: { connected: "Connectat a Account AV.", emailTitle: "Correu electrònic", planFree: "Compte connectat", planPro: "Pro", planTitle: "Accés", sessionTitle: "Sessió", signOut: "Tancar sessió", signedIn: "Sessió iniciada", title: "Compte" },
  de: { connected: "Verbunden mit Account AV.", emailTitle: "E-Mail", planFree: "Verbundenes Konto", planPro: "Pro", planTitle: "Zugriff", sessionTitle: "Sitzung", signOut: "Abmelden", signedIn: "Angemeldet", title: "Konto" },
  en: { connected: "Connected to Account AV.", emailTitle: "Email", planFree: "Connected account", planPro: "Pro", planTitle: "Plan", sessionTitle: "Session", signOut: "Sign out", signedIn: "Signed in", title: "Account" },
  es: { connected: "Conectado a Account AV.", emailTitle: "Email", planFree: "Cuenta conectada", planPro: "Pro", planTitle: "Plan", sessionTitle: "Sesión", signOut: "Cerrar sesión", signedIn: "Sesión iniciada", title: "Cuenta" },
  fr: { connected: "Connecté à Account AV.", emailTitle: "E-mail", planFree: "Compte connecté", planPro: "Pro", planTitle: "Accès", sessionTitle: "Session", signOut: "Se déconnecter", signedIn: "Connecté", title: "Compte" }
} as const;

const safetyLabels = {
  ca: { deleteDetail: "Obre la pàgina compartida d'eliminació de compte.", deleteTitle: "Eliminar compte", subtitle: "Les accions de compte sensibles obren el flux compartit d'Account AV.", title: "Seguretat del compte" },
  de: { deleteDetail: "Öffne die gemeinsame Seite zur Kontolöschung.", deleteTitle: "Konto löschen", subtitle: "Sensible Kontoaktionen öffnen den gemeinsamen Account AV-Ablauf.", title: "Kontosicherheit" },
  en: { deleteDetail: "Open the shared account deletion page.", deleteTitle: "Delete account", subtitle: "Account-level actions open the shared Account AV flow.", title: "Account safety" },
  es: { deleteDetail: "Abre la página compartida de eliminación de cuenta.", deleteTitle: "Eliminar cuenta", subtitle: "Las acciones de cuenta sensibles abren el flujo compartido de Account AV.", title: "Seguridad de cuenta" },
  fr: { deleteDetail: "Ouvrir la page partagée de suppression du compte.", deleteTitle: "Supprimer le compte", subtitle: "Les actions sensibles ouvrent le flux Account AV partagé.", title: "Sécurité du compte" }
} as const;

interface ProfileLabels {
  sync: {
    detailDisabled: string;
    detailFailed: string;
    detailSynced: string;
    detailSyncing: string;
    headlineDisabled: string;
    headlineFailed: string;
    headlineSynced: string;
    headlineSyncing: string;
  };
}

const profileLabels = {
  ca: {
    accountTitle: "El meu compte",
    accountSubtitle: "Gestiona inici de sessió, accés, facturació i seguretat del compte.",
    pro: {
      accountDetail: "Mantén l'accés Pro vinculat al teu compte d'Apps AV.",
      accountTitle: "Compte Pro",
      aviDetail: "Mantingues la guia de seguiment al costat de la sèrie actual.",
      aviTitle: "Avi a Home",
      libraryDetail: "Segueix fins a 1000 sèries actives.",
      libraryTitle: "Biblioteca més gran",
      manage: "Gestionar subscripció",
      subtitleFree: "Millora per seguir més sèries actives i mantenir l'accés Pro vinculat al compte.",
      subtitlePro: "El teu accés Pro està actiu. Gestiona la facturació a Account AV.",
      title: "Series AV Pro",
      upgrade: "Veure Pro"
    },
    sync: syncLabels.ca,
    account: accountLabels.ca,
    safety: safetyLabels.ca
  },
  de: {
    accountTitle: "Mein Konto",
    accountSubtitle: "Verwalte Anmeldung, Zugriff, Abrechnung und Kontosicherheit.",
    pro: {
      accountDetail: "Halte Pro-Zugriff mit deinem Apps AV-Konto verknüpft.",
      accountTitle: "Pro-Konto",
      aviDetail: "Behalte die Serienhilfe direkt bei deiner aktuellen Serie.",
      aviTitle: "Avi auf Home",
      libraryDetail: "Verfolge bis zu 1000 aktive Serien.",
      libraryTitle: "Größere Bibliothek",
      manage: "Abo verwalten",
      subtitleFree: "Upgrade, um mehr aktive Serien zu verfolgen und Pro-Zugriff mit deinem Konto zu verbinden.",
      subtitlePro: "Dein Pro-Zugriff ist aktiv. Verwalte die Abrechnung in Account AV.",
      title: "Series AV Pro",
      upgrade: "Pro ansehen"
    },
    sync: syncLabels.de,
    account: accountLabels.de,
    safety: safetyLabels.de
  },
  en: {
    accountTitle: "My account",
    accountSubtitle: "Manage sign-in, access, billing, and account safety.",
    pro: {
      accountDetail: "Keep Pro access linked to your Apps AV account.",
      accountTitle: "Pro account",
      aviDetail: "Keep tracking guidance next to your current series.",
      aviTitle: "Avi on Home",
      libraryDetail: "Track up to 1000 active series.",
      libraryTitle: "Larger library",
      manage: "Manage subscription",
      subtitleFree: "Upgrade to track more active series and keep Pro access linked to your account.",
      subtitlePro: "Your Pro access is active. Manage billing in Account AV.",
      title: "Series AV Pro",
      upgrade: "View Pro"
    },
    sync: syncLabels.en,
    account: accountLabels.en,
    safety: safetyLabels.en
  },
  es: {
    accountTitle: "Mi cuenta",
    accountSubtitle: "Gestiona inicio de sesión, acceso, facturación y seguridad de cuenta.",
    pro: {
      accountDetail: "Mantén el acceso Pro vinculado a tu cuenta de Apps AV.",
      accountTitle: "Cuenta Pro",
      aviDetail: "Mantén la guía de seguimiento junto a tu serie actual.",
      aviTitle: "Avi en Home",
      libraryDetail: "Sigue hasta 1000 series activas.",
      libraryTitle: "Biblioteca mayor",
      manage: "Gestionar suscripción",
      subtitleFree: "Mejora para seguir más series activas y mantener tu acceso Pro vinculado a la cuenta.",
      subtitlePro: "Tu acceso Pro está activo. Gestiona la facturación en Account AV.",
      title: "Series AV Pro",
      upgrade: "Ver Pro"
    },
    sync: syncLabels.es,
    account: accountLabels.es,
    safety: safetyLabels.es
  },
  fr: {
    accountTitle: "Mon compte",
    accountSubtitle: "Gérez connexion, accès, facturation et sécurité du compte.",
    pro: {
      accountDetail: "Gardez l'accès Pro lié à votre compte Apps AV.",
      accountTitle: "Compte Pro",
      aviDetail: "Garde la guidance de suivi près de ta série actuelle.",
      aviTitle: "Avi sur Home",
      libraryDetail: "Suivez jusqu'à 1000 séries actives.",
      libraryTitle: "Bibliothèque plus grande",
      manage: "Gérer l'abonnement",
      subtitleFree: "Passez à Pro pour suivre plus de séries actives et garder l'accès Pro lié au compte.",
      subtitlePro: "Votre accès Pro est actif. Gérez la facturation dans Account AV.",
      title: "Series AV Pro",
      upgrade: "Voir Pro"
    },
    sync: syncLabels.fr,
    account: accountLabels.fr,
    safety: safetyLabels.fr
  }
} as const;
