import { useAppsAvLocale, type AppsAvLocale, type AppsAvProductLink } from "@avalsys/apps-av-web";

const en = {
  account: {
    signInTitle: "Sign in to Series AV",
    signInSubtitle: "Welcome back. Sign in to keep your series notebook connected."
  },
  avi: {
    body: "Avi helps turn a messy watch list into a clear next step: continue, save, catch up, or discover something that fits your habits.",
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
        text: "Recommendations can grow from what you actually watch instead of starting from a blank catalog.",
        title: "Discover with context"
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
      "Keep recommendations close to your real watching habits."
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
    heroBody: "Sign in to keep your library, episode progress, and Avi guidance connected wherever you watch.",
    heroTitle: "Your series notebook, always ready.",
    intro: "Follow every show, remember the next episode, and keep your watch list close from any screen.",
    mapBody: "The web experience keeps the notebook feeling from iOS: paper texture, ink lines, green checkpoints, and Avi close at hand.",
    mapTitle: "A hand-drawn progress map for your next episode.",
    notebook: "Series notebook",
    search: "Series search"
  },
  nav: {
    avi: "Avi",
    home: "Home",
    homeLabel: "Series AV home",
    library: "Library",
    mobileNavigation: "Mobile navigation",
    openNavigation: "Open navigation",
    primaryNavigation: "Primary navigation",
    search: "Search"
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
      signInTitle: "Inicia sessio a Series AV",
      signInSubtitle: "Torna-hi. Inicia sessio per mantenir connectat el teu quadern de series."
    },
    avi: {
      body: "Avi ajuda a convertir una llista desordenada en un proper pas clar: continuar, desar, posar-te al dia o descobrir alguna cosa que encaixi amb els teus habits.",
      cards: [
        { text: "Avi pot indicar quines series necessiten un estat desat, un proper episodi o una nota de progres mes clara.", title: "Prepara el quadern" },
        { text: "Els episodis propers i les series actives es mantenen llegibles, perque el proper pas no quedi enterrat.", title: "Tria que ve despres" },
        { text: "Les recomanacions poden creixer a partir del que realment mires, no d'un cataleg en blanc.", title: "Descobreix amb context" }
      ],
      libraryCta: "Obre la biblioteca",
      searchCta: "Troba una serie",
      title: "Una guia tranquil-la per al proper episodi."
    },
    config: {
      body: "Executa la web amb el wrapper de Varlock perque la configuracio d'Account AV estigui disponible. L'acces web sempre requereix iniciar sessio.",
      eyebrow: "Configuracio necessaria",
      title: "Series AV Web necessita la configuracio de Clerk."
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
        "Comenca des de les series actuals i troba el proper pas util.",
        "Detecta progres pendent abans que la cua sigui dificil de llegir.",
        "Mantingues les recomanacions a prop dels teus habits reals."
      ],
      aviTitle: "Avi vigila",
      body: "Cerca al cataleg, desa el progres i mante un mapa clar del que toca mirar despres.",
      cta: "Cerca al cataleg",
      items: [
        { label: "Cerca al cataleg", value: "Troba series pel titol" },
        { label: "Biblioteca", value: "Mantingues juntes les series desades" },
        { label: "Propers episodis", value: "Torna al que esta per arribar" }
      ],
      title: "Repren el teu quadern de series."
    },
    library: {
      add: "Afegeix serie",
      body: "Continua mirant, planifica que ve despres i aparta les series acabades sense perdre-les.",
      emptyBody: "Cerca al cataleg, tria una serie i Series AV mantindra aqui el proper episodi i les notes de progres.",
      emptyTitle: "Comenca desant una serie.",
      filters: ["Totes", "Mirant", "Vull mirar", "Vistes", "Arxivades"],
      hints: [
        { text: "Les series actives queden a dalt per trobar facilment el proper pas.", title: "Mirant" },
        { text: "Els nous episodis poden aparèixer al costat de les series que ja segueixes.", title: "Properament" },
        { text: "Les series acabades o pausades continuen disponibles sense omplir la llista principal.", title: "Arxiu" }
      ],
      kicker: "Biblioteca",
      title: "Les teves series desades, ordenades pel proper episodi."
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
    nav: {
      avi: "Avi",
      home: "Inici",
      homeLabel: "Inici de Series AV",
      library: "Biblioteca",
      mobileNavigation: "Navegacio mobil",
      openNavigation: "Obre la navegacio",
      primaryNavigation: "Navegacio principal",
      search: "Cerca"
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
    },
    search: {
      dateUnknown: "Data desconeguda",
      description: "Troba un titol, revisa'n l'art i prepara'l per al flux de biblioteca amb sessio iniciada.",
      emptyBody: "Prova amb un altre titol.",
      emptyTitle: "No s'han trobat series",
      errorTitle: "La cerca de series ha fallat",
      inputLabel: "Cerca series",
      noArtwork: "Sense imatge",
      noOverview: "Encara no hi ha cap resum disponible.",
      placeholder: "Cerca una serie",
      title: "Cerca al cataleg de Series AV."
    }
  },
  de: {
    account: {
      signInTitle: "Bei Series AV anmelden",
      signInSubtitle: "Willkommen zurueck. Melde dich an, damit dein Seriennotizbuch verbunden bleibt."
    },
    avi: {
      body: "Avi macht aus einer unuebersichtlichen Watchlist einen klaren naechsten Schritt: fortsetzen, speichern, aufholen oder etwas Passendes entdecken.",
      cards: [
        { text: "Avi kann zeigen, welche Serien einen gespeicherten Status, die naechste Folge oder eine klarere Fortschrittsnotiz brauchen.", title: "Notizbuch vorbereiten" },
        { text: "Kommende Folgen und aktive Serien bleiben lesbar, damit der naechste Schritt nicht untergeht.", title: "Naechstes auswaehlen" },
        { text: "Empfehlungen koennen aus dem wachsen, was du wirklich schaust, statt bei einem leeren Katalog zu starten.", title: "Mit Kontext entdecken" }
      ],
      libraryCta: "Bibliothek oeffnen",
      searchCta: "Serie finden",
      title: "Eine ruhige Hilfe fuer deine naechste Folge."
    },
    config: {
      body: "Starte die Web-App ueber den Varlock-Wrapper, damit die Account AV-Konfiguration verfuegbar ist. Webzugriff ist immer anmeldepflichtig.",
      eyebrow: "Konfiguration erforderlich",
      title: "Series AV Web benoetigt die Clerk-Konfiguration."
    },
    footer: {
      deleteAccount: "Konto loeschen",
      language: "Sprache",
      privacy: "Datenschutz",
      support: "Hilfe",
      terms: "Bedingungen"
    },
    home: {
      aviBody: [
        "Beginne mit deinen aktuellen Serien und finde den naechsten sinnvollen Schritt.",
        "Erkenne fehlenden Fortschritt, bevor die Liste schwer lesbar wird.",
        "Halte Empfehlungen nah an deinen echten Sehgewohnheiten."
      ],
      aviTitle: "Avi passt auf",
      body: "Durchsuche den Katalog, speichere Fortschritt und behalte klar im Blick, was als Naechstes dran ist.",
      cta: "Katalog durchsuchen",
      items: [
        { label: "Katalogsuche", value: "Serien nach Titel finden" },
        { label: "Bibliothek", value: "Gespeicherte Serien beisammen halten" },
        { label: "Naechste Folgen", value: "Zu dem zurueckkehren, was ansteht" }
      ],
      title: "Nimm dein Seriennotizbuch wieder auf."
    },
    library: {
      add: "Serie hinzufuegen",
      body: "Schaue weiter, plane was kommt und verschiebe beendete Serien, ohne sie zu verlieren.",
      emptyBody: "Durchsuche den Katalog, waehle eine Serie aus, und Series AV sammelt hier die naechste Folge und Fortschrittsnotizen.",
      emptyTitle: "Beginne mit einer gespeicherten Serie.",
      filters: ["Alle", "Aktuell", "Ansehen", "Gesehen", "Archiviert"],
      hints: [
        { text: "Aktive Serien bleiben oben, damit der naechste Schritt leicht zu finden ist.", title: "Aktuell" },
        { text: "Neue Folgen koennen neben den Serien erscheinen, denen du schon folgst.", title: "Demnaechst" },
        { text: "Beendete oder pausierte Serien bleiben verfuegbar, ohne die Hauptliste zu fuellen.", title: "Archiv" }
      ],
      kicker: "Bibliothek",
      title: "Deine gespeicherten Serien, nach der naechsten Folge sortiert."
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
    nav: {
      avi: "Avi",
      home: "Start",
      homeLabel: "Series AV Start",
      library: "Bibliothek",
      mobileNavigation: "Mobile Navigation",
      openNavigation: "Navigation oeffnen",
      primaryNavigation: "Hauptnavigation",
      search: "Suche"
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
    },
    search: {
      dateUnknown: "Datum unbekannt",
      description: "Finde einen Titel, pruefe das Artwork und bereite ihn fuer den angemeldeten Bibliotheksfluss vor.",
      emptyBody: "Versuche es mit einem anderen Titel.",
      emptyTitle: "Keine Serien gefunden",
      errorTitle: "Seriensuche fehlgeschlagen",
      inputLabel: "Serien suchen",
      noArtwork: "Kein Artwork",
      noOverview: "Noch keine Beschreibung verfuegbar.",
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
      body: "Avi convierte una lista desordenada en un siguiente paso claro: continuar, guardar, ponerte al día o descubrir algo que encaje con tus hábitos.",
      cards: [
        { text: "Avi puede señalar qué series necesitan un estado guardado, un próximo episodio o una nota de progreso más clara.", title: "Prepara el cuaderno" },
        { text: "Los episodios próximos y las series activas se mantienen legibles para que el siguiente paso no quede enterrado.", title: "Elige qué va después" },
        { text: "Las recomendaciones pueden crecer desde lo que realmente ves, no desde un catálogo en blanco.", title: "Descubre con contexto" }
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
        "Mantén las recomendaciones cerca de tus hábitos reales."
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
    nav: {
      avi: "Avi",
      home: "Inicio",
      homeLabel: "Inicio de Series AV",
      library: "Biblioteca",
      mobileNavigation: "Navegación móvil",
      openNavigation: "Abrir navegación",
      primaryNavigation: "Navegación principal",
      search: "Buscar"
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
      signInSubtitle: "Bon retour. Connectez-vous pour garder votre carnet de series synchronise."
    },
    avi: {
      body: "Avi transforme une liste de visionnage confuse en prochaine etape claire : continuer, enregistrer, rattraper ou decouvrir quelque chose qui correspond a vos habitudes.",
      cards: [
        { text: "Avi peut signaler les series qui ont besoin d'un statut enregistre, d'un prochain episode ou d'une note de progression plus claire.", title: "Preparer le carnet" },
        { text: "Les episodes a venir et les series actives restent lisibles, afin que la prochaine action ne soit pas enterree.", title: "Choisir la suite" },
        { text: "Les recommandations peuvent partir de ce que vous regardez vraiment, plutot que d'un catalogue vide.", title: "Decouvrir avec contexte" }
      ],
      libraryCta: "Ouvrir la bibliotheque",
      searchCta: "Trouver une serie",
      title: "Un guide calme pour votre prochain episode."
    },
    config: {
      body: "Lancez l'app web avec le wrapper Varlock afin que la configuration Account AV soit disponible. L'acces web requiert toujours une connexion.",
      eyebrow: "Configuration requise",
      title: "Series AV Web a besoin de la configuration Clerk."
    },
    footer: {
      deleteAccount: "Supprimer le compte",
      language: "Langue",
      privacy: "Confidentialite",
      support: "Aide",
      terms: "Conditions"
    },
    home: {
      aviBody: [
        "Partez de vos series en cours et trouvez la prochaine action utile.",
        "Reperez les progressions manquantes avant que la file devienne difficile a lire.",
        "Gardez les recommandations proches de vos vraies habitudes."
      ],
      aviTitle: "Avi veille",
      body: "Parcourez le catalogue, enregistrez votre progression et gardez une carte claire de la suite.",
      cta: "Chercher dans le catalogue",
      items: [
        { label: "Recherche catalogue", value: "Trouver des series par titre" },
        { label: "Bibliotheque", value: "Garder vos series enregistrees ensemble" },
        { label: "Prochains episodes", value: "Revenir a ce qui arrive bientot" }
      ],
      title: "Reprenez votre carnet de series."
    },
    library: {
      add: "Ajouter une serie",
      body: "Continuez a regarder, planifiez la suite et rangez les series terminees sans les perdre.",
      emptyBody: "Cherchez dans le catalogue, choisissez une serie, et Series AV gardera ici le prochain episode et les notes de progression.",
      emptyTitle: "Commencez par enregistrer une serie.",
      filters: ["Toutes", "En cours", "A regarder", "Vues", "Archivees"],
      hints: [
        { text: "Les series actives restent en haut pour retrouver facilement la prochaine etape.", title: "En cours" },
        { text: "Les nouveaux episodes peuvent apparaitre pres des series que vous suivez deja.", title: "A venir" },
        { text: "Les series terminees ou en pause restent disponibles sans encombrer la liste principale.", title: "Archive" }
      ],
      kicker: "Bibliotheque",
      title: "Vos series enregistrees, rangees pour le prochain episode."
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
    nav: {
      avi: "Avi",
      home: "Accueil",
      homeLabel: "Accueil Series AV",
      library: "Bibliotheque",
      mobileNavigation: "Navigation mobile",
      openNavigation: "Ouvrir la navigation",
      primaryNavigation: "Navigation principale",
      search: "Recherche"
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
    },
    search: {
      dateUnknown: "Date inconnue",
      description: "Trouvez un titre, verifiez son visuel et preparez-le pour le parcours bibliotheque connecte.",
      emptyBody: "Essayez un autre titre.",
      emptyTitle: "Aucune serie trouvee",
      errorTitle: "La recherche de series a echoue",
      inputLabel: "Rechercher des series",
      noArtwork: "Aucun visuel",
      noOverview: "Aucun resume n'est encore disponible.",
      placeholder: "Rechercher une serie",
      title: "Rechercher dans le catalogue Series AV."
    }
  }
};

export function useSeriesText() {
  return seriesText[useAppsAvLocale()];
}

export function useSeriesNavLinks(): AppsAvProductLink[] {
  const text = useSeriesText();

  return [
    { href: "/", label: text.nav.home },
    { href: "/library", label: text.nav.library },
    { href: "/search", label: text.nav.search },
    { href: "/avi", label: text.nav.avi }
  ];
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
    home: text.nav.homeLabel,
    mobileNavigation: text.nav.mobileNavigation,
    openNavigation: text.nav.openNavigation,
    primaryNavigation: text.nav.primaryNavigation
  };
}

export function useSeriesAccountLocalization() {
  const text = useSeriesText();

  return {
    signIn: {
      start: {
        title: text.account.signInTitle,
        subtitle: text.account.signInSubtitle
      }
    }
  };
}
