#!/usr/bin/env node

import { runSharedWebSmokeQa } from "../../../../apps-av/web/scripts/shared-web-smoke-qa.mjs";

const result = await runSharedWebSmokeQa({
  baseUrl: process.env.SERIESAV_WEB_QA_BASE_URL ?? "http://localhost:5193",
  expectations: {
    ca: {
      protectedTitle: "Porta el teu quadern de series amb tu",
      publicCopy: "El teu quadern de series",
      signInCopy: "Inicia sessio"
    },
    de: {
      protectedTitle: "Nimm dein Seriennotizbuch mit",
      publicCopy: "Dein Seriennotizbuch",
      signInCopy: "Anmelden"
    },
    en: {
      protectedTitle: "Keep your series notebook with you",
      publicCopy: "Your series notebook",
      signInCopy: "Sign in"
    },
    es: {
      protectedTitle: "Lleva tu cuaderno de series contigo",
      publicCopy: "Tu cuaderno de series",
      signInCopy: "Iniciar sesion"
    },
    fr: {
      protectedTitle: "Gardez votre carnet de series avec vous",
      publicCopy: "Votre carnet de series",
      signInCopy: "Se connecter"
    }
  },
  name: "Series AV",
  ownRoutePrefixes: ["/", "/library", "/search", "/avi", "/account", "/settings", "/sign-in", "/series/"],
  productIdentity: "Series AV",
  routes: ["/", "/library", "/search", "/avi", "/account", "/settings"]
});

if (!result.passed) {
  process.exit(1);
}
