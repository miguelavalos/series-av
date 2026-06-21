import type { AppsAvProductConfig } from "@avalsys/apps-av-web";

export const seriesProductConfig: AppsAvProductConfig = {
  appId: "seriesav",
  accentColor: "#6DBE45",
  assistant: {
    href: "/avi",
    imageSrc: "/assets/avi-footer-icon.png",
    label: "Open Avi guidance",
    name: "Avi"
  },
  iconSrc: "https://cdn.avalsys.com/apps-av/series-av/web-v3/series-av-icon.png",
  logoSrc: "https://cdn.avalsys.com/apps-av/series-av/web-v3/series-av-wordmark.png",
  logoDarkSrc: "https://cdn.avalsys.com/apps-av/series-av/web-v3/series-av-wordmark.png",
  name: "Series AV",
  links: {
    deleteAccount: externalLink(accountManagementUrl("/account/delete"), "Delete account"),
    privacy: externalLink(import.meta.env.VITE_SERIESAV_PRIVACY_URL, "Privacy"),
    suite: externalLink(import.meta.env.VITE_ACCOUNTAV_MANAGEMENT_URL, "Apps"),
    support: externalLink(supportUrl(), "Support"),
    terms: externalLink(import.meta.env.VITE_SERIESAV_TERMS_URL, "Terms")
  }
};

export const seriesBrandAssets = {
  aviFullBody: "/assets/avi-full-body.png",
  aviLoginPeek: "https://cdn.avalsys.com/apps-av/series-av/web-v3/series-av-splash.png",
  aviLoginSheetPeek: "/assets/avi-login-sheet-peek.png",
  aviOnboardingCta: "/assets/avi-onboarding-cta.png",
  guestHomeShelf: "/assets/series-av-guest-home-1.webp",
  guestHomePlanning: "/assets/series-av-guest-home-2.webp",
  guestHomeAvi: "/assets/series-av-guest-home-3.webp",
  logo: "https://cdn.avalsys.com/apps-av/series-av/web-v3/series-av-logo.png",
  onboarding: "https://cdn.avalsys.com/apps-av/series-av/web-v3/series-av-onboarding.png",
  wordmark: "https://cdn.avalsys.com/apps-av/series-av/web-v3/series-av-wordmark.png"
} as const;

export function getSeriesApiBaseUrl() {
  return requiredUrl(import.meta.env.VITE_SERIESAV_API_BASE_URL, "VITE_SERIESAV_API_BASE_URL");
}

export function getAccountApiBaseUrl() {
  return requiredUrl(import.meta.env.VITE_ACCOUNTAV_API_BASE_URL, "VITE_ACCOUNTAV_API_BASE_URL");
}

export function getAccountPublishableKey() {
  return import.meta.env.VITE_ACCOUNTAV_PUBLISHABLE_KEY as string | undefined;
}

export function isSeriesWebAppComingSoon() {
  return import.meta.env.VITE_SERIESAV_WEBAPP_COMING_SOON === "true";
}

function requiredUrl(value: string | undefined, key: string) {
  const normalized = trimTrailingSlash(value);
  if (!normalized) {
    throw new Error(`${key} is required.`);
  }
  return normalized;
}

function accountManagementUrl(path: string) {
  const baseUrl = trimTrailingSlash(import.meta.env.VITE_ACCOUNTAV_MANAGEMENT_URL);
  return baseUrl ? `${baseUrl}${path}` : undefined;
}

function supportUrl() {
  return trimTrailingSlash(import.meta.env.VITE_SUPPORTAV_BASE_URL) || commercialSiteUrl("/support");
}

function commercialSiteUrl(path: string) {
  const privacyUrl = trimTrailingSlash(import.meta.env.VITE_SERIESAV_PRIVACY_URL);
  const url = privacyUrl ? new URL(privacyUrl) : new URL("https://series-av.avalsys.com");
  return `${url.origin}${path}`;
}

function externalLink(href: string | undefined, label: string) {
  const normalized = normalizeHref(href);
  return normalized ? { href: normalized, label, external: true } : undefined;
}

function normalizeHref(value: string | undefined) {
  if (!value) {
    return "";
  }

  return value.startsWith("mailto:") ? value.trim() : trimTrailingSlash(value);
}

function trimTrailingSlash(value: string | undefined) {
  return value?.trim().replace(/\/+$/, "") ?? "";
}
