import {
  SettingsActionRow,
  SettingsInfoRow,
  SettingsOptionButtonGroup,
  SettingsProfileScaffold,
  SettingsSectionCard,
  useAppsAvLocale,
  appsAvLocaleNames,
  appsAvExternalSearchEngines,
  type AppsAvExternalSearchEngine,
  type AppsAvLocale
} from "@avalsys/apps-av-web";
import { HelpLegalSection } from "@avalsys/apps-av-web/src/components/account-settings-sections";
import { applyAppsAvThemePreference, normalizeAppsAvThemePreference, readAppsAvThemePreference, type AppsAvThemePreference } from "@avalsys/apps-av-web/src/lib/theme-preference";
import { createFileRoute } from "@tanstack/react-router";
import { Contrast, Globe, HardDrive, Languages, ListChecks, Moon, RotateCcw, Search, Smartphone, Sun, Trash2 } from "lucide-react";
import { useEffect, useState } from "react";
import { ProtectedRoute } from "@/components/protected-route";
import { SeriesAppShell } from "@/components/series-app-shell";
import { seriesProductConfig } from "@/lib/series-config";
import { readSeriesExternalSearchEngine, writeSeriesExternalSearchEngine } from "@/lib/series-external-preferences";
import { useSeriesLibrary } from "@/lib/series-library-provider";
import { localizedExternalUrl, localizedSeriesPath } from "@/lib/series-i18n";

export const Route = createFileRoute("/settings")({
  component: SettingsRoute
});

function SettingsRoute() {
  const locale = useAppsAvLocale();
  const library = useSeriesLibrary();
  const labels = profileLabels[locale];
  const [theme, setThemeState] = useState<AppsAvThemePreference>("system");
  const [searchEngine, setSearchEngineState] = useState<AppsAvExternalSearchEngine>("google");

  useEffect(() => {
    const storedTheme = normalizeAppsAvThemePreference(readAppsAvThemePreference(themeStorageKey));
    setThemeState(storedTheme);
    applyTheme(storedTheme);
    setSearchEngineState(readSeriesExternalSearchEngine());
  }, []);

  const setTheme = (nextTheme: AppsAvThemePreference) => {
    setThemeState(nextTheme);
    applyTheme(nextTheme);
  };

  const setSearchEngine = (nextSearchEngine: AppsAvExternalSearchEngine) => {
    setSearchEngineState(nextSearchEngine);
    writeSeriesExternalSearchEngine(nextSearchEngine);
  };

  const clearLocalData = () => {
    const detail = library.entries.length === 0 ? labels.local.delete.empty : labels.local.delete.detail(library.entries.length);
    if (window.confirm(`${labels.local.delete.confirmTitle}\n\n${labels.local.delete.confirmDetail}\n\n${detail}`)) {
      library.clearLocalData();
    }
  };

  return (
    <ProtectedRoute>
      <SeriesAppShell>
        <SettingsProfileScaffold title={labels.settingsTitle} subtitle={labels.settingsSubtitle} heroClassName="series-paper">
          <SettingsSectionCard title={labels.preferences.title} subtitle={labels.preferences.subtitle}>
            <SettingsInfoRow icon={<Globe className="size-5" />} title={labels.preferences.languageTitle} detail={labels.preferences.languageDetail} />
            <SettingsOptionButtonGroup
              selectedId={locale}
              onSelect={(id) => {
                window.location.href = localizedSeriesPath("/settings", id as AppsAvLocale);
              }}
              options={locales.map((item) => ({
                id: item,
                icon: item === locale ? <Languages className="size-4" /> : undefined,
                label: `${languageDisplayNames[locale][item]} (${appsAvLocaleNames[item]})`
              }))}
            />
            <SettingsInfoRow icon={<Contrast className="size-5" />} title={labels.preferences.themeTitle} detail={labels.preferences.themeDetail} />
            <SettingsOptionButtonGroup
              selectedId={theme}
              onSelect={(id) => setTheme(id as AppsAvThemePreference)}
              options={themeOptions.map((item) => ({
                id: item,
                icon: themeIcon(item),
                label: labels.preferences.themeOptions[item]
              }))}
            />
            <SettingsInfoRow icon={<Search className="size-5" />} title={labels.preferences.searchEngineTitle} detail={labels.preferences.searchEngineDetail} />
            <label className="grid gap-2">
              <span className="sr-only">{labels.preferences.searchEngineTitle}</span>
              <select
                className="h-12 w-full rounded-lg border border-[#d7c494] bg-[#fff8df]/80 px-4 text-sm font-semibold text-[#112a55] outline-none transition focus:border-[#112a55] focus:ring-2 focus:ring-[#112a55]/20"
                value={searchEngine}
                onChange={(event) => setSearchEngine(event.target.value as AppsAvExternalSearchEngine)}
              >
                {appsAvExternalSearchEngines.map((engine) => (
                  <option key={engine} value={engine}>
                    {labels.preferences.searchEngineOptions[engine]}
                  </option>
                ))}
              </select>
            </label>
          </SettingsSectionCard>

          <SettingsSectionCard title={labels.series.title} subtitle={labels.series.subtitle}>
            <SettingsInfoRow icon={<ListChecks className="size-5" />} title={labels.series.cursorTitle} detail={labels.series.cursorDetail} />
            <SettingsInfoRow icon={<RotateCcw className="size-5" />} title={labels.series.reversibleTitle} detail={labels.series.reversibleDetail} />
          </SettingsSectionCard>

          <SettingsSectionCard title={labels.local.title} subtitle={labels.local.subtitle}>
            <SettingsInfoRow icon={<Smartphone className="size-5" />} title={labels.local.libraryTitle} detail={labels.local.libraryDetail} />
            <SettingsInfoRow icon={<HardDrive className="size-5" />} title={labels.local.syncTitle} detail={labels.local.syncDetail} />
            <SettingsActionRow
              icon={<Trash2 className="size-5" />}
              title={labels.local.delete.title}
              detail={library.entries.length === 0 ? labels.local.delete.empty : labels.local.delete.detail(library.entries.length)}
              disabled={library.entries.length === 0}
              onAction={clearLocalData}
            />
          </SettingsSectionCard>

          <HelpLegalSection labels={{ ...labels.help, deleteTitle: labels.safety.deleteTitle, deleteDetail: labels.safety.deleteDetail }} links={helpLegalLinks(locale)} />
        </SettingsProfileScaffold>
      </SeriesAppShell>
    </ProtectedRoute>
  );
}

const locales: AppsAvLocale[] = ["en", "es", "fr", "de", "ca"];
const themeStorageKey = "series-av.theme";
const themeOptions: AppsAvThemePreference[] = ["system", "light", "dark"];

const externalSearchEngineLabels: Record<AppsAvExternalSearchEngine, string> = {
  baidu: "Baidu",
  bing: "Bing",
  brave: "Brave Search",
  duckduckgo: "DuckDuckGo",
  ecosia: "Ecosia",
  google: "Google",
  qwant: "Qwant",
  startpage: "Startpage",
  yahoo: "Yahoo",
  yandex: "Yandex"
};

function themeIcon(theme: AppsAvThemePreference) {
  if (theme === "light") {
    return <Sun className="size-4" />;
  }
  if (theme === "dark") {
    return <Moon className="size-4" />;
  }
  return <Smartphone className="size-4" />;
}

function openSourceUrl() {
  return import.meta.env.VITE_SERIESAV_OPEN_SOURCE_URL || "https://github.com/avalsys/series-av";
}

function helpLegalLinks(locale: AppsAvLocale) {
  return {
    deleteAccount: localizedExternalUrl(seriesProductConfig.links.deleteAccount?.href, locale),
    openSource: localizedExternalUrl(openSourceUrl(), locale),
    privacy: localizedExternalUrl(seriesProductConfig.links.privacy?.href, locale),
    support: localizedExternalUrl(seriesProductConfig.links.support?.href, locale),
    terms: localizedExternalUrl(seriesProductConfig.links.terms?.href, locale)
  };
}

function applyTheme(theme: AppsAvThemePreference) {
  applyAppsAvThemePreference({ attributeName: "seriesTheme", storageKey: themeStorageKey, theme });
}

const languageDisplayNames: Record<AppsAvLocale, Record<AppsAvLocale, string>> = {
  ca: { ca: "Català", de: "Alemany", en: "Anglès", es: "Espanyol", fr: "Francès" },
  de: { ca: "Katalanisch", de: "Deutsch", en: "Englisch", es: "Spanisch", fr: "Französisch" },
  en: { ca: "Catalan", de: "German", en: "English", es: "Spanish", fr: "French" },
  es: { ca: "Catalán", de: "Alemán", en: "Inglés", es: "Español", fr: "Francés" },
  fr: { ca: "Catalan", de: "Allemand", en: "Anglais", es: "Espagnol", fr: "Français" }
};

const profileLabels = {
  ca: {
    settingsTitle: "Ajustos",
    settingsSubtitle: "Ajusta l'app, gestiona aquest dispositiu i obre enllaços d'ajuda.",
    preferences: {
      languageDetail: "Tria l'idioma que fa servir la interfície de Series AV.",
      languageTitle: "Idioma de l'app",
      subtitle: "Tria com es mostra Series AV en aquest dispositiu.",
      themeDetail: "Tria si Series AV segueix l'aparença del sistema o si sempre fa servir un tema fix en aquest dispositiu.",
      themeOptions: { dark: "Fosc", light: "Clar", system: "Sistema" },
      themeTitle: "Aparença",
      searchEngineDetail: "Tria el cercador que s'obre des dels enllaços de fonts.",
      searchEngineOptions: externalSearchEngineLabels,
      searchEngineTitle: "Cercador",
      title: "Preferències de l'app"
    },
    series: {
      cursorDetail: "Marca un episodi i Series AV deixa anteriors com vistos i posteriors com pendents.",
      cursorTitle: "Punt únic de progrés",
      reversibleDetail: "Mou el punt enrere o endavant si toques l'episodi incorrecte.",
      reversibleTitle: "Correccions ràpides",
      subtitle: "Un únic punt clar per sèrie.",
      title: "Seguiment de sèries"
    },
    local: {
      delete: {
        confirmDetail: "S'esborraran les sèries, estats i progrés guardats en aquest navegador. Això no esborra el teu compte Apps AV.",
        confirmTitle: "Esborrar dades locals",
        detail: (count: number) => `Esborra ${count} sèries d'aquest navegador.`,
        empty: "No hi ha dades locals per esborrar.",
        title: "Esborrar dades locals"
      },
      libraryDetail: "Free guarda el seguiment en aquest navegador quan la sync cloud no està activa.",
      libraryTitle: "Biblioteca local",
      subtitle: "El mode local es manté simple i privat.",
      syncDetail: "El progrés local queda en aquest navegador fins que Account AV habilita sync.",
      syncTitle: "Dades locals",
      title: "En aquest dispositiu"
    },
    help: {
      openSourceDetail: "Series AV es manté com una app de codi obert i independent.",
      openSourceTitle: "Projecte de codi obert",
      privacyDetail: "Consulta com Series AV gestiona les teves dades.",
      privacyTitle: "Política de privacitat",
      sourceCodeDetail: "Consulta el repositori, les incidències i com contribuir.",
      sourceCodeTitle: "Codi font",
      subtitle: "Obre des d'aquí suport, privacitat, termes i enllaços del codi font.",
      supportDetail: "Obre el suport de Series AV.",
      supportTitle: "Contactar amb suport",
      termsDetail: "Revisa els termes aplicables a Series AV.",
      termsTitle: "Termes del servei",
      title: "Ajuda i legal"
    },
    safety: { deleteDetail: "Obre la pàgina compartida d'eliminació de compte.", deleteTitle: "Eliminar compte" }
  },
  de: {
    settingsTitle: "Einstellungen",
    settingsSubtitle: "Passe die App an, verwalte dieses Gerät und öffne Hilfelinks.",
    preferences: {
      languageDetail: "Wähle die Sprache der Series AV Oberfläche.",
      languageTitle: "App-Sprache",
      subtitle: "Lege fest, wie Series AV auf diesem Gerät angezeigt wird.",
      themeDetail: "Wähle, ob Series AV dem Systemdesign folgt oder auf diesem Gerät immer ein festes Theme verwendet.",
      themeOptions: { dark: "Dunkel", light: "Hell", system: "System" },
      themeTitle: "Darstellung",
      searchEngineDetail: "Wähle die Suchmaschine für Quellen-Links.",
      searchEngineOptions: externalSearchEngineLabels,
      searchEngineTitle: "Suchmaschine",
      title: "App-Einstellungen"
    },
    series: {
      cursorDetail: "Markiere eine Folge und Series AV setzt frühere als gesehen und spätere als offen.",
      cursorTitle: "Ein Fortschrittspunkt",
      reversibleDetail: "Verschiebe den Punkt zurück oder vor, wenn du die falsche Folge antippst.",
      reversibleTitle: "Schnelle Korrekturen",
      subtitle: "Ein klarer Fortschrittspunkt pro Serie.",
      title: "Serien-Tracking"
    },
    local: {
      delete: {
        confirmDetail: "Serien, Status und Fortschritt in diesem Browser werden gelöscht. Dein Apps AV-Konto wird dadurch nicht gelöscht.",
        confirmTitle: "Lokale Daten löschen",
        detail: (count: number) => `Löscht ${count} Serien von diesem Browser.`,
        empty: "Es gibt keine lokalen Daten zum Löschen.",
        title: "Lokale Daten löschen"
      },
      libraryDetail: "Free speichert Tracking in diesem Browser, wenn Cloud-Sync nicht aktiv ist.",
      libraryTitle: "Lokale Bibliothek",
      subtitle: "Der lokale Modus bleibt einfach und privat.",
      syncDetail: "Lokaler Fortschritt bleibt in diesem Browser, bis Account AV Sync aktiviert.",
      syncTitle: "Lokale Daten",
      title: "Auf diesem Gerät"
    },
    help: {
      openSourceDetail: "Series AV wird als unabhängiges Open-Source-Projekt gepflegt.",
      openSourceTitle: "Open-Source-Projekt",
      privacyDetail: "Erfahre, wie Series AV mit deinen Daten umgeht.",
      privacyTitle: "Datenschutzerklärung",
      sourceCodeDetail: "Sieh dir Repository, Issues und Hinweise zum Mitwirken an.",
      sourceCodeTitle: "Quellcode",
      subtitle: "Öffne hier Projektlinks, Support, Datenschutz und Nutzungsbedingungen.",
      supportDetail: "Series AV Support öffnen.",
      supportTitle: "Support kontaktieren",
      termsDetail: "Prüfe die für Series AV geltenden Bedingungen.",
      termsTitle: "Nutzungsbedingungen",
      title: "Hilfe und Rechtliches"
    },
    safety: { deleteDetail: "Öffne die gemeinsame Seite zur Kontolöschung.", deleteTitle: "Konto löschen" }
  },
  en: {
    settingsTitle: "Settings",
    settingsSubtitle: "Tune the app, manage this device, and open help links.",
    preferences: {
      languageDetail: "Choose the language used by the Series AV interface.",
      languageTitle: "App language",
      subtitle: "Pick how Series AV is shown on this device.",
      themeDetail: "Choose whether Series AV follows the system appearance or always uses a fixed theme on this device.",
      themeOptions: { dark: "Dark", light: "Light", system: "System" },
      themeTitle: "Appearance",
      searchEngineDetail: "Choose the search engine opened by source links.",
      searchEngineOptions: externalSearchEngineLabels,
      searchEngineTitle: "Search engine",
      title: "App preferences"
    },
    series: {
      cursorDetail: "Mark an episode and Series AV keeps earlier episodes watched and later episodes pending.",
      cursorTitle: "Single progress point",
      reversibleDetail: "Move the point backward or forward whenever you tap the wrong episode.",
      reversibleTitle: "Fast corrections",
      subtitle: "One clear watching point per series.",
      title: "Series tracking"
    },
    local: {
      delete: {
        confirmDetail: "Series, status, and progress saved in this browser will be deleted. This does not delete your Apps AV account.",
        confirmTitle: "Delete local data",
        detail: (count: number) => `Deletes ${count} series from this browser.`,
        empty: "There is no local data to delete.",
        title: "Delete local data"
      },
      libraryDetail: "Free keeps tracking in this browser when cloud sync is not active.",
      libraryTitle: "Local library",
      subtitle: "Local mode stays simple and private.",
      syncDetail: "Local progress stays in this browser until Account AV enables sync.",
      syncTitle: "Local data",
      title: "On this device"
    },
    help: {
      openSourceDetail: "Series AV is maintained as an independent open-source project.",
      openSourceTitle: "Open-source project",
      privacyDetail: "See how Series AV handles your data.",
      privacyTitle: "Privacy policy",
      sourceCodeDetail: "Browse the repository, issues, and contribution guidelines.",
      sourceCodeTitle: "Source code",
      subtitle: "Open support, privacy, terms, and source links from here.",
      supportDetail: "Open Series AV support.",
      supportTitle: "Contact support",
      termsDetail: "Review the terms that apply to Series AV.",
      termsTitle: "Terms of service",
      title: "Help and legal"
    },
    safety: { deleteDetail: "Open the shared account deletion page.", deleteTitle: "Delete account" }
  },
  es: {
    settingsTitle: "Ajustes",
    settingsSubtitle: "Ajusta la app, gestiona este dispositivo y abre enlaces de ayuda.",
    preferences: {
      languageDetail: "Elige el idioma que usa la interfaz de Series AV.",
      languageTitle: "Idioma de la app",
      subtitle: "Elige cómo se muestra Series AV en este dispositivo.",
      themeDetail: "Elige si Series AV sigue la apariencia del sistema o usa siempre un tema fijo en este dispositivo.",
      themeOptions: { dark: "Oscuro", light: "Claro", system: "Sistema" },
      themeTitle: "Apariencia",
      searchEngineDetail: "Elige el buscador que se abre desde los enlaces de fuentes.",
      searchEngineOptions: externalSearchEngineLabels,
      searchEngineTitle: "Buscador",
      title: "Preferencias de la app"
    },
    series: {
      cursorDetail: "Marca un episodio y Series AV deja anteriores como vistos y posteriores como pendientes.",
      cursorTitle: "Punto único de progreso",
      reversibleDetail: "Mueve el punto atrás o adelante si tocas el episodio incorrecto.",
      reversibleTitle: "Correcciones rápidas",
      subtitle: "Un único punto claro por serie.",
      title: "Seguimiento de series"
    },
    local: {
      delete: {
        confirmDetail: "Se borrarán las series, estados y progreso guardados en este navegador. Esta acción no borra tu cuenta Apps AV.",
        confirmTitle: "Borrar datos locales",
        detail: (count: number) => `Borra ${count} series de este navegador.`,
        empty: "No hay datos locales que borrar.",
        title: "Borrar datos locales"
      },
      libraryDetail: "Free guarda el seguimiento en este navegador cuando la sync cloud no está activa.",
      libraryTitle: "Biblioteca local",
      subtitle: "El modo local se mantiene simple y privado.",
      syncDetail: "El progreso local queda en este navegador hasta que Account AV habilita sync.",
      syncTitle: "Datos locales",
      title: "En este dispositivo"
    },
    help: {
      openSourceDetail: "Series AV se mantiene como una app de código abierto e independiente.",
      openSourceTitle: "Proyecto de código abierto",
      privacyDetail: "Consulta cómo Series AV gestiona tus datos.",
      privacyTitle: "Política de privacidad",
      sourceCodeDetail: "Consulta el repositorio, las incidencias y cómo contribuir.",
      sourceCodeTitle: "Código fuente",
      subtitle: "Abre desde aquí soporte, privacidad, términos y enlaces del código fuente.",
      supportDetail: "Abre el soporte de Series AV.",
      supportTitle: "Contactar con soporte",
      termsDetail: "Revisa los términos aplicables a Series AV.",
      termsTitle: "Términos del servicio",
      title: "Ayuda y legal"
    },
    safety: { deleteDetail: "Abre la página compartida de eliminación de cuenta.", deleteTitle: "Eliminar cuenta" }
  },
  fr: {
    settingsTitle: "Réglages",
    settingsSubtitle: "Ajustez l'app, gérez cet appareil et ouvrez les liens d'aide.",
    preferences: {
      languageDetail: "Choisissez la langue utilisée par l'interface de Series AV.",
      languageTitle: "Langue de l'app",
      subtitle: "Choisissez comment Series AV s'affiche sur cet appareil.",
      themeDetail: "Choisissez si Series AV suit l'apparence du système ou utilise toujours un thème fixe sur cet appareil.",
      themeOptions: { dark: "Sombre", light: "Clair", system: "Système" },
      themeTitle: "Apparence",
      searchEngineDetail: "Choisissez le moteur utilisé par les liens de sources.",
      searchEngineOptions: externalSearchEngineLabels,
      searchEngineTitle: "Moteur de recherche",
      title: "Préférences de l'app"
    },
    series: {
      cursorDetail: "Marquez un épisode et Series AV garde les précédents vus et les suivants en attente.",
      cursorTitle: "Point de progression unique",
      reversibleDetail: "Déplacez le point en arrière ou en avant si vous touchez le mauvais épisode.",
      reversibleTitle: "Corrections rapides",
      subtitle: "Un seul point clair par série.",
      title: "Suivi des séries"
    },
    local: {
      delete: {
        confirmDetail: "Les séries, états et progressions enregistrés dans ce navigateur seront supprimés. Cela ne supprime pas votre compte Apps AV.",
        confirmTitle: "Supprimer les données locales",
        detail: (count: number) => `Supprime ${count} séries de ce navigateur.`,
        empty: "Aucune donnée locale à supprimer.",
        title: "Supprimer les données locales"
      },
      libraryDetail: "Free garde le suivi dans ce navigateur quand la sync cloud n'est pas active.",
      libraryTitle: "Bibliothèque locale",
      subtitle: "Le mode local reste simple et privé.",
      syncDetail: "La progression locale reste dans ce navigateur jusqu'à ce qu'Account AV active la sync.",
      syncTitle: "Données locales",
      title: "Sur cet appareil"
    },
    help: {
      openSourceDetail: "Series AV est maintenue comme une app open source indépendante.",
      openSourceTitle: "Projet open-source",
      privacyDetail: "Découvrez comment Series AV gère vos données.",
      privacyTitle: "Politique de confidentialité",
      sourceCodeDetail: "Consultez le dépôt, les issues et les règles de contribution.",
      sourceCodeTitle: "Code source",
      subtitle: "Ouvrez ici les liens du projet, l'assistance, la confidentialité et les conditions.",
      supportDetail: "Ouvrir l'assistance Series AV.",
      supportTitle: "Contacter l'assistance",
      termsDetail: "Consultez les conditions applicables à Series AV.",
      termsTitle: "Conditions d'utilisation",
      title: "Aide et légal"
    },
    safety: { deleteDetail: "Ouvrir la page partagée de suppression du compte.", deleteTitle: "Supprimer le compte" }
  }
} as const;
