import { useMemo } from "react";
import { useAppsAvLocale, type AppsAvLocale, type AppsAvProductConfig, type AppsAvProductLink } from "@avalsys/apps-av-web";
import { appsAvLocalizedPath } from "@avalsys/apps-av-web/src/lib/localized-links";
import { caES } from "@clerk/localizations/ca-ES";
import { deDE } from "@clerk/localizations/de-DE";
import { enUS } from "@clerk/localizations/en-US";
import { esES } from "@clerk/localizations/es-ES";
import { frFR } from "@clerk/localizations/fr-FR";
import { seriesProductConfig } from "@/lib/series-config";

const en = {
  account: {
    signInTitle: "Sign in to Series AV",
    signInSubtitle: "Welcome back. Sign in to keep your series notebook connected."
  },
  avi: {
    body: "Avi helps turn a messy watch list into a clear next step: continue, save, catch up, or keep the library easier to read.",
    cards: [
      {
        text: "Avi can point out which shows need a saved status, a next episode, or a cleaner progress note.",
        title: "Prepare the notebook"
      },
      {
        text: "Upcoming episodes and active shows stay readable, so the next action does not get buried.",
        title: "Choose what is next"
      },
      {
        text: "Library guidance starts from the series you already saved and the next episode you can act on.",
        title: "Use real context"
      }
    ],
    libraryCta: "Open library",
    searchCta: "Find a series",
    title: "A calm guide for your next episode."
  },
  config: {
    body: "Run the web app through the Varlock wrapper so Account AV configuration is available. Web access is always login-first.",
    eyebrow: "Configuration required",
    title: "Series AV Web needs Clerk configuration."
  },
  footer: {
    deleteAccount: "Delete account",
    language: "Language",
    privacy: "Privacy",
    support: "Support",
    terms: "Terms"
  },
  home: {
    aviBody: [
      "Start from your current shows and find the next useful action.",
      "Spot missing progress before the queue becomes hard to read.",
      "Keep guidance close to your real watching habits."
    ],
    aviTitle: "Avi keeps watch",
    body: "Search the catalog, save progress, and keep a clear map of what to watch next.",
    cta: "Search catalog",
    items: [
      { label: "Catalog search", value: "Find series by title" },
      { label: "Library", value: "Keep your saved shows together" },
      { label: "Next episodes", value: "Return to what is coming up" }
    ],
    title: "Pick up your series notebook."
  },
  library: {
    add: "Add series",
    body: "Keep watching, plan what comes next, and move finished shows out of the way without losing them.",
    emptyBody: "Search the catalog, choose a show, and Series AV will keep the next episode and progress notes together here.",
    emptyTitle: "Start by saving a series.",
    filters: ["All", "Watching", "Want to watch", "Watched", "Archived"],
    hints: [
      { text: "Active shows stay at the top so the next step is easy to find.", title: "Watching" },
      { text: "New episodes can surface beside the shows you already follow.", title: "Upcoming" },
      { text: "Finished or paused series stay available without crowding the main list.", title: "Archive" }
    ],
    kicker: "Library",
    title: "Your saved series, ordered for the next episode."
  },
  login: {
    aviGuidance: "Avi guidance",
    cardBody: "Save what you are watching, find what is next, and return to your progress without rebuilding the list.",
    cardTitle: "Continue from your list",
    cta: "Sign in",
    heroBody: "Sign in to keep your library, episode progress, and Avi guidance connected with your AV account.",
    heroTitle: "Your series notebook, always ready.",
    intro: "Follow every show, remember the next episode, and keep your watch list close in Series AV.",
    mapBody: "The web experience keeps the notebook feeling from iOS: paper texture, ink lines, green checkpoints, and Avi close at hand.",
    mapTitle: "A hand-drawn progress map for your next episode.",
    notebook: "Series notebook",
    search: "Series search"
  },
  nav: {
    account: "Account",
    avi: "Avi",
    aviLabel: "Open Avi guidance",
    home: "Home",
    homeLabel: "Series AV home",
    library: "Library",
    mobileNavigation: "Mobile navigation",
    openNavigation: "Open navigation",
    primaryNavigation: "Primary navigation",
    search: "Search",
    settings: "Settings"
  },
  protected: {
    body: "Sign in to open your library, search the catalog, and let Avi help you choose what to watch next.",
    cta: "Sign in",
    title: "Keep your series notebook with you."
  },
  signIn: {
    aviPanelBody: "A quiet nudge when the next episode is unclear.",
    body: "Sign in to keep your shows, next episodes, and Avi guidance connected with your AV account.",
    continue: "Continue",
    signedIn: "You are signed in.",
    title: "Your Series AV library follows you."
  },
  search: {
    dateUnknown: "Date unknown",
    description: "Find a title, review its artwork, and prepare it for the signed-in library workflow.",
    emptyBody: "Try a different title.",
    emptyTitle: "No series found",
    errorTitle: "Series search failed",
    inputLabel: "Search series",
    noArtwork: "No artwork",
    noOverview: "No overview is available yet.",
    placeholder: "Search a series",
    title: "Search the Series AV catalog."
  }
};

export const seriesText: Record<AppsAvLocale, typeof en> = {
  ca: {
    account: {
      signInTitle: "Inicia sessió a Series AV",
      signInSubtitle: "Torna-hi. Inicia sessió per mantenir connectat el teu quadern de sèries."
    },
    avi: {
      body: "Avi ajuda a convertir una llista desordenada en un proper pas clar: continuar, desar, posar-te al dia o mantenir la biblioteca més fàcil de llegir.",
      cards: [
        { text: "Avi pot indicar quines sèries necessiten un estat desat, un proper episodi o una nota de progrés més clara.", title: "Prepara el quadern" },
        { text: "Els episodis propers i les sèries actives es mantenen llegibles, perquè el proper pas no quedi enterrat.", title: "Tria què ve després" },
        { text: "La guia de la biblioteca parteix de les sèries que ja has desat i del proper episodi que pots fer avançar.", title: "Fes servir context real" }
      ],
      libraryCta: "Obre la biblioteca",
      searchCta: "Troba una sèrie",
      title: "Una guia tranquil·la per al proper episodi."
    },
    config: {
      body: "Executa la web amb el wrapper de Varlock perquè la configuració d'Account AV estigui disponible. L'accés web sempre requereix iniciar sessió.",
      eyebrow: "Configuració necessària",
      title: "Series AV Web necessita la configuració de Clerk."
    },
    footer: {
      deleteAccount: "Eliminar compte",
      language: "Idioma",
      privacy: "Privacitat",
      support: "Ajuda",
      terms: "Condicions"
    },
    home: {
      aviBody: [
        "Comença des de les sèries actuals i troba el proper pas útil.",
        "Detecta progrés pendent abans que la cua sigui difícil de llegir.",
        "Mantingues la guia a prop dels teus hàbits reals."
      ],
      aviTitle: "Avi vigila",
      body: "Cerca al catàleg, desa el progrés i manté un mapa clar del que toca mirar després.",
      cta: "Cerca al catàleg",
      items: [
        { label: "Cerca al catàleg", value: "Troba sèries pel títol" },
        { label: "Biblioteca", value: "Mantingues juntes les sèries desades" },
        { label: "Propers episodis", value: "Torna al que està per arribar" }
      ],
      title: "Reprèn el teu quadern de sèries."
    },
    library: {
      add: "Afegeix sèrie",
      body: "Continua mirant, planifica què ve després i aparta les sèries acabades sense perdre-les.",
      emptyBody: "Cerca al catàleg, tria una sèrie i Series AV mantindrà aquí el proper episodi i les notes de progrés.",
      emptyTitle: "Comença desant una sèrie.",
      filters: ["Totes", "Mirant", "Vull mirar", "Vistes", "Arxivades"],
      hints: [
        { text: "Les sèries actives queden a dalt per trobar fàcilment el proper pas.", title: "Mirant" },
        { text: "Els nous episodis poden aparèixer al costat de les sèries que ja segueixes.", title: "Properament" },
        { text: "Les sèries acabades o pausades continuen disponibles sense omplir la llista principal.", title: "Arxiu" }
      ],
      kicker: "Biblioteca",
      title: "Les teves sèries desades, ordenades pel proper episodi."
    },
    login: {
      aviGuidance: "Guia d'Avi",
      cardBody: "Desa el que mires, troba què ve després i torna al teu progrés sense refer la llista.",
      cardTitle: "Continua des de la teva llista",
      cta: "Inicia sessió",
      heroBody: "Inicia sessió per mantenir la biblioteca, el progrés dels episodis i l'ajuda d'Avi connectats amb el teu compte AV.",
      heroTitle: "El teu quadern de sèries, sempre a punt.",
      intro: "Segueix cada sèrie, recorda el proper episodi i tingues la llista a mà a Series AV.",
      mapBody: "L'experiència web manté el to de quadern d'iOS: textura de paper, línies de tinta, punts verds i Avi ben a prop.",
      mapTitle: "Un mapa de progrés dibuixat a mà per al proper episodi.",
      notebook: "Quadern de sèries",
      search: "Cerca de sèries"
    },
    nav: {
      account: "Compte",
      avi: "Avi",
      aviLabel: "Obre la guia d'Avi",
      home: "Inici",
      homeLabel: "Inici de Series AV",
      library: "Biblioteca",
      mobileNavigation: "Navegació mòbil",
      openNavigation: "Obre la navegació",
      primaryNavigation: "Navegació principal",
      search: "Cerca",
      settings: "Configuració"
    },
    protected: {
      body: "Inicia sessió per obrir la biblioteca, cercar el catàleg i deixar que Avi t'ajudi a triar què mirar després.",
      cta: "Inicia sessió",
      title: "Porta el teu quadern de sèries amb tu."
    },
    signIn: {
      aviPanelBody: "Un petit impuls quan el proper episodi no queda clar.",
      body: "Inicia sessió per mantenir les sèries, els propers episodis i la guia d'Avi connectats amb el teu compte AV.",
      continue: "Continua",
      signedIn: "Ja has iniciat sessió.",
      title: "La teva biblioteca de Series AV t'acompanya."
    },
    search: {
      dateUnknown: "Data desconeguda",
      description: "Troba un títol, revisa'n l'art i prepara'l per al flux de biblioteca amb sessió iniciada.",
      emptyBody: "Prova amb un altre títol.",
      emptyTitle: "No s'han trobat sèries",
      errorTitle: "La cerca de sèries ha fallat",
      inputLabel: "Cerca sèries",
      noArtwork: "Sense imatge",
      noOverview: "Encara no hi ha cap resum disponible.",
      placeholder: "Cerca una sèrie",
      title: "Cerca al catàleg de Series AV."
    }
  },
  de: {
    account: {
      signInTitle: "Bei Series AV anmelden",
      signInSubtitle: "Willkommen zurück. Melde dich an, damit dein Seriennotizbuch verbunden bleibt."
    },
    avi: {
      body: "Avi macht aus einer unübersichtlichen Watchlist einen klaren nächsten Schritt: fortsetzen, speichern, aufholen oder die Bibliothek leichter lesbar halten.",
      cards: [
        { text: "Avi kann zeigen, welche Serien einen gespeicherten Status, die nächste Folge oder eine klarere Fortschrittsnotiz brauchen.", title: "Notizbuch vorbereiten" },
        { text: "Kommende Folgen und aktive Serien bleiben lesbar, damit der nächste Schritt nicht untergeht.", title: "Nächstes auswählen" },
        { text: "Bibliotheksführung beginnt bei den Serien, die du bereits gespeichert hast, und der nächsten Folge, die du angehen kannst.", title: "Echten Kontext nutzen" }
      ],
      libraryCta: "Bibliothek öffnen",
      searchCta: "Serie finden",
      title: "Eine ruhige Hilfe für deine nächste Folge."
    },
    config: {
      body: "Starte die Web-App über den Varlock-Wrapper, damit die Account AV-Konfiguration verfügbar ist. Webzugriff ist immer anmeldepflichtig.",
      eyebrow: "Konfiguration erforderlich",
      title: "Series AV Web benötigt die Clerk-Konfiguration."
    },
    footer: {
      deleteAccount: "Konto löschen",
      language: "Sprache",
      privacy: "Datenschutz",
      support: "Hilfe",
      terms: "Bedingungen"
    },
    home: {
      aviBody: [
        "Beginne mit deinen aktuellen Serien und finde den nächsten sinnvollen Schritt.",
        "Erkenne fehlenden Fortschritt, bevor die Liste schwer lesbar wird.",
        "Halte die Führung nah an deinen echten Sehgewohnheiten."
      ],
      aviTitle: "Avi passt auf",
      body: "Durchsuche den Katalog, speichere Fortschritt und behalte klar im Blick, was als Nächstes dran ist.",
      cta: "Katalog durchsuchen",
      items: [
        { label: "Katalogsuche", value: "Serien nach Titel finden" },
        { label: "Bibliothek", value: "Gespeicherte Serien beisammen halten" },
        { label: "Nächste Folgen", value: "Zu dem zurückkehren, was ansteht" }
      ],
      title: "Nimm dein Seriennotizbuch wieder auf."
    },
    library: {
      add: "Serie hinzufügen",
      body: "Schaue weiter, plane was kommt und verschiebe beendete Serien, ohne sie zu verlieren.",
      emptyBody: "Durchsuche den Katalog, wähle eine Serie aus, und Series AV sammelt hier die nächste Folge und Fortschrittsnotizen.",
      emptyTitle: "Beginne mit einer gespeicherten Serie.",
      filters: ["Alle", "Aktuell", "Ansehen", "Gesehen", "Archiviert"],
      hints: [
        { text: "Aktive Serien bleiben oben, damit der nächste Schritt leicht zu finden ist.", title: "Aktuell" },
        { text: "Neue Folgen können neben den Serien erscheinen, denen du schon folgst.", title: "Demnächst" },
        { text: "Beendete oder pausierte Serien bleiben verfügbar, ohne die Hauptliste zu füllen.", title: "Archiv" }
      ],
      kicker: "Bibliothek",
      title: "Deine gespeicherten Serien, nach der nächsten Folge sortiert."
    },
    login: {
      aviGuidance: "Avi hilft dir",
      cardBody: "Speichere, was du schaust, finde die nächste Folge und kehre zu deinem Fortschritt zurück.",
      cardTitle: "Mach mit deiner Liste weiter",
      cta: "Anmelden",
      heroBody: "Melde dich an, damit Bibliothek, Episodenfortschritt und Avi-Hilfe mit deinem AV-Konto verbunden bleiben.",
      heroTitle: "Dein Seriennotizbuch, immer bereit.",
      intro: "Behalte jede Serie im Blick, merke dir die nächste Folge und halte deine Watchlist in Series AV griffbereit.",
      mapBody: "Die Web-Erfahrung behält das Notizbuchgefühl von iOS: Papierstruktur, Tintenlinien, grüne Markierungen und Avi in der Nähe.",
      mapTitle: "Eine handgezeichnete Fortschrittskarte für deine nächste Folge.",
      notebook: "Seriennotizbuch",
      search: "Seriensuche"
    },
    nav: {
      account: "Konto",
      avi: "Avi",
      aviLabel: "Avi-Hilfe öffnen",
      home: "Start",
      homeLabel: "Series AV Start",
      library: "Bibliothek",
      mobileNavigation: "Mobile Navigation",
      openNavigation: "Navigation öffnen",
      primaryNavigation: "Hauptnavigation",
      search: "Suche",
      settings: "Einstellungen"
    },
    protected: {
      body: "Melde dich an, um deine Bibliothek zu öffnen, den Katalog zu durchsuchen und Avi bei der nächsten Wahl helfen zu lassen.",
      cta: "Anmelden",
      title: "Nimm dein Seriennotizbuch mit."
    },
    signIn: {
      aviPanelBody: "Ein ruhiger Hinweis, wenn die nächste Folge unklar ist.",
      body: "Melde dich an, damit deine Serien, nächsten Folgen und Avi-Hilfe mit deinem AV-Konto verbunden bleiben.",
      continue: "Weiter",
      signedIn: "Du bist angemeldet.",
      title: "Deine Series AV Bibliothek begleitet dich."
    },
    search: {
      dateUnknown: "Datum unbekannt",
      description: "Finde einen Titel, prüfe das Artwork und bereite ihn für den angemeldeten Bibliotheksfluss vor.",
      emptyBody: "Versuche es mit einem anderen Titel.",
      emptyTitle: "Keine Serien gefunden",
      errorTitle: "Seriensuche fehlgeschlagen",
      inputLabel: "Serien suchen",
      noArtwork: "Kein Artwork",
      noOverview: "Noch keine Beschreibung verfügbar.",
      placeholder: "Serie suchen",
      title: "Den Series AV-Katalog durchsuchen."
    }
  },
  en,
  es: {
    account: {
      signInTitle: "Inicia sesión en Series AV",
      signInSubtitle: "Bienvenido de nuevo. Inicia sesión para mantener conectado tu cuaderno de series."
    },
    avi: {
      body: "Avi convierte una lista desordenada en un siguiente paso claro: continuar, guardar, ponerte al día o mantener la biblioteca más fácil de leer.",
      cards: [
        { text: "Avi puede señalar qué series necesitan un estado guardado, un próximo episodio o una nota de progreso más clara.", title: "Prepara el cuaderno" },
        { text: "Los episodios próximos y las series activas se mantienen legibles para que el siguiente paso no quede enterrado.", title: "Elige qué va después" },
        { text: "La guía de biblioteca parte de las series que ya guardaste y del próximo episodio sobre el que puedes actuar.", title: "Usa contexto real" }
      ],
      libraryCta: "Abrir biblioteca",
      searchCta: "Encontrar una serie",
      title: "Una guía tranquila para tu próximo episodio."
    },
    config: {
      body: "Ejecuta la web con el wrapper de Varlock para que la configuración de Account AV esté disponible. El acceso web siempre requiere iniciar sesión.",
      eyebrow: "Configuración requerida",
      title: "Series AV Web necesita la configuración de Clerk."
    },
    footer: {
      deleteAccount: "Eliminar cuenta",
      language: "Idioma",
      privacy: "Privacidad",
      support: "Ayuda",
      terms: "Condiciones"
    },
    home: {
      aviBody: [
        "Empieza por tus series actuales y encuentra el siguiente paso útil.",
        "Detecta progreso pendiente antes de que la cola sea difícil de leer.",
        "Mantén la guía cerca de tus hábitos reales."
      ],
      aviTitle: "Avi está atento",
      body: "Busca en el catálogo, guarda progreso y mantén un mapa claro de qué ver después.",
      cta: "Buscar catálogo",
      items: [
        { label: "Búsqueda de catálogo", value: "Encuentra series por título" },
        { label: "Biblioteca", value: "Mantén juntas tus series guardadas" },
        { label: "Próximos episodios", value: "Vuelve a lo que está por llegar" }
      ],
      title: "Retoma tu cuaderno de series."
    },
    library: {
      add: "Añadir serie",
      body: "Sigue viendo, planifica lo que viene y aparta las series terminadas sin perderlas.",
      emptyBody: "Busca en el catálogo, elige una serie y Series AV guardará aquí el próximo episodio y las notas de progreso.",
      emptyTitle: "Empieza guardando una serie.",
      filters: ["Todas", "Viendo", "Quiero ver", "Vistas", "Archivadas"],
      hints: [
        { text: "Las series activas se quedan arriba para encontrar fácilmente el siguiente paso.", title: "Viendo" },
        { text: "Los nuevos episodios pueden aparecer junto a las series que ya sigues.", title: "Próximamente" },
        { text: "Las series terminadas o pausadas siguen disponibles sin llenar la lista principal.", title: "Archivo" }
      ],
      kicker: "Biblioteca",
      title: "Tus series guardadas, ordenadas para el próximo episodio."
    },
    login: {
      aviGuidance: "Guía de Avi",
      cardBody: "Guarda lo que estás viendo, encuentra qué viene después y vuelve a tu progreso sin reconstruir la lista.",
      cardTitle: "Continúa desde tu lista",
      cta: "Iniciar sesión",
      heroBody: "Inicia sesión para mantener tu biblioteca, progreso de episodios y guía de Avi conectados con tu cuenta AV.",
      heroTitle: "Tu cuaderno de series, siempre listo.",
      intro: "Sigue cada serie, recuerda el próximo episodio y mantén tu lista cerca en Series AV.",
      mapBody: "La experiencia web mantiene el tono de cuaderno de iOS: textura de papel, líneas de tinta, marcas verdes y Avi cerca.",
      mapTitle: "Un mapa de progreso dibujado a mano para tu próximo episodio.",
      notebook: "Cuaderno de series",
      search: "Búsqueda de series"
    },
    nav: {
      account: "Cuenta",
      avi: "Avi",
      aviLabel: "Abrir guía de Avi",
      home: "Inicio",
      homeLabel: "Inicio de Series AV",
      library: "Biblioteca",
      mobileNavigation: "Navegación móvil",
      openNavigation: "Abrir navegación",
      primaryNavigation: "Navegación principal",
      search: "Buscar",
      settings: "Ajustes"
    },
    protected: {
      body: "Inicia sesión para abrir tu biblioteca, buscar en el catálogo y dejar que Avi te ayude a elegir qué ver después.",
      cta: "Iniciar sesión",
      title: "Lleva tu cuaderno de series contigo."
    },
    signIn: {
      aviPanelBody: "Un pequeño empujón cuando el próximo episodio no está claro.",
      body: "Inicia sesión para mantener tus series, próximos episodios y guía de Avi conectados con tu cuenta AV.",
      continue: "Continuar",
      signedIn: "Has iniciado sesión.",
      title: "Tu biblioteca de Series AV te acompaña."
    },
    search: {
      dateUnknown: "Fecha desconocida",
      description: "Encuentra un título, revisa su arte y prepáralo para el flujo de biblioteca con sesión iniciada.",
      emptyBody: "Prueba con otro título.",
      emptyTitle: "No se encontraron series",
      errorTitle: "La búsqueda de series falló",
      inputLabel: "Buscar series",
      noArtwork: "Sin imagen",
      noOverview: "Todavía no hay resumen disponible.",
      placeholder: "Buscar una serie",
      title: "Busca en el catálogo de Series AV."
    }
  },
  fr: {
    account: {
      signInTitle: "Connectez-vous à Series AV",
      signInSubtitle: "Bon retour. Connectez-vous pour garder votre carnet de séries synchronisé."
    },
    avi: {
      body: "Avi transforme une liste de visionnage confuse en prochaine étape claire : continuer, enregistrer, rattraper ou garder la bibliothèque plus lisible.",
      cards: [
        { text: "Avi peut signaler les séries qui ont besoin d'un statut enregistré, d'un prochain épisode ou d'une note de progression plus claire.", title: "Préparer le carnet" },
        { text: "Les épisodes à venir et les séries actives restent lisibles, afin que la prochaine action ne soit pas enterrée.", title: "Choisir la suite" },
        { text: "Les conseils de bibliothèque partent des séries déjà enregistrées et du prochain épisode sur lequel agir.", title: "Utiliser le vrai contexte" }
      ],
      libraryCta: "Ouvrir la bibliothèque",
      searchCta: "Trouver une série",
      title: "Un guide calme pour votre prochain épisode."
    },
    config: {
      body: "Lancez l'app web avec le wrapper Varlock afin que la configuration Account AV soit disponible. L'accès web requiert toujours une connexion.",
      eyebrow: "Configuration requise",
      title: "Series AV Web a besoin de la configuration Clerk."
    },
    footer: {
      deleteAccount: "Supprimer le compte",
      language: "Langue",
      privacy: "Confidentialité",
      support: "Aide",
      terms: "Conditions"
    },
    home: {
      aviBody: [
        "Partez de vos séries en cours et trouvez la prochaine action utile.",
        "Repérez les progressions manquantes avant que la file devienne difficile à lire.",
        "Gardez les conseils proches de vos vraies habitudes."
      ],
      aviTitle: "Avi veille",
      body: "Parcourez le catalogue, enregistrez votre progression et gardez une carte claire de la suite.",
      cta: "Chercher dans le catalogue",
      items: [
        { label: "Recherche catalogue", value: "Trouver des séries par titre" },
        { label: "Bibliothèque", value: "Garder vos séries enregistrées ensemble" },
        { label: "Prochains épisodes", value: "Revenir à ce qui arrive bientôt" }
      ],
      title: "Reprenez votre carnet de séries."
    },
    library: {
      add: "Ajouter une série",
      body: "Continuez à regarder, planifiez la suite et rangez les séries terminées sans les perdre.",
      emptyBody: "Cherchez dans le catalogue, choisissez une série, et Series AV gardera ici le prochain épisode et les notes de progression.",
      emptyTitle: "Commencez par enregistrer une série.",
      filters: ["Toutes", "En cours", "À regarder", "Vues", "Archivées"],
      hints: [
        { text: "Les séries actives restent en haut pour retrouver facilement la prochaine étape.", title: "En cours" },
        { text: "Les nouveaux épisodes peuvent apparaître près des séries que vous suivez déjà.", title: "À venir" },
        { text: "Les séries terminées ou en pause restent disponibles sans encombrer la liste principale.", title: "Archive" }
      ],
      kicker: "Bibliothèque",
      title: "Vos séries enregistrées, rangées pour le prochain épisode."
    },
    login: {
      aviGuidance: "Conseils d'Avi",
      cardBody: "Enregistrez ce que vous regardez, trouvez la suite et retrouvez votre progression sans refaire la liste.",
      cardTitle: "Reprendre depuis votre liste",
      cta: "Se connecter",
      heroBody: "Connectez-vous pour garder votre bibliothèque, la progression des épisodes et l'aide d'Avi liées à votre compte AV.",
      heroTitle: "Votre carnet de séries, toujours prêt.",
      intro: "Suivez chaque série, gardez le prochain épisode en mémoire et retrouvez votre liste dans Series AV.",
      mapBody: "L'expérience web garde l'esprit carnet d'iOS : texture papier, traits d'encre, repères verts et Avi tout près.",
      mapTitle: "Une carte de progression dessinée à la main pour votre prochain épisode.",
      notebook: "Carnet de séries",
      search: "Recherche de séries"
    },
    nav: {
      account: "Compte",
      avi: "Avi",
      aviLabel: "Ouvrir les conseils d'Avi",
      home: "Accueil",
      homeLabel: "Accueil Series AV",
      library: "Bibliothèque",
      mobileNavigation: "Navigation mobile",
      openNavigation: "Ouvrir la navigation",
      primaryNavigation: "Navigation principale",
      search: "Recherche",
      settings: "Réglages"
    },
    protected: {
      body: "Connectez-vous pour ouvrir votre bibliothèque, parcourir le catalogue et laisser Avi vous aider à choisir la suite.",
      cta: "Se connecter",
      title: "Gardez votre carnet de séries avec vous."
    },
    signIn: {
      aviPanelBody: "Un petit coup de pouce quand le prochain épisode n'est pas clair.",
      body: "Connectez-vous pour garder vos séries, prochains épisodes et conseils d'Avi liés à votre compte AV.",
      continue: "Continuer",
      signedIn: "Vous êtes connecté.",
      title: "Votre bibliothèque Series AV vous accompagne."
    },
    search: {
      dateUnknown: "Date inconnue",
      description: "Trouvez un titre, vérifiez son visuel et préparez-le pour le parcours bibliothèque connecté.",
      emptyBody: "Essayez un autre titre.",
      emptyTitle: "Aucune série trouvée",
      errorTitle: "La recherche de séries a échoué",
      inputLabel: "Rechercher des séries",
      noArtwork: "Aucun visuel",
      noOverview: "Aucun résumé n'est encore disponible.",
      placeholder: "Rechercher une série",
      title: "Rechercher dans le catalogue Series AV."
    }
  }
};

export function useSeriesText() {
  return seriesText[useAppsAvLocale()];
}

export function useSeriesNavLinks(): AppsAvProductLink[] {
  const locale = useAppsAvLocale();
  const text = useSeriesText();

  return [
    { href: localizedSeriesPath("/", locale), label: text.nav.home },
    { href: localizedSeriesPath("/library", locale), label: text.nav.library },
    { href: localizedSeriesPath("/search", locale), label: text.nav.search },
    { href: localizedSeriesPath("/avi", locale), label: text.nav.avi },
    { href: localizedSeriesPath("/account", locale), label: text.nav.account },
    { href: localizedSeriesPath("/settings", locale), label: text.nav.settings }
  ];
}

export function useSeriesProductConfig(): AppsAvProductConfig {
  const locale = useAppsAvLocale();
  const text = useSeriesText();

  return useMemo(() => ({
    ...seriesProductConfig,
    assistant: seriesProductConfig.assistant
      ? {
        ...seriesProductConfig.assistant,
        href: localizedSeriesPath(seriesProductConfig.assistant.href, locale),
        label: text.nav.aviLabel
      }
      : undefined
  }), [locale, text.nav.aviLabel]);
}

export function useSeriesApiLocale() {
  const locale = useAppsAvLocale();

  return {
    ca: "ca-ES",
    de: "de-DE",
    en: "en-US",
    es: "es-ES",
    fr: "fr-FR"
  }[locale];
}

export function useSeriesShellLabels() {
  const text = useSeriesText();

  return {
    assistant: text.nav.aviLabel,
    home: text.nav.homeLabel,
    mobileNavigation: text.nav.mobileNavigation,
    openNavigation: text.nav.openNavigation,
    primaryNavigation: text.nav.primaryNavigation
  };
}

export function useSeriesAccountLocalization() {
  const text = useSeriesText();
  const baseLocalization = {
    ca: caES,
    de: deDE,
    en: enUS,
    es: esES,
    fr: frFR
  }[useAppsAvLocale()];

  return {
    ...baseLocalization,
    signIn: {
      ...baseLocalization.signIn,
      start: {
        ...baseLocalization.signIn?.start,
        title: text.account.signInTitle,
        subtitle: text.account.signInSubtitle
      }
    }
  };
}

export function localizedSeriesPath(path: string, locale: AppsAvLocale): string {
  if (locale === "en") {
    return path;
  }

  return appsAvLocalizedPath(path, locale);
}

export function localizedExternalUrl(href: string | undefined, locale: AppsAvLocale): string | undefined {
  if (!href || locale === "en") {
    return href;
  }

  try {
    const url = new URL(href);
    if (!url.pathname.split("/").filter(Boolean).includes(locale)) {
      url.pathname = `/${locale}${url.pathname === "/" ? "" : url.pathname}`;
    }
    return url.toString().replace(/\/$/, "");
  } catch {
    return href;
  }
}
