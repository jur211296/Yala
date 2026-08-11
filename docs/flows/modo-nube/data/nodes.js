// nodes.js — el CONTENIDO de los paneles del Atlas de Flujos de Modo Nube.
//
// Regla madre (cabecera de MODO-NUBE-CHIPS-FLUJOS): cada campo `code` apunta a una celda REAL de una
// tabla de lógica pura o a una línea de una vista LEÍDA. Nada sale de MODO-NUBE-ARQUITECTURA. Donde el
// diseño y el código difieren, gana el código y la divergencia va en `notes` con la marca ⚠︎.
//
// Medido el 2026-08-09 contra HEAD 9d6f0f1c (branch 2.0.5).
//
// Campos:
//   title    — nombre humano del nodo
//   shot     — id de screenshot (F2 lo puebla en img/<shot>); null = nodo de DECISIÓN pura, sin pantalla
//   sees     — qué ve el usuario
//   persists — qué queda escrito (keys, faro, sesión, par, journal)
//   exits    — salidas y recuperación (cancelar / matar la app / sin red)
//   code     — [{ t: coordenada, d: qué decide ahí }]
//   notes    — divergencias con el diseño, huecos y hallazgos

window.ATLAS_NODES = {

  // ══════════════════════════════════════════════════════════════════════════
  // FLUJO 1 · Alta born-cloud (A4 → A5)
  // ══════════════════════════════════════════════════════════════════════════

  "alta-hero": {
    title: "Welcome · Hero",
    shot: "alta-hero.png",
    sees: "Pantalla de bienvenida con el logo y el botón «Empezar». Si el Hero detectó datos en iCloud, al tocar sale el alert «Detectamos tu cuenta» con tres botones: Cargar mis datos · Empezar de cero · Cancelar.",
    persists: "Nada. `hasTappedEmpezar` es estado de vista.",
    exits: "El Cancel del alert es EXPLÍCITO a propósito (B-11): sin él, el dismiss implícito de iOS dejaba el Hero consumido y sin re-tap posible. Cancelar → chooser.",
    code: [
      { t: "WelcomeFlowContainer.swift:168 `handleHeroDecision`", d: "`.proceedNoData` → chooser · `.proceedWithData` → alert" },
      { t: "WelcomeFlowContainer.swift:146-165", d: "los 3 botones del alert y a dónde va cada uno" }
    ],
    notes: []
  },

  "alta-chooser": {
    title: "Welcome · Chooser (3 ramas)",
    shot: "alta-chooser.png",
    sees: "«Soy nuevo» · «Ya tengo una cuenta» · «Me invitaron a un grupo».",
    persists: "Nada todavía. `hasShownWelcomeChooser` lo escribe el CALLBACK de ContentView, no el chooser.",
    exits: "Back → Hero.",
    code: [
      { t: "WelcomeFlowContainer.swift:109-121", d: "`.restore` → handleExistingBranch · `.new` → handleNewBranch · `.invite` → onSelectBranch" },
      { t: "ContentView.swift:1261-1277", d: "el `case .new` histórico sigue existiendo y es INALCANZABLE desde A4 (el container desvía `.new` a su 2º nivel); delega al mismo helper para que los dos caminos no diverjan" }
    ],
    notes: ["`WelcomeChooserView.Branch` conserva sus TRES ramas — §k.2 es explícito y A4 no las tocó."]
  },

  "alta-faro": {
    title: "Decisión · el faro va ANTES de la elección (A26)",
    shot: null,
    sees: "Nada: es una decisión, ocurre entre el tap y la siguiente pantalla.",
    persists: "Nada. Es LECTURA del iCloud-KV (`yala.cloud.accountLinked` / `accountProvider`).",
    exits: "N/A.",
    code: [
      { t: "WelcomeAccountChoiceLogic.swift:103 `routeNewBranch`", d: "faro vinculado + entrada nube disponible → `.cloudSignIn(provider)`; si no, `bypass` → `.single` o `.chooser`" },
      { t: "WelcomeFlowContainer.swift:196 `handleNewBranch`", d: "el ORDEN es el contrato: el faro se consulta antes de ofrecer nada y antes de que ContentView limpie prefs residuales" },
      { t: "WelcomeAccountChoiceLogic.swift:112", d: "provider desconocido/ausente ⇒ `.apple`; el faro solo ENCAMINA, el mismatch lo dice la pantalla de destino" },
      { t: "CloudBeacon.swift:44-51", d: "las 4 keys del faro" }
    ],
    notes: [
      "Residual DECLARADO en el propio código: bajo el kill-switch remoto `cloudEntryAvailable` es false ⇒ el faro no encamina y un born-cloud en su 2º device vuelve a poder divergir. Es el mismo residual que ya acepta la card de re-entrada, ampliado a este camino (WelcomeAccountChoiceLogic.swift:100-102).",
      "Medido el 2026-08-09 y anotado en la vista: `OnboardingResetHelper.safeKeysToClear` son SOLO `userName` y `defaultCurrencyCode` ⇒ la limpieza de fresh-start no toca las keys `yala.cloud.*`."
    ]
  },

  "alta-newchooser": {
    title: "Sub-chooser «Soy nuevo» (privado | nube)",
    shot: "alta-newchooser.png",
    sees: "Dos cards: privacidad total (iCloud) y cuenta en la nube. NINGUNA lleva distintivo de recomendada — la elección es del usuario. La de nube muestra su renuncia de privacidad inline. Con UNA sola opción visible esta pantalla NO se monta (bypass) — que es el recorrido de producción de hoy.",
    persists: "Nada.",
    exits: "Back → chooser.",
    code: [
      { t: "WelcomeAccountChoiceLogic.swift:42 `visibleNewOptions`", d: "la card nube exige los CINCO términos: configurado ∧ ¬uitest ∧ compilado ∧ kill-switch nube ∧ sub-flag de la elección" },
      { t: "WelcomeFlowContainer.swift:85-92", d: "el cableado real de los 5 términos" },
      { t: "WelcomeAccountChoiceLogic.swift:73 `bypass`", d: "una sola opción ⇒ se navega directo a ella" },
      { t: "CloudRemoteConfig.swift:133 `cloudOnboardingChoiceEnabled`", d: "el percent remoto — `\"0\"` en producción, fail-closed" }
    ],
    notes: [
      "`bornCloudEnabled` es la constante COMPILADA `CloudSyncFlags.bornCloudChoiceEnabled`, hoy `true`. La palanca de release es el PERCENT remoto, no la constante — la fila «A7 flipa la constante» del spec quedó obsoleta (anotación 1 del punto de control).",
      "⚠︎ La captura `alta-newchooser.png` está OBSOLETA a propósito (2026-08-10, chip RC): muestra el badge «Recomendado» sobre la card privada, que ya no existe ni en la vista ni en la etiqueta de accesibilidad. Se re-captura en la pasada de screenshots ya prevista."
    ]
  },

  "alta-privado": {
    title: "«Soy nuevo → privacidad total»",
    shot: "alta-privado.png",
    sees: "Va directo al onboarding normal, salvo que haya datos locales: entonces sale el alert de wipe.",
    persists: "`hasShownWelcomeChooser = true` · `OnboardingResetHelper.clearResidualPreferencesForFreshStart()` borra `userName` y `defaultCurrencyCode` del KV.",
    exits: "El alert de wipe deja el cover del Welcome VISIBLE hasta resolverse.",
    code: [
      { t: "ContentView.swift:1387 `startFreshPrivateOnboarding`", d: "limpieza de residuales → alert si `hasExistingData`, si no → onboarding" },
      { t: "ContentView.swift:1305-1310", d: "callback `onSelectPrivateAccount`" }
    ],
    notes: []
  },

  "alta-consent": {
    title: "Consentimiento informado (path `.bornCloud`)",
    shot: "alta-consent.png",
    sees: "Sheet con los 7 puntos de §k.6 y el botón «Aceptar». El copy es GENÉRICO — no cambia por path.",
    persists: "AL ACEPTAR: `cloudConsentAcceptedAt` (epoch) y `cloudConsentTextVersion` vía `PreferenceSyncService.set(int:)`. En `.icloud` van al iKV; el drenaje del cutover los lleva al backend. Métrica `cloudConsentAccepted(path:)`.",
    exits: "Descartar el sheet sin aceptar NO persiste nada (el registro vive en el botón). El flujo solo arranca desde `onAccept` — los botones del intro únicamente abren el sheet.",
    code: [
      { t: "WelcomeCloudSignInView.swift:108-113", d: "el consent SIEMPRE precede al sign-in, en las dos entradas" },
      { t: "CloudConsentView.swift:92-111 `registerConsent`", d: "las dos keys + la métrica, en el tap de Aceptar" },
      { t: "CloudMigrationController.swift:253", d: "`ConsentPath` — `.migration` · `.adopt` · `.bornCloud`" }
    ],
    notes: ["⚠︎ Corrección MEDIDA del spec (anotación 3 del punto de control): la promesa «cancelar deja el device sin consent-flag ni faro» era INSATISFACIBLE. El consent se persiste al aceptarse (append-only, precedente del repo). Ver el nodo «Matriz de cancelación»."]
  },

  "alta-intro": {
    title: "Intro del alta · elegir método",
    shot: "alta-intro.png",
    sees: "Título + subtítulo del alta y DOS botones de prominencia equivalente (Apple y Google, guideline 4.8) más la nota §13: la cuenta queda ligada al método.",
    persists: "Nada. El tap solo fija `chosenProvider` en memoria y abre el consent.",
    exits: "Back permitido (`canGoBack` incluye `.intro`).",
    code: [
      { t: "WelcomeCloudSignInView.swift:230 `bornCloudIntro`", d: "los dos botones + la nota" },
      { t: "WelcomeCloudSignInView.swift:274 `beginBornCloudSignUp`", d: "fija el método y abre el consent — NO firma nada" },
      { t: "WelcomeCloudSignInView.swift:153 `canGoBack`", d: "`.intro`/`.notFound`/`.blockedForeignData`/`.error`/`.providerMismatch` → sí; el resto no" }
    ],
    notes: ["El VStack va SIN `accessibilityIdentifier` de contenedor a propósito: uno aplicado arriba PISA los ids de los botones (medido con `snapshot_ui`) y dejaría al XCUITest sin poder targetearlos."]
  },

  "alta-signin": {
    title: "Sign-in (Apple | Google)",
    shot: "alta-signin.png",
    sees: "El sheet nativo de SIWA o el flujo web de Google.",
    persists: "Sesión Yala en el Keychain (`CloudAuthService`) + provider almacenado.",
    exits: "Con sesión ya viva se SALTA (no re-pide Face ID). Cancel de Google → vuelta al intro en silencio. Fallo de Apple → vuelta al intro sin alarma (ASAuthorization no distingue cancel de fallo). Fallo de Google → error con retry.",
    code: [
      { t: "WelcomeCloudSignInView.swift:504 `ensureSignedIn`", d: "las 4 salidas y la asimetría Apple/Google, que NO es cosmética" }
    ],
    notes: ["El sim NO completa SIWA/Google reales: en F2 esto queda `device-only` salvo la captura del sheet."]
  },

  "alta-creating": {
    title: "«Creando tu cuenta…» (fase `.creating`)",
    shot: "alta-creating.png",
    sees: "Spinner con el copy del alta. Es un caso PROPIO y no un `.checking` con otro texto: son dos hechos distintos.",
    persists: "Nada aún — el claim está en vuelo.",
    exits: "SIN back: el claim puede CREAR la cuenta server-side y salir a mitad dejaría al usuario sin saber si se dio de alta.",
    code: [
      { t: "CloudWelcomeSignInFlow.swift:20-23 `.creating`", d: "por qué es un caso propio" },
      { t: "WelcomeCloudSignInView.swift:159-160", d: "`.creating` NO permite back" }
    ],
    notes: []
  },

  "alta-claim": {
    title: "Decisión · claim born-cloud",
    shot: null,
    sees: "Nada (sigue el spinner de `.creating`).",
    persists: "SOLO con `created`: faro (`writeCloudAccountLinked`) → estampado (`CloudClaimActionStore.record`) → verificación del consent → métrica `cloudRegistrationCompletedIfFirst`. Ese ORDEN es el contrato y lo pinnea un source-scan.",
    exits: "El claim es IDEMPOTENTE por contrato (§f.1: el re-claim del mismo device colapsa a `created`) ⇒ reintentar es seguro. Matar la app aquí deja, como mucho, una cuenta reservada sin par de storage: el re-intento cae en `existing_stable` y encamina al returning-user.",
    code: [
      { t: "BornCloudSignUpService.swift:169 `signUp`", d: "el encadenado completo" },
      { t: "BornCloudSignUpService.swift:180-181", d: "`migration: false` EXPLÍCITO — `true` armaría una máquina de migración que aquí no existe" },
      { t: "AccountClaimDecision.swift:71 `decide`", d: "la tabla: 3 estados × 3 ramas" },
      { t: "CloudWelcomeSignInFlow.swift:120 `BornCloudSignUpFlow.step`", d: "traduce los 7 outcomes a 4 pasos de pantalla" },
      { t: "BornCloudSignUpService.swift:221-224", d: "el faro se escribe SOLO en `created` (con `existing_stable` pisaría el `linkedAt` y el provider del device que la creó)" }
    ],
    notes: [
      "⚠︎ MEDIDO: la variante B (`showProviderMismatch`) es `returningUser`-ONLY (AccountClaimDecision.swift:83) ⇒ desde `.bornCloud` es HOY INALCANZABLE con cualquier combinación del faro. El consumidor la mapea igual porque la tabla que decide vive en `AccountClaimDecision`.",
      "`proceedMigration` desde born-cloud también es inalcanzable; si apareciera, la respuesta es NO seguir (`transient`) + breadcrumb `unexpectedAction`."
    ]
  },

  "alta-par-relaunch": {
    title: "Par `.cloud` + «Cierra y vuelve a abrir Yala»",
    shot: "alta-par-relaunch.png",
    sees: "Pantalla TERMINAL con el icono de recarga: «Cierra Yala y vuelve a abrirla». Sin botones, sin back, sin dismiss interactivo.",
    persists: "`cloudSync.storageMode = cloud` Y `cloudSync.migration.relaunchRequested = true`, escritas por `StorageModePersistence.writeCloudArmed` (escritor ÚNICO del par). El journal se queda en `notStarted`.",
    exits: "NUNCA auto-kill: iOS trata la auto-muerte como un crash y App Review la rechaza. La app se queda usable en esta pantalla hasta que el usuario la cierre.",
    code: [
      { t: "BornCloudSignUpService.swift:301 `activateBornCloudStorage`", d: "escribe el par y DEVUELVE la fase terminal" },
      { t: "CloudSyncFlags.swift:91 `writeCloudArmed`", d: "modo → armado, en ese orden; el docblock explica por qué el born-cloud puede saltarse el gate del marcador" },
      { t: "WelcomeCloudSignInView.swift:414 `relaunchContent`", d: "la pantalla" },
      { t: "MigrationBootDecision.swift:80 `isPersonalMountMismatch`", d: "en esta ventana el motor NO arranca: el par dice `.cloud` y este proceso montó `.icloud`" }
    ],
    notes: [
      "El par NO se puede hacer atómico (`UserDefaults` no tiene transacción) ni invertir (la mitad `armado + .icloud` pintaría `needsRelaunch(.toCloud)` en bucle). El invariante se enforcea en el CONSUMIDOR: `MigrationRuntimeGate.canRun`.",
      "El born-cloud se salta el gate del marcador porque no hay corpus en CloudKit del que nadie pueda divergir — mismo razonamiento que `ICloudChannelVerdict.noChannelNoFootprint`."
    ]
  },

  "alta-postrelaunch": {
    title: "Post-relanzamiento · onboarding normal en modo nube",
    shot: "alta-postrelaunch.png",
    sees: "El `OnboardingView` de siempre. Como `hasShownWelcomeChooser` ya es `true`, se va directo ahí sin volver a pasar por el Welcome.",
    persists: "Lo que escriba el onboarding. El store personal ya monta SIN mirror de CloudKit y el motor de sync arranca solo (fase `notStarted` = estable + el estampado del claim).",
    exits: "N/A — es el estado normal.",
    code: [
      { t: "WelcomeCloudSignInView.swift:538-541", d: "el alta NO marca los flags de onboarding: el onboarding es justamente lo que corre después" },
      { t: "MigrationBootDecision.swift:84 `isDomainStablePhase`", d: "`notStarted` y `done` son las dos fases estables" },
      { t: "OnboardingGroupsPurposeGateLogic.swift:97 `shouldShowGroupsCard`", d: "en `.cloud` la card «Solo grupos» NO se pinta (A6)" }
    ],
    notes: []
  },

  "alta-returning": {
    title: "`existing_stable` → continuar como returning-user",
    shot: null,
    sees: "La pantalla cambia a `.checking` y sigue por el flujo de re-entrada, CON LA SESIÓN VIVA (no se vuelve a firmar).",
    persists: "Nada propio: a partir de aquí manda el flujo 2.",
    exits: "Ver flujo 2.",
    code: [
      { t: "WelcomeCloudSignInView.swift:553-557", d: "variante A de §f.1: sobre una cuenta poblada JAMÁS se siembra" },
      { t: "WelcomeCloudSignInView.swift:19-28", d: "por qué es una vista PARAMETRIZADA y no una hermana: una hermana sería un segundo anchor presentando (el bug del sign-out del 2026-07-14)" }
    ],
    notes: []
  },

  "alta-waitingleader": {
    title: "`claiming_in_progress` → esperar al líder",
    shot: "alta-waitingleader.png",
    sees: "«Otro dispositivo está migrando» + botón Reintentar + «Continuar a la app».",
    persists: "Nada.",
    exits: "En el ALTA, Reintentar re-lanza el CLAIM (idempotente), no un poll de máquina: born-cloud no tiene máquina que pollear y llamar a `pollLeader()` dejaría la pantalla clavada.",
    code: [
      { t: "WelcomeCloudSignInView.swift:388 `waitingLeaderContent`", d: "la pantalla" },
      { t: "WelcomeCloudSignInView.swift:399-402", d: "la bifurcación del Reintentar por entrada" }
    ],
    notes: []
  },

  "alta-error-401": {
    title: "401 · sesión no viva",
    shot: "alta-error-401.png",
    sees: "Error con botón Reintentar.",
    persists: "Se SUELTA la sesión antes de mostrar el error.",
    exits: "Si no se soltara, el re-tap reusaría la sesión muerta (`runSignInFlow` salta el sign-in cuando `hasSession`) y el usuario quedaría en un bucle de reintentos imposibles.",
    code: [
      { t: "CloudWelcomeSignInFlow.swift:113-117 `.releaseSessionAndShowError`", d: "el porqué, escrito en la tabla" },
      { t: "WelcomeCloudSignInView.swift:560-563", d: "signOut → `.error(retryable: true)`" }
    ],
    notes: []
  },

  "alta-error-403": {
    title: "403 · cuenta no disponible",
    shot: "alta-error-403.png",
    sees: "Error SIN botón de reintentar.",
    persists: "Nada.",
    exits: "Reintentar no despierta una cuenta suspendida — por eso el retry no se ofrece.",
    code: [{ t: "CloudWelcomeSignInFlow.swift:136-137", d: "`accountUnavailable` → `.error(retryable: false)`" }],
    notes: []
  },

  "alta-error-transient": {
    title: "Red / 5xx · transitorio",
    shot: "alta-error-transient.png",
    sees: "Error con botón Reintentar.",
    persists: "Nada.",
    exits: "El retry re-ejecuta `runFlowAfterConsent()` — el consent ya está aceptado, así que reentra por el sign-in (que se salta con sesión viva) y re-claima.",
    code: [{ t: "CloudWelcomeSignInFlow.swift:138-141", d: "el claim es idempotente ⇒ reintentar es seguro" }],
    notes: []
  },

  "alta-cancel": {
    title: "Matriz de cancelación (TRES filas)",
    shot: null,
    sees: "N/A — es la respuesta a «¿qué queda si me echo atrás?».",
    persists: "Depende de dónde se corte, y por eso son tres filas y no una promesa.",
    exits: "FILA 1 · antes de aceptar el consent: nada persistido (el device queda como estaba). FILA 2 · consent aceptado y cortado antes del `created`: quedan `cloudConsentAcceptedAt` + `cloudConsentTextVersion` (registro append-only, por precedente del repo NINGÚN camino los borra) y, si hubo sign-in, la sesión Yala. FILA 3 · tras un `created`: además el faro (4 keys en iCloud-KV) y el estampado del claim ⇒ el estado es RE-ENTRANTE, no virgen: el siguiente intento cae en `existing_stable` y encamina al returning-user.",
    code: [
      { t: "CloudConsentView.swift:103-110", d: "el consent se persiste al ACEPTAR" },
      { t: "BornCloudSignUpService.swift:221-235", d: "faro + estampado, solo con `created`" },
      { t: "AccountClaimDecision.swift:80-81", d: "`existing_stable` → `routeReturningUser`, NUNCA sembrar" }
    ],
    notes: ["⚠︎ Esto CORRIGE el criterio de hecho de A5 en el spec («cancelar deja el device exactamente como estaba: ni par, ni faro, ni consent»). Es la anotación 3 del punto de control, y aquí queda dibujada."]
  },

  // ══════════════════════════════════════════════════════════════════════════
  // FLUJO 2 · Returning-user / re-entrada
  // ══════════════════════════════════════════════════════════════════════════

  "reentry-chooser": {
    title: "Sub-chooser «Ya tengo una cuenta»",
    shot: "reentry-chooser.png",
    sees: "Hasta tres cards: Restaurar de iCloud · Entrar con Apple · Entrar con Google. Con una sola visible (producción DARK de hoy) hace bypass a Restaurar.",
    persists: "`hasShownWelcomeChooser = true` en el callback.",
    exits: "Back → chooser.",
    code: [
      { t: "WelcomeAccountChoiceLogic.swift:60 `visibleExistingOptions`", d: "las cards de nube exigen configurado ∧ ¬uitest ∧ kill-switch nube" },
      { t: "WelcomeFlowContainer.swift:180 `handleExistingBranch`", d: "bypass con una sola opción" },
      { t: "ContentView.swift:1287-1303", d: "el provider se setea EXPLÍCITO por card — jamás se hereda el del intento anterior" }
    ],
    notes: ["Residual ratificado por el owner: un usuario nube que REINSTALA bajo el kill-switch no ve la card ⇒ no re-entra hasta el re-encendido (WelcomeAccountChoiceLogic.swift:57-59)."]
  },

  "reentry-intro": {
    title: "Intro de re-entrada",
    shot: "reentry-intro.png",
    sees: "Un solo botón, el del método que trae el `Entry` (o el que dictó el faro), más la nota §13.",
    persists: "Nada.",
    exits: "Back permitido.",
    code: [{ t: "WelcomeCloudSignInView.swift:279 `reentryIntro`", d: "el botón por provider y el subtítulo específico de Google" }],
    notes: []
  },

  "reentry-exists": {
    title: "Decisión · `GET /account/exists` (read-only)",
    shot: null,
    sees: "Spinner «Comprobando…» (`.checking`).",
    persists: "Nada — es read-only A PROPÓSITO: un claim con `created` CREARÍA la cuenta, por eso JAMÁS se claimea sin `exists == true` previo.",
    exits: "`sessionExpired` y `transient` colapsan a `failed(retryable: true)`.",
    code: [
      { t: "CloudWelcomeSignInFlow.swift:58 `route`", d: "4 outcomes → 3 rutas" },
      { t: "WelcomeCloudSignInView.swift:579-582", d: "`CloudAccountClient` SIN attest a propósito: `/account/exists` va por `requireUser` y es PRE-SESIÓN" }
    ],
    notes: []
  },

  "reentry-mismatch": {
    title: "Guard R9 · «firmaste con el método equivocado»",
    shot: "reentry-mismatch.png",
    sees: "«Parece que tu cuenta se creó con Apple/Google» (o el copy genérico si el provider no se reconoce).",
    persists: "Se suelta la sesión SIEMPRE en esta rama (nunca dejar un `sub` huérfano vivo). NO hay claim ⇒ nada server-side.",
    exits: "Back permitido: nada está comprometido.",
    code: [
      { t: "ProviderMismatchLogic.swift:45 `decide`", d: "las 5 reglas EN ORDEN, sub-first" },
      { t: "WelcomeCloudSignInView.swift:586-604", d: "el cableado: faro → veredicto → signOut → fase" },
      { t: "ProviderMismatchLogic.swift:74 `displayName`", d: "desconocido → nil ⇒ copy genérico; jamás interpolar un rawValue del wire" }
    ],
    notes: ["La señal PRIMARIA es el SUB, no el provider: GoTrue LINKEA identidades con el mismo email verificado al MISMO `sub`, así que un sign-in Google puede aterrizar legítimamente en una cuenta creada con Apple (hallazgo H4 del wire)."]
  },

  "reentry-notfound": {
    title: "Sin cuenta para este Apple ID",
    shot: "reentry-notfound.png",
    sees: "«No encontramos una cuenta».",
    persists: "Sesión soltada.",
    exits: "Back permitido.",
    code: [{ t: "WelcomeCloudSignInView.swift:602-603", d: "`.proceed` del guard R9 ⇒ `.notFound` honesto" }],
    notes: []
  },

  "reentry-guard": {
    title: "Decisión · guard cross-cuenta (F0-C / M1)",
    shot: null,
    sees: "Nada.",
    persists: "Nada.",
    exits: "Tres salidas: `proceed` (device limpio o misma cuenta) · `blockedForeignData` · `proceedSecondarySession` (M1, hoy DARK).",
    code: [
      { t: "CrossAccountEntryGuardLogic.swift:47 `decide`", d: "la tabla completa" },
      { t: "WelcomeCloudSignInView.swift:608-612", d: "el cableado; `hasLocalDataNow` es un fetch VIVO, no un snapshot (S5: el mirror puede estar re-importando durante el Welcome)" }
    ],
    notes: ["La MISMA cuenta re-entra libre: su claim persistido (`CloudClaimActionStore`, keyed por userID, sobrevive al sign-out a propósito) es la prueba de que el corpus local le pertenece."]
  },

  "reentry-blocked": {
    title: "Bloqueado · datos de otra identidad",
    shot: "reentry-blocked.png",
    sees: "«Estos datos son de otra cuenta» con el icono de escudo.",
    persists: "Sesión soltada antes de mostrar la pantalla.",
    exits: "Back permitido.",
    code: [{ t: "WelcomeCloudSignInView.swift:614-616", d: "signOut → `.blockedForeignData`" }],
    notes: ["El bloqueo existe porque el orphan-reconcile del adopt corre ANTES del relanzamiento y pushearía las filas del dueño a la cuenta entrante."]
  },

  "reentry-secondary": {
    title: "M1 · confirmación de sesión secundaria",
    shot: "reentry-secondary.png",
    sees: "«Entrarás con tu cuenta; los datos del dueño no se tocan» + CTA y Cancelar propio.",
    persists: "SOLO al confirmar, y EN ORDEN: claim → descriptor (`SecondarySessionStore.activate`) → flags de onboarding.",
    exits: "El Cancelar es PROPIO (suelta la sesión SIWA; el back genérico la dejaría colgada). Belt: si el modo persistido no es `.icloud`, hay estado corrupto ⇒ error, jamás armar.",
    code: [
      { t: "WelcomeCloudSignInView.swift:644 `confirmSecondaryEntry`", d: "el orden y su kill-safety" },
      { t: "WelcomeCloudSignInView.swift:617-626", d: "el belt del modo persistido" },
      { t: "CloudSyncFlags.swift:255 `secondarySessionEntryAvailable`", d: "el gate de ENTRADA (DARK hoy)" }
    ],
    notes: ["DARK: la entrada exige el flag M1, que en producción es `false`. El mount y el wipe honran el descriptor incondicionalmente para que una secundaria YA activa no quede brickeada si el flag se apagara."]
  },

  "reentry-adopt": {
    title: "Adopt en curso (máquina de migración)",
    shot: "reentry-adopt.png",
    sees: "Barra de progreso + «Conectando…». Si la pre-espera de quiescencia está activa aparece además el hint honesto de import.",
    persists: "Los flags de onboarding se marcan TEMPRANO (antes de conducir la máquina): un kill a mitad aterriza en MainTab con la card de Almacenamiento reflejando el estado real, y el seed del onboarding JAMÁS corre sobre una cuenta existente.",
    exits: "SIN back. Sin red, el drive corta retomable y el auto-resume entra.",
    code: [
      { t: "WelcomeCloudSignInView.swift:627-636", d: "`onAdoptStarted` → `startAdoptWithExistingSession` → poll" },
      { t: "CloudWelcomeSignInFlow.swift:70 `phase(for:)`", d: "mapea los 8 casos de `CloudMigrationUIState` a fase de pantalla; `reverting` y `needsRelaunch(.toICloud)` son IMPOSIBLES aquí y degradan a error no-retryable" },
      { t: "ContentView.swift:1358-1365", d: "`completeOnboardingAsRestoreSkip()` + `hasCompletedOnboarding`" }
    ],
    notes: []
  },

  "reentry-autoresume": {
    title: "Detector de adopt APARCADO (auto-resume)",
    shot: "reentry-autoresume.png",
    sees: "Nada hasta agotar los intentos; entonces aparece el botón «Reintentar» manual.",
    persists: "Nada. Breadcrumbs `welcomeAdoptAutoResume` / `welcomeAdoptAutoResumeExhausted`.",
    exits: "4 ticks ociosos (~4 s) → auto-resume; 3 autos sin avance → botón manual. Un avance REAL de la máquina repone intentos frescos.",
    code: [
      { t: "CloudWelcomeSignInFlow.swift:158 `WelcomeAdoptAutoResume`", d: "la tabla del tick" },
      { t: "WelcomeCloudSignInView.swift:694 `evaluateAutoResume`", d: "el cableado + el belt: jamás conducir con el wipe de sign-out armado" },
      { t: "WelcomeCloudSignInView.swift:725 `retryAdoptResume`", d: "con el journal normalizado a `notStarted` sin efectos, `resumeIfNeeded` sería un no-op perpetuo ⇒ re-arranca el adopt" }
    ],
    notes: ["Existe porque `startAdoptWithExistingSession()` RETORNA cuando el drive corta retomable y el poll solo OBSERVABA: sin botón y con el re-kick disparando solo al volver a foreground, la pantalla quedaba clavada en «Conectando…» (H-2026-07-17-5)."]
  },

  "reentry-relaunch": {
    title: "Adopt completo · «Cierra y reabre Yala»",
    shot: "reentry-relaunch.png",
    sees: "Terminal, misma pantalla que el alta.",
    persists: "El par `.cloud` + armado lo escribió `runAdoptFlow`; el journal queda `notStarted` (device ADOPTADO, #30).",
    exits: "NUNCA auto-kill.",
    code: [
      { t: "CloudWelcomeSignInFlow.swift:77-81", d: "`needsRelaunch(.toCloud)` y `cloudActive` mapean los dos a `.relaunch`" }
    ],
    notes: []
  },

  // ══════════════════════════════════════════════════════════════════════════
  // FLUJO 3 · Migración iCloud → nube
  // ══════════════════════════════════════════════════════════════════════════

  "migracion-fila": {
    title: "Ajustes · fila «Dónde viven tus datos»",
    shot: "migracion-fila.png",
    sees: "Fila en Perfil con subtítulo dinámico según el modo real.",
    persists: "Nada.",
    exits: "Con el kill-switch remoto OFF la fila DESAPARECE… salvo para un usuario «engaged».",
    code: [
      { t: "StorageRowGateLogic.swift:26 `isVisible`", d: "configurado ∧ ¬secundaria ∧ (remoto ∨ engaged)" },
      { t: "ProfileView.swift:930", d: "el cableado" },
      { t: "ProfileView.swift:225-229 `dataLocationSubtitle`", d: "el subtítulo por modo" }
    ],
    notes: ["Decisión owner: el kill-switch corta la ENTRADA, no la SALIDA — quien ya está en `.cloud` o con una migración en vuelo/fallida conserva la fila SIEMPRE: es su panel de gestión, resume y REVERSA."]
  },

  "migracion-idle": {
    title: "Almacenamiento · estado iCloud (idle)",
    shot: "migracion-idle.png",
    sees: "Card de estado (candado + «tus datos viven en tu iCloud») y card de migrar con «Ver qué se migraría».",
    persists: "El dry-run NO escribe nada (es una simulación en memoria).",
    exits: "Salir de la pantalla no deja nada a medias.",
    code: [
      { t: "StorageSettingsView.swift:134-152", d: "el switch por `uiState`" },
      { t: "StorageSettingsView.swift:210-227", d: "el preview del dry-run (solo en migración, no en adopt)" },
      { t: "MigrationStateMachine.swift:45", d: "`dryRun` escribe NADA y no es progreso durable" }
    ],
    notes: []
  },

  "migracion-adopt-copy": {
    title: "Variante ADOPT (marcador de un líder en el mirror)",
    shot: "migracion-adopt-copy.png",
    sees: "El mismo sitio, con el copy de ADOPTAR en vez de MIGRAR: evita el falso «migrar» sobre una cuenta ya poblada.",
    persists: "Nada.",
    exits: "El adopt NO lleva doble confirmación destructiva (no mueve datos): del consent va directo al paso de auth.",
    code: [
      { t: "StorageSettingsView.swift:181", d: "`markerDecision() == .secondaryDeviceCloudLogin` elige el copy" },
      { t: "StorageSettingsView.swift:479-483", d: "`.adopt` salta las confirmaciones" }
    ],
    notes: []
  },

  "migracion-signin-decision": {
    title: "Decisión · paso de auth (C-7)",
    shot: null,
    sees: "Antes del tap, la card ya AVISA cuál será el comportamiento: nota de reuso de cuenta, o nota de cuenta ajena con el botón deshabilitado.",
    persists: "Nada.",
    exits: "Tres salidas: `reuseLiveSession` (no se pregunta el método) · `askProvider` (chooser Apple|Google) · `blockedOtherAccount` (botón deshabilitado).",
    code: [
      { t: "StorageMigrationSignInLogic.swift", d: "la tabla (14 tests)" },
      { t: "StorageSettingsView.swift:545 `signInDecision`", d: "se re-evalúa en cada lectura — jamás se cachea en `@State`" },
      { t: "StorageSettingsView.swift:500 `proceedToSignInStep`", d: "el dispatch" }
    ],
    notes: ["Con sesión viva NO se pregunta el método, y se dice ANTES para que saltarse el chooser no sea una sorpresa (cumple la promesa de `groups.signin.accountNote`)."]
  },

  "migracion-confirm": {
    title: "Doble confirmación destructiva",
    shot: "migracion-confirm.png",
    sees: "Dos `confirmationDialog` encadenados, ambos con el botón en rojo.",
    persists: "Nada hasta el segundo Confirmar.",
    exits: "Cancelar en cualquiera corta limpio.",
    code: [
      { t: "StorageSettingsView.swift:586-599", d: "los dos diálogos de migración" },
      { t: "StorageSettingsView.swift:476 `onConsentDismissed`", d: "el enrutado ocurre en el `onDismiss` del consent, no en su callback: presentar desde el callback sería sheet-sobre-sheet en el mismo anchor" }
    ],
    notes: ["El `case .bornCloud` de `onConsentDismissed` es INALCANZABLE desde Almacenamiento y hace `break` a propósito: el alta vive entera en el Welcome. Si algún día esta pantalla ofreciera el alta, el compilador NO avisaría, y este `break` deja el camino muerto en vez de disparar una doble confirmación de migración sobre un flujo que no migra nada."]
  },

  "migracion-progreso": {
    title: "Migración en curso (fases journaleadas)",
    shot: "migracion-progreso.png",
    sees: "Barra + «Migrando…» + botón «Retomar». Dos captions honestos cuando aplican: esperando al import y esperando la confirmación de iCloud.",
    persists: "Cada fase se JOURNALEA (`MigrationState`). Las fases: consent → authenticating → claimingMigration → assigningIdentity → uploadingSnapshot → verifying → cutover(4 sub-estados) → done.",
    exits: "Matar la app aquí es SEGURO: el boot retoma (`MigrationBootDecision.decide` → `.resume`) y el foreground re-kickea. La pantalla además empuja cada 30 s para que el tope del paso 4 llegue a evaluarse aunque el usuario se quede mirando.",
    code: [
      { t: "MigrationStateMachine.swift:42 `MigrationPhase`", d: "las 21 fases journaleadas" },
      { t: "CloudMigrationController.swift:111 `fraction(for:)`", d: "la fracción por fase" },
      { t: "MigrationBootDecision.swift:117 `decide`", d: "resume / pollLeader / none" },
      { t: "MigrationBootDecision.swift:144 `shouldRekick`", d: "reusa la misma tabla en foreground" },
      { t: "StorageSettingsView.swift:82-96", d: "el tick de 1 s y el empujón cada 30" }
    ],
    notes: ["El caption del paso 4 existe porque antes era una barra clavada al 89 % SIN una palabra: el usuario no podía saber si seguía trabajando o estaba colgada."]
  },

  "migracion-cutover": {
    title: "Cutover · 4 sub-estados en orden estricto",
    shot: "migracion-cutover.png",
    sees: "Sigue la barra; el 89 % es `markerWritten` esperando a iCloud.",
    persists: "pending → serverConfirmed (`profiles.migrated_at`) → localModeSet (`storageMode = .cloud`) → markerWritten (`CloudMigrationMarker`) → mirrorOff (par armado).",
    exits: "El cutover NO es una caja atómica: son ≥4 escrituras cross-sistema en orden estricto, con el marcador de CloudKit como ÚLTIMO efecto observable. Cada sub-estado es durable.",
    code: [
      { t: "MigrationStateMachine.swift:134 `CutoverSubstate`", d: "los sub-estados y por qué su rawValue codifica el orden" },
      { t: "ICloudCutoverGateLogic.swift:86 `decide`", d: "el veredicto del canal iCloud: 5 casos, FAIL-OPEN" },
      { t: "ICloudCutoverGateLogic.swift:50 `blocksCutoverEntry`", d: "qué veredictos abortan ANTES de tocar nada durable" }
    ],
    notes: ["iOS NO expone la cuota de iCloud: la única señal real de «lleno» es el `CKError.quotaExceeded` POST-HOC ⇒ el gate es necesario-no-suficiente y la autoridad final es el TOPE POR TIEMPO del paso 4."]
  },

  "migracion-relaunch": {
    title: "Card BLOQUEANTE de relanzamiento",
    shot: "migracion-relaunch.png",
    sees: "Card con el icono de recarga: «Cierra Yala y vuelve a abrirla».",
    persists: "El par ya está escrito; falta que el proceso muera para remontar el store sin mirror.",
    exits: "Relanzamiento ASISTIDO — nunca `exit()`.",
    code: [
      { t: "CloudMigrationController.swift:75-77", d: "`mirrorOffArmed && mountedMode == .icloud` ⇒ `needsRelaunch(.toCloud)`, y mira el armado SIN mirar el modo (por eso invertir el orden del par daría un bucle)" },
      { t: "StorageSettingsView.swift:363 `relaunchCard`", d: "la card" }
    ],
    notes: []
  },

  "migracion-fallo": {
    title: "Fallo → rollback, con el copy por MOTIVO",
    shot: "migracion-fallo.png",
    sees: "Cuatro mensajes distintos según el veredicto journaleado: iCloud lleno · iCloud no activo · no confirmó el último paso · genérico.",
    persists: "El veredicto del canal sobrevive en el journal a `failedRollback` justo para esto.",
    exits: "«Reintentar» → `resetAfterRollback`, que DRENA los efectos pendientes antes de limpiar el journal.",
    code: [
      { t: "StorageSettingsView.swift:421 `failureMessage`", d: "los 4 copys" },
      { t: "MigrationBootDecision.swift:122", d: "los terminales de FALLO NO auto-resumen: es decisión del usuario" }
    ],
    notes: ["«No pudimos» sin decir por qué deja al usuario sin ninguna acción posible; con «iCloud lleno» la acción (liberar espacio) es concreta."]
  },

  "migracion-cloudactive": {
    title: "Modo nube activo",
    shot: "migracion-cloudactive.png",
    sees: "Card de estado en nube + sección de sync + card de volver a iCloud.",
    persists: "N/A.",
    exits: "Ver flujo 4.",
    code: [{ t: "StorageSettingsView.swift:138-141", d: "`.cloudActive` pinta las tres cards" }],
    notes: []
  },

  // ══════════════════════════════════════════════════════════════════════════
  // FLUJO 4 · Reversa nube → iCloud
  // ══════════════════════════════════════════════════════════════════════════

  "reversa-card": {
    title: "Card «Volver a iCloud»",
    shot: "reversa-card.png",
    sees: "Título, cuerpo, la nota del desenlace del enlace privado↔nube y, si es elegible, el botón; si no, el texto de no-elegible.",
    persists: "Nada.",
    exits: "Gate `reverseEligibility()` antes de ofrecer el botón.",
    code: [{ t: "StorageSettingsView.swift:247 `revertCard`", d: "elegibilidad → botón o texto" }],
    notes: []
  },

  "reversa-confirm": {
    title: "Doble confirmación de reversa",
    shot: "reversa-confirm.png",
    sees: "Dos diálogos destructivos.",
    persists: "`reverseConfirm` es NO durable; su `ReverseOrigin` recuerda a dónde vuelve un decline: `.done` (líder original) o `.notStarted` (device que ADOPTÓ).",
    exits: "Sin el origen, un decline desde `done` resetearía el journal a `notStarted` y la reconciliación de marcador dispararía un `secondaryDeviceCloudLogin` FALSO.",
    code: [
      { t: "MigrationStateMachine.swift:81 `reverseConfirm(ReverseOrigin)`", d: "el porqué del origen" },
      { t: "StorageSettingsView.swift:600-613", d: "los dos diálogos" }
    ],
    notes: []
  },

  "reversa-fases": {
    title: "Fases de la reversa",
    shot: "reversa-fases.png",
    sees: "La misma card de progreso con el copy «Revirtiendo…».",
    persists: "reverseClaimLeader → reverseDrainAll → reverseVerify → reverseFreezeBackend → reverseMountMirror → reverseReconcile(4 sub-estados) → reverseUpload → icloudActive. Todas durables salvo `reverseConfirm`.",
    exits: "La premisa de orden está REORDENADA a propósito (§h.1): el mirror se monta ANTES de borrar nada. La frontera del rollback es el montaje del mirror — fallos PRE-mount revierten (local intacto, modo sigue `.cloud`); fallos POST-mount SOSTIENEN y reintentan idempotente.",
    code: [
      { t: "MigrationStateMachine.swift:70-103", d: "las fases de reversa con su premisa de orden" },
      { t: "MigrationStateMachine.swift:117 `ReverseReconcileSubstate`", d: "awaitingQuiescence → deletingZombies → rebindingUUIDs → dedupHealed, `Comparable` para que el resume nunca regrese ni salte" },
      { t: "CloudMigrationController.swift:90-92", d: "las 8 fases de reversa pintan `.reverting`" }
    ],
    notes: []
  },

  "reversa-relaunch": {
    title: "Relanzamiento de reversa (`toICloud`)",
    shot: "reversa-relaunch.png",
    sees: "La misma card bloqueante.",
    persists: "La máquina está en `reverseMountMirror` y este proceso montó `.cloud` ⇒ hay que reabrir para re-encender el mirror `.private`.",
    exits: "Resuelto por OBSERVACIÓN en el resume, nunca por re-ejecución ciega.",
    code: [{ t: "CloudMigrationController.swift:80-82", d: "la segunda regla del deriver" }],
    notes: []
  },

  "reversa-cierre": {
    title: "Cuarteto de cierre + terminal `icloudActive`",
    shot: "reversa-cierre.png",
    sees: "Vuelta a la pantalla de estado iCloud: se vuelve a ofrecer migrar.",
    persists: "`icloudActive` es terminal ESTABLE de reversa, y el deriver lo pinta como `.idle` justamente para volver a ofrecer la migración. El faro se limpia (las 4 keys) — dejarlo puesto haría que un 2º device firmara «cuenta nube activa» para un Apple ID que ya volvió a CloudKit.",
    exits: "`reverseFailedRollback` es el otro terminal estable: la reversa abortó PRE-mount y el device se queda en modo nube limpio (el mirror nunca se re-encendió).",
    code: [
      { t: "CloudMigrationController.swift:101-103", d: "`icloudActive` → `.idle`" },
      { t: "CloudBeacon.swift:76 `clearCloudAccountLinked`", d: "las 4 keys, simétrico a la escritura" }
    ],
    notes: ["⚠︎ RESIDUAL DOCUMENTADO VIVO (`.claude/rules/swiftdata-cloudkit.md`): el cuarteto de cierre de la reversa tiene el orden INVERSO al del abort del cutover y por eso conserva su bug-class — un terminal de fallo que no devuelve el modo a `.icloud` como PRIMER efecto es peor que el limbo que arregla. Ticket aparte."]
  },

  // ══════════════════════════════════════════════════════════════════════════
  // FLUJO 5 · Sign-out en `.cloud` + las tres borradas
  // ══════════════════════════════════════════════════════════════════════════

  "signout-path": {
    title: "Decisión · camino de sign-out (precedencia CONGELADA)",
    shot: null,
    sees: "Nada; decide qué filas se pintan y qué hoja de alcance sale.",
    persists: "Nada.",
    exits: "Precedencia: secundaria M1 → `.cloud` → solo-grupos (flag ∧ sesión) → privado.",
    code: [
      { t: "CloudSignOutFlowLogic.swift:51 `path`", d: "las 4 filas y su orden" },
      { t: "CloudSignOutFlowLogic.swift:104 `rowLayout`", d: "cuántas filas pinta Ajustes: none · plainSignOut · exitYalaOnly · groupsSignOutPlusExitYala" },
      { t: "ProfileView.swift:136 `signOutRowPath`", d: "lee la capacidad COMPILADA, igual que el coordinador — las dos lecturas TIENEN que moverse juntas" }
    ],
    notes: ["Si esta lectura se quedara compuesta y la del coordinador no, bajo un kill remoto la hoja resolvería `.signOutPrivate` (que pinta los grupos como preservados) mientras el dispatch arma el borrado del store de grupos: la hoja MENTIRÍA."]
  },

  "signout-hoja": {
    title: "Hoja de alcance destructiva (3 filas)",
    shot: "signout-hoja.png",
    sees: "Siempre TRES filas en orden 📱 dispositivo → ☁️ iCloud/cuenta → 👥 grupos, cada una con su tono (se borra / no se toca / cambia pero sobrevive), más las líneas condicionales y las acciones secundarias seguras.",
    persists: "Nada: es capa de presentación pura.",
    exits: "Las acciones secundarias existen para desviar de la destrucción: «Ver mis grupos» · «Exportar antes» · «También salir de mis grupos».",
    code: [
      { t: "DestructiveScopeLogic.swift:115 `model`", d: "las 11 operaciones y sus filas/tonos/líneas/secundarias" },
      { t: "DestructiveScopeLogic.swift:96 `cloudLabel`", d: "la etiqueta ☁️ por modo — mata de raíz el copy que caduca" },
      { t: "ProfileView.swift:118 `signOutScopeOperation`", d: "qué operación resuelve cada contexto" }
    ],
    notes: []
  },

  "signout-pushall": {
    title: "Push-all previo al cierre (jamás descartar)",
    shot: "signout-pushall.png",
    sees: "Spinner en la fila y, si el bloqueo es transitorio, el caption honesto «Guardando tus cambios pendientes…».",
    persists: "Nada se descarta NUNCA: si el outbox no vacía, el cierre se ABORTA.",
    exits: "Veredicto: `drained` (outbox vivo == 0 VERIFICADO por fetch) o `blocked(pendingCount:reason:)`. Transitorio → retry interno con presupuesto de 45 s cada 2 s; permanente (401/403) → error inmediato sin reintentar.",
    code: [
      { t: "CloudSignOutFlowLogic.swift:154 `pushAllVerdict`", d: "drained / blocked / seguir iterando" },
      { t: "CloudSignOutFlowLogic.swift:132 `classify`", d: "los 5 outcomes de cadencia → transitorio o permanente" },
      { t: "CloudSignOutFlowLogic.swift:193 `GroupsSignOutRetryDecision.decide`", d: "el retry interno" },
      { t: "CloudSessionSignOut.swift:31 `Phase`", d: "idle · working · blocked · awaitingRelaunch" }
    ],
    notes: ["El retry interno existe porque el device-QA mostró que el bloqueo típico es TRANSITORIO (writes internos del boot asentándose) y el usuario tenía que tocar «Cerrar sesión» 2-3 veces."]
  },

  "signout-relaunch": {
    title: "Cover terminal de cierre + wipe al boot",
    shot: "signout-relaunch.png",
    sees: "Cover bloqueante «cierra y reabre».",
    persists: "`signOutWipeArmed`. El borrado real es de ARCHIVOS y corre en el BOOT pre-mount.",
    exits: "En `.cloud` NUNCA se borran FILAS en sesión: los deletes de filas quedan en la History y el remount con mirror los REPLAYARÍA hacia iCloud. El desarmado es SIEMPRE el último paso del boot-cleanup (un kill a mitad re-entra idempotente).",
    code: [
      { t: "CloudSignOutFlowLogic.swift:9-12", d: "el invariante F0, escrito en la cabecera" },
      { t: "CloudSyncFlags.swift:107-126", d: "armar / leer / desarmar el wipe" },
      { t: "ContentView.swift:1419 `SignOutRelaunchNetModifier`", d: "DUEÑO ÚNICO del cover; la presentación EFECTIVA solo la prueba el `onAppear` del contenido real" }
    ],
    notes: ["ProfileView ya NO presenta este cover: dos anchors ante el mismo observable eran una carrera de reconciliación que tumbaba AMBAS cadenas dejando el flag en `true` sin que ningún `onDismiss` corriera (bug de device del 2026-07-14)."]
  },

  "signout-exityala": {
    title: "Fila «Salir de Yala en este dispositivo»",
    shot: "signout-exityala.png",
    sees: "Fila propia, mutuamente excluyente con «Cerrar sesión» salvo en el split D2, donde se pintan las DOS.",
    persists: "Fuerza `.privateReset`: vuelve al Welcome sin tocar datos ni grupos.",
    exits: "Existe porque el solo-grupos legado (group-invite SIN sesión backend, vivo hoy) no tenía NINGUNA salida.",
    code: [
      { t: "CloudSignOutFlowLogic.swift:80 `shouldShowExitYalaRow`", d: "group-invite ∧ sin sesión" },
      { t: "CloudSignOutFlowLogic.swift:71 `shouldShowRow`", d: "«Cerrar sesión» siempre, salvo group-invite sin sesión" },
      { t: "ProfileView.swift:411", d: "el dispatch a `exitYalaOnThisDevice`" }
    ],
    notes: []
  },

  "signout-borrarcuenta": {
    title: "Eliminar mi cuenta (las líneas condicionales)",
    shot: "signout-borrarcuenta.png",
    sees: "Hoja de alcance con hasta 5 líneas EN ORDEN: base · aviso de deudas · desvío a «Vaciar mis datos» · copia iCloud congelada (solo `.cloud`) · huella legacy de CloudKit. Después, un segundo diálogo irreversible.",
    persists: "El resumen de grupos se recalcula al tocar la fila y viaja COMO ITEM de la presentación.",
    exits: "El aviso de deudas INFORMA y JAMÁS bloquea (línea roja GDPR). Con deuda, «Ver mis grupos» va PRIMERO en las secundarias: protege a terceros.",
    code: [
      { t: "AccountDeletionDebtLogic.swift:89 `lines`", d: "las 5 líneas y su orden" },
      { t: "AccountDeletionDebtLogic.swift:55 `groupsWithOutstandingBalance`", d: "epsilon 0.01, uno por moneda" },
      { t: "ProfileView.swift:196-205", d: "por qué el resumen va como ITEM: medido el 2026-08-03, calcularlo y encender `isPresented` en el MISMO tap armaba el contenido con el valor ANTERIOR y la rama de deudas NO se presentaba NUNCA" }
    ],
    notes: ["La huella legacy solo se muestra si el device la tiene: `groups_forget_user` anonimiza SOLO el backend, no las zonas CloudKit ⇒ un born-backend sin pasado CloudKit no ve ese caveat (evita un aviso falso)."]
  },

  "signout-vaciar": {
    title: "Vaciar mis datos",
    shot: "signout-vaciar.png",
    sees: "Hoja con 📱 y ☁️ destructivos y 👥 preservado, más el residual multi-device declarado EN COPY cuando el modo es nube.",
    persists: "N/A (lo ejecuta `DataWipeService`).",
    exits: "«Exportar antes» SIEMPRE en el vaciado completo (red de seguridad §m.4).",
    code: [
      { t: "DestructiveScopeLogic.swift:109 `wipeOperation`", d: "`isGroupInviteMode` es el ÚNICO discriminante" },
      { t: "DestructiveScopeLogic.swift:123-140", d: "las filas y las secundarias del vaciado completo" }
    ],
    notes: ["Una sesión backend viva NUNCA baja el alcance a «solo grupos»: la presencia de vida personal la determina el ONBOARDING, no la sesión — por eso la sesión ni se recibe como parámetro."]
  },

  // ══════════════════════════════════════════════════════════════════════════
  // FLUJO 6 · Onboarding de propósito + alta solo-grupos
  // ══════════════════════════════════════════════════════════════════════════

  "onboarding-purpose": {
    title: "Paso «Propósito» · qué cards existen",
    shot: "onboarding-purpose.png",
    sees: "Dos o tres cards: «Llevar el control» · «Solo anotar gastos» · «Dividir gastos con amigos» (esta última solo en `.icloud` y solo en el flujo inicial).",
    persists: "`selectedUsageMode` en memoria hasta completar.",
    exits: "Volver atrás desde «Cuentas» re-entra aquí, y por eso `.dayToDay` es alcanzable en este paso.",
    code: [
      { t: "OnboardingGroupsPurposeGateLogic.swift:97 `shouldShowGroupsCard`", d: "flujo inicial ∧ modo `.icloud`" },
      { t: "OnboardingPurposeSelectionLogic.swift:62 `selectedCard`", d: "SSOT total-y-única: los 4 modos → 3 cards" },
      { t: "OnboardingView.swift:513-540", d: "el cableado de las dos decisiones" }
    ],
    notes: ["A6: en `.cloud` la card NO se pinta (elegir nube para lo personal + «solo quiero Grupos» es contradictorio: el modo solo-grupos no usa el store personal y dejaría VACÍO el backend recién estrenado). Se OCULTA y no se deshabilita con copy: un botón que solo sirve para explicar por qué no sirve es peor que su ausencia."]
  },

  "onboarding-muro": {
    title: "Muro iCloud del selector (canal de Grupos OFF)",
    shot: "onboarding-muro.png",
    sees: "Alert «necesitas iCloud» al tocar la card de grupos.",
    persists: "Nada: el tap no cambia el modo.",
    exits: "Con el canal backend ON el muro se RETIRA ENTERO — y además su copy («los grupos se sincronizan por iCloud») MENTIRÍA.",
    code: [
      { t: "OnboardingGroupsPurposeGateLogic.swift:56 `shouldBlockSelection`", d: "canal ON ⇒ nunca bloquea; canal OFF ⇒ bloquea sin cuenta iCloud" },
      { t: "OnboardingView.swift:530-538", d: "el cableado" }
    ],
    notes: ["Sin parámetro `isUITest` a propósito: bajo `-uitest` el canal está SIEMPRE ON, así que ningún XCUITest puede alcanzar la rama del muro."]
  },

  "onboarding-groupsonly": {
    title: "Cierre en modo «Solo grupos»",
    shot: "onboarding-groupsonly.png",
    sees: "Aterriza directamente en el tab Grupos (con `.groupInvite` el tab bar se reduce).",
    persists: "Nombre, divisa y período · `onboardingMode = groupInvite` (dual-write al KV) · `groupsBetaUnlocked` · semillas de categorías personales y de sistema · notificaciones. NO crea cuenta ni presupuesto.",
    exits: "N/A.",
    code: [
      { t: "OnboardingView.swift:1816 `completeGroupsOnlyOnboarding`", d: "todo lo que escribe" },
      { t: "OnboardingView.swift:1858-1862", d: "el aterrizaje en el tab Grupos" }
    ],
    notes: ["⚠︎ AGUJERO DE DATOS MEDIDO (§6.2 punto 4 del spec, confirmado en este árbol): `completeGroupsOnlyOnboarding` NO toca `storageMode` ⇒ el device queda `.icloud` y, sin cuenta iCloud del OS, el store monta local-sin-mirror. Las `TransactionItem` puenteadas desde los gastos de grupo no tienen NINGUNA copia. D-A7 le da salida a los usuarios NUEVOS (elegir nube en el alta); la cohorte que ya existe NO se cura sola — ticket aparte, §6.5."]
  },

  "onboarding-educativo": {
    title: "Educativo del tab Grupos + CTA de sign-in",
    shot: "onboarding-educativo.png",
    sees: "Sheet informativo; el último paso ofrece «Iniciar sesión» cuando el canal está ON y no hay sesión.",
    persists: "`hasShownGroupsOnboarding` solo si se completa (la «X» NO la persiste: volverá a aparecer).",
    exits: "El CTA NO es un muro: quien lo salte cae en el empty state, que ya pide sesión. El intent se emite con el sheet YA desmontado (`onDismiss`) — emitirlo con el sheet puesto lo dejaría RETENIDO por peek-first.",
    code: [
      { t: "GroupsOnboardingLogic.swift:30 `shouldShow`", d: "AND-gating: flag persistida, modo group-invite y deeplink pendiente bloquean" },
      { t: "GroupsOnboardingLogic.swift:60 `shouldShowSignInCTA`", d: "último paso ∧ canal ON ∧ sin sesión" },
      { t: "GroupsContainerView.swift:374", d: "el cableado" }
    ],
    notes: []
  },

  "onboarding-empty": {
    title: "Empty state del tab Grupos",
    shot: "onboarding-empty.png",
    sees: "«Aún no tienes grupos» (CTA crear) o «tus grupos están en tu cuenta» (CTA iniciar sesión).",
    persists: "Nada.",
    exits: "Con el canal OFF SIEMPRE es el estándar ⇒ el shipping DARK queda byte-idéntico.",
    code: [
      { t: "GroupsEmptyStateLogic.swift:29 `decide`", d: "flag ON ∧ sin sesión ⇒ re-entrada" },
      { t: "GroupsContainerView.swift:318", d: "el cableado, con la identidad de accesibilidad preservada por rama" }
    ],
    notes: ["Fuera de v1 y DOCUMENTADO: el caso «sin sesión + grupos CloudKit todavía visibles» no aplica aquí — el empty state solo se pinta con la lista VACÍA."]
  },

  "onboarding-crear": {
    title: "Crear grupo · sign-in contextual",
    shot: "onboarding-crear.png",
    sees: "El form de crear grupo, o antes el consent de grupos, o antes el sign-in.",
    persists: "Nada hasta guardar.",
    exits: "Residual DOCUMENTADO: no hay auto-continuación — tras el consent/sign-in el usuario re-tapea «crear grupo».",
    code: [
      { t: "GroupCreateRoutingLogic.swift:28 `route`", d: "flag OFF → CloudKit; sin sesión → sign-in; sin consent → consent; listo → backend" },
      { t: "GroupsContainerView.swift:623 `requestCreateGroup`", d: "cede el anchor a ContentView para presentar; el form es sheet de ESTE anchor" }
    ],
    notes: []
  },

  // ══════════════════════════════════════════════════════════════════════════
  // FLUJO 7 · Estados degradados (transversales)
  // ══════════════════════════════════════════════════════════════════════════

  "degradado-killswitch": {
    title: "Kill-switch remoto puesto",
    shot: "degradado-killswitch.png",
    sees: "Desaparecen: la card nube de «Soy nuevo», las cards de sign-in de «Ya tengo cuenta» y la fila de Almacenamiento (salvo usuario engaged).",
    persists: "El snapshot de remote-config; se refresca como MUCHO cada 6 h, y ausente ⇒ `false` en producción (fail-closed).",
    exits: "El Welcome y Almacenamiento fuerzan un `refreshIfDue()` al ENTRAR, porque un fresh install pre-onboarding puede no tener cache del boot.",
    code: [
      { t: "CloudRemoteConfig.swift:127-141", d: "`cloudModeEnabled` · `cloudOnboardingChoiceEnabled` · `groupsBackendEnabled` (el remoto solo puede MATAR)" },
      { t: "CloudRemoteConfig.swift:113 `absentDefault`", d: "fail-closed en producción" },
      { t: "StorageRowGateLogic.swift:26", d: "engaged conserva la fila" },
      { t: "WelcomeFlowContainer.swift:139-145", d: "el refresh en la entrada; bajo uitest NO se toca red" }
    ],
    notes: ["Con el kill puesto, el faro deja de encaminar (`cloudEntryAvailable` es false) ⇒ el residual del 2º device born-cloud vuelve a estar abierto. Está declarado, no escondido."]
  },

  "degradado-sesion": {
    title: "Sesión caducada con cambios pendientes (banner S11)",
    shot: "degradado-sesion.png",
    sees: "En Almacenamiento: «tienes N cambios sin subir» + botón para volver a entrar. Sin pendientes NO aparece nada (se muestra «al día»).",
    persists: "Nada. Los datos están SEGUROS en local: el hueco es de visibilidad, no de pérdida.",
    exits: "El método de re-firma NO se elige: es determinista, el de la cuenta (`storedProvider()`, que la expiración del SDK no borra). Ofrecer chooser aquí invitaría al mismatch R9.",
    code: [
      { t: "SessionExpiryPolicy.swift:34 `decide`", d: "pendientes > 0 ∧ sesión irrenovable ⇒ estado bloqueado explícito" },
      { t: "CloudMigrationController.swift:564 `refreshSyncBanner`", d: "cuenta las filas VIVAS del outbox" },
      { t: "CloudMigrationController.swift:583 `signInToResumeSync`", d: "el belt: si la sesión revivió por otra entrada, solo despierta la cadencia" }
    ],
    notes: []
  },

  "degradado-mount": {
    title: "Guard de mount-mismatch personal (A3)",
    shot: "degradado-mount.png",
    sees: "NADA. Este guard no tiene pantalla propia: bloquea el motor en silencio.",
    persists: "Nada. Su única superficie de observación es el breadcrumb `personalMountMismatch`, fuera de `#if DEBUG`.",
    exits: "Se resuelve solo con el relanzamiento.",
    code: [
      { t: "MigrationBootDecision.swift:55 `canRun`", d: "¬mountMismatch ∧ ¬cloudWithMirrorOn ∧ fase estable" },
      { t: "MigrationBootDecision.swift:80 `isPersonalMountMismatch`", d: "persistido `.cloud` ∧ montado `.icloud`" },
      { t: "CloudSyncRuntime.swift:249-257", d: "el cableado" },
      { t: "CloudSyncEngine.swift:767", d: "el breadcrumb" }
    ],
    notes: [
      "⚠︎ HUECO DICHO, no silenciado: el chip F1 lo nombra como «la pantalla de relanzamiento pendiente» y MEDIDO no existe tal pantalla para este guard. Lo que sí pinta una card es `CloudMigrationUIStateDeriver` cuando el par está armado (`needsRelaunch(.toCloud)`), y esa card vive en Almacenamiento — inalcanzable durante el alta born-cloud, porque el onboarding aún no ha terminado.",
      "En la práctica el usuario del alta no puede escapar: la fase `.relaunch` es terminal, sin back y con `interactiveDismissDisabled()`. El guard es la red por si alguien mañana escribe el par sin relanzar: el motor se queda quieto en vez de duplicar escrituras.",
      "En `.icloud` el término es `false` por construcción ⇒ inerte para el 99 % del parque."
    ]
  },

  "degradado-sinred": {
    title: "Sin red",
    shot: "degradado-sinred.png",
    sees: "Depende del punto: en el alta, error con Reintentar; en el adopt, la pantalla se queda y entra el auto-resume; en la migración, la barra se aparca y el foreground re-kickea.",
    persists: "Nada se pierde: el journal es durable y todo paso es idempotente y resumible.",
    exits: "El presupuesto del paso 4 se mide por TIEMPO journaleado y no por INTENTOS — la cadencia es boot + foreground + tap, así que un contador castigaría a quien abre la app muchas veces y premiaría a quien no la abre.",
    code: [
      { t: "ICloudCutoverGateLogic.swift:59-70 `stallCause`", d: "definitivo (presupuesto corto) vs desconocido (presupuesto largo)" },
      { t: "CloudWelcomeSignInFlow.swift:170-172", d: "las constantes del auto-resume" },
      { t: "MigrationBootDecision.swift:144", d: "el re-kick de foreground" }
    ],
    notes: []
  },

  "degradado-claiming": {
    title: "`claiming_in_progress` · otro device lidera",
    shot: "degradado-claiming.png",
    sees: "Pantalla de espera con Reintentar y «Continuar a la app».",
    persists: "Nada.",
    exits: "Un seguidor NUNCA siembra ni adopta hasta que el líder termine — sea cual sea la rama.",
    code: [
      { t: "AccountClaimDecision.swift:78-79", d: "`claimingInProgress` → `waitForLeader`, con independencia de la rama" },
      { t: "MigrationBootDecision.swift:120-121", d: "el boot en `waitingForLeader` SONDEA, no retoma" }
    ],
    notes: []
  }
};
