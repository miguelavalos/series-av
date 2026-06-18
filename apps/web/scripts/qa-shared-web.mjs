#!/usr/bin/env node

import { runSharedWebSmokeQa } from "../../../../apps-av/web/scripts/shared-web-smoke-qa.mjs";

const result = await runSharedWebSmokeQa({
  baseUrl: process.env.SERIESAV_WEB_QA_BASE_URL ?? "http://localhost:5193",
  expectations: {
    ca: {
      protectedTitle: "Porta el teu quadern de series amb tu",
      publicCopy: "El teu quadern de series",
      signInCopy: "Inicia sessio",
      signInRouteCopy: "Inicia sessio per mantenir les series"
    },
    de: {
      protectedTitle: "Nimm dein Seriennotizbuch mit",
      publicCopy: "Dein Seriennotizbuch",
      signInCopy: "Anmelden",
      signInRouteCopy: "Melde dich an"
    },
    en: {
      protectedTitle: "Keep your series notebook with you",
      publicCopy: "Your series notebook",
      signInCopy: "Sign in",
      signInRouteCopy: "Sign in to keep your shows"
    },
    es: {
      protectedTitle: "Lleva tu cuaderno de series contigo",
      publicCopy: "Tu cuaderno de series",
      signInCopy: "Iniciar sesion",
      signInRouteCopy: "Inicia sesion para mantener tus series"
    },
    fr: {
      protectedTitle: "Gardez votre carnet de series avec vous",
      publicCopy: "Votre carnet de series",
      signInCopy: "Se connecter",
      signInRouteCopy: "Connectez-vous pour garder vos series"
    }
  },
  name: "Series AV",
  ownRoutePrefixes: ["/", "/library", "/search", "/avi", "/account", "/settings", "/sign-in", "/series/"],
  productIdentity: "Series AV",
  routes: ["/", "/sign-in", "/library", "/search", "/avi", "/account", "/settings", "/series/thetvdb%3A348545"],
  signInRoutes: ["/sign-in"]
});

if (!result.passed) {
  process.exit(1);
}
