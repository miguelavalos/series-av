import { useAppsAvLocale } from "@avalsys/apps-av-web";
import { Link, createFileRoute } from "@tanstack/react-router";
import { Globe, HelpCircle, Moon, Trash2 } from "lucide-react";
import { useEffect, useState } from "react";
import { ProtectedRoute } from "@/components/protected-route";
import { SeriesAppShell } from "@/components/series-app-shell";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { seriesProductConfig } from "@/lib/series-config";
import { useSeriesLibrary } from "@/lib/series-library-provider";
import { localizedExternalUrl, localizedSeriesPath, useSeriesText } from "@/lib/series-i18n";

export const Route = createFileRoute("/settings")({
  component: SettingsRoute
});

function SettingsRoute() {
  const locale = useAppsAvLocale();
  const text = useSeriesText();
  const library = useSeriesLibrary();
  const locales = ["en", "es", "fr", "de", "ca"] as const;
  const labels = settingsLabels[locale];
  const [theme, setThemeState] = useState<SeriesTheme>("system");

  useEffect(() => {
    const storedTheme = readThemePreference();
    if (storedTheme === "light" || storedTheme === "dark") {
      setThemeState(storedTheme);
      applyTheme(storedTheme);
      return;
    }
    setThemeState("system");
    applyTheme("system");
  }, []);

  const setTheme = (nextTheme: SeriesTheme) => {
    setThemeState(nextTheme);
    applyTheme(nextTheme);
  };

  return (
    <ProtectedRoute>
      <SeriesAppShell>
        <section className="grid gap-6 lg:grid-cols-[1fr_22rem]">
          <Card className="series-paper gap-5 rounded-lg border-[#d7c494] p-6 py-6 shadow-lg shadow-[#172f5c]/8 sm:p-8 sm:py-8">
            <div>
              <p className="text-sm font-semibold text-[#5a8f2f]">{text.nav.settings}</p>
              <h1 className="mt-2 text-4xl font-semibold leading-tight text-[#112a55]">{labels.title}</h1>
              <p className="mt-3 max-w-2xl text-sm leading-6 text-[#53617a]">{labels.body}</p>
            </div>
            <section className="rounded-lg border border-[#d7c494] bg-[#fff8df]/72 p-4">
              <h2 className="flex items-center gap-2 font-semibold text-[#112a55]">
                <Globe className="size-4 text-[#5a8f2f]" /> {text.footer.language}
              </h2>
              <div className="mt-3 flex flex-wrap gap-2">
                {locales.map((item) => (
                  <Button key={item} asChild variant={locale === item ? "default" : "outline"} className={locale === item ? "rounded-full bg-[#112a55] text-white" : "rounded-full border-[#c8ad72] bg-white/60"}>
                    <Link to={localizedSeriesPath("/settings", item)}>{item.toUpperCase()}</Link>
                  </Button>
                ))}
              </div>
            </section>
            <section className="rounded-lg border border-[#d7c494] bg-[#fff8df]/72 p-4">
              <h2 className="flex items-center gap-2 font-semibold text-[#112a55]">
                <Moon className="size-4 text-[#5a8f2f]" /> {labels.themeTitle}
              </h2>
              <div className="mt-3 flex flex-wrap gap-2">
                {themeOptions.map((item) => (
                  <Button
                    key={item}
                    variant={theme === item ? "default" : "outline"}
                    className={theme === item ? "rounded-full bg-[#112a55] text-white" : "rounded-full border-[#c8ad72] bg-white/60"}
                    onClick={() => setTheme(item)}
                  >
                    {labels.themeOptions[item]}
                  </Button>
                ))}
              </div>
            </section>
            <section className="rounded-lg border border-[#d7c494] bg-[#fff8df]/72 p-4">
              <h2 className="flex items-center gap-2 font-semibold text-[#112a55]">
                <Trash2 className="size-4 text-[#5a8f2f]" /> {labels.localTitle}
              </h2>
              <p className="mt-2 text-sm leading-6 text-[#53617a]">{labels.localBody}</p>
              <Button variant="outline" className="mt-3 rounded-full border-red-200 bg-white/60 text-red-700" disabled={library.entries.length === 0} onClick={() => library.clearLocalData()}>
                {labels.clearLocal}
              </Button>
            </section>
          </Card>
          <Card className="gap-3 rounded-lg border-[#d7c494] bg-[#fff8df]/88 p-5 py-5 text-[#112a55] shadow-sm shadow-[#172f5c]/6">
            <h2 className="flex items-center gap-2 font-semibold">
              <HelpCircle className="size-4 text-[#5a8f2f]" /> {labels.helpLegal}
            </h2>
            <a className="text-sm font-semibold text-[#112a55] underline" href={localizedExternalUrl(seriesProductConfig.links.support?.href, locale)}>{text.footer.support}</a>
            <a className="text-sm font-semibold text-[#112a55] underline" href={localizedExternalUrl(seriesProductConfig.links.privacy?.href, locale)}>{text.footer.privacy}</a>
            <a className="text-sm font-semibold text-[#112a55] underline" href={localizedExternalUrl(seriesProductConfig.links.terms?.href, locale)}>{text.footer.terms}</a>
            <a className="text-sm font-semibold text-[#112a55] underline" href={localizedExternalUrl(seriesProductConfig.links.deleteAccount?.href, locale)}>{text.footer.deleteAccount}</a>
          </Card>
        </section>
      </SeriesAppShell>
    </ProtectedRoute>
  );
}

type SeriesTheme = "system" | "light" | "dark";

const themeStorageKey = "series-av.theme";
const themeOptions: SeriesTheme[] = ["system", "light", "dark"];

function applyTheme(theme: SeriesTheme) {
  if (theme === "system") {
    removeThemePreference();
    delete document.documentElement.dataset.seriesTheme;
    return;
  }

  writeThemePreference(theme);
  document.documentElement.dataset.seriesTheme = theme;
}

function readThemePreference() {
  try {
    return window.localStorage?.getItem(themeStorageKey);
  } catch {
    return null;
  }
}

function writeThemePreference(theme: Exclude<SeriesTheme, "system">) {
  try {
    window.localStorage?.setItem(themeStorageKey, theme);
  } catch {
    // Theme still applies for the current page when browser storage is unavailable.
  }
}

function removeThemePreference() {
  try {
    window.localStorage?.removeItem(themeStorageKey);
  } catch {
    // Theme still returns to system for the current page when browser storage is unavailable.
  }
}

const settingsLabels = {
  ca: {
    body: "Idioma, còpia local i enllaços de suport en un lloc.",
    clearLocal: "Neteja la biblioteca local",
    helpLegal: "Ajuda i legal",
    localBody: "Esborra només la còpia d'aquest navegador. El núvol continua sent propietat d'Account AV.",
    localTitle: "En aquest navegador",
    themeOptions: { dark: "Fosc", light: "Clar", system: "Sistema" },
    themeTitle: "Tema",
    title: "Preferències"
  },
  de: {
    body: "Sprache, lokale Kopie und Hilfe-Links an einem Ort.",
    clearLocal: "Lokale Bibliothek leeren",
    helpLegal: "Hilfe und Rechtliches",
    localBody: "Löscht nur die Kopie in diesem Browser. Cloud-Daten bleiben bei Account AV.",
    localTitle: "In diesem Browser",
    themeOptions: { dark: "Dunkel", light: "Hell", system: "System" },
    themeTitle: "Design",
    title: "Einstellungen"
  },
  en: {
    body: "Language, local copy, and support links in one place.",
    clearLocal: "Clear local library",
    helpLegal: "Help and legal",
    localBody: "Clears only this browser copy. Cloud state remains Account AV-owned.",
    localTitle: "On this browser",
    themeOptions: { dark: "Dark", light: "Light", system: "System" },
    themeTitle: "Theme",
    title: "Preferences"
  },
  es: {
    body: "Idioma, copia local y enlaces de soporte en un sitio.",
    clearLocal: "Borrar biblioteca local",
    helpLegal: "Ayuda y legal",
    localBody: "Borra solo la copia de este navegador. El estado cloud sigue en Account AV.",
    localTitle: "En este navegador",
    themeOptions: { dark: "Oscuro", light: "Claro", system: "Sistema" },
    themeTitle: "Tema",
    title: "Preferencias"
  },
  fr: {
    body: "Langue, copie locale et liens d'aide au même endroit.",
    clearLocal: "Effacer la bibliothèque locale",
    helpLegal: "Aide et légal",
    localBody: "Efface seulement la copie de ce navigateur. L'état cloud reste côté Account AV.",
    localTitle: "Sur ce navigateur",
    themeOptions: { dark: "Sombre", light: "Clair", system: "Système" },
    themeTitle: "Thème",
    title: "Préférences"
  }
} as const;
