import { useAppsAvLocale, type AppsAvLocale } from "@avalsys/apps-av-web";

const en = {
  footer: {
    deleteAccount: "Delete account",
    language: "Language",
    privacy: "Privacy",
    support: "Support",
    terms: "Terms"
  },
  login: {
    aviGuidance: "Avi guidance",
    cardBody: "Save what you are watching, find what is next, and return to your progress without rebuilding the list.",
    cardTitle: "Continue from your list",
    cta: "Sign in",
    heroBody: "Sign in to keep your library, episode progress, and Avi guidance connected wherever you watch.",
    heroTitle: "Your series notebook, always ready.",
    intro: "Follow every show, remember the next episode, and keep your watch list close from any screen.",
    mapBody: "The web experience keeps the notebook feeling from iOS: paper texture, ink lines, green checkpoints, and Avi close at hand.",
    mapTitle: "A hand-drawn progress map for your next episode.",
    notebook: "Series notebook",
    search: "Series search"
  },
  protected: {
    body: "Sign in to open your library, search the catalog, and let Avi help you choose what to watch next.",
    cta: "Sign in",
    title: "Keep your series notebook with you."
  },
  signIn: {
    aviPanelBody: "A quiet nudge when the next episode is unclear.",
    body: "Sign in to keep your shows, next episodes, and Avi recommendations connected with your AV account.",
    continue: "Continue",
    signedIn: "You are signed in.",
    title: "Your Series AV library follows you."
  }
};

export const seriesText: Record<AppsAvLocale, typeof en> = {
  ca: {
    footer: {
      deleteAccount: "Eliminar compte",
      language: "Idioma",
      privacy: "Privacitat",
      support: "Ajuda",
      terms: "Condicions"
    },
    login: {
      aviGuidance: "Guia d'Avi",
      cardBody: "Desa el que mires, troba que ve despres i torna al teu progres sense refer la llista.",
      cardTitle: "Continua des de la teva llista",
      cta: "Inicia sessio",
      heroBody: "Inicia sessio per mantenir la biblioteca, el progres dels episodis i l'ajuda d'Avi connectats alla on miris.",
      heroTitle: "El teu quadern de series, sempre a punt.",
      intro: "Segueix cada serie, recorda el proper episodi i tingues la llista a ma des de qualsevol pantalla.",
      mapBody: "L'experiencia web mante el to de quadern d'iOS: textura de paper, linies de tinta, punts verds i Avi ben a prop.",
      mapTitle: "Un mapa de progres dibuixat a ma per al proper episodi.",
      notebook: "Quadern de series",
      search: "Cerca de series"
    },
    protected: {
      body: "Inicia sessio per obrir la biblioteca, cercar el cataleg i deixar que Avi t'ajudi a triar que mirar despres.",
      cta: "Inicia sessio",
      title: "Porta el teu quadern de series amb tu."
    },
    signIn: {
      aviPanelBody: "Un petit impuls quan el proper episodi no queda clar.",
      body: "Inicia sessio per mantenir les series, els propers episodis i les recomanacions d'Avi connectades amb el teu compte AV.",
      continue: "Continua",
      signedIn: "Ja has iniciat sessio.",
      title: "La teva biblioteca de Series AV t'acompanya."
    }
  },
  de: {
    footer: {
      deleteAccount: "Konto loeschen",
      language: "Sprache",
      privacy: "Datenschutz",
      support: "Hilfe",
      terms: "Bedingungen"
    },
    login: {
      aviGuidance: "Avi hilft dir",
      cardBody: "Speichere, was du schaust, finde die naechste Folge und kehre zu deinem Fortschritt zurueck.",
      cardTitle: "Mach mit deiner Liste weiter",
      cta: "Anmelden",
      heroBody: "Melde dich an, damit Bibliothek, Episodenfortschritt und Avi-Hilfe ueberall verbunden bleiben.",
      heroTitle: "Dein Seriennotizbuch, immer bereit.",
      intro: "Behalte jede Serie im Blick, merke dir die naechste Folge und nimm deine Watchlist auf jeden Bildschirm mit.",
      mapBody: "Die Web-Erfahrung behaelt das Notizbuchgefuehl von iOS: Papierstruktur, Tintenlinien, gruene Markierungen und Avi in der Naehe.",
      mapTitle: "Eine handgezeichnete Fortschrittskarte fuer deine naechste Folge.",
      notebook: "Seriennotizbuch",
      search: "Seriensuche"
    },
    protected: {
      body: "Melde dich an, um deine Bibliothek zu oeffnen, den Katalog zu durchsuchen und Avi bei der naechsten Wahl helfen zu lassen.",
      cta: "Anmelden",
      title: "Nimm dein Seriennotizbuch mit."
    },
    signIn: {
      aviPanelBody: "Ein ruhiger Hinweis, wenn die naechste Folge unklar ist.",
      body: "Melde dich an, damit deine Serien, naechsten Folgen und Avi-Empfehlungen mit deinem AV-Konto verbunden bleiben.",
      continue: "Weiter",
      signedIn: "Du bist angemeldet.",
      title: "Deine Series AV Bibliothek begleitet dich."
    }
  },
  en,
  es: {
    footer: {
      deleteAccount: "Eliminar cuenta",
      language: "Idioma",
      privacy: "Privacidad",
      support: "Ayuda",
      terms: "Condiciones"
    },
    login: {
      aviGuidance: "Guia de Avi",
      cardBody: "Guarda lo que estas viendo, encuentra que viene despues y vuelve a tu progreso sin reconstruir la lista.",
      cardTitle: "Continua desde tu lista",
      cta: "Iniciar sesion",
      heroBody: "Inicia sesion para mantener tu biblioteca, progreso de episodios y guia de Avi conectados alli donde mires.",
      heroTitle: "Tu cuaderno de series, siempre listo.",
      intro: "Sigue cada serie, recuerda el proximo episodio y manten tu lista cerca desde cualquier pantalla.",
      mapBody: "La experiencia web mantiene el tono de cuaderno de iOS: textura de papel, lineas de tinta, marcas verdes y Avi cerca.",
      mapTitle: "Un mapa de progreso dibujado a mano para tu proximo episodio.",
      notebook: "Cuaderno de series",
      search: "Busqueda de series"
    },
    protected: {
      body: "Inicia sesion para abrir tu biblioteca, buscar en el catalogo y dejar que Avi te ayude a elegir que ver despues.",
      cta: "Iniciar sesion",
      title: "Lleva tu cuaderno de series contigo."
    },
    signIn: {
      aviPanelBody: "Un pequeno empujon cuando el proximo episodio no esta claro.",
      body: "Inicia sesion para mantener tus series, proximos episodios y recomendaciones de Avi conectados con tu cuenta AV.",
      continue: "Continuar",
      signedIn: "Has iniciado sesion.",
      title: "Tu biblioteca de Series AV te acompana."
    }
  },
  fr: {
    footer: {
      deleteAccount: "Supprimer le compte",
      language: "Langue",
      privacy: "Confidentialite",
      support: "Aide",
      terms: "Conditions"
    },
    login: {
      aviGuidance: "Conseils d'Avi",
      cardBody: "Enregistrez ce que vous regardez, trouvez la suite et retrouvez votre progression sans refaire la liste.",
      cardTitle: "Reprendre depuis votre liste",
      cta: "Se connecter",
      heroBody: "Connectez-vous pour garder votre bibliotheque, la progression des episodes et l'aide d'Avi synchronisees partout.",
      heroTitle: "Votre carnet de series, toujours pret.",
      intro: "Suivez chaque serie, gardez le prochain episode en memoire et retrouvez votre liste sur tous vos ecrans.",
      mapBody: "L'experience web garde l'esprit carnet d'iOS : texture papier, traits d'encre, reperes verts et Avi tout pres.",
      mapTitle: "Une carte de progression dessinee a la main pour votre prochain episode.",
      notebook: "Carnet de series",
      search: "Recherche de series"
    },
    protected: {
      body: "Connectez-vous pour ouvrir votre bibliotheque, parcourir le catalogue et laisser Avi vous aider a choisir la suite.",
      cta: "Se connecter",
      title: "Gardez votre carnet de series avec vous."
    },
    signIn: {
      aviPanelBody: "Un petit coup de pouce quand le prochain episode n'est pas clair.",
      body: "Connectez-vous pour garder vos series, prochains episodes et recommandations d'Avi liees a votre compte AV.",
      continue: "Continuer",
      signedIn: "Vous etes connecte.",
      title: "Votre bibliotheque Series AV vous accompagne."
    }
  }
};

export function useSeriesText() {
  return seriesText[useAppsAvLocale()];
}
