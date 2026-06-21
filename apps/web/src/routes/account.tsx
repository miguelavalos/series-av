import { AccountSignOutButton, useAccountUser } from "@avalsys/account-av-web";
import { AccountSafetySection, CloudSyncSection, PlanFeatureSection, SettingsButton, SettingsInfoRow, SettingsProfileScaffold, SettingsSectionCard, useAppsAvLocale } from "@avalsys/apps-av-web";
import { createFileRoute } from "@tanstack/react-router";
import { Mail, Sparkles, UserCircle } from "lucide-react";
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
  const planDetail = library.accessIsLoading ? labels.account.planLoading : isPro ? labels.account.planPro : labels.account.planFree;
  const canUseCloudSync = library.access?.capabilities.canUseCloudSync === true;
  const email = account.data?.email ?? null;
  const displayName = account.data?.displayName ?? email ?? labels.account.signedIn;

  return (
    <ProtectedRoute>
      <SeriesAppShell>
        <SettingsProfileScaffold title={labels.accountTitle} subtitle={labels.accountSubtitle}>
          <SettingsSectionCard title={labels.account.title} subtitle={email ?? labels.account.connected}>
            <SettingsInfoRow icon={<UserCircle className="size-5" />} title={labels.account.sessionTitle} detail={displayName} />
            {email ? <SettingsInfoRow icon={<Mail className="size-5" />} title={labels.account.emailTitle} detail={email} /> : null}
            <SettingsInfoRow icon={<Sparkles className="size-5" />} title={labels.account.planTitle} detail={planDetail} />
            <AccountSignOutButton>
              <SettingsButton>{labels.account.signOut}</SettingsButton>
            </AccountSignOutButton>
          </SettingsSectionCard>

          <PlanFeatureSection isPro={isPro} labels={labels.pro} manageHref={localizedExternalUrl(seriesProductConfig.links.suite?.href, locale)} />

          {canUseCloudSync ? (
            <CloudSyncSection labels={labels.sync} syncState={library.syncState} error={library.syncError} onRetry={() => void library.refreshSync()} />
          ) : null}

          <AccountSafetySection labels={labels.safety} deleteHref={localizedExternalUrl(seriesProductConfig.links.deleteAccount?.href, locale)} />
        </SettingsProfileScaffold>
      </SeriesAppShell>
    </ProtectedRoute>
  );
}

const syncLabels = {
  ca: { detailDisabled: "Amb Series AV Pro, la teva biblioteca queda guardada al compte.", detailFailed: "Series AV no ha pogut actualitzar la teva biblioteca. Torna-ho a provar quan tinguis connexió.", detailSynced: "Sèries, estat i progrés d'episodis estan al dia.", detailSyncing: "Series AV està actualitzant la teva biblioteca.", headlineDisabled: "Disponible amb Pro", headlineFailed: "Revisa la connexió", headlineSynced: "Biblioteca al dia", headlineSyncing: "Actualitzant biblioteca", retry: "Actualitzar ara", retrySyncing: "Actualitzant...", subtitle: "El teu progrés Pro es conserva al compte.", title: "Biblioteca del compte" },
  de: { detailDisabled: "Mit Series AV Pro bleibt deine Bibliothek in deinem Konto gesichert.", detailFailed: "Series AV konnte deine Bibliothek nicht aktualisieren. Versuche es erneut, wenn du online bist.", detailSynced: "Serien, Status und Folgenfortschritt sind aktuell.", detailSyncing: "Series AV aktualisiert deine Bibliothek.", headlineDisabled: "Mit Pro verfügbar", headlineFailed: "Verbindung prüfen", headlineSynced: "Bibliothek aktuell", headlineSyncing: "Bibliothek wird aktualisiert", retry: "Jetzt aktualisieren", retrySyncing: "Aktualisiert...", subtitle: "Dein Pro-Fortschritt bleibt in deinem Konto erhalten.", title: "Kontobibliothek" },
  en: { detailDisabled: "With Series AV Pro, your library is saved to your account.", detailFailed: "Series AV could not update your library. Try again when you are online.", detailSynced: "Series, status, and episode progress are up to date.", detailSyncing: "Series AV is updating your library.", headlineDisabled: "Available with Pro", headlineFailed: "Check your connection", headlineSynced: "Library up to date", headlineSyncing: "Updating library", retry: "Update now", retrySyncing: "Updating...", subtitle: "Your Pro progress stays with your account.", title: "Account library" },
  es: { detailDisabled: "Con Series AV Pro, tu biblioteca queda guardada en tu cuenta.", detailFailed: "Series AV no ha podido actualizar tu biblioteca. Inténtalo de nuevo cuando tengas conexión.", detailSynced: "Series, estado y progreso de episodios están al día.", detailSyncing: "Series AV está actualizando tu biblioteca.", headlineDisabled: "Disponible con Pro", headlineFailed: "Revisa la conexión", headlineSynced: "Biblioteca al día", headlineSyncing: "Actualizando biblioteca", retry: "Actualizar ahora", retrySyncing: "Actualizando...", subtitle: "Tu progreso Pro se conserva en tu cuenta.", title: "Biblioteca de la cuenta" },
  fr: { detailDisabled: "Avec Series AV Pro, votre bibliothèque est enregistrée dans votre compte.", detailFailed: "Series AV n'a pas pu mettre à jour votre bibliothèque. Réessayez quand vous êtes en ligne.", detailSynced: "Séries, état et progression des épisodes sont à jour.", detailSyncing: "Series AV met à jour votre bibliothèque.", headlineDisabled: "Disponible avec Pro", headlineFailed: "Vérifiez la connexion", headlineSynced: "Bibliothèque à jour", headlineSyncing: "Bibliothèque en cours", retry: "Mettre à jour", retrySyncing: "Mise à jour...", subtitle: "Votre progression Pro reste liée à votre compte.", title: "Bibliothèque du compte" }
} as const;

const accountLabels = {
  ca: { connected: "Sessió iniciada.", emailTitle: "Correu electrònic", planFree: "Free", planLoading: "Actualitzant accés", planPro: "Pro", planTitle: "Accés", sessionTitle: "Sessió", signOut: "Tancar sessió", signedIn: "Sessió iniciada", title: "Compte" },
  de: { connected: "Angemeldet.", emailTitle: "E-Mail", planFree: "Free", planLoading: "Zugriff wird aktualisiert", planPro: "Pro", planTitle: "Zugriff", sessionTitle: "Sitzung", signOut: "Abmelden", signedIn: "Angemeldet", title: "Konto" },
  en: { connected: "Signed in.", emailTitle: "Email", planFree: "Free", planLoading: "Updating access", planPro: "Pro", planTitle: "Plan", sessionTitle: "Session", signOut: "Sign out", signedIn: "Signed in", title: "Account" },
  es: { connected: "Sesión iniciada.", emailTitle: "Email", planFree: "Free", planLoading: "Actualizando acceso", planPro: "Pro", planTitle: "Plan", sessionTitle: "Sesión", signOut: "Cerrar sesión", signedIn: "Sesión iniciada", title: "Cuenta" },
  fr: { connected: "Connecté.", emailTitle: "E-mail", planFree: "Free", planLoading: "Mise à jour de l'accès", planPro: "Pro", planTitle: "Accès", sessionTitle: "Session", signOut: "Se déconnecter", signedIn: "Connecté", title: "Compte" }
} as const;

const safetyLabels = {
  ca: { deleteDetail: "Obre la pàgina per eliminar el compte.", deleteTitle: "Eliminar compte", subtitle: "Gestiona les accions importants del compte amb calma.", title: "Seguretat del compte" },
  de: { deleteDetail: "Öffnet die Seite zum Löschen deines Kontos.", deleteTitle: "Konto löschen", subtitle: "Verwalte wichtige Kontoaktionen in Ruhe.", title: "Kontosicherheit" },
  en: { deleteDetail: "Open the page to delete your account.", deleteTitle: "Delete account", subtitle: "Manage important account actions carefully.", title: "Account safety" },
  es: { deleteDetail: "Abre la página para eliminar tu cuenta.", deleteTitle: "Eliminar cuenta", subtitle: "Gestiona las acciones importantes de la cuenta con calma.", title: "Seguridad de cuenta" },
  fr: { deleteDetail: "Ouvrir la page pour supprimer votre compte.", deleteTitle: "Supprimer le compte", subtitle: "Gérez les actions importantes du compte avec attention.", title: "Sécurité du compte" }
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
    retry: string;
    retrySyncing: string;
    subtitle: string;
    title: string;
  };
}

const profileLabels = {
  ca: {
    accountTitle: "El meu compte",
    accountSubtitle: "Gestiona inici de sessió, accés, facturació i seguretat del compte.",
    pro: {
      accountDetail: "Mantén l'accés Pro vinculat al teu compte d'Apps AV.",
      accountTitle: "Compte Pro",
      assistantDetail: "Mantingues la guia de seguiment al costat de la sèrie actual.",
      assistantTitle: "Avi a Home",
      libraryDetail: "Segueix fins a 1000 sèries actives.",
      libraryTitle: "Biblioteca més gran",
      manage: "Gestionar subscripció",
      subtitleFree: "Millora per seguir més sèries actives i mantenir l'accés Pro vinculat al compte.",
      subtitlePro: "El teu accés Pro està actiu. Pots gestionar la subscripció des d'aquí.",
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
      assistantDetail: "Behalte die Serienhilfe direkt bei deiner aktuellen Serie.",
      assistantTitle: "Avi auf Home",
      libraryDetail: "Verfolge bis zu 1000 aktive Serien.",
      libraryTitle: "Größere Bibliothek",
      manage: "Abo verwalten",
      subtitleFree: "Upgrade, um mehr aktive Serien zu verfolgen und Pro-Zugriff mit deinem Konto zu verbinden.",
      subtitlePro: "Dein Pro-Zugriff ist aktiv. Du kannst dein Abo von hier aus verwalten.",
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
      assistantDetail: "Keep tracking guidance next to your current series.",
      assistantTitle: "Avi on Home",
      libraryDetail: "Track up to 1000 active series.",
      libraryTitle: "Larger library",
      manage: "Manage subscription",
      subtitleFree: "Upgrade to track more active series and keep Pro access linked to your account.",
      subtitlePro: "Your Pro access is active. You can manage your subscription from here.",
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
      assistantDetail: "Mantén la guía de seguimiento junto a tu serie actual.",
      assistantTitle: "Avi en Home",
      libraryDetail: "Sigue hasta 1000 series activas.",
      libraryTitle: "Biblioteca mayor",
      manage: "Gestionar suscripción",
      subtitleFree: "Mejora para seguir más series activas y mantener tu acceso Pro vinculado a la cuenta.",
      subtitlePro: "Tu acceso Pro está activo. Puedes gestionar tu suscripción desde aquí.",
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
      assistantDetail: "Garde la guidance de suivi près de ta série actuelle.",
      assistantTitle: "Avi sur Home",
      libraryDetail: "Suivez jusqu'à 1000 séries actives.",
      libraryTitle: "Bibliothèque plus grande",
      manage: "Gérer l'abonnement",
      subtitleFree: "Passez à Pro pour suivre plus de séries actives et garder l'accès Pro lié au compte.",
      subtitlePro: "Votre accès Pro est actif. Vous pouvez gérer l'abonnement depuis ici.",
      title: "Series AV Pro",
      upgrade: "Voir Pro"
    },
    sync: syncLabels.fr,
    account: accountLabels.fr,
    safety: safetyLabels.fr
  }
} as const;
