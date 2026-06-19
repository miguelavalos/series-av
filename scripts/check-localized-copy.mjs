#!/usr/bin/env node
import { readFileSync } from "node:fs";
import { join } from "node:path";

const repoRoot = new URL("..", import.meta.url).pathname.replace(/\/$/, "");
const iosResources = join(repoRoot, "apps/ios/SeriesAV/Resources");
const locales = ["en", "ca", "de", "es", "fr"];
const blockedVisibleCopy = [
  /\bRecommended\b/,
  /\brecommendations?\b/i,
  /\bwherever you watch\b/i,
  /\bfrom any screen\b/i,
  /\brecomanacions?\b/i,
  /\brecomendaciones?\b/i,
  /\bEmpfehlungen?\b/i,
  /\brecommandations?\b/i,
  /\ball[aà] on miris\b/i,
  /\bdesde cualquier pantalla\b/i,
  /\btous vos [ée]crans\b/i,
  /\büberall\b/i
];

const expectedMoreToTrack = {
  ca: "Més per seguir",
  de: "Mehr zum Verfolgen",
  en: "More to track",
  es: "Más para seguir",
  fr: "Plus à suivre"
};

function fail(message) {
  console.error(message);
  process.exitCode = 1;
}

function iosStrings(locale) {
  const path = join(iosResources, `${locale}.lproj/Localizable.strings`);
  const text = readFileSync(path, "utf8");
  const entries = new Map();
  for (const match of text.matchAll(/^"([^"]+)"\s*=\s*"((?:\\"|[^"])*)";/gm)) {
    entries.set(match[1], match[2]);
  }
  return { entries, path, text };
}

const english = iosStrings("en");
for (const locale of locales) {
  const current = iosStrings(locale);
  const missing = [...english.entries.keys()].filter((key) => !current.entries.has(key));
  const extra = [...current.entries.keys()].filter((key) => !english.entries.has(key));
  if (missing.length > 0) {
    fail(`${current.path}: missing iOS localization keys: ${missing.join(", ")}`);
  }
  if (extra.length > 0) {
    fail(`${current.path}: extra iOS localization keys: ${extra.join(", ")}`);
  }
  const railLabel = current.entries.get("home.rail.recommended");
  if (railLabel !== expectedMoreToTrack[locale]) {
    fail(`${current.path}: home.rail.recommended must be "${expectedMoreToTrack[locale]}", got "${railLabel}"`);
  }
}

const visibleCopyFiles = [
  ...locales.map((locale) => join(iosResources, `${locale}.lproj/Localizable.strings`)),
  join(repoRoot, "apps/web/src/lib/series-i18n.ts"),
  join(repoRoot, "apps/web/src/routes/index.tsx")
];

for (const path of visibleCopyFiles) {
  const text = readFileSync(path, "utf8");
  for (const pattern of blockedVisibleCopy) {
    const match = text.match(pattern);
    if (match) {
      fail(`${path}: blocked stale copy matched ${pattern}: "${match[0]}"`);
    }
  }
}

const webHome = readFileSync(join(repoRoot, "apps/web/src/routes/index.tsx"), "utf8");
for (const [locale, label] of Object.entries(expectedMoreToTrack)) {
  if (!webHome.includes(`recommended: "${label}"`)) {
    fail(`apps/web/src/routes/index.tsx: missing ${locale} Home rail label "${label}"`);
  }
}

if (!process.exitCode) {
  console.log("Localized copy audit passed.");
}
