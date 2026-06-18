#!/usr/bin/env node

const baseUrl = (process.env.SERIESAV_WEB_QA_BASE_URL ?? "http://localhost:5193").replace(/\/+$/, "");

const locales = ["en", "es", "fr", "de", "ca"];
const routes = ["/", "/library", "/search", "/avi", "/account", "/settings"];
const protectedRoutes = routes.filter((route) => route !== "/");

const guestCopyPattern = /\b(guest|guest-mode|invitado|invitada|convidat|convidada|gastmodus)\b/i;
const failurePattern = /(Something went wrong|The requested module|Internal Server Error|Unhandled Runtime Error|ReferenceError|TypeError)/i;

const expectations = {
  ca: {
    home: "El teu quadern de series",
    lang: '<html lang="ca"',
    protected: "Porta el teu quadern de series amb tu",
    signIn: "Inicia sessio"
  },
  de: {
    home: "Dein Seriennotizbuch",
    lang: '<html lang="de"',
    protected: "Nimm dein Seriennotizbuch mit",
    signIn: "Anmelden"
  },
  en: {
    home: "Your series notebook",
    lang: '<html lang="en"',
    protected: "Keep your series notebook with you",
    signIn: "Sign in"
  },
  es: {
    home: "Tu cuaderno de series",
    lang: '<html lang="es"',
    protected: "Lleva tu cuaderno de series contigo",
    signIn: "Iniciar sesion"
  },
  fr: {
    home: "Votre carnet de series",
    lang: '<html lang="fr"',
    protected: "Gardez votre carnet de series avec vous",
    signIn: "Se connecter"
  }
};

const failures = [];

for (const locale of locales) {
  for (const route of routes) {
    const url = localizedUrl(route, locale);
    const response = await fetch(url, { redirect: "manual" });
    const html = await response.text();
    const normalized = normalizeText(html);

    check(response.status === 200, `${locale} ${route} returns 200`, `${response.status} from ${url}`);
    check(normalized.includes("Series AV"), `${locale} ${route} renders product identity`);
    check(normalized.includes(expectations[locale].lang), `${locale} ${route} sets html lang`);
    check(!failurePattern.test(normalized), `${locale} ${route} has no runtime error marker`);
    check(!guestCopyPattern.test(normalized), `${locale} ${route} has no guest product copy`);

    if (route === "/") {
      check(
        normalized.includes(expectations[locale].home),
        `${locale} public home renders localized public copy`
      );
      check(
        ownLinksPreserveLocale(html, locale),
        `${locale} public home keeps locale on product-owned links`
      );
    }

    if (protectedRoutes.includes(route)) {
      check(
        normalized.includes(expectations[locale].protected) && normalized.includes(expectations[locale].signIn),
        `${locale} ${route} shows signed-out protection gate`
      );
      check(
        ownLinksPreserveLocale(html, locale),
        `${locale} ${route} keeps locale on product-owned links`
      );
    }
  }
}

if (failures.length > 0) {
  console.error(`Series AV shared web QA failed (${failures.length}):`);
  for (const failure of failures) {
    console.error(`- ${failure}`);
  }
  process.exit(1);
}

console.log(`Series AV shared web QA passed for ${locales.length} locales and ${routes.length} routes at ${baseUrl}.`);

function localizedUrl(route, locale) {
  const path = locale === "en" ? route : `${route}?lang=${locale}`;
  return `${baseUrl}${path}`;
}

function check(condition, label, detail) {
  if (!condition) {
    failures.push(detail ? `${label}: ${detail}` : label);
  }
}

function normalizeText(value) {
  return value
    .normalize("NFD")
    .replace(/\p{Diacritic}/gu, "")
    .replace(/&amp;/g, "&")
    .replace(/&#x27;/g, "'")
    .replace(/\s+/g, " ");
}

function ownLinksPreserveLocale(html, locale) {
  if (locale === "en") {
    return true;
  }

  const hrefs = Array.from(html.matchAll(/\shref="([^"]+)"/g), (match) =>
    match[1].replace(/&amp;/g, "&")
  );

  const ownRouteHrefs = hrefs.filter((href) => {
    if (!href.startsWith("/")) {
      return false;
    }
    if (href.startsWith("/assets/") || href.startsWith("/@") || href.startsWith("/_")) {
      return false;
    }
    return ["/", "/library", "/search", "/avi", "/account", "/settings", "/sign-in", "/series/"].some((prefix) =>
      prefix === "/" ? href === "/" || href.startsWith("/?") : href.startsWith(prefix)
    );
  });

  return ownRouteHrefs.every((href) => {
    const parsed = new URL(href, baseUrl);
    return parsed.searchParams.get("lang") === locale;
  });
}
