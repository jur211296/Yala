//
//  SessionPreferenceKeys.swift
//  Yala
//
//  **El inventario: qué preferencia es de la PERSONA y qué preferencia es del TELÉFONO.**
//
//  `SessionDefaults` decide EN QUÉ dominio se escribe; este fichero decide QUÉ se escribe ahí. Son
//  preguntas distintas y por eso viven separadas: la puerta no tiene por qué saber nada de keys, y
//  la lista no tiene por qué saber nada de suites.
//
//  ## Por qué una allowlist de PERSONA y no una denylist de DISPOSITIVO
//
//  El sesgo importa y es deliberado: **una key olvidada en esta lista sigue fugando exactamente como
//  hoy, sin regresión.** Una key olvidada en la lista contraria se llevaría al cajón de la visita algo
//  del teléfono del dueño, que es daño NUEVO. Cuando haya que equivocarse, que sea hacia el lado que
//  ya conocemos.
//
//  ## La red de completitud, y por qué NO es «lo que está marcado como sincronizado»
//
//  La v1 del plan proponía «toda key `synced: true`». **Medido: insuficiente por los dos lados.**
//
//  - Seis keys son `PrefSyncKey` y **no** son `synced: true` — entre ellas `appLanguageOverride`,
//    `onboardingMode`, `financialMindset` y los dos del consent de nube.
//  - Cinco keys son `synced: true` y **no** son `PrefSyncKey` (`moreSectionOrder`, `sankeyLabelMode`
//    y las tres de `panelHeroKPIs`). Ésas son además un residual ABIERTO del canal de sync, ajeno a
//    este fichero y ya documentado en `.claude/rules/swiftdata-cloudkit.md`: suben y no vuelven jamás.
//  - Y el síntoma TITULAR del ticket —la barra de pestañas— es `synced: false`
//    (`AppPreferences.swift:184`), así que ninguna de las dos redes lo alcanzaba.
//
//  ⇒ **Red = `PrefSyncKey.allCases ∪ {synced: true}`**, más las que se añaden A MANO por formar PAR
//  con una de la red. Lo que la red garantiza no es que la lista esté completa —eso no lo garantiza
//  nada— sino que **ninguna key de la red se quede sin clasificar en silencio**: el escáner de
//  `SessionPreferenceKeysTests` falla si aparece una nueva y nadie la ha puesto de un lado o del otro.
//
//  ## Los PARES, que son la parte que no se deduce
//
//  Una key puede ser de persona sin estar en ninguna de las dos redes, porque **acompaña** a una que
//  sí lo está. Separarlas es el «lector desalineado» del ticket en su forma más barata de producir:
//
//  - `tabConfigJSON` viaja con `usageFocus` — `FullModeActivationView.swift:109-114` las escribe
//    JUNTAS, y en secundaria lo hace **sin un solo guard**.
//  - `customPeriodStart`/`customPeriodEnd` viajan con `defaultPeriod`: son el rango del período
//    `.custom` (`SessionState.swift:99-104` los escribe, `:797-798` los lee). Un `defaultPeriod` en
//    el cajón con su rango en el dominio del dueño da un período personalizado sin fechas.
//  - `financialMindset` es espejo byte-idéntico de `expensesOnlyMode` en `SessionState`
//    (`:128-131` frente a `:149-154`), y ya entra por `PrefSyncKey`.
//
//  ## Las N GRAFÍAS, y por qué el conteo las SUMA
//
//  La misma key se nombra de formas distintas y el escáner tiene que resolverlas todas: literal
//  (`"chatQuestionsToday"`), símbolo de `AppPreferences.Keys` (`Keys.financialMindset`), `PrefSyncKey`
//  (`.usageFocus.rawValue`), constante de un tercero (`UsageFocus.userDefaultsKey`,
//  `CurrencyUtils.preferredCurrencyKey`) o constante privada de un servicio
//  (`ProUpsellService.sessionCountKey`). **Con el conteo hecho sobre una sola grafía, mover un sitio de
//  literal a símbolo deja el escáner en verde sin comprobar nada** — y `DataWipeService` mezcla las dos
//  dentro de la misma función. La medición que lo confirmó: `transactionsSavedCount` se incrementa en
//  `NewTransactionViewModel.swift:564-565` **y también** en `DraftService.swift:343`, un segundo
//  escritor que ninguna lista previa nombraba.
//

import Foundation

nonisolated enum SessionPreferenceKeys {

    /// **Keys de la PERSONA**: lo que la visita escribe en SU cajón y el dueño recupera intacto al
    /// volver.
    ///
    /// Las 42 primeras salen de la red y **ninguna necesitó excepción**, lo cual no es casualidad ni
    /// pereza: estar en `PrefSyncKey` o en `synced: true` significa, por definición, «esto viaja con
    /// la CUENTA a los otros dispositivos de su dueño» ⇒ es de la persona por construcción. El
    /// mecanismo de excepción existe para la key que mañana entre en la red sin serlo.
    static let person: Set<String> = [
        // — Identidad y dinero
        "userName", "userProfileIcon", "defaultCurrencyCode", "secondaryCurrencies",
        "currencyDisplayFormat", "decimalPlaces", "firstWeekday", "defaultPeriod",
        // — El PAR de `defaultPeriod`: el rango del período `.custom`. Un período personalizado en el
        //   cajón con sus fechas en el dominio del dueño es un período sin fechas.
        "customPeriodStart", "customPeriodEnd",
        // — Captura y voz
        "autoFocusField", "voiceLanguage",
        // — Cuentas, panel y presentación
        "accountsSortOrderNames", "colorfulIcons", "showVariations", "averageLineMode",
        "panelAccountsCollapsed", "panelSectionsOrder", "panelSectionsHidden",
        "panelTendenciasOrder", "panelTendenciasHidden",
        "panelDistribucionOrder", "panelDistribucionHidden",
        "panelPlanificacionOrder", "panelPlanificacionHidden",
        "panelHeroKPIsOrder", "panelHeroKPIsHidden", "panelHeroKPIsCustomized",
        "moreSectionOrder", "sankeyLabelMode",
        // — El PAR de `usageFocus`, y el síntoma TITULAR del ticket: la barra de pestañas.
        //   `FullModeActivationView.swift:109-114` las escribe juntas y sin guard.
        "usageFocus", "tabBarConfiguration",
        // — Ideas y avisos
        "insightsTone", "insightsFocus", "budgetAlertsEnabled",
        // — Grupos: cómo quiere ver ella sus gastos compartidos
        "includeGroupTransactionsInFeed", "includeGroupsInPanelTotal",
        "includeGroupTransactionsInStats", "bridgeGroupExpensesToPersonalAccounts",
        // — Modo y perfil
        "expensesOnlyMode", "financialMindset", "onboardingMode", "appLanguageOverride",
        // — Consent de nube: es un hecho de SU cuenta, no de este teléfono
        "cloudConsentAcceptedAt", "cloudConsentTextVersion",

        // — Contadores (D6, decisión del owner 2026-08-13). No están en ninguna red: son literales
        //   sueltos repartidos por servicios, y cada uno mide algo de UNA persona.
        "chatQuestionsToday",        // cupo diario del chat de IA: si es del dueño, ella se lo come
        "chat_draft_saved_signal", // su borrador de chat a medias; viaja con `SessionState`
        "transactionsSavedCount",    // a las 3 transacciones se pide permiso de notificaciones
        "needsPostOnboardingTrial",  // one-shot del trial; la decisión de no ofrecérselo sigue en pie

        // — La oferta Pro, las OCHO (decisión del owner 2026-08-13). Describen la relación de UNA
        //   persona con la oferta: cuántas veces la vio, si la descartó, si estuvo en trial. Ninguna
        //   es del teléfono, y partirlas dejaría a `ProUpsellService` leyendo de dos cajones.
        "pro.upsell.sessionCount", "pro.upsell.lastShownDate", "pro.upsell.dismissCount",
        "pro.upsell.monthlyShownCount", "pro.upsell.monthlyResetDate",
        "pro.trial.wasInTrial", "pro.trial.expiredSheetShown", "pro.milestone.lastShown",

        // — F4 · el resto de `AppPreferences`, las `synced: false`. **Ya viajaban al cajón** desde F3
        //   (el consumidor se mueve entero, no key por key); declararlas aquí es lo que las mete en la
        //   red del escáner de lectores desalineados, que es donde estaba el trabajo de verdad.

        //   Consentimientos de IA. Son de la PERSONA por la razón más fuerte de todo el inventario:
        //   un consentimiento es un hecho de quien lo da, y heredar el del dueño equivaldría a darlo
        //   por ella. Es la misma lección que sacó del canal de prefs el consent de Grupos (C1).
        "aiDataConsentAccepted", "aiChatConsentAccepted", "aiInsightsConsentAccepted",

        //   Qué funciones de IA quiere encendidas, y por dónde entra.
        "aiInsightsEnabled", "cashFlowAIEnabled", "chatAssistantEnabled",
        "imageInputEnabled", "voiceInputEnabled", "chatFABVisible",

        //   Qué ideas quiere ver en su panel, y cómo ordena lo suyo.
        "insightsShowTexts", "insightsShowNature", "insightsShowWeekday", "insightsShowQuickStats",
        "insightsShowBudgetsAtRisk", "insightsShowSubscriptions", "insightsShowPendingPayments",
        "budgets.hideInactive", "tagsSortOrderNames", "userAlias",

        //   Tours, hints y coach-marks: PERSONA, y la decisión merece decirse porque la intuición
        //   tira a «esto es del teléfono». Un tour no recuerda un ajuste: explica la app a alguien que
        //   no la conoce. Si la visita nunca ha usado Yala, verlos es lo correcto — y el cajón nace
        //   vacío, así que los ve sin que nadie tenga que sembrarlos. La contrapartida es que el dueño
        //   NO los vuelve a ver al recuperar su móvil, porque los suyos nunca se tocaron.
        "hasSeenSettingsTour", "hasSeenCashFlowSetupTour", "hasSeenCashFlowTableTour",
        "hasSeenTodayFXCoachMark", "hasSeenGroupsNotificationPrompt", "hasShownGroupsOnboarding",
        "showSiriTip", "showWidgetHints",

        // — F4 · los servicios con su propio almacén, fuera de `AppPreferences`. Aquí el criterio es
        //   el mismo de siempre —¿el hecho es de la persona o del teléfono?— aplicado a cuatro casos
        //   que ni el ticket ni el plan nombraban.

        //   La apariencia elegida. Es lo más visible de todo el inventario: si la visita cambia el
        //   tema, el dueño recupera su móvil con otro aspecto.
        "userTheme",

        //   Cuántas veces se le enseñó un aviso a ESTA persona y si interactuó. Misma familia exacta
        //   que `pro.upsell.sessionCount`, que el owner ya resolvió como PERSONA: a la visita le
        //   saldrían en su primera pantalla como si llevara meses.
        "nudge.lastShownDate", "nudge.weeklyShownCount", "nudge.monthlyShownCount",
        "nudge.weeklyResetDate", "nudge.monthlyResetDate",

        //   «Ya le pedí una reseña a esta persona». Pedírsela a la visita el día que entra, contando
        //   los meses de uso del dueño, es justo lo que estas tres evitan.
        "reviewFirstLaunchDate", "reviewLastPromptDate", "reviewPromptCount",

        //   El PAR de `chatQuestionsToday`, y la lección más cara de F4: al mover el contador sin
        //   ella, `ChatAssistantService` quedó comparando la fecha del DUEÑO contra el contador de la
        //   VISITA — el lector desalineado en su forma exacta, introducido por el propio fix. **El
        //   escáner no lo cazó porque solo protege lo que está DECLARADO**: un par cuya otra mitad no
        //   figura en esta lista es invisible para él. ⇒ al añadir una key, busca con qué se compara.
        "chatLastQuestionDate",

        //   Lo suyo, en pantallas donde el reparto y la bandeja recuerdan la última elección.
        "lastSplitType", "lastSplitPercentage", "lastInboxDraftCheckDate",
        "hasSeenNotificationPrimer", "hasExportedData",
    ]

    /// **Familias de keys DINÁMICAS de la persona**, que no se pueden enumerar una a una porque su
    /// nombre se compone en tiempo de ejecución. Son tres y cada una tiene su generador:
    /// `nudge.interacted.<tipo>` (`NudgeService.Keys.interacted`), `guide.<id>.dismissed`
    /// (`ContextualGuideBanner`) y la familia `pro.*` de la oferta.
    ///
    /// Un `Set` exacto las perdería enteras, y perderlas no es inocuo: son justo las que registran
    /// «a esta persona ya se le enseñó esto».
    static let personPrefixes: [String] = ["nudge.", "guide.", "pro."]

    /// ¿Esta key viaja con la persona? Contempla las dos formas — enumerada y por familia.
    static func belongsToPerson(_ key: String) -> Bool {
        person.contains(key) || personPrefixes.contains { key.hasPrefix($0) }
    }

    /// **Keys que NO son de la persona**, cada una con su porqué EN EL CÓDIGO.
    ///
    /// Ninguna de la red cayó aquí (ver `person`), así que lo que hay son las del TELÉFONO que el
    /// cajón acaba conteniendo de todos modos — porque en F3 los consumidores se mueven ENTEROS, no
    /// key por key: `AppPreferences` lleva sus 76 properties al dominio que le den. Que estén aquí
    /// declaradas es lo que conecta este inventario con la SIEMBRA de F1: las dos primeras son
    /// exactamente las que el cajón hereda del dueño al nacer, y sin heredarlas la visita vería el
    /// Welcome sobre un store vacío.
    static let deviceExceptions: [String: String] = [
        "hasCompletedOnboarding":
            "Del TELÉFONO: dice si esta instalación ya pasó el onboarding. El cajón la SIEMBRA con el "
            + "valor del dueño (`SessionDefaults.seededDeviceKeys`); sin ella, la visita arranca en el "
            + "Welcome sobre un store secundario vacío, que es el brick que el mount prohíbe.",
        "hasShownWelcomeChooser":
            "Del TELÉFONO, y va en PAR con la anterior: es la segunda que el healing de entrada escribe "
            + "(`SwiftDataConfiguration.swift:916-917`) y la segunda que la siembra copia.",
        "hasShownYalaAIOnboarding":
            "Del TELÉFONO. Fuera de la siembra obligatoria por decisión D4 del owner: medido, el healing "
            + "de entrada NO la escribe, y su impacto es cosmético — a lo sumo la visita vuelve a ver "
            + "una presentación que el dueño ya había visto.",
        "lastSeenAppVersion":
            "Del TELÉFONO: qué versión de la app se abrió por última vez en este aparato. Nada que ver "
            + "con quién la abre.",
        "groupsBetaUnlocked":
            "Del TELÉFONO, y con historia: es el sello de adopción del dominio Grupos, y que la visita "
            + "lo escribiera en el dominio del dueño fue una de las tres vías que cerró el chip M1 de "
            + "2026-08-11. Su guard vive en el ESCRITOR y ahí se queda.",
        "yala.wasProUser":
            "Del TELÉFONO, y es el caso donde la intuición falla: Pro NO se compra con la cuenta de "
            + "Yala sino con el Apple ID del dispositivo, así que durante la visita la app es Pro "
            + "porque lo es el móvil del dueño — no porque ella haya comprado nada. Llevarlo al cajón "
            + "haría que StoreKit y el espejo local discreparan, y al salir el dueño podría encontrarse "
            + "la app creyendo que dejó de ser Pro. El estado de suscripción lo resuelve StoreKit por "
            + "Apple ID; esta key solo lo espeja.",
        "dev.forceProTier":
            "Del TELÉFONO: interruptor de desarrollo del scheme Dev, sin significado para ningún "
            + "usuario real. Vive fuera de la frontera a propósito.",
        "dev.forceFreeTier":
            "Del TELÉFONO, por el mismo motivo que su gemelo `dev.forceProTier`.",
        "devSeedDataExecuted":
            "Del TELÉFONO: centinela del seed de datos de desarrollo, sin significado para ningún "
            + "usuario real.",
        "notificationsSeeded":
            "Del TELÉFONO: centinela de que las notificaciones locales de ESTA instalación ya se "
            + "sembraron. Habla del aparato y de su permiso del sistema, no de quién lo usa.",
    ]
}
