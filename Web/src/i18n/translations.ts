export const languages = {
  es: 'Español',
  en: 'English',
  de: 'Deutsch',
  fr: 'Français',
  it: 'Italiano',
  pt: 'Português',
} as const;

export type Language = keyof typeof languages;

export const defaultLang: Language = 'es';

export const translations = {
  es: {
    // Meta
    title: 'Neto – Tu centro de control financiero',
    description: 'Registra en segundos, entiende en minutos. Tu app de finanzas personales.',

    // Nav
    navFeatures: 'Características',
    navAnalytics: 'Analítica',
    navPrivacy: 'Privacidad',
    navDownload: 'Descargar',

    // Hero
    heroTitle: 'Tu centro de control financiero',
    heroSubtitle: 'Registra en segundos, entiende en minutos. Importa, automatiza o registra por voz. Analítica que responde preguntas.',
    heroAppStore: 'Descargar en App Store',
    heroLearnMore: 'Conocer más',

    // Features
    featuresTitle: 'Todo lo que necesitas para tomar el control',
    feature1Title: 'Importación rápida',
    feature1Desc: 'Importa desde CSV o Excel en segundos. Migra sin perder historial.',
    feature2Title: 'Registro por voz',
    feature2Desc: 'Dicta tus gastos y deja que la IA los registre por ti.',
    feature3Title: 'Atajos de Apple',
    feature3Desc: 'Automatiza registros recurrentes con Shortcuts.',
    feature4Title: 'Analítica avanzada',
    feature4Desc: 'Gráficos interactivos, filtros y reportes que revelan patrones.',

    // Stats
    stat1: 'Privado y local',
    stat2: 'Cuentas ilimitadas',
    stat3: 'Divisas soportadas',
    stat4: 'Datos en la nube',

    // Screenshots
    screenshotsTitle: 'Diseñado para la claridad',
    screenshotsSubtitle: 'Interfaz intuitiva que te muestra exactamente lo que necesitas ver.',

    // Analytics Section
    analyticsTitle: 'Entiende qué está pasando con tu dinero',
    analyticsDesc: 'No solo registres. Neto convierte tus datos en respuestas: tendencias por categoría, flujo neto mensual, y presupuestos con seguimiento real.',
    analyticsBullet1: 'Filtros por periodo, categoría, cuenta y etiqueta',
    analyticsBullet2: 'Presupuestos semanales, mensuales y anuales',
    analyticsBullet3: 'Múltiples cuentas con conversión de divisas',

    // Privacy
    privacyTitle: 'Privacidad por diseño',
    privacyDesc: 'Tus datos financieros viven en tu iPhone, no en nuestros servidores. Sin cuentas, sin rastreo, sin compromisos.',
    privacyLink: 'Leer política de privacidad',

    // CTA
    ctaTitle: 'Control real, sin fricción.',
    ctaSubtitle: 'Únete a quienes ya tomaron el control de sus finanzas personales.',

    // Footer
    footerPrivacy: 'Privacidad',
    footerTerms: 'Términos',
    footerContact: 'Contacto',

    // Privacy Page
    privacyPageTitle: 'Política de Privacidad - Neto',
    privacyBackHome: '← Volver a Inicio',
    privacyLastUpdate: 'Última actualización: Enero 2026',
    privacyH1: 'Política de Privacidad de Neto',
    privacyIntroTitle: '1. Introducción',
    privacyIntroText: 'Neto ("la App") es una aplicación de finanzas personales diseñada con un principio fundamental: **tu información financiera te pertenece exclusivamente a ti**. Esta Política de Privacidad explica cómo manejamos (o más bien, cómo *no* manejamos) tus datos.',
    privacyDataTitle: '2. Recopilación y almacenamiento de datos',
    privacyDataIntro: 'Neto opera bajo un modelo de "Privacidad Primero" (Privacy-First) y "Almacenamiento Local" (Local Storage).',
    privacyDataBullet1: '**Datos Financieros:** Todas tus transacciones, cuentas, presupuestos y categorizaciones se almacenan **única y exclusivamente en tu dispositivo** (iPhone/iPad). Neto no envía esta información a ningún servidor externo propio ni de terceros.',
    privacyDataBullet2: '**Sin cuentas de usuario:** No requerimos que crees una cuenta con email o contraseña para usar la App. No tenemos una base de datos de usuarios.',
    privacyDataBullet3: '**Sin conexión bancaria:** Neto no se conecta con tus bancos ni solicita credenciales bancarias.',
    privacyIcloudTitle: '3. Uso de iCloud',
    privacyIcloudText: 'Si tienes activada la copia de seguridad de iCloud en tu dispositivo, los datos de Neto se incluirán en dicha copia. Este proceso es gestionado enteramente por Apple y se rige por la Política de Privacidad de Apple. Nosotros no tenemos acceso a esas copias de seguridad.',
    privacyAnalyticsTitle: '4. Análisis y Mejoras (Analytics)',
    privacyAnalyticsText: 'Para mejorar la estabilidad y el rendimiento de la App, podemos recopilar métricas técnicas **anónimas** (como informes de fallos o "crashes" y estadísticas de uso general de funciones) que no contienen información personal identificable ni detalles financieros.',
    privacyChangesTitle: '5. Cambios en esta política',
    privacyChangesText: 'Podemos actualizar esta Política de Privacidad ocasionalmente. Te notificaremos de cualquier cambio significativo a través de una actualización de la App.',
    privacyContactTitle: '6. Contacto',
    privacyContactText: 'Si tienes preguntas sobre esta política, puedes contactarnos en:',
  },

  en: {
    title: 'Neto – Your Financial Control Center',
    description: 'Track in seconds, understand in minutes. Your personal finance app.',

    navFeatures: 'Features',
    navAnalytics: 'Analytics',
    navPrivacy: 'Privacy',
    navDownload: 'Download',

    heroTitle: 'Your financial control center',
    heroSubtitle: 'Track in seconds, understand in minutes. Import, automate, or record by voice. Analytics that answer questions.',
    heroAppStore: 'Download on App Store',
    heroLearnMore: 'Learn more',

    featuresTitle: 'Everything you need to take control',
    feature1Title: 'Quick import',
    feature1Desc: 'Import from CSV or Excel in seconds. Migrate without losing history.',
    feature2Title: 'Voice recording',
    feature2Desc: 'Dictate your expenses and let AI record them for you.',
    feature3Title: 'Apple Shortcuts',
    feature3Desc: 'Automate recurring records with Shortcuts.',
    feature4Title: 'Advanced analytics',
    feature4Desc: 'Interactive charts, filters, and reports that reveal patterns.',

    stat1: 'Private & local',
    stat2: 'Unlimited accounts',
    stat3: 'Currencies supported',
    stat4: 'Data in the cloud',

    screenshotsTitle: 'Designed for clarity',
    screenshotsSubtitle: 'Intuitive interface that shows you exactly what you need to see.',

    analyticsTitle: 'Understand what\'s happening with your money',
    analyticsDesc: 'Don\'t just track. Neto turns your data into answers: trends by category, monthly net flow, and budgets with real tracking.',
    analyticsBullet1: 'Filters by period, category, account, and tag',
    analyticsBullet2: 'Weekly, monthly, and annual budgets',
    analyticsBullet3: 'Multiple accounts with currency conversion',

    privacyTitle: 'Privacy by design',
    privacyDesc: 'Your financial data lives on your iPhone, not on our servers. No accounts, no tracking, no compromises.',
    privacyLink: 'Read privacy policy',

    ctaTitle: 'Real control, no friction.',
    ctaSubtitle: 'Join those who already took control of their personal finances.',

    footerPrivacy: 'Privacy',
    footerTerms: 'Terms',
    footerContact: 'Contact',

    // Privacy Page
    privacyPageTitle: 'Privacy Policy - Neto',
    privacyBackHome: '← Back to Home',
    privacyLastUpdate: 'Last updated: January 2026',
    privacyH1: 'Neto Privacy Policy',
    privacyIntroTitle: '1. Introduction',
    privacyIntroText: 'Neto ("the App") is a personal finance application designed with one fundamental principle: **your financial information belongs exclusively to you**. This Privacy Policy explains how we handle (or rather, how we *don\'t* handle) your data.',
    privacyDataTitle: '2. Data Collection and Storage',
    privacyDataIntro: 'Neto operates under a "Privacy-First" and "Local Storage" model.',
    privacyDataBullet1: '**Financial Data:** All your transactions, accounts, budgets, and categorizations are stored **only and exclusively on your device** (iPhone/iPad). Neto does not send this information to any external server, ours or third parties.',
    privacyDataBullet2: '**No user accounts:** We don\'t require you to create an account with email or password to use the App. We have no user database.',
    privacyDataBullet3: '**No bank connections:** Neto does not connect to your banks or request banking credentials.',
    privacyIcloudTitle: '3. iCloud Usage',
    privacyIcloudText: 'If you have iCloud backup enabled on your device, Neto data will be included in that backup. This process is managed entirely by Apple and is governed by Apple\'s Privacy Policy. We have no access to those backups.',
    privacyAnalyticsTitle: '4. Analytics and Improvements',
    privacyAnalyticsText: 'To improve the App\'s stability and performance, we may collect **anonymous** technical metrics (such as crash reports and general feature usage statistics) that contain no personally identifiable information or financial details.',
    privacyChangesTitle: '5. Changes to this Policy',
    privacyChangesText: 'We may update this Privacy Policy occasionally. We will notify you of any significant changes through an App update.',
    privacyContactTitle: '6. Contact',
    privacyContactText: 'If you have questions about this policy, you can contact us at:',
  },

  de: {
    title: 'Neto – Dein Finanzkontrollzentrum',
    description: 'Erfasse in Sekunden, verstehe in Minuten. Deine persönliche Finanz-App.',

    navFeatures: 'Funktionen',
    navAnalytics: 'Analytik',
    navPrivacy: 'Datenschutz',
    navDownload: 'Herunterladen',

    heroTitle: 'Dein Finanzkontrollzentrum',
    heroSubtitle: 'Erfasse in Sekunden, verstehe in Minuten. Importiere, automatisiere oder nimm per Sprache auf. Analytik, die Fragen beantwortet.',
    heroAppStore: 'Im App Store laden',
    heroLearnMore: 'Mehr erfahren',

    featuresTitle: 'Alles, was du brauchst, um die Kontrolle zu übernehmen',
    feature1Title: 'Schneller Import',
    feature1Desc: 'Importiere aus CSV oder Excel in Sekunden. Migriere ohne Verlust.',
    feature2Title: 'Sprachaufnahme',
    feature2Desc: 'Diktiere deine Ausgaben und lass die KI sie für dich erfassen.',
    feature3Title: 'Apple Kurzbefehle',
    feature3Desc: 'Automatisiere wiederkehrende Einträge mit Kurzbefehlen.',
    feature4Title: 'Erweiterte Analytik',
    feature4Desc: 'Interaktive Diagramme, Filter und Berichte, die Muster aufdecken.',

    stat1: 'Privat & lokal',
    stat2: 'Unbegrenzte Konten',
    stat3: 'Unterstützte Währungen',
    stat4: 'Daten in der Cloud',

    screenshotsTitle: 'Für Klarheit gestaltet',
    screenshotsSubtitle: 'Intuitive Oberfläche, die dir genau zeigt, was du sehen musst.',

    analyticsTitle: 'Verstehe, was mit deinem Geld passiert',
    analyticsDesc: 'Nicht nur erfassen. Neto verwandelt deine Daten in Antworten: Trends nach Kategorie, monatlicher Nettofluss und Budgets mit echtem Tracking.',
    analyticsBullet1: 'Filter nach Zeitraum, Kategorie, Konto und Tag',
    analyticsBullet2: 'Wöchentliche, monatliche und jährliche Budgets',
    analyticsBullet3: 'Mehrere Konten mit Währungsumrechnung',

    privacyTitle: 'Datenschutz durch Design',
    privacyDesc: 'Deine Finanzdaten leben auf deinem iPhone, nicht auf unseren Servern. Keine Konten, kein Tracking, keine Kompromisse.',
    privacyLink: 'Datenschutzrichtlinie lesen',

    ctaTitle: 'Echte Kontrolle, ohne Reibung.',
    ctaSubtitle: 'Schließe dich denen an, die bereits die Kontrolle über ihre Finanzen übernommen haben.',

    footerPrivacy: 'Datenschutz',
    footerTerms: 'AGB',
    footerContact: 'Kontakt',

    // Privacy Page
    privacyPageTitle: 'Datenschutzrichtlinie - Neto',
    privacyBackHome: '← Zurück zur Startseite',
    privacyLastUpdate: 'Letzte Aktualisierung: Januar 2026',
    privacyH1: 'Datenschutzrichtlinie von Neto',
    privacyIntroTitle: '1. Einleitung',
    privacyIntroText: 'Neto ("die App") ist eine persönliche Finanz-App, die nach einem grundlegenden Prinzip entwickelt wurde: **Deine Finanzinformationen gehören ausschließlich dir**. Diese Datenschutzrichtlinie erklärt, wie wir mit deinen Daten umgehen (oder besser gesagt, wie wir *nicht* damit umgehen).',
    privacyDataTitle: '2. Datenerfassung und -speicherung',
    privacyDataIntro: 'Neto arbeitet nach einem "Privacy-First"- und "Local Storage"-Modell.',
    privacyDataBullet1: '**Finanzdaten:** Alle deine Transaktionen, Konten, Budgets und Kategorisierungen werden **nur und ausschließlich auf deinem Gerät** (iPhone/iPad) gespeichert. Neto sendet diese Informationen nicht an externe Server, weder eigene noch von Dritten.',
    privacyDataBullet2: '**Keine Benutzerkonten:** Wir verlangen nicht, dass du ein Konto mit E-Mail oder Passwort erstellst, um die App zu nutzen. Wir haben keine Benutzerdatenbank.',
    privacyDataBullet3: '**Keine Bankverbindung:** Neto verbindet sich nicht mit deinen Banken und fragt keine Bankdaten ab.',
    privacyIcloudTitle: '3. iCloud-Nutzung',
    privacyIcloudText: 'Wenn du die iCloud-Sicherung auf deinem Gerät aktiviert hast, werden die Neto-Daten in diese Sicherung einbezogen. Dieser Prozess wird vollständig von Apple verwaltet und unterliegt der Datenschutzrichtlinie von Apple. Wir haben keinen Zugriff auf diese Backups.',
    privacyAnalyticsTitle: '4. Analyse und Verbesserungen',
    privacyAnalyticsText: 'Um die Stabilität und Leistung der App zu verbessern, können wir **anonyme** technische Metriken sammeln (wie Absturzberichte und allgemeine Nutzungsstatistiken), die keine personenbezogenen Daten oder Finanzdetails enthalten.',
    privacyChangesTitle: '5. Änderungen dieser Richtlinie',
    privacyChangesText: 'Wir können diese Datenschutzrichtlinie gelegentlich aktualisieren. Wir werden dich über wesentliche Änderungen durch ein App-Update benachrichtigen.',
    privacyContactTitle: '6. Kontakt',
    privacyContactText: 'Bei Fragen zu dieser Richtlinie kannst du uns kontaktieren unter:',
  },

  fr: {
    title: 'Neto – Ton centre de contrôle financier',
    description: 'Enregistre en secondes, comprends en minutes. Ton app de finances personnelles.',

    navFeatures: 'Fonctionnalités',
    navAnalytics: 'Analytique',
    navPrivacy: 'Confidentialité',
    navDownload: 'Télécharger',

    heroTitle: 'Ton centre de contrôle financier',
    heroSubtitle: 'Enregistre en secondes, comprends en minutes. Importe, automatise ou enregistre par la voix. Analytique qui répond aux questions.',
    heroAppStore: 'Télécharger sur l\'App Store',
    heroLearnMore: 'En savoir plus',

    featuresTitle: 'Tout ce dont tu as besoin pour prendre le contrôle',
    feature1Title: 'Import rapide',
    feature1Desc: 'Importe depuis CSV ou Excel en secondes. Migre sans perdre l\'historique.',
    feature2Title: 'Enregistrement vocal',
    feature2Desc: 'Dicte tes dépenses et laisse l\'IA les enregistrer pour toi.',
    feature3Title: 'Raccourcis Apple',
    feature3Desc: 'Automatise les enregistrements récurrents avec les Raccourcis.',
    feature4Title: 'Analytique avancée',
    feature4Desc: 'Graphiques interactifs, filtres et rapports qui révèlent des patterns.',

    stat1: 'Privé et local',
    stat2: 'Comptes illimités',
    stat3: 'Devises supportées',
    stat4: 'Données dans le cloud',

    screenshotsTitle: 'Conçu pour la clarté',
    screenshotsSubtitle: 'Interface intuitive qui te montre exactement ce que tu dois voir.',

    analyticsTitle: 'Comprends ce qui se passe avec ton argent',
    analyticsDesc: 'Ne fais pas que suivre. Neto transforme tes données en réponses : tendances par catégorie, flux net mensuel et budgets avec suivi réel.',
    analyticsBullet1: 'Filtres par période, catégorie, compte et tag',
    analyticsBullet2: 'Budgets hebdomadaires, mensuels et annuels',
    analyticsBullet3: 'Plusieurs comptes avec conversion de devises',

    privacyTitle: 'Confidentialité par conception',
    privacyDesc: 'Tes données financières vivent sur ton iPhone, pas sur nos serveurs. Sans compte, sans traçage, sans compromis.',
    privacyLink: 'Lire la politique de confidentialité',

    ctaTitle: 'Contrôle réel, sans friction.',
    ctaSubtitle: 'Rejoins ceux qui ont déjà pris le contrôle de leurs finances personnelles.',

    footerPrivacy: 'Confidentialité',
    footerTerms: 'Conditions',
    footerContact: 'Contact',

    // Privacy Page
    privacyPageTitle: 'Politique de Confidentialité - Neto',
    privacyBackHome: '← Retour à l\'accueil',
    privacyLastUpdate: 'Dernière mise à jour : Janvier 2026',
    privacyH1: 'Politique de Confidentialité de Neto',
    privacyIntroTitle: '1. Introduction',
    privacyIntroText: 'Neto ("l\'App") est une application de finances personnelles conçue avec un principe fondamental : **tes informations financières t\'appartiennent exclusivement**. Cette Politique de Confidentialité explique comment nous gérons (ou plutôt, comment nous *ne gérons pas*) tes données.',
    privacyDataTitle: '2. Collecte et stockage des données',
    privacyDataIntro: 'Neto fonctionne selon un modèle "Privacy-First" (Confidentialité d\'abord) et "Local Storage" (Stockage local).',
    privacyDataBullet1: '**Données financières :** Toutes tes transactions, comptes, budgets et catégorisations sont stockés **uniquement et exclusivement sur ton appareil** (iPhone/iPad). Neto n\'envoie pas ces informations à des serveurs externes, ni les nôtres ni ceux de tiers.',
    privacyDataBullet2: '**Pas de compte utilisateur :** Nous ne demandons pas de créer un compte avec email ou mot de passe pour utiliser l\'App. Nous n\'avons pas de base de données d\'utilisateurs.',
    privacyDataBullet3: '**Pas de connexion bancaire :** Neto ne se connecte pas à tes banques et ne demande pas tes identifiants bancaires.',
    privacyIcloudTitle: '3. Utilisation d\'iCloud',
    privacyIcloudText: 'Si tu as activé la sauvegarde iCloud sur ton appareil, les données de Neto seront incluses dans cette sauvegarde. Ce processus est entièrement géré par Apple et est régi par la Politique de Confidentialité d\'Apple. Nous n\'avons pas accès à ces sauvegardes.',
    privacyAnalyticsTitle: '4. Analyse et Améliorations',
    privacyAnalyticsText: 'Pour améliorer la stabilité et les performances de l\'App, nous pouvons collecter des métriques techniques **anonymes** (comme les rapports de plantage et les statistiques générales d\'utilisation) qui ne contiennent aucune information personnelle identifiable ni détails financiers.',
    privacyChangesTitle: '5. Modifications de cette politique',
    privacyChangesText: 'Nous pouvons mettre à jour cette Politique de Confidentialité occasionnellement. Nous te notifierons de tout changement significatif via une mise à jour de l\'App.',
    privacyContactTitle: '6. Contact',
    privacyContactText: 'Si tu as des questions sur cette politique, tu peux nous contacter à :',
  },

  it: {
    title: 'Neto – Il tuo centro di controllo finanziario',
    description: 'Registra in secondi, comprendi in minuti. La tua app di finanza personale.',

    navFeatures: 'Funzionalità',
    navAnalytics: 'Analitica',
    navPrivacy: 'Privacy',
    navDownload: 'Scarica',

    heroTitle: 'Il tuo centro di controllo finanziario',
    heroSubtitle: 'Registra in secondi, comprendi in minuti. Importa, automatizza o registra con la voce. Analitica che risponde alle domande.',
    heroAppStore: 'Scarica su App Store',
    heroLearnMore: 'Scopri di più',

    featuresTitle: 'Tutto ciò di cui hai bisogno per prendere il controllo',
    feature1Title: 'Import rapido',
    feature1Desc: 'Importa da CSV o Excel in secondi. Migra senza perdere lo storico.',
    feature2Title: 'Registrazione vocale',
    feature2Desc: 'Detta le tue spese e lascia che l\'IA le registri per te.',
    feature3Title: 'Comandi rapidi Apple',
    feature3Desc: 'Automatizza le registrazioni ricorrenti con i Comandi rapidi.',
    feature4Title: 'Analitica avanzata',
    feature4Desc: 'Grafici interattivi, filtri e report che rivelano pattern.',

    stat1: 'Privato e locale',
    stat2: 'Account illimitati',
    stat3: 'Valute supportate',
    stat4: 'Dati nel cloud',

    screenshotsTitle: 'Progettato per la chiarezza',
    screenshotsSubtitle: 'Interfaccia intuitiva che ti mostra esattamente ciò che devi vedere.',

    analyticsTitle: 'Comprendi cosa sta succedendo con i tuoi soldi',
    analyticsDesc: 'Non solo registrare. Neto trasforma i tuoi dati in risposte: tendenze per categoria, flusso netto mensile e budget con monitoraggio reale.',
    analyticsBullet1: 'Filtri per periodo, categoria, conto e tag',
    analyticsBullet2: 'Budget settimanali, mensili e annuali',
    analyticsBullet3: 'Account multipli con conversione di valuta',

    privacyTitle: 'Privacy by design',
    privacyDesc: 'I tuoi dati finanziari vivono sul tuo iPhone, non sui nostri server. Senza account, senza tracciamento, senza compromessi.',
    privacyLink: 'Leggi l\'informativa sulla privacy',

    ctaTitle: 'Controllo reale, senza attriti.',
    ctaSubtitle: 'Unisciti a chi ha già preso il controllo delle proprie finanze personali.',

    footerPrivacy: 'Privacy',
    footerTerms: 'Termini',
    footerContact: 'Contatto',

    // Privacy Page
    privacyPageTitle: 'Informativa sulla Privacy - Neto',
    privacyBackHome: '← Torna alla Home',
    privacyLastUpdate: 'Ultimo aggiornamento: Gennaio 2026',
    privacyH1: 'Informativa sulla Privacy di Neto',
    privacyIntroTitle: '1. Introduzione',
    privacyIntroText: 'Neto ("l\'App") è un\'applicazione di finanza personale progettata con un principio fondamentale: **le tue informazioni finanziarie appartengono esclusivamente a te**. Questa Informativa sulla Privacy spiega come gestiamo (o meglio, come *non* gestiamo) i tuoi dati.',
    privacyDataTitle: '2. Raccolta e archiviazione dei dati',
    privacyDataIntro: 'Neto opera secondo un modello "Privacy-First" e "Local Storage".',
    privacyDataBullet1: '**Dati finanziari:** Tutte le tue transazioni, conti, budget e categorizzazioni sono archiviati **solo ed esclusivamente sul tuo dispositivo** (iPhone/iPad). Neto non invia queste informazioni a server esterni, né nostri né di terze parti.',
    privacyDataBullet2: '**Nessun account utente:** Non richiediamo di creare un account con email o password per usare l\'App. Non abbiamo un database di utenti.',
    privacyDataBullet3: '**Nessuna connessione bancaria:** Neto non si connette alle tue banche e non richiede credenziali bancarie.',
    privacyIcloudTitle: '3. Utilizzo di iCloud',
    privacyIcloudText: 'Se hai attivato il backup di iCloud sul tuo dispositivo, i dati di Neto saranno inclusi in quel backup. Questo processo è gestito interamente da Apple ed è regolato dall\'Informativa sulla Privacy di Apple. Non abbiamo accesso a quei backup.',
    privacyAnalyticsTitle: '4. Analisi e Miglioramenti',
    privacyAnalyticsText: 'Per migliorare la stabilità e le prestazioni dell\'App, potremmo raccogliere metriche tecniche **anonime** (come report di crash e statistiche generali di utilizzo) che non contengono informazioni personali identificabili né dettagli finanziari.',
    privacyChangesTitle: '5. Modifiche a questa informativa',
    privacyChangesText: 'Potremmo aggiornare questa Informativa sulla Privacy occasionalmente. Ti notificheremo di eventuali modifiche significative tramite un aggiornamento dell\'App.',
    privacyContactTitle: '6. Contatto',
    privacyContactText: 'Se hai domande su questa informativa, puoi contattarci a:',
  },

  pt: {
    title: 'Neto – Seu centro de controle financeiro',
    description: 'Registre em segundos, entenda em minutos. Seu app de finanças pessoais.',

    navFeatures: 'Recursos',
    navAnalytics: 'Análise',
    navPrivacy: 'Privacidade',
    navDownload: 'Baixar',

    heroTitle: 'Seu centro de controle financeiro',
    heroSubtitle: 'Registre em segundos, entenda em minutos. Importe, automatize ou registre por voz. Análise que responde perguntas.',
    heroAppStore: 'Baixar na App Store',
    heroLearnMore: 'Saiba mais',

    featuresTitle: 'Tudo o que você precisa para assumir o controle',
    feature1Title: 'Importação rápida',
    feature1Desc: 'Importe de CSV ou Excel em segundos. Migre sem perder histórico.',
    feature2Title: 'Registro por voz',
    feature2Desc: 'Dite seus gastos e deixe a IA registrá-los para você.',
    feature3Title: 'Atalhos da Apple',
    feature3Desc: 'Automatize registros recorrentes com Atalhos.',
    feature4Title: 'Análise avançada',
    feature4Desc: 'Gráficos interativos, filtros e relatórios que revelam padrões.',

    stat1: 'Privado e local',
    stat2: 'Contas ilimitadas',
    stat3: 'Moedas suportadas',
    stat4: 'Dados na nuvem',

    screenshotsTitle: 'Projetado para clareza',
    screenshotsSubtitle: 'Interface intuitiva que mostra exatamente o que você precisa ver.',

    analyticsTitle: 'Entenda o que está acontecendo com seu dinheiro',
    analyticsDesc: 'Não apenas registre. Neto transforma seus dados em respostas: tendências por categoria, fluxo líquido mensal e orçamentos com acompanhamento real.',
    analyticsBullet1: 'Filtros por período, categoria, conta e tag',
    analyticsBullet2: 'Orçamentos semanais, mensais e anuais',
    analyticsBullet3: 'Múltiplas contas com conversão de moeda',

    privacyTitle: 'Privacidade por design',
    privacyDesc: 'Seus dados financeiros vivem no seu iPhone, não em nossos servidores. Sem contas, sem rastreamento, sem compromissos.',
    privacyLink: 'Ler política de privacidade',

    ctaTitle: 'Controle real, sem atrito.',
    ctaSubtitle: 'Junte-se a quem já assumiu o controle de suas finanças pessoais.',

    footerPrivacy: 'Privacidade',
    footerTerms: 'Termos',
    footerContact: 'Contato',

    // Privacy Page
    privacyPageTitle: 'Política de Privacidade - Neto',
    privacyBackHome: '← Voltar ao Início',
    privacyLastUpdate: 'Última atualização: Janeiro 2026',
    privacyH1: 'Política de Privacidade do Neto',
    privacyIntroTitle: '1. Introdução',
    privacyIntroText: 'Neto ("o App") é um aplicativo de finanças pessoais projetado com um princípio fundamental: **suas informações financeiras pertencem exclusivamente a você**. Esta Política de Privacidade explica como lidamos (ou melhor, como *não* lidamos) com seus dados.',
    privacyDataTitle: '2. Coleta e armazenamento de dados',
    privacyDataIntro: 'Neto opera sob um modelo "Privacy-First" (Privacidade Primeiro) e "Local Storage" (Armazenamento Local).',
    privacyDataBullet1: '**Dados financeiros:** Todas as suas transações, contas, orçamentos e categorizações são armazenados **única e exclusivamente no seu dispositivo** (iPhone/iPad). Neto não envia essas informações para nenhum servidor externo, nosso ou de terceiros.',
    privacyDataBullet2: '**Sem contas de usuário:** Não exigimos que você crie uma conta com email ou senha para usar o App. Não temos banco de dados de usuários.',
    privacyDataBullet3: '**Sem conexão bancária:** Neto não se conecta aos seus bancos nem solicita credenciais bancárias.',
    privacyIcloudTitle: '3. Uso do iCloud',
    privacyIcloudText: 'Se você tiver o backup do iCloud ativado no seu dispositivo, os dados do Neto serão incluídos nesse backup. Esse processo é gerenciado inteiramente pela Apple e é regido pela Política de Privacidade da Apple. Não temos acesso a esses backups.',
    privacyAnalyticsTitle: '4. Análise e Melhorias',
    privacyAnalyticsText: 'Para melhorar a estabilidade e o desempenho do App, podemos coletar métricas técnicas **anônimas** (como relatórios de falhas e estatísticas gerais de uso) que não contêm informações pessoais identificáveis nem detalhes financeiros.',
    privacyChangesTitle: '5. Alterações nesta política',
    privacyChangesText: 'Podemos atualizar esta Política de Privacidade ocasionalmente. Notificaremos você sobre quaisquer alterações significativas por meio de uma atualização do App.',
    privacyContactTitle: '6. Contato',
    privacyContactText: 'Se você tiver dúvidas sobre esta política, pode nos contatar em:',
  },
} as const;

export function getTranslations(lang: Language) {
  return translations[lang] || translations[defaultLang];
}

export function getLangFromUrl(url: URL): Language {
  const [, lang] = url.pathname.split('/');
  if (lang in languages) {
    return lang as Language;
  }
  return defaultLang;
}
