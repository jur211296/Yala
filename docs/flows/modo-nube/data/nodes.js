// nodes.js — el CONTENIDO de los paneles del Atlas de Flujos de Modo Nube.
//
// Regla madre (cabecera de MODO-NUBE-CHIPS-FLUJOS): cada campo `code` apunta a una celda REAL de una
// tabla de lógica pura o a una línea de una vista LEÍDA. Nada sale de MODO-NUBE-ARQUITECTURA. Donde el
// diseño y el código difieren, gana el código y la divergencia va en `notes` con la marca ⚠︎.
//
// Medido el 2026-08-09 contra HEAD 9d6f0f1c (branch 2.0.5).
//
// **F5 (2026-08-12) · re-derivación contra HEAD 6c6eb3fe.** Las olas W (el Welcome habla claro), G
// (Grupos-first), C (consent y puertas) y M (frontera de sesión secundaria) —19 commits desde `724f661e`—
// traen superficie que el Atlas no tenía: la vía del ORGANIZADOR entera con su puerta, las CUATRO puertas
// de Grupos unificadas, el consent que viaja con la cuenta, el empty state de cinco casos, el retiro de
// los grupos de la era CloudKit y los cuatro ajustes que una visita ya no toca. Los flujos 1, 2, 6 y 7
// están re-derivados; **los flujos 3 y 4 no se tocan, y eso está MEDIDO**: `git diff 724f661e..HEAD` no
// roza `StorageSettingsView`, `MigrationStateMachine`, `CloudMigrationController` ni `MigrationBootDecision`
// (sus 12 coordenadas se re-verificaron una a una y siguen exactas).
//
// Y una lección de este refresco, para el yo-futuro: `check.mjs` estaba en EXIT 1 por 24 fallos de l10n,
// todos del flujo 1 — pero eso era lo BARATO de arreglar. Lo que el pin no puede ver son las pantallas que
// FALTAN y las coordenadas desplazadas: 35 símbolos se habían movido de línea sin que ningún bloque lo
// notara. Un `check.mjs` en verde no significa que el Atlas esté completo.
//
// **F3 (2026-08-11) · re-derivación contra HEAD 24b4bc91.** La tanda «relanzamiento cero»
// (`6d0358b5`…`24b4bc91`, 6 chips) movió el relanzamiento de sitio y cambió el alta, la rama
// iCloud/restaurar, el sign-out y el chooser. Los nodos de los flujos 1, 2, 5 y 7 afectados están
// re-medidos contra ese árbol y sus coordenadas se resolvieron una a una; los flujos 3, 4 y 6
// (migración, reversa, onboarding de propósito) siguen anclados al 2026-08-09 porque la tanda no los
// toca —comprobado, no asumido: `git diff f4d10fa6..HEAD` no roza `MigrationWorkExecutor`,
// `MigrationRunner`, `StorageSettingsView`, `OnboardingView` ni las Logic del flujo 6—. Cada panel
// tocado dice de qué árbol es su coordenada cuando no es obvio.
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
    title: "Welcome · Hero (W1 · sin subtítulo y sin alert)",
    shot: "alta-hero.png",
    sees: "Logo, el carousel de 8 cards rotando, el título en dos líneas y el botón «Empezar». **Nada más**: desde `c8575d8b` no hay subtítulo, y desde `e999bfef` el tap NO abre ningún alert. Sea cual sea el estado del device, «Empezar» lleva SIEMPRE al chooser.",
    persists: "Nada. `hasTappedEmpezar` sigue siendo estado de vista y solo sirve para no re-disparar la animación de salida.",
    exits: "Una sola salida, y esa es la noticia: `WelcomeHeroView { goTo(.chooser) }`. La rama que se fue —el alert «Detectamos tu cuenta» con sus tres botones— era la ÚNICA bifurcación del Hero; con ella se fueron su Cancel explícito (B-11) y su productor de destino `.restoreICloud`.",
    code: [
      { t: "WelcomeFlowContainer.swift:134-138", d: "el `case .hero` entero: un solo callback, `goTo(.chooser)`, sin alert ni condición" },
      { t: "WelcomeHeroView.swift:9-14", d: "el porqué, escrito en el docblock: la señal del KV-store solo habla de la cuenta iCloud del container y empujaba hacia esa mitad a quien podía tener su cuenta en la nube ⇒ **la reentrada es decisión del usuario**, y se elige en «Ya tengo una cuenta»" },
      { t: "WelcomeHeroView.swift:70-83 `makeCards`", d: "las 8 cards del carousel, cacheadas en `@State`: 16 lookups por recompute a 60 fps sería derroche" },
      { t: "WelcomeHeroView.swift:110-112", d: "`heroTitle` — el subtítulo que iba aquí se retiró con su key" }
    ],
    notes: [
      "⚠︎ RE-DERIVADO el 2026-08-12 (F5). El panel de F4 describía una pantalla que ya no existe: subtítulo (`welcome.hero.subtitle`) y alert de datos detectados (`welcome.detectedData.*`). Las cinco keys están BORRADAS de los 16 locales — por eso el pin de l10n cayó, y ese fallo es la señal de que el Atlas había caducado, no un defecto del pin.",
      "MEDIDO, y es lo que evita el error de leer «se retiró la detección»: la señal del KV-store **NO** se retiró. `RestoreOfferGate` y `RestoreBreadcrumb` siguen vivos y los siguen leyendo `ContentView` y `WelcomeRestoreView`. Lo que se retiró es que el HERO decidiera con ella."
    ]
  },

  "alta-chooser": {
    title: "Welcome · Chooser (3 ramas)",
    shot: "alta-chooser.png",
    sees: "«Es mi primera vez en Yala» · «Ya tengo una cuenta» · «Vengo por un grupo». Las tres ramas siguen ahí, pero **ninguna de las tres se llama como antes**: la pregunta pasó de «¿cómo llegaste a Yala?» a «¿qué quieres hacer en Yala?», y la tercera dejó de presuponer que traes invitación.",
    persists: "Nada todavía. `hasShownWelcomeChooser` lo escribe el CALLBACK de ContentView, no el chooser — y desde G2 tampoco lo escribe la rama de grupos al tapear, porque ahora abre un 2º nivel igual que las otras dos.",
    exits: "Back → Hero. Las tres ramas abren su 2º nivel (o hacen bypass si solo hay una opción visible); ninguna sale ya directa del cover.",
    code: [
      { t: "WelcomeFlowContainer.swift:139-155", d: "el `case .chooser`: `.restore` → handleExistingBranch · `.new` → handleNewBranch · `.invite` → `goTo(.groupsChooser)`" },
      { t: "WelcomeFlowContainer.swift:147-150", d: "G2: la card ya no es «me invitaron» sino «vengo por un grupo» ⇒ **no puede salir directa a la recuperación de invitación**; abre el step de los dos caminos y ahí elige el invitado" },
      { t: "WelcomeChooserView.swift:30-44", d: "las 3 cards salen de `Branch.title`/`.body`" },
      { t: "ContentView.swift:1438-1443", d: "el `case .new` histórico sigue existiendo y es INALCANZABLE desde A4 (el container desvía `.new` a su 2º nivel); delega en el MISMO helper que el callback nuevo para que los dos caminos no diverjan" }
    ],
    notes: [
      "⚠︎ RE-DERIVADO el 2026-08-12 (F5): los tres títulos y los tres cuerpos cambiaron de valor (G1), y la rama `.invite` cambió de DESTINO (G2). El id de las keys es el mismo, así que solo el pin de valores lo detecta — es exactamente el caso que un check de existencia de keys dejaría pasar.",
      "`WelcomeChooserView.Branch` conserva sus TRES ramas — §k.2 es explícito y ni A4 ni G2 las tocaron: lo que cambia es a dónde lleva cada una."
    ]
  },

  "alta-faro": {
    title: "Decisión · el faro va ANTES de la elección (A26)",
    shot: null,
    sees: "Nada: es una decisión, ocurre entre el tap y la siguiente pantalla.",
    persists: "Nada. Es LECTURA del iCloud-KV (`yala.cloud.accountLinked` / `accountProvider`).",
    exits: "N/A.",
    code: [
      { t: "WelcomeAccountChoiceLogic.swift:103 `routeNewBranch`", d: "faro vinculado + entrada nube disponible → `.cloudSignIn(provider)`; si no, `bypass` → `.single` o `.chooser`" },
      { t: "WelcomeAccountChoiceLogic.swift:123 `WelcomeNewBranchRouter.route`", d: "el adaptador que la vista llama: lee el faro vivo y delega en la tabla pura" },
      { t: "WelcomeFlowContainer.swift:272 `handleNewBranch`", d: "el ORDEN es el contrato: el faro se consulta antes de ofrecer nada y antes de que ContentView limpie prefs residuales" },
      { t: "WelcomeFlowContainer.swift:279", d: "R2: el encaminamiento por faro sale por el PORTAL con destino `.cloudSignIn`, que NO necesita el mirror ⇒ nunca interpone relanzamiento" },
      { t: "WelcomeAccountChoiceLogic.swift:112", d: "provider desconocido/ausente ⇒ `.apple`; el faro solo ENCAMINA, el mismatch lo dice la pantalla de destino" },
      { t: "CloudBeacon.swift:45-51", d: "las 4 keys del faro" }
    ],
    notes: [
      "Residual DECLARADO en el propio código: bajo el kill-switch remoto `cloudEntryAvailable` es false ⇒ el faro no encamina y un born-cloud en su 2º device vuelve a poder divergir. Es el mismo residual que ya acepta la card de re-entrada, ampliado a este camino (WelcomeAccountChoiceLogic.swift:100-102).",
      "Medido el 2026-08-09 y anotado en la vista: `OnboardingResetHelper.safeKeysToClear` son SOLO `userName` y `defaultCurrencyCode` ⇒ la limpieza de fresh-start no toca las keys `yala.cloud.*`."
    ]
  },

  "alta-newchooser": {
    title: "Sub-chooser «Soy nuevo» (privado | nube)",
    shot: "alta-newchooser.png",
    sees: "Dos cards con títulos paralelos —«Tu cuenta en la nube» y «Tu cuenta en tu iCloud privado»—, **en ese orden**, sin distintivo de recomendada en ninguna y **sin la renuncia inline** que llevaba la de nube. Con UNA sola opción visible esta pantalla NO se monta (bypass) — que es el recorrido de producción de hoy.",
    persists: "Nada.",
    exits: "Back → chooser.",
    code: [
      { t: "WelcomeNewChooserView.swift:100 `displayOrder`", d: "W3: **la nube va primero**. El orden de PANTALLA vive aquí y no en `visibleNewOptions` — reordenar el array de la Logic no cambiaría nada de lo que se ve, y el docblock lo avisa" },
      { t: "WelcomeNewChooserView.swift:9-32", d: "las tres decisiones de producto que retiraron §k.6 de esta pantalla: sin badge (RC), orden invertido (W2 punto 6) y sin renuncia inline (W2 punto 10)" },
      { t: "WelcomeNewChooserView.swift:47-52 `contentHeights`", d: "las dos cards se igualan midiendo el CONTENIDO y no la card enmarcada: medir la enmarcada realimentaría (crecer → medir más → crecer)" },
      { t: "WelcomeAccountChoiceLogic.swift:42 `visibleNewOptions`", d: "la card nube exige los CINCO términos: configurado ∧ ¬uitest ∧ compilado ∧ kill-switch nube ∧ sub-flag de la elección" },
      { t: "WelcomeFlowContainer.swift:115-121", d: "el cableado real de los 5 términos" },
      { t: "WelcomeAccountChoiceLogic.swift:73 `bypass`", d: "una sola opción ⇒ se navega directo a ella" },
      { t: "CloudRemoteConfig.swift:140 `cloudOnboardingChoiceEnabled`", d: "el percent remoto — `\"0\"` en producción, fail-closed" },
      { t: "WelcomeNewChooserView.swift:159 `accessibilityLabel`", d: "RC: la card privada ya no interpola ningún distintivo — retirarlo de la vista y dejarlo aquí habría hecho que VoiceOver recomendara lo que la pantalla no recomienda" }
    ],
    notes: [
      "`bornCloudEnabled` es la constante COMPILADA `CloudSyncFlags.bornCloudChoiceEnabled`, hoy `true`. La palanca de release es el PERCENT remoto, no la constante — la fila «A7 flipa la constante» del spec quedó obsoleta (anotación 1 del punto de control).",
      "Captura RE-HECHA el 2026-08-11 (F3) sobre HEAD `24b4bc91`: el badge «Recomendado» que `951fada0` retiró ya no sale, y la etiqueta de accesibilidad medida con `snapshot_ui` tampoco lo nombra. La imagen obsoleta que el chip RC dejó anotada queda sustituida."
    ]
  },

  "alta-privado": {
    title: "«Soy nuevo → privacidad total»",
    shot: "alta-privado.png",
    sees: "El onboarding normal (paso del nombre) — **con un relanzamiento por delante si este proceso montó el store NEUTRO**, que es el caso de toda instalación fresca desde R2. Sobre un device que YA tiene archivo de store va directo, y si además hay datos locales sale antes el alert de wipe.",
    persists: "`hasShownWelcomeChooser = true` · `OnboardingResetHelper.clearResidualPreferencesForFreshStart()` borra `userName` y `defaultCurrencyCode` del KV. En el camino con relanzamiento las dos cosas se escriben ANTES de pedir que se reabra (más el destino pendiente), no después.",
    exits: "El alert de wipe deja el cover del Welcome VISIBLE hasta resolverse. En el camino con relanzamiento no hay alert que mostrar: el mount neutro exige que NO exista archivo de store, así que no puede haber datos que confirmar.",
    code: [
      { t: "WelcomeFlowContainer.swift:287-300 `handleNewOption`", d: "R2: las dos cards salen por el PORTAL; `.privateAccount` → destino `.privateOnboarding`, que SÍ necesita el mirror" },
      { t: "WelcomeMirrorRelaunchLogic.swift:78 `requiresMirror`", d: "`privateOnboarding` es `true` porque lo que el usuario cree en su primera sesión tiene que espejarse; que un mirror adjuntado en un arranque POSTERIOR exporte lo escrito en la ventana neutra es plausible pero NO está medido" },
      { t: "ContentView.swift:1608 `startFreshPrivateOnboarding`", d: "el camino SIN relanzamiento: limpieza de residuales → alert si `hasExistingData`, si no → onboarding" },
      { t: "ContentView.swift:1470-1475", d: "callback `onSelectPrivateAccount`" },
      { t: "ContentView.swift:1517-1532", d: "callback `onNeedsMirrorRelaunch`: marca el chooser visto, limpia residuales y PERSISTE el destino" }
    ],
    notes: [
      "⚠︎ MEDIDO en sim el 2026-08-11 (F3): este es **el recorrido de producción de hoy** —con el percent remoto de la elección nube en 0 el sub-chooser ni se monta— y desde `339f7825` **paga un relanzamiento que antes no pagaba**. El saldo del parque es +1 relanzamiento hasta que el owner suba ese percent; es el reparto que la Opción C aprueba y la decisión del punto de control lo ratifica (ningún build con R2 se distribuye con el percent en 0). Ver el hallazgo F3-H1.",
      "La captura es el estado FINAL (el onboarding ya montado). Se verificó en sim que se llega ahí tras el relanzamiento, no en su lugar: ver el nodo «Un último paso: reabre Yala»."
    ]
  },

  "alta-mirrorrelaunch": {
    title: "R2 · «Un último paso: reabre Yala» (terminal del Welcome)",
    shot: "alta-mirrorrelaunch.png",
    sees: "Pantalla terminal con el icono de recarga: «Un último paso: reabre Yala» + «Para cuidar tus datos, Yala tiene que abrirse de nuevo. Ve a la pantalla de inicio y vuelve a entrar: seguimos justo donde lo dejaste.». Sin botones y sin back. Copy PROPIO, no el `Storage.Relaunch.*` de la migración: aquí el usuario todavía no tiene datos que mover.",
    persists: "`hasShownWelcomeChooser = true` (que es lo que rompe el mount neutro en el arranque siguiente) · el destino elegido en `WelcomePendingDestinationStore` (`welcome.pendingMirrorRelaunchDestination`) · en la rama privada, la limpieza de residuales.",
    exits: "**Se cierra sola al ir a background** (R0): el proceso hace `exit(0)` y el arranque siguiente CONSUME el destino y aterriza donde el usuario pidió. Solo `.background` — `.inactive` (app switcher, centro de notificaciones) no mata nada. El testigo del auto-exit es el DESTINO PENDIENTE y se lee con `peek`, jamás con `consume`: retirarlo ahí dejaría a quien pidió restaurar aterrizando en el onboarding normal con su elección perdida.",
    code: [
      { t: "WelcomeMirrorRelaunchLogic.swift:94 `shouldRelaunch`", d: "dos términos: el destino necesita mirror ∧ el mount es EXACTAMENTE `.neutralNoMirror` (no `!attachesCloudKitMirror`: los otros mounts sin mirror son devices ya en modo nube, donde este Welcome no se presenta)" },
      { t: "WelcomeFlowContainer.swift:230-240 `leaveWelcome`", d: "el PORTAL ÚNICO de salida del Welcome — seis productores de destino pasan por aquí, así que una salida nueva está obligada a nombrar su `Destination`" },
      { t: "WelcomeMirrorRelaunchView.swift:25", d: "la pantalla, con `interactiveDismissDisabled()`; vive como STEP del cover del Welcome y no como cover propio (regla 3 de Presentaciones)" },
      { t: "RelaunchNetLogic.swift:86 `shouldExitOnBackground`", d: "el tercer término, `welcomeMirrorRelaunchArmed`" },
      { t: "YalaApp.swift:179-191", d: "el cableado: `WelcomePendingDestinationStore.peek() != nil` y el `exit(0)`" },
      { t: "ContentView.swift:1358-1379", d: "el consumo al arrancar: va ANTES del chooser y del onboarding porque es más específico que los dos" },
      { t: "WelcomeMirrorRelaunchLogic.swift:113 `WelcomePendingDestinationStore`", d: "`set` / `peek` / `consume` / `clear` — sin TTL y de consumo one-shot; vive en el mismo fichero que la decisión, no en un servicio aparte" }
    ],
    notes: [
      "MEDIDO en sim el 2026-08-11 (F3), instalación limpia de Yala Dev: «Soy nuevo → privacidad total» monta esta pantalla; al pulsar Inicio el **proceso desaparece** (`launchctl list` sin la app) dejando `welcome.pendingMirrorRelaunchDestination = privateOnboarding` y `hasShownWelcomeChooser = true` en el plist del contenedor; al relanzar, la app aterriza en el **onboarding** y la key del destino ya NO existe. Las tres mitades del mecanismo —auto-exit, durabilidad y consumo one-shot— quedan verificadas de punta a punta. El chip R0 daba el auto-exit por no verificable desde el repo: lo es en sim con un build normal (el corte es `isRunningTests`, no `#if DEBUG`).",
      "Los tres destinos que llegan aquí son `privateOnboarding`, `restoreICloud` e `inviteRecovery`. Los dos de nube (`cloudAccount`, `cloudSignIn`) NO, y por eso el `switch` del consumo los trata como inalcanzables y cae al recorrido normal en vez de saltar al cover de nube con una sesión que este proceso no ha visto."
    ]
  },

  // ── G2/G3/G4 · la vía del ORGANIZADOR («Vengo por un grupo» → «Crear mi primer grupo») ──────

  "alta-groupschooser": {
    title: "G2 · «¿Cómo empiezas con tu grupo?» — las dos vías",
    shot: "alta-groupschooser.png",
    sees: "Título «¿Cómo empiezas con tu grupo?», la bajada «Las dos vías te dejan en el mismo sitio.» y DOS cards de alto igualado: «Crear mi primer grupo» y «Tengo una invitación». Antes de G2 esta pantalla no existía: la card de nivel 1 se llamaba «Me invitaron a un grupo» y salía directa a recuperar la invitación, así que quien quería CREAR uno no tenía puerta.",
    persists: "Nada. Y en concreto **no** se marca `hasShownWelcomeChooser`: desde que este step se interpuso, tapear la card de nivel 1 dejó de marcarlo, para que un abandono aquí pueda volver al Welcome en vez de caer al onboarding completo.",
    exits: "«Volver» → chooser de 3 ramas. «Tengo una invitación» cruza el portal con destino `.inviteRecovery`, que SÍ pide mirror ⇒ sobre un mount neutro pasa antes por «Un último paso: reabre Yala». «Crear mi primer grupo» NO cruza el portal: abre el step de la PUERTA, y solo ella lo cruza si abre.",
    code: [
      { t: "WelcomeFlowContainer.swift:150", d: "`case .invite: goTo(.groupsChooser)` — la card «Vengo por un grupo» dejó de salir por el portal" },
      { t: "WelcomeFlowContainer.swift:161", d: "`onCreate` → `goTo(.groupsGate)`: no sale del cover" },
      { t: "WelcomeFlowContainer.swift:163", d: "`onJoin` → `leaveWelcome(to: .inviteRecovery)`, el MISMO destino de siempre" },
      { t: "WelcomeGroupsChooserView.swift:54 `visiblePaths`", d: "`Path.allCases`: las dos cards se pintan SIEMPRE" },
      { t: "WelcomeMirrorRelaunchLogic.swift:78-85 `requiresMirror`", d: "`.inviteRecovery` → true · `.groupsOrganizer` → false: las dos cards contiguas caen a lados opuestos" }
    ],
    notes: [
      "⚠︎ Dos cards de la MISMA pantalla se comportan distinto ante el mount neutro: unirse puede exigir reabrir la app, crear nunca. MEDIDO en `requiresMirror`, con el porqué escrito en el propio fichero (:73-77): la vía del organizador va por el BACKEND y su alta es solo-grupos, así que no crea corpus personal que espejar.",
      "⚠︎ Asimetría de `hasShownWelcomeChooser`: la card de unirse lo marca (pasa por `onSelectBranch`), la de crear no. Abandonar la vía de crear devuelve al Welcome; abandonar la de unirse ya no.",
      "El alto de las dos cards se iguala por MEDICIÓN (`onGeometryChange`) y no por copy: el título envuelve distinto según el idioma."
    ]
  },

  "alta-groupsgate": {
    title: "G3 · LA PUERTA — «Comprobando que todo esté listo…»",
    shot: "alta-groupsgate.png",
    sees: "Un spinner grande y «Comprobando que todo esté listo…». Es lo único que se ve mientras corre el refresh forzado del remote-config. Si todo está en orden el step se desmonta en la misma vuelta —no hay pantalla de éxito, sería un parpadeo— y si no, sale uno de los tres bloqueos.",
    persists: "**NADA, y esa es la mitad del chip**: ni `onboardingMode`, ni `groupsBetaUnlocked`, ni `hasCompletedOnboarding`, ni la divisa. `evaluate()` no escribe una sola key ni llama a nada que escriba.",
    exits: "El `.task` hace tres cosas en orden: fuerza `refreshIfDue(force: true)` (salvo bajo `-uitest`), comprueba `Task.isCancelled` y decide. `.proceed` cruza el portal a `.groupsOrganizer`, que **nunca** relanza.",
    code: [
      { t: "WelcomeGroupsGateView.swift:148-150", d: "el `force: true` no es cosmético: sin él `refreshIfDue` es un no-op EXACTAMENTE en el caso del bug — el min-interval de 6 h ya lo gastó el refresh del arranque" },
      { t: "WelcomeGroupsGateView.swift:155 `guard !Task.isCancelled`", d: "la cancelación del step es COOPERATIVA y `refreshIfDue` no la mira: sin este guard, un «Volver» durante el refresh sacaría igual al usuario del Welcome cuando la red conteste" },
      { t: "WelcomeGroupsGateView.swift:157-163", d: "el cableado: canal ya re-medido · `SecondarySessionStore.isActive()` · fetch VIVO del corpus" },
      { t: "GroupsOrganizerGateLogic.swift:78-85 `decide`", d: "tres guards en cascada: canal → secundaria → datos ajenos → `.proceed`" },
      { t: "WelcomeGroupsGateView.swift:39", d: "`decision` arranca en `nil` a propósito: un default optimista pintaría medio frame de la rama buena antes de bloquear" },
      { t: "WelcomeFlowContainer.swift:175", d: "`leaveWelcome(to: .groupsOrganizer)` — el único cruce del portal de esta rama" }
    ],
    notes: [
      "CELDAS: 3 booleanos = 8 combinaciones, **4 clases** por cortocircuito. El ORDEN es load-bearing y está escrito: el canal va primero porque es lo que el `force` acaba de re-medir y porque su copy describe algo TRANSITORIO; **la secundaria va antes que los datos ajenos** porque en secundaria el detector mide el store de la INVITADA —vacío en una sesión recién montada— así que `hasExistingData` daría `false` y la puerta abriría justo en el caso más caro.",
      "⚠︎ HALLAZGO: la puerta no emite NINGÚN canario. En las cuatro salidas no hay una sola llamada a `MetricsService` ⇒ «cuántos organizadores rebotan aquí, y por cuál de los tres motivos» es hoy inobservable en producción.",
      "No puede ser un `.alert(`: el source-scan de `WelcomeHeroReentryTests` lo prohíbe en el container, y un alert contaría además como camino muerto en un flujo que el spec exige que no lo tenga."
    ]
  },

  "alta-groupsgate-blocked": {
    title: "G3/C3 · Las TRES puertas cerradas",
    shot: "alta-groupsgate-blocked.png",
    sees: "Tres pantallas hermanas —icono, título, cuerpo y un «Volver»— con copy distinto según el motivo: **canal apagado** («Ahora mismo no podemos abrirte grupos»), **sesión de visita** («Aquí estás como invitado», C3) y **datos de otro humano** (el «Este dispositivo tiene datos de otra cuenta» prestado del guard de sign-in).",
    persists: "Nada, en las tres. Es literalmente el punto: se bloquea ANTES de pedir nombre e identidad.",
    exits: "«Volver» → chooser de grupos, con la otra vía intacta. No hay botón de reintento: el reintento ES volver a tapear la card, que remonta el step y vuelve a forzar el refresh. La salida real del bloqueo por visita está FUERA de la app —cerrar la sesión de invitado y volver desde el dispositivo propio—, y el copy lo dice.",
    code: [
      { t: "WelcomeGroupsGateView.swift:60-83", d: "las tres ramas del `switch` con sus identifiers: `..._channel_off` · `..._secondary_session` · `..._foreign_data`" },
      { t: "GroupsOrganizerGateLogic.swift:81-83", d: "los tres guards, en el orden en que se evalúan" },
      { t: "CloudSyncFlags.swift:344-347 `groupsBackendEnabled`", d: "compilado ∧ remoto: el remoto solo puede MATAR" },
      { t: "GroupsOrganizerOnboarding.swift:164", d: "C3 · defensa en profundidad en el ESCRITOR: el guard de secundaria subió de una key al método entero" },
      { t: "ContentView.swift:1086-1102 `checkHasExistingData`", d: "cuenta cuentas y categorías no-sistema MÁS `SplitGroup` y las `TransactionItem` con `splitExpenseID`: un dueño anterior que venía de «Solo Grupos» daría `false` con el detector estrecho" },
      { t: "ContentView.swift:1104-1107", d: "el `catch` devuelve `true`: falla CERRADO" }
    ],
    notes: [
      "⚠︎ El copy de datos ajenos es PRESTADO del guard de sign-in de nube y habla de «conectar una cuenta distinta»: aquí el usuario no está conectando ninguna cuenta, está intentando crear un grupo. El hecho es el mismo; la acción que el texto nombra, no. Y su «Su dueño puede volver a entrar cuando quiera» describe una salida que en ESTA pantalla no existe.",
      "⚠︎ Como `checkHasExistingData` falla cerrado, un error de lectura pinta «este dispositivo tiene datos de otra cuenta» a alguien con el device vacío. La dirección es la segura; el copy miente sobre la causa.",
      "El bloqueo por visita (C3) es el único de los tres con copy PROPIO en los 16 locales, y por eso: el hecho no es «hay datos de otro humano» sino «esta sesión no es de este dispositivo», y aquí sí hay salida.",
      "⚠︎ Las tres pantallas tienen DOS controles que hacen lo mismo: el back de la esquina y el botón primario «Volver». No es un bug, pero conviene saberlo al leer una captura."
    ]
  },

  "alta-organizername": {
    title: "G3 · «¿Cómo te llamas?» → «Crear mi grupo»",
    shot: "alta-organizername.png",
    sees: "Cover a pantalla completa: «¿Cómo te llamas?», «Es el nombre que verán los demás en el grupo.», un campo con placeholder «Tu nombre» y el botón «Crear mi grupo». Es lo ÚNICO que esta rama pide.",
    persists: "Nada mientras la pantalla está abierta. Al tapear el CTA se escribe todo de golpe — ver el nodo del alta.",
    exits: "El CTA escribe y cierra el cover; su `onDismiss` submitea el avance, que ya decide el formulario. Cerrar por swipe —o que UIKit tumbe el cover— apaga la rama y devuelve al chooser de grupos: nunca deja una pantalla muerta. **El botón NO se deshabilita con el campo vacío**: un nombre vacío es legítimo y el escritor lo resuelve a «Usuario»; un botón muerto aquí sería la regresión del «botón muerto» de la 2.0.5.",
    code: [
      { t: "GroupsOrganizerNameView.swift:77-80", d: "`YalaPrimaryButton` sin `isDisabled`, a propósito" },
      { t: "GroupsOrganizerNameView.swift:90-93 `complete()`", d: "escribe (`completeSetup`) y después avisa" },
      { t: "ContentView.swift:337-356", d: "el cover, su `onDismiss` de respaldo y el one-shot `organizerSetupCompleted`" },
      { t: "ContentView.swift:1013-1029", d: "la puerta B (card «Solo grupos») SALTA esta pantalla: ya preguntó nombre y divisa, así que escribe directamente con el payload" },
      { t: "ContentViewReadinessLogic.swift:150", d: "blocker `groupsOrganizerName` en la matriz de readiness" }
    ],
    notes: [
      "Pantalla propia y NO `OnboardingView`: reusar aquella arrastraría sus 8 steps, el planner por `selectedUsageMode` y el gate de la card de propósito, para pedir un campo.",
      "Decisión del owner: el alta del organizador pide SOLO el nombre. La divisa se deriva de la región en silencio y es editable en el grupo desde el primer minuto.",
      "⚠︎ El docblock de `GroupsOrganizerNameView` dice que `completeSetup` tiene «su ÚNICO call-site de producción» aquí. MEDIDO: hoy son DOS —esta vista y `ContentView.advanceGroupsOrganizerFlow` en su caso `.presentName` con payload— y el propio `GroupsOrganizerOnboarding` lo dice bien. Es un docblock que se quedó atrás al añadirse la puerta B."
    ]
  },

  "alta-organizerwrite": {
    title: "G3+G4 · El alta del organizador: lo único que escribe la rama entera",
    shot: null,
    sees: "Nada propio. Lo que el usuario percibe es que el tab bar se reduce a Grupos y aterriza allí en el mismo render.",
    persists: "SEIS keys, y solo aquí. **Sincronizadas** (iKV en `.icloud`, outbox de prefs en `.cloud`): `userName` (trimeado, o «Usuario» si viene vacío), `defaultPeriod = thisMonth`, `defaultCurrencyCode` y `onboardingMode = groupInvite`. **Per-device**: `groupsBetaUnlocked` y `hasCompletedOnboarding`. Además, en SwiftData: categorías personales, categorías de sistema del bridge y notificaciones por defecto — sin cuenta ni presupuesto.",
    exits: "No es una pantalla: es el paso terminal del cover del nombre (o, en la puerta B, el que sustituye a esa pantalla). Si `writePreferences` devuelve `false` —frontera de sesión secundaria— `completeSetup` aborta ANTES de los seeds y del aterrizaje: seguir dejaría a la invitada en un shell de Grupos que ninguna preferencia sostiene.",
    code: [
      { t: "GroupsOrganizerOnboarding.swift:111-118 `writtenKeys`", d: "el inventario PUBLICADO; el test del camino bloqueado afirma su ausencia contra ESTA lista y no contra una copia a mano" },
      { t: "GroupsOrganizerOnboarding.swift:180-185", d: "G4 · la divisa: la elección EXPLÍCITA (puerta B) gana siempre; si no, se deriva de la región y **solo si la key está AUSENTE**" },
      { t: "CurrencyUtils.swift:837-845 `detectCurrencyFromRegion`", d: "`CurrencyCode.fromRegion`; sin match cae a `.usd`, no al `.pen` global de `AppPreferences`" },
      { t: "GroupsOrganizerOnboarding.swift:196", d: "`onboardingMode = .groupInvite` por el canal sincronizado (dual-write)" },
      { t: "GroupsOrganizerOnboarding.swift:238-240", d: "los seeds: categorías personales, categorías de sistema del bridge y notificaciones" },
      { t: "GroupsOrganizerOnboarding.swift:254-259", d: "métrica de alta y aterrizaje en el tab Grupos" },
      { t: "GroupsOrganizerOnboarding.swift:47-56", d: "el canal de escritura inyectable, con los dos caminos SEPARADOS y un `hasValue(forKey:)` para que la condición de la divisa sea afirmable sobre un store" }
    ],
    notes: [
      "G4 · la divisa por país es la ÚNICA escritura condicional del alta, y el guard es el invariante: `defaultCurrencyCode` es sincronizada, así que en una instalación nueva de un Apple ID que ya usa Yala en otro dispositivo el valor puede haber BAJADO por iKV antes de que el organizador toque nada; pisarlo le cambiaría la divisa por la de la región donde esté hoy.",
      "⚠︎ TELEMETRÍA: los dos caminos que llegan aquí emiten el MISMO `localRegistrationCompleted(mode: \"groupsOrganizer\")`, aunque el comentario de esa línea diga que el modo propio existe «para poder separar las dos puertas de entrada al mismo shell». Desde que la card «Solo grupos» pasa por `completeSetup`, las dos puertas son indistinguibles en el dashboard.",
      "El orden de la rama es lo que hace segura esta escritura: `onboardingMode` es never-downgrade cross-device y viaja al iKV del Apple ID; escrito antes de confirmar la puerta, no vuelve."
    ]
  },

  "alta-organizercancel": {
    title: "G3 · Matriz de cancelación de la rama organizador",
    shot: null,
    sees: "Nada propio: el usuario ve reaparecer «¿Cómo empiezas con tu grupo?».",
    persists: "Nada, en las CUATRO filas (educativo · sign-in · consent · cover del nombre). Y se descarta el payload en memoria de la puerta B: un payload superviviente haría que el siguiente intento saltara la pantalla del nombre con datos de una sesión abandonada.",
    exits: "Cancelar cualquiera de los cuatro apaga `groupsOrganizerFlowActive` y reabre el Welcome en `.groupsChooser` — al chooser de GRUPOS y no al de tres ramas, porque es donde estaba el usuario y desde ahí puede reintentar o irse por la otra vía sin volver a pasar por el Hero.",
    code: [
      { t: "ContentView.swift:750-761 `returnToGroupsChooser`", d: "choke-point de TODA cancelación: descarta el payload y reabre el Welcome en el step de los dos caminos" },
      { t: "GroupsBackendInviteModifier.swift:153-157 `handleCancel`", d: "no-op para el INVITADO; para el organizador, vuelta al Welcome" },
      { t: "ContentView.swift:342-346", d: "el cancel del cover del nombre, por su `onDismiss` de respaldo" }
    ],
    notes: [
      "El organizador NO puede quedarse donde está al cancelar: ya SALIÓ del Welcome y debajo no hay shell, porque su alta no ha corrido. Esa es la diferencia entera con el invitado, cuyo intent sobrevive en `PendingJoinStore` (TTL 7 días) y para quien estos mismos sheets no cancelan nada.",
      "El descarte del payload NO se centralizó en el modifier sino en `returnToGroupsChooser`, porque el cover del nombre no pasa por el modifier."
    ]
  },

  "alta-consent": {
    title: "Consentimiento informado (path `.bornCloud`)",
    shot: "alta-consent.png",
    sees: "Sheet con **tres puntos y un pie**, título «Tus datos en la nube de Yala», el enlace a la política de privacidad y el botón «Entiendo y quiero activar la nube». Se lee como unos términos, no como una alarma. El copy es GENÉRICO — no cambia por path.",
    persists: "AL ACEPTAR, y **desde M0 depende de por dónde vaya el flujo**: en el alta born-cloud y en la migración escribe la pantalla (`CloudConsentRegistrar.register()` → `cloudConsentAcceptedAt` + `cloudConsentTextVersion`, hoy **versión 2**); en la RE-ENTRADA la pantalla NO escribe (`persistsOnAccept = false`) y la escritura se difiere hasta que el guard cross-cuenta diga por dónde va. La métrica `cloudConsentAccepted(path:)` NO se difiere en ningún caso: aceptar ocurrió aquí.",
    exits: "Descartar el sheet sin aceptar NO persiste nada. Y en re-entrada, un intento que termina BLOQUEADO tampoco deja nada: su `Placement` es `.never`.",
    code: [
      { t: "CloudConsentView.swift:125-128 `registerConsent`", d: "el registro CONDICIONAL (`persistsOnAccept`) + la métrica incondicional" },
      { t: "CloudConsentView.swift:136-138 `points`", d: "los tres puntos que quedan: servidores · fotos · acceso" },
      { t: "CloudConsentText.swift:33 `version`", d: "**2** desde W4: el recorte saca del contrato el envío a la IA y la ubicación de los servidores ⇒ es un cambio de qué-sale y dónde-se-guarda, y por eso bumpea" },
      { t: "CloudConsentRegistrationLogic.swift:44 `placement(for:)`", d: "M0: la tabla que decide DÓNDE cae la escritura en re-entrada — `.beforeAdopt` · `.afterSecondaryDescriptor` · `.never`" },
      { t: "CloudConsentRegistrationLogic.swift:63 `persistIfDue`", d: "las tres condiciones y el `pending` como `inout`: un retry tras `.error` no re-escribe, así que el epoch conserva su T0" },
      { t: "CloudMigrationController.swift:271", d: "`ConsentPath` — `.migration` · `.adopt` · `.bornCloud`" }
    ],
    notes: [
      "⚠︎ RE-DERIVADO el 2026-08-12 (F5): el panel de F4 describía **siete** puntos con las keys `storage.consent.point1..point7`, hoy borradas de los 16 locales.",
      "⚠︎ El BUG que M0 cierra, medido y vale la pena leerlo entero: la pantalla escribía al aceptar, y en re-entrada ahí la ruta todavía no existe —el sign-in ni ha ocurrido—, así que `PreferenceSyncService` resolvía el destino con el modo persistido del device, que durante el Welcome es el `.icloud` **del dueño del móvil**. Un intento cross-cuenta que acababa BLOQUEADO ya había dejado el epoch de la otra persona en el iKV del dueño, y el paso 5-bis del cutover lo habría subido un día como consent SUYO.",
      "MEDIDO y conviene saberlo antes de razonar sobre la versión: **ningún camino compara `CloudConsentText.version` con lo persistido**. La pantalla se presenta siempre antes de firmar, así que nadie se queda con una versión vieja sin volver a aceptar; la versión deja registrado QUÉ texto se aceptó, no gatea una re-petición.",
      "⚠︎ Corrección MEDIDA del spec (anotación 3 del punto de control): la promesa «cancelar deja el device sin consent-flag ni faro» era INSATISFACIBLE. El consent se persiste al aceptarse (append-only). Ver el nodo «Matriz de cancelación» — y desde M0 su FILA 2 se estrecha en la re-entrada, donde cortar antes del guard ya no deja epoch."
    ]
  },

  "alta-intro": {
    title: "Intro del alta · elegir método",
    shot: "alta-intro.png",
    sees: "Título + subtítulo del alta y DOS botones de prominencia equivalente (Apple y Google, guideline 4.8), los dos con el verbo de **crear cuenta** — «Crear cuenta con Google» y el rótulo de registro que pinta el sistema en el de Apple —, más la nota §13 en su variante de alta: la cuenta quedará ligada al método que elijas.",
    persists: "Nada. El tap solo fija `chosenProvider` en memoria y abre el consent.",
    exits: "Back permitido (`canGoBack` incluye `.intro`).",
    code: [
      { t: "WelcomeCloudSignInView.swift:296 `bornCloudIntro`", d: "los dos botones + la nota" },
      { t: "WelcomeCloudSignInView.swift:311-321", d: "W4b: `AppleSignInButton(type: .signUp)` y `GoogleSignInButton(purpose: .signUp)` — el verbo es del CONTEXTO, no del botón" },
      { t: "GoogleSignInButton.swift:44-50", d: "los tres propósitos y su key: `.signUp` → crear cuenta · `.signIn` → iniciar sesión · `.continue` → continuar" },
      { t: "WelcomeCloudSignInView.swift:340 `beginBornCloudSignUp`", d: "fija el método y abre el consent — NO firma nada" },
      { t: "WelcomeCloudSignInView.swift:203 `canGoBack`", d: "`.intro`/`.notFound`/`.blockedForeignData`/`.error`/`.providerMismatch` → sí; el resto no — y desde R2 `.bornCloudReady` entra en el lado sin salida" }
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
      { t: "WelcomeCloudSignInView.swift:599 `ensureSignedIn`", d: "las 4 salidas y la asimetría Apple/Google, que NO es cosmética" }
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
      { t: "CloudWelcomeSignInFlow.swift:20-24 `.creating`", d: "por qué es un caso propio" },
      { t: "WelcomeCloudSignInView.swift:203-213 `canGoBack`", d: "`.creating` NO permite back" }
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
      { t: "BornCloudSignUpService.swift:191 `signUp`", d: "el encadenado completo" },
      { t: "BornCloudSignUpService.swift:203", d: "`migration: false` EXPLÍCITO — `true` armaría una máquina de migración que aquí no existe" },
      { t: "AccountClaimDecision.swift:71 `decide`", d: "la tabla: 3 estados × 3 ramas" },
      { t: "CloudWelcomeSignInFlow.swift:146 `BornCloudSignUpFlow.step`", d: "traduce los 7 outcomes a 4 pasos de pantalla" },
      { t: "BornCloudSignUpService.swift:244 `writeCloudAccountLinked`", d: "el faro se escribe SOLO en `created` (con `existing_stable` pisaría el `linkedAt` y el provider del device que la creó)" }
    ],
    notes: [
      "⚠︎ MEDIDO: la variante B (`showProviderMismatch`) es `returningUser`-ONLY (AccountClaimDecision.swift:83) ⇒ desde `.bornCloud` es HOY INALCANZABLE con cualquier combinación del faro. El consumidor la mapea igual porque la tabla que decide vive en `AccountClaimDecision`.",
      "`proceedMigration` desde born-cloud también es inalcanzable; si apareciera, la respuesta es NO seguir (`transient`) + breadcrumb `unexpectedAction`."
    ]
  },

  "alta-par-relaunch": {
    title: "Par `.cloud` + «Cierra y vuelve a abrir Yala» (solo si el mount lleva mirror)",
    shot: "alta-par-relaunch.png",
    sees: "Pantalla TERMINAL con el icono de recarga: «Cierra Yala y vuelve a abrirla». Sin botones, sin back, sin dismiss interactivo.",
    persists: "`cloudSync.storageMode = cloud` Y `cloudSync.migration.relaunchRequested = true`, escritas por `StorageModePersistence.writeCloudArmed` (escritor ÚNICO del par). El journal se queda en `notStarted`.",
    exits: "NUNCA auto-kill: iOS trata la auto-muerte como un crash y App Review la rechaza. La app se queda usable en esta pantalla hasta que el usuario la cierre. **Este terminal NO hereda el auto-exit de R0**, y su docblock dice por qué: su fase es `@State private` de la vista, así que `handleScenePhase` —que ve el scenePhase agregado del proceso— no tiene nada durable que consultar.",
    code: [
      { t: "BornCloudSignUpService.swift:340 `activateBornCloudStorage`", d: "escribe el par y DEVUELVE la fase terminal" },
      { t: "BornCloudSignUpService.swift:344-348", d: "R2: la terminal la decide el testigo de mount — `attachesCloudKitMirror` ⇒ `.relaunch`; sin mirror ⇒ `.bornCloudReady`" },
      { t: "CloudSyncFlags.swift:91 `writeCloudArmed`", d: "modo → armado, en ese orden; el docblock explica por qué el born-cloud puede saltarse el gate del marcador" },
      { t: "WelcomeCloudSignInView.swift:482 `relaunchContent`", d: "la pantalla" },
      { t: "MigrationBootDecision.swift:85 `isPersonalMountMismatch`", d: "en esta ventana el motor NO arranca: el par dice `.cloud` y el mount de este proceso lleva el mirror ADJUNTO" }
    ],
    notes: [
      "⚠︎ RE-DERIVADO el 2026-08-11 (F3): desde `339f7825` esta pantalla es la rama del **device que llegó al alta CON archivo de store** (mount `.iCloudMirror` o `.localNoMirror`). Una instalación fresca monta NEUTRO y el alta termina en «Tu cuenta está lista» sin relanzar nada. La pregunta que decide es el EJE (`attachesCloudKitMirror`), no el nombre de la decisión — por eso el mismo guard que bloquea aquí deja pasar el caso neutro.",
      "El par NO se puede hacer atómico (`UserDefaults` no tiene transacción) ni invertir (la mitad `armado + .icloud` pintaría `needsRelaunch(.toCloud)` en bucle). El invariante se enforcea en el CONSUMIDOR: `MigrationRuntimeGate.canRun`.",
      "El born-cloud se salta el gate del marcador porque no hay corpus en CloudKit del que nadie pueda divergir — mismo razonamiento que `ICloudChannelVerdict.noChannelNoFootprint`."
    ]
  },

  "alta-bornready": {
    title: "R2 · «¡Tu cuenta está lista!» — el alta que NO relanza",
    shot: "alta-bornready.png",
    sees: "Check verde, «¡Tu cuenta está lista!», «Ya puedes empezar. Todo lo que registres se guardará en tu cuenta.» y un botón «Empezar». Es una pantalla de CONTINUIDAD, no una terminal de espera: por eso lleva CTA y no un texto pasivo. El copy no promete sincronización todavía —el motor acaba de arrancar—, solo que la cuenta existe.",
    persists: "El par `.cloud` + `mirrorOffArmed` (mismo escritor único) y **el motor del dominio arrancado EN ESTA SESIÓN**. El journal sigue en `notStarted`. No se marca ningún flag de onboarding: el onboarding es lo que viene después.",
    exits: "SIN back (`canGoBack` la trata como terminal, igual que `.relaunch`): la cuenta está creada y el par escrito. El CTA cierra el cover y enciende el onboarding NORMAL — explícitamente, porque la rama de respaldo del `onDismiss` devolvería al chooser del que el usuario acaba de salir.",
    code: [
      { t: "BornCloudSignUpService.swift:351-357", d: "sin mirror adjunto: breadcrumb `bornCloudReady`, arranque del motor y fase de continuidad" },
      { t: "BornCloudSignUpService.swift:176-180", d: "el seam del arranque: en producción es `CloudSyncRuntime.startShared`, y va DESPUÉS de escribir el par (al revés encontraría `.icloud` y se retiraría sin arrancar nada)" },
      { t: "WelcomeCloudSignInView.swift:504 `bornCloudReadyContent`", d: "la pantalla y su CTA" },
      { t: "WelcomeCloudSignInView.swift:203-213 `canGoBack`", d: "`.bornCloudReady` entra en la lista de fases sin salida" },
      { t: "ContentView.swift:1576-1587", d: "`onBornCloudCompleted`: cierra el cover y enciende `showOnboarding`" },
      { t: "ContentView.swift:1544-1550", d: "el término `!showOnboarding` del `onDismiss` — sin él, el respaldo montaría el chooser ENCIMA del onboarding recién abierto (regla 4 de Presentaciones)" }
    ],
    notes: [
      "⚠︎ Precisión sobre el enunciado del chip F3, MEDIDA: «el alta sigue directo al onboarding» no es exacto — hay una pantalla intermedia con CTA (`welcome_born_cloud_ready`). El Atlas dibuja la que existe.",
      "Sin el arranque en sesión, un alta que no relanza dejaría el motor apagado hasta el arranque siguiente: **nada sube, en silencio**. Los otros dos call-sites de `startShared` (boot y re-arranque del controller) corren ANTES de que el par exista, así que ninguno cubre este hueco; lo que lo pinnea es un source-scan del `init`, no un test de comportamiento."
    ]
  },

  "alta-postrelaunch": {
    title: "Onboarding normal en modo nube (con relanzamiento o sin él)",
    shot: "alta-postrelaunch.png",
    sees: "El `OnboardingView` de siempre. Se llega por el CTA de «Tu cuenta está lista» (instalación fresca, sin relanzar) o tras cerrar y reabrir la app (device que ya tenía archivo de store). Como `hasShownWelcomeChooser` ya es `true`, no se vuelve a pasar por el Welcome.",
    persists: "Lo que escriba el onboarding. El store personal monta SIN mirror de CloudKit y el motor de sync ya corre (arrancado en sesión por el alta, o al boot con fase `notStarted` = estable + el estampado del claim).",
    exits: "N/A — es el estado normal.",
    code: [
      { t: "WelcomeCloudSignInView.swift:631-636", d: "el alta NO marca los flags de onboarding: el onboarding es justamente lo que corre después" },
      { t: "MigrationBootDecision.swift:90 `isDomainStablePhase`", d: "`notStarted` y `done` son las dos fases estables" },
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
      { t: "WelcomeCloudSignInView.swift:654-659", d: "variante A de §f.1: sobre una cuenta poblada JAMÁS se siembra" },
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
      { t: "WelcomeCloudSignInView.swift:456 `waitingLeaderContent`", d: "la pantalla" },
      { t: "WelcomeCloudSignInView.swift:462-470", d: "la bifurcación del Reintentar por entrada" }
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
      { t: "CloudWelcomeSignInFlow.swift:140-143 `.releaseSessionAndShowError`", d: "el porqué, escrito en la tabla" },
      { t: "WelcomeCloudSignInView.swift:661-664", d: "signOut → `.error(retryable: true)`" }
    ],
    notes: []
  },

  "alta-error-403": {
    title: "403 · cuenta no disponible",
    shot: "alta-error-403.png",
    sees: "Error SIN botón de reintentar.",
    persists: "Nada.",
    exits: "Reintentar no despierta una cuenta suspendida — por eso el retry no se ofrece.",
    code: [{ t: "CloudWelcomeSignInFlow.swift:161-163", d: "`accountUnavailable` → `.error(retryable: false)`" }],
    notes: []
  },

  "alta-error-transient": {
    title: "Red / 5xx · transitorio",
    shot: "alta-error-transient.png",
    sees: "Error con botón Reintentar.",
    persists: "Nada.",
    exits: "El retry re-ejecuta `runFlowAfterConsent()` — el consent ya está aceptado, así que reentra por el sign-in (que se salta con sesión viva) y re-claima.",
    code: [{ t: "CloudWelcomeSignInFlow.swift:164-167", d: "el claim es idempotente ⇒ reintentar es seguro" }],
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
      { t: "BornCloudSignUpService.swift:242-254", d: "faro + estampado, solo con `created`" },
      { t: "AccountClaimDecision.swift:80-81", d: "`existing_stable` → `routeReturningUser`, NUNCA sembrar" }
    ],
    notes: [
      "⚠︎ Esto CORRIGE el criterio de hecho de A5 en el spec («cancelar deja el device exactamente como estaba: ni par, ni faro, ni consent»). Es la anotación 3 del punto de control, y aquí queda dibujada.",
      "Re-medido el 2026-08-11 (F3): las tres filas siguen siendo las mismas. Lo único que cambia con el relanzamiento cero es que, sobre un mount neutro, la fila 3 tampoco deja un relanzamiento pendiente — el par escrito ya coincide con el store montado."
    ]
  },

  // ══════════════════════════════════════════════════════════════════════════
  // FLUJO 2 · Returning-user / re-entrada
  // ══════════════════════════════════════════════════════════════════════════

  "reentry-chooser": {
    title: "Sub-chooser «Ya tengo una cuenta»",
    shot: "reentry-chooser.png",
    sees: "Hasta tres cards: Restaurar de iCloud · Entrar con Apple · Entrar con Google. Con una sola visible (producción DARK de hoy) hace bypass a Restaurar.",
    persists: "`hasShownWelcomeChooser = true` en el callback. **Si la opción elegida es Restaurar de iCloud y este proceso montó neutro**, además se persiste el destino y la salida es el terminal «reabre Yala» (R2).",
    exits: "Back → chooser.",
    code: [
      { t: "WelcomeAccountChoiceLogic.swift:60 `visibleExistingOptions`", d: "las cards de nube exigen configurado ∧ ¬uitest ∧ kill-switch nube" },
      { t: "WelcomeFlowContainer.swift:245-251 `handleExistingBranch`", d: "bypass con una sola opción" },
      { t: "WelcomeFlowContainer.swift:255-262 `handleExistingOption`", d: "R2: el sub-chooser y su bypass comparten PORTAL — `restoreICloud` → destino que necesita mirror; las dos entradas de nube montan el mismo store que el neutro ya es" },
      { t: "ContentView.swift:1452-1468", d: "el provider se setea EXPLÍCITO por card — jamás se hereda el del intento anterior" }
    ],
    notes: [
      "Residual ratificado por el owner: un usuario nube que REINSTALA bajo el kill-switch no ve la card ⇒ no re-entra hasta el re-encendido (WelcomeAccountChoiceLogic.swift:57-59).",
      "⚠︎ RE-DERIVADO el 2026-08-11 (F3): «Restaurar de iCloud» es el destino que NO admite matices — `RestoreProgressView` cuenta filas esperando la quiescencia del import de CloudKit, y sin mirror agotaría su timeout diciéndole al usuario que su cuenta está vacía. Por eso conserva el relanzamiento, ahora en su pantalla propia."
    ]
  },

  "reentry-intro": {
    title: "Intro de re-entrada",
    shot: "reentry-intro.png",
    sees: "Un solo botón, el del método que trae el `Entry` (o el que dictó el faro), más la nota §13.",
    persists: "Nada.",
    exits: "Back permitido.",
    code: [{ t: "WelcomeCloudSignInView.swift:345 `reentryIntro`", d: "el botón por provider y el subtítulo específico de Google" }],
    notes: []
  },

  "reentry-exists": {
    title: "Decisión · `GET /account/exists` (read-only)",
    shot: null,
    sees: "Spinner «Comprobando…» (`.checking`).",
    persists: "Nada — es read-only A PROPÓSITO: un claim con `created` CREARÍA la cuenta, por eso JAMÁS se claimea sin `exists == true` previo.",
    exits: "`sessionExpired` y `transient` colapsan a `failed(retryable: true)`.",
    code: [
      { t: "CloudWelcomeSignInFlow.swift:80 `route`", d: "4 outcomes → 3 rutas" },
      { t: "WelcomeCloudSignInView.swift:680-683", d: "`CloudAccountClient` SIN attest a propósito: `/account/exists` va por `requireUser` y es PRE-SESIÓN" }
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
      { t: "WelcomeCloudSignInView.swift:685-706", d: "el cableado: faro → veredicto → signOut → fase" },
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
    code: [{ t: "WelcomeCloudSignInView.swift:703-704", d: "`.proceed` del guard R9 ⇒ `.notFound` honesto" }],
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
      { t: "WelcomeCloudSignInView.swift:708-715", d: "el cableado; `hasLocalDataNow` es un fetch VIVO, no un snapshot (S5: el mirror puede estar re-importando durante el Welcome)" }
    ],
    notes: ["La MISMA cuenta re-entra libre: su claim persistido (`CloudClaimActionStore`, keyed por userID, sobrevive al sign-out a propósito) es la prueba de que el corpus local le pertenece."]
  },

  "reentry-blocked": {
    title: "Bloqueado · datos de otra identidad",
    shot: "reentry-blocked.png",
    sees: "«Estos datos son de otra cuenta» con el icono de escudo.",
    persists: "Sesión soltada antes de mostrar la pantalla.",
    exits: "Back permitido.",
    code: [{ t: "WelcomeCloudSignInView.swift:719-721", d: "signOut → `.blockedForeignData`" }],
    notes: ["El bloqueo existe porque el orphan-reconcile del adopt corre ANTES del relanzamiento y pushearía las filas del dueño a la cuenta entrante."]
  },

  "reentry-secondary": {
    title: "M1 · confirmación de sesión secundaria",
    shot: "reentry-secondary.png",
    sees: "«Entrarás con tu cuenta; los datos del dueño no se tocan» + CTA y Cancelar propio.",
    persists: "SOLO al confirmar, y EN ORDEN: claim → descriptor (`SecondarySessionStore.activate`) → flags de onboarding.",
    exits: "El Cancelar es PROPIO (suelta la sesión SIWA; el back genérico la dejaría colgada). Belt: si el modo persistido no es `.icloud`, hay estado corrupto ⇒ error, jamás armar.",
    code: [
      { t: "WelcomeCloudSignInView.swift:755 `confirmSecondaryEntry`", d: "el orden y su kill-safety" },
      { t: "WelcomeCloudSignInView.swift:725-734", d: "el belt del modo persistido" },
      { t: "CloudSyncFlags.swift:315 `secondarySessionEntryAvailable`", d: "M2: el gate de ENTRADA, ahora con **cuatro** términos y DOS flags remotos — el percent PROPIO del feature y el kill-switch del Modo Nube" },
      { t: "CloudRemoteConfig.swift:157 `secondarySessionEnabled`", d: "el percent propio que M2 le dio: hasta entonces esta entrada tomaba prestado el kill-switch del Modo Nube" }
    ],
    notes: [
      "⚠︎ RE-DERIVADO el 2026-08-12 (F5): **el DARK ya no lo pone el binario**. Hasta `b5dab36d` la entrada estaba apagada por la constante compilada; hoy la apaga un PERCENT REMOTO propio, y el kill del Modo Nube se conserva como segunda palanca porque son independientes y cualquiera corta la entrada — un kill-switch doble y gratis.",
      "Con el percent ausente (fresh install de producción antes del primer fetch) el término remoto es `absentDefault = false` ⇒ el guard cross-cuenta degrada la celda a «datos ajenos»: el usuario ve la pantalla honesta de hoy, jamás un error.",
      "Sigue siendo una ENTRADA: el kill la corta, pero una secundaria YA ACTIVA no se toca — mount y wipe honran el descriptor incondicionalmente, que es lo que hace barato usar el kill-switch."
    ]
  },

  "reentry-consentwrite": {
    title: "M0 · Decisión: dónde se registra el consent aceptado",
    shot: null,
    sees: "Nada. Ocurre entre el sign-in y la pantalla siguiente: el usuario ya aceptó en el sheet y lo único que cambia es en qué almacén cae su epoch.",
    persists: "Depende de la salida del guard cross-cuenta, y de nada más. `.proceed` (el propio dueño) → las dos keys se escriben ANTES de arrancar la máquina de adopt. `.proceedSecondarySession` (invitada M1) → DESPUÉS de `SecondarySessionStore.activate`, que es el único instante en que la resolución de prefs devuelve `.localOnly`. `.blockedForeignData` → **nunca** se escribe nada en este device.",
    exits: "Salida única por rama y de una sola vez: `pending` es `inout` y se consume al escribir, así que un retry tras `.error` vuelve a pasar por el guard sin mover el epoch de su T0. Matar la app entre aceptar y el veredicto NO deja registro —el pendiente vive en `@State`— y al reintentar el epoch será el de la SEGUNDA aceptación.",
    code: [
      { t: "CloudConsentRegistrationLogic.swift:44 `placement(for:)`", d: "la tabla, total sobre las tres salidas del guard: añadir una cuarta obliga a decidir su destino aquí y no en la pantalla" },
      { t: "CloudConsentRegistrationLogic.swift:32-39 `Placement`", d: "el porqué de cada punto: `beforeAdopt` porque el paso 5-bis del cutover re-emite el epoch PERSISTIDO y sin él cae al fallback `now()`, que es la hora de FIN del adopt" },
      { t: "WelcomeCloudSignInView.swift:738", d: "rama `.proceed`: la escritura va ANTES de arrancar el adopt" },
      { t: "WelcomeCloudSignInView.swift:784", d: "rama secundaria: la escritura va DESPUÉS de activar el descriptor — **ese orden ES el fix**" },
      { t: "PreferenceSyncService.swift:43 `PrefsSyncBehavior.resolve`", d: "la secundaria gana PRIMERO (`.localOnly`); si no, `.icloud` → iKV y `.cloud` → outbox. Es lo que hace que el DÓNDE sea propiedad del instante en que se escribe" }
    ],
    notes: [
      "MEDIDO: el alta born-cloud NO pasa por aquí. Su ruta ya se conoce al aceptar (no cruza el guard) y su claim la VERIFICA — aunque esa verificación solo comprueba PRESENCIA de las dos keys y hace ruido si falta alguna; no aborta nada.",
      "⚠︎ INFERIDO del código, no medido en device: el pendiente es `@State` y muere con la vista. Aceptar y no llegar al veredicto (kill, back desde `.notFound`, error no reintentado) deja la métrica de consent emitida y CERO registro GDPR en el device.",
      "Lo que sostiene el invariante es un source-scan del cableado, no un test de comportamiento: la tabla puede ser perfecta y sus tests verdes mientras la pantalla sigue escribiendo al aceptar."
    ]
  },

  "reentry-slotocupado": {
    title: "M1 · El hueco de invitada ya es de otra persona: se bloquea, no se mezcla",
    shot: "reentry-slotocupado.png",
    sees: "La misma pantalla honesta que ya existía para los datos ajenos: candado y «Este dispositivo tiene datos de otra cuenta». **No hay copy propio** para este caso — el hecho que se le cuenta a la segunda invitada es el mismo (aquí hay datos que no son tuyos), aunque los datos ajenos sean los de otra invitada y no los del dueño del móvil.",
    persists: "Nada. La sesión recién firmada se suelta antes de pintar —igual que la otra salida bloqueada del guard— y el descriptor sigue nombrando a la PRIMERA invitada, con sus archivos `-Secondary` intactos.",
    exits: "Terminal dentro del Welcome: se vuelve al chooser. Entrar habría sido montar el corpus de la primera invitada bajo la sesión de la segunda, porque `activate(userID:)` se limita a reescribir el nombre del ocupante del único hueco. La celda «misma cuenta» SÍ pasa a propósito: es la re-entrada idempotente de quien murió entre el descriptor y el relanzamiento, y bloquearla la dejaría sin forma de volver a su propia sesión.",
    code: [
      { t: "SecondarySlotOccupancyLogic.swift:46 `decide`", d: "la tabla entera: tres celdas — hueco libre, misma cuenta, ocupado por otro" },
      { t: "SecondarySlotOccupancyLogic.swift:47", d: "un descriptor vacío cuenta como hueco LIBRE, no como ocupante anónimo" },
      { t: "WelcomeCloudSignInView.swift:755 `confirmSecondaryEntry`", d: "el único call-site: compara el ocupante leído del store con el `sub` recién firmado, ANTES de armar la entrada" },
      { t: "SecondarySessionStore.swift:42 `activate(userID:)`", d: "lo que habría pasado sin el guard: un `set` del nombre nuevo sobre el mismo slot" }
    ],
    notes: [
      "⚠︎ El `userID` del descriptor existía desde antes y su docblock prometía por escrito que «valida que quien re-entra al slot es la misma cuenta»: hasta `9301b74d` **no tenía un solo consumidor de producción** — el mount pregunta `isActive()`, nunca *quién*.",
      "MEDIDO: la comprobación vive en la ENTRADA y en ningún otro sitio. El mount y el wipe honran el descriptor INCONDICIONALMENTE por diseño, para que una sesión ya activa no quede brickeada si el flag se apagara.",
      "Comparte copy con la pantalla de datos ajenos: si mañana hace falta distinguir «datos del dueño» de «datos de otra invitada», hace falta key nueva.",
      "En producción el camino entero es inalcanzable: la entrada secundaria sigue DARK (ver el nodo de la sesión secundaria)."
    ]
  },

  "reentry-adopt": {
    title: "Adopt en curso (máquina de migración)",
    shot: "reentry-adopt.png",
    sees: "Barra de progreso + «Conectando…». Si la pre-espera de quiescencia está activa aparece además el hint honesto de import.",
    persists: "Los flags de onboarding se marcan TEMPRANO (antes de conducir la máquina): un kill a mitad aterriza en MainTab con la card de Almacenamiento reflejando el estado real, y el seed del onboarding JAMÁS corre sobre una cuenta existente.",
    exits: "SIN back. Sin red, el drive corta retomable y el auto-resume entra.",
    code: [
      { t: "WelcomeCloudSignInView.swift:734-746", d: "`onAdoptStarted` → `startAdoptWithExistingSession` → poll" },
      { t: "CloudWelcomeSignInFlow.swift:92 `phase(for:)`", d: "mapea los 8 casos de `CloudMigrationUIState` a fase de pantalla; `reverting` y `needsRelaunch(.toICloud)` son IMPOSIBLES aquí y degradan a error no-retryable" },
      { t: "ContentView.swift:1561-1565", d: "`completeOnboardingAsRestoreSkip()` + `hasCompletedOnboarding`" }
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
      { t: "CloudWelcomeSignInFlow.swift:204 `WelcomeAdoptAutoResume.tick`", d: "la tabla del tick" },
      { t: "WelcomeCloudSignInView.swift:825 `evaluateAutoResume`", d: "el cableado + el belt: jamás conducir con el wipe de sign-out armado" },
      { t: "WelcomeCloudSignInView.swift:856 `retryAdoptResume`", d: "con el journal normalizado a `notStarted` sin efectos, `resumeIfNeeded` sería un no-op perpetuo ⇒ re-arranca el adopt" }
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
      { t: "CloudWelcomeSignInFlow.swift:99-102", d: "`needsRelaunch(.toCloud)` y `cloudActive` mapean los dos a `.relaunch`" }
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
      { t: "StorageRowGateLogic.swift:50 `isVisible`", d: "configurado ∧ ¬secundaria ∧ (remoto ∨ engaged)" },
      { t: "ProfileView.swift:939", d: "el cableado" },
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
      { t: "CloudMigrationController.swift:117 `fraction(for:)`", d: "la fracción por fase" },
      { t: "MigrationBootDecision.swift:123 `decide`", d: "resume / pollLeader / none" },
      { t: "MigrationBootDecision.swift:150 `shouldRekick`", d: "reusa la misma tabla en foreground" },
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
      { t: "CloudMigrationController.swift:77-83", d: "R1: `mirrorOffArmed && mountedDecision.attachesCloudKitMirror` ⇒ `needsRelaunch(.toCloud)`, y mira el armado SIN mirar el modo (por eso invertir el orden del par daría un bucle)" },
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
      { t: "MigrationBootDecision.swift:121-122", d: "los terminales de FALLO NO auto-resumen: es decisión del usuario" }
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
    title: "Cover terminal de cierre + wipe al boot — CAMINO DEGRADADO desde R4",
    shot: "signout-relaunch.png",
    sees: "Cover bloqueante «cierra y reabre». **Desde `21f10410` esto es la degradación, no el camino feliz**: en el cierre `.cloud` sale a pantalla igual —la fase entra en `.awaitingRelaunch` ANTES de intentar el swap— pero desaparece sola cuando el swap in-process se consuma. Se queda puesto solo si el swap no era posible o abortó.",
    persists: "`signOutWipeArmed`. El borrado real es de ARCHIVOS y corre en el BOOT pre-mount — el MISMO `performSignOutWipeIfArmed` que ejecuta el swap, no una copia, así que los dos caminos terminan en el mismo estado (par `.icloud` + neutro armado).",
    exits: "En `.cloud` NUNCA se borran FILAS en sesión: los deletes de filas quedan en la History y el remount con mirror los REPLAYARÍA hacia iCloud. El desarmado es SIEMPRE el último paso del boot-cleanup (un kill a mitad re-entra idempotente). El cover conserva además su auto-exit en background, que es anterior a esta tanda.",
    code: [
      { t: "CloudSignOutFlowLogic.swift:9-12", d: "el invariante F0, escrito en la cabecera" },
      { t: "CloudSyncFlags.swift:107-126", d: "armar / leer / desarmar el wipe" },
      { t: "ContentView.swift:1640 `SignOutRelaunchNetModifier`", d: "DUEÑO ÚNICO del cover; la presentación EFECTIVA solo la prueba el `onAppear` del contenido real" },
      { t: "CloudSessionSignOut.swift:308-330", d: "R4: el swap se intenta en la ÚLTIMA línea, con el wipe ya armado y el cover ya en pantalla; la fase vuelve a `.idle` SOLO si sale `.swapped`" },
      { t: "CloudSyncEngine.swift:442 `swapReleaseAborted`", d: "**la firma de esta degradación**: su `reason` distingue «alguien retiene el container» de «la conexión sigue abierta»" }
    ],
    notes: [
      "ProfileView ya NO presenta este cover: dos anchors ante el mismo observable eran una carrera de reconciliación que tumbaba AMBAS cadenas dejando el flag en `true` sin que ningún `onDismiss` corriera (bug de device del 2026-07-14).",
      "⚠︎ RE-DESCRITO el 2026-08-11 (F3). El nodo NO se borra a propósito: el camino sigue vivo y es el que ve cualquier cierre cuyo release no verifique. Si el swap rinde en device o no es la pregunta que solo el owner puede responder — y la superficie que lo dice sin abrir el código es el canario `swapReleaseAborted`."
    ]
  },

  "signout-swap": {
    title: "R4 · cambio de persona SIN relanzar (swap in-process)",
    shot: null,
    sees: "Sin pantalla propia: el cover terminal aparece un instante y se va solo; al terminar, la app está en el **Welcome** con el store vacío, lista para la persona siguiente. Los dos extremos ya están capturados por otros nodos (el cover en `signout-relaunch.png`, el aterrizaje en `alta-hero.png`).",
    persists: "Lo que deja el mismo wipe del boot: archivos del store personal y de `syncMeta` borrados, par repuesto a `.icloud`, `signOutWipeArmed` desarmado y **`cloudSync.neutralMountArmed` puesto** — el neutro DURABLE, que es lo que hace que el arranque siguiente monte sin mirror aunque el archivo ya exista.",
    exits: "Tres abortos, y son estados distintos: mount con mirror adjunto (fuera del alcance medido, ni se intenta) · el release no verifica (se repone el container y el usuario ve la pantalla de relanzamiento de siempre) · el wipe se consumó pero el remonte lanzó (disco consistente, cover terminal, y el arranque siguiente monta neutro y aterriza en el Welcome). **La red se conserva siempre**: el wipe de boot se arma ANTES de intentar nada y este camino jamás lo desarma por su cuenta.",
    code: [
      { t: "PersonalContainerSwap.swift:193 `attemptSignOutSwap`", d: "los 6 pasos y su orden: guard de alcance → colapsar la jerarquía → quiesce → canario → wipe → remonte" },
      { t: "PersonalContainerSwap.swift:204", d: "`releaseForSwap()`: poner el container a `nil` es lo único que se lleva los 37 ViewModels y los 67 `@Query` — una lista de retenedores no puede" },
      { t: "PersonalSwapReleaseLogic.swift:57 `verdict`", d: "«release verificado» = sentinel `nil` **Y** cero descriptores abiertos; el spike R3 midió que el `weak` a secas no discrimina (WAL persistente)" },
      { t: "PersonalContainerSwap.swift:302 `openDescriptorCountForPersonalStore`", d: "el instrumento portado del spike: `fcntl(F_GETPATH)` sobre el trío del store" },
      { t: "PersonalContainerSwap.swift:229", d: "el wipe es el MISMO `performSignOutWipeIfArmed` del boot" },
      { t: "SwiftDataConfiguration.swift:648 `armNeutralMount`", d: "el neutro durable lo arma el WIPE y no el coordinador: así el kill entre armar y borrar sigue siendo el no-op re-armable que el orden kill-safe tolera" },
      { t: "SwiftDataConfiguration.swift:534 `reopenPersonalStoreMountedDecisionCaptureForSwap`", d: "el testigo de mount se re-captura antes de evaluar la configuración nueva; congelado en `.cloudMirrorOff`, «Restaurar de iCloud» no pediría reabrir la app" },
      { t: "PersonalContainerSwap.swift:57 `PersonalContainerHost`", d: "el container pasa a ser ESTADO de proceso, con `generation` como `.id(...)` de la jerarquía" }
    ],
    notes: [
      "Alcance CERRADO a `performCloudSecureSignOut`: el secundario (M1), el solo-grupos y los dos cierres post-borrado de cuenta conservan su relanzamiento sin tocar. El cierre post-borrado comparte estado terminal y es el candidato natural del siguiente incremento — residual DECLARADO, ratificado por el punto de control.",
      "Ninguna transición que ENCIENDA o APAGUE un mirror entra aquí, y no es cautela: el eje 3 del spike R3 midió en device que el mirror `.private` emite eventos hasta 10 s DESPUÉS del release ⇒ el trabajo en vuelo de CloudKit sobrevive al container. Para este camino da igual (sin mirror por construcción); para cualquier debate del cutover es la pregunta previa.",
      "⚠︎ NO verificado y no verificable desde el repo: el e2e «A entra, sale, B entra sin una sola pantalla de relanzamiento». El host de tests no monta la jerarquía de vistas y el alta contra producción exige un build de distribución. Lo mide el owner; los canarios que lo dicen son `swapReleaseAborted` y `swapRemountFailed`."
    ]
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
      { t: "ProfileView.swift:416", d: "el dispatch a `exitYalaOnThisDevice`" }
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
      { t: "OnboardingView.swift:529-556", d: "el cableado de las dos decisiones" }
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
      { t: "OnboardingView.swift:546-554", d: "el cableado" }
    ],
    notes: ["Sin parámetro `isUITest` a propósito: bajo `-uitest` el canal está SIEMPRE ON, así que ningún XCUITest puede alcanzar la rama del muro."]
  },

  "onboarding-groupsonly": {
    title: "C2 · La card «Solo grupos» ya no cierra el alta: la CEDE",
    shot: "onboarding-groupsonly.png",
    sees: "El último paso del onboarding de 8 pasos en su variante solo-grupos. Al terminarlo el usuario **ya no aterriza en el tab**: entra en la misma cadena que la rama organizador del Welcome —educativo, cuenta, permiso— y solo al final se le da de alta y se le lleva a Grupos.",
    persists: "**NADA en este paso, y ese es el chip entero.** El nombre y la divisa viajan EN MEMORIA hasta que la cadena confirma identidad y consent; el alta la escribe `GroupsOrganizerOnboarding.completeSetup` al final, con sus seis keys y sus semillas. Sigue sin crear cuenta personal ni presupuesto. En sesión SECUNDARIA no escribe ni una key y el alta no ocurre.",
    exits: "Ya no es un terminal. Cancelar en cualquier escalón descarta el payload y devuelve al chooser de Grupos del Welcome —no al onboarding de 8 pasos, que ya se cerró—. En sesión secundaria la rama entera se desvía a la puerta del Welcome, que es la que sabe pintar ese veredicto: un `return` mudo dejaría un botón que no hace nada.",
    code: [
      { t: "OnboardingView.swift:1768-1777", d: "la rama ya no escribe: entrega el payload y cede; **sin el callback cableado NO completa**, a propósito — el fallback de antes era escribir el trío sin cuenta" },
      { t: "OnboardingView.swift:1835-1849", d: "la LÁPIDA: qué escribía `completeGroupsOnlyOnboarding()` y por qué era irreversible. No se dejó como código muerto porque un método privado que sigue compilando es lo que alguien vuelve a llamar" },
      { t: "ContentView.swift:733 `startGroupsOnlyBranch`", d: "guarda el payload, cierra el onboarding y submitea sin presentar nada a pelo" },
      { t: "ContentView.swift:1003", d: "`entry = .onboardingCard` cuando hay payload: comparte cadena y terminal con la rama organizador" },
      { t: "ContentView.swift:1013-1029", d: "`case .presentName` CON payload: no se vuelve a preguntar el nombre, se ESCRIBE, y se re-submitea para que la máquina re-decida" },
      { t: "GroupsOrganizerOnboarding.swift:218 `completeSetup`", d: "el sustituto, con DOS call-sites de producción y los dos detrás de la cadena completa" }
    ],
    notes: [
      "⚠︎ **EL AGUJERO DE DATOS SIGUE ABIERTO Y CAMBIÓ DE DUEÑO** — re-medido el 2026-08-12 sobre HEAD `6c6eb3fe`: el sustituto `completeSetup` TAMPOCO toca `storageMode` (no aparece ni en su inventario de keys ni en su cuerpo), y ninguno de los escritores del modo de storage está en la cadena de Grupos ⇒ el device queda `.icloud` y, sin cuenta iCloud del OS, monta local-sin-mirror: las `TransactionItem` puenteadas desde los gastos de grupo **siguen sin ninguna copia**. Sin re-anclar el hallazgo a `completeSetup`, el borrado de la función vieja lo haría parecer resuelto.",
      "Lo que C2 SÍ cierra es otra cosa, y está cerrado: que el trío se escribiera sin cuenta, sin consent y sin canal comprobado. Los datos del GRUPO tienen ahora respaldo en la cuenta; lo que no lo tiene es su espejo personal.",
      "MEDIDO: el retiro de los grupos de la era CloudKit (`43b473c8`) **no** toca este camino ni lo cierra — su barrido solo alcanza zonas sin canal vivo, y un alta solo-grupos de hoy nace en el canal backend.",
      "Lo que el borrado se llevó sin que nadie lo listara fue el guard de sesión secundaria de la función eliminada; reponerlo en el destino es lo que hace `ec551b71`."
    ]
  },

  "onboarding-puertas": {
    title: "C2 · las CUATRO puertas de Grupos, una sola tabla",
    shot: null,
    sees: "Nada: es la decisión de qué pantalla toca ahora. Lo que el usuario nota es el ORDEN — primero le cuentan qué es un grupo, después se le pide la cuenta, después el permiso, y solo al final el nombre.",
    persists: "Nada **a propósito, y es la invariante entera del chip**: nombre, modo y consent se escriben JUNTOS y al final, en `GroupsOrganizerOnboarding.completeSetup`. `onboardingMode = .groupInvite` es never-downgrade cross-device y viaja al iKV del Apple ID: escrito antes de confirmar la ruta, se propaga a los otros dispositivos de esa cuenta —donde el usuario ve una app recortada a Grupos y vacía— y **no vuelve**; su única recuperación sería restaurar por iCloud.",
    exits: "Cada llamada RE-EVALÚA condiciones vivas en vez de recordar en qué paso iba, así que un sign-in hecho en otra pantalla, un consent aceptado por otra vía o un kill-and-relaunch a mitad no dejan la máquina desalineada.",
    code: [
      { t: "GroupsGateLogic.swift:105 `nextStep`", d: "la SSOT: precedencia educativo → sign-in → consent → terminal por entrada" },
      { t: "GroupsGateLogic.swift:56-67 `Entry`", d: "las cuatro puertas: `.organizer` (Welcome) · `.onboardingCard` (card «Solo grupos») · `.invite` (link backend) · `.tab` (crear desde el tab)" },
      { t: "GroupsGateLogic.swift:135 `showsEducationalFirst`", d: "el educativo general se antepone SOLO en dos: al invitado le tocaría uno detrás de otro y en el tab competiría con el sheet que ya lo monta" },
      { t: "GroupsGateLogic.swift:93-97", d: "el término es `hasShownGroupsOnboarding`, el hecho REAL. El corte anterior (`onboardingMode == .groupInvite`) suprimía el educativo justo a quien entraba por la card «Solo grupos» — la gente con MENOS contexto" },
      { t: "GroupsGateLogic.swift:37-43", d: "el canal NO entra aquí: vive en `GroupCreateRoutingLogic` y en `GroupsOrganizerGateLogic`, y en los dos es el PRIMER término" }
    ],
    notes: [
      "⚠︎ La cuarta puerta —la card «Solo grupos» del onboarding de 8 pasos— **no pasaba por ninguna tabla**: escribía el trío (`userName`, `onboardingMode`, `groupsBetaUnlocked`, `hasCompletedOnboarding`) sin sesión, sin consent y sin canal comprobado. Las otras tres se prometían paridad por docblock, que es como divergen.",
      "MEDIDO y anotado en el propio código: esta tabla es PURA y recibe el canal ya leído, así que puede estar perfecta y sus tests verdes mientras un llamador mide un snapshot de hasta 6 h. Lo que fija el `refreshIfDue(force: true)` antes de la lectura son los source-scan de los call-sites, no esta tabla."
    ]
  },

  "onboarding-adopcion": {
    title: "G2 · Entrar al tab Grupos ES el acto de adopción (murió el código «1050»)",
    shot: null,
    sees: "Lo que se ve es una pantalla que **ya no existe**: el tab Grupos monta su contenido sin condición. Desaparecen la pantalla de bloqueo con el campo del código, el alert «tengo un código» de la card de «Más», el badge «Beta» de esa card y el gateo de la opción «Grupo» del FAB en Panel, Registros y Estadísticas — hoy se muestra siempre.",
    persists: "`groupsBetaUnlocked = true`, escrito en el `onAppear` del tab. La key conserva su string histórico a propósito: renombrarla obligaría a migrar el parque sin ganar nada. Con la key ya puesta no se escribe nada, y en una sesión SECUNDARIA no se escribe nada en absoluto.",
    exits: "No hay deshacer: la adopción es per-device y permanente. El único camino que la repone es «empiezo de cero» del Welcome ⇒ ⚠︎ cerrar una sesión de invitada NO la repone, y por eso el guard de sesión secundaria es lo que impide que la invitada le deje al dueño el dominio adoptado.",
    code: [
      { t: "ContentView.swift:2354-2365", d: "el tab monta el contenedor de Grupos SIN condición" },
      { t: "ContentView.swift:2370", d: "el cableado del marcador de adopción, en el `onAppear`" },
      { t: "GroupsDomainAdoptionLogic.swift:40 `isDomainOpen`", d: "`isUnlocked || isGroupInviteMode`; quitar el segundo término cerraría el bridge al invitado normal, que es la mayoría" },
      { t: "GroupsDomainAdoptionLogic.swift:66-70 `isBridgeAllowed`", d: "el default es PERMITIR; solo el device sellado por un fresh-start queda cerrado" },
      { t: "MoreView.swift:242", d: "la card, sin badge y con navegación directa: el alert de intro y el modifier del código se borraron" },
      { t: "FABStackView.swift:182-186", d: "la opción «Grupo» ya no lleva gate: se pinta siempre en los tres hosts" }
    ],
    notes: [
      "**Cierra el hallazgo F2-H1.** MEDIDO con grep sobre este árbol: cero ocurrencias de `GroupsBetaGateView`, del campo del código y del gate del FAB; las 6 keys del gate se retiraron de los 16 idiomas. Lo único que sobrevive es el STRING de la key de `UserDefaults`.",
      "⚠︎ MEDIDO: hay CUATRO escritores de la adopción en producción —el tab, la invitación warm, la invitación con el flag apagado y el alta solo-grupos— y **solo dos llevan guard de sesión secundaria**.",
      "MEDIDO: Grupos no es un tab activo por defecto, así que la puerta normal al tab —y por tanto a la adopción— es la card de «Más»."
    ]
  },

  "onboarding-consent": {
    title: "C1 · El consent de Grupos — una sola pantalla para las cuatro puertas",
    shot: "onboarding-consent.png",
    sees: "«Grupos en la nube» y cuatro puntos: que los grupos viven en la nube de Yala para que todos vean lo mismo, que solo sale el alias y los gastos del grupo, que las finanzas personales no se mueven, y que los datos viajan protegidos y se puede salir cuando se quiera. Debajo, el enlace a la política de privacidad y «Aceptar y continuar».",
    persists: "Al aceptar, y EN ESTE ORDEN: el snapshot local **sellado con el `sub`** de la cuenta, el intent durable del registro, y —cuando haya red— la fila en `groups_consents` de la cuenta. La hora guardada es la de la ACEPTACIÓN, jamás la del reintento que consiguió red.",
    exits: "Aceptar cierra el sheet y la continuación corre en el `onDismiss`, con la dismissal ya terminada. Cancelar no continúa nada: el invitado se queda como estaba —su intent sobrevive 7 días— y al organizador se le apaga la rama y vuelve al chooser de Grupos. **El registro contra la cuenta NO bloquea**: la caché local se escribe siempre, así que la puerta no depende del request.",
    code: [
      { t: "GroupsConsentView.swift:116-118 `registerConsent`", d: "choke-point único: `GroupsConsentRegistrar.register` + la métrica" },
      { t: "GroupsConsentRegistrar.swift:88 `register`", d: "caché local → arma el intent → lanza el intento; sin sesión escribe la caché y no arma" },
      { t: "GroupsConsentDecisionLogic.swift:53 `isAccepted`", d: "las tres reglas: sin snapshot no; versión por debajo de la sustantiva no; sello que contradice al `sub` vivo, tampoco" },
      { t: "GroupsConsentText.swift:41-47", d: "`version = 1` y `requiresReacceptanceFrom = 1` ⇒ hoy nadie vuelve a ver esta pantalla por versión" },
      { t: "GroupsBackendInviteModifier.swift:143", d: "el ÚNICO call-site de la vista; el `path` sale de `groupsOrganizerFlowActive`" }
    ],
    notes: [
      "⚠︎ El `path` que llega al servidor nunca vale `\"tab\"`, aunque el docblock de la vista declare `organizer | invite | tab`: el único call-site discrimina por `groupsOrganizerFlowActive`, así que un consent aceptado desde el FAB o desde el empty state del tab se registra como `\"invite\"`. Es diagnóstico, no PII — pero es justo el campo con el que se sabría por dónde entra la gente.",
      "⚠︎ El header del fichero sigue citando `GroupsConsentState.register()` (PrefSyncKeys §C5). Ese método ya no existe: C1 lo sustituyó por `GroupsConsentRegistrar` y las dos `PrefSyncKey` salieron del enum.",
      "El sheet lleva `path` como parámetro y no como rama: la pantalla es literal para las cuatro puertas, sin variantes de copy."
    ]
  },

  "onboarding-consentcuenta": {
    title: "C1 · Tu permiso viaja con tu cuenta (decisión, sin pantalla)",
    shot: null,
    sees: "Nada nuevo — se nota por lo que YA NO pasa: quien aceptó en su iPhone y entra con su cuenta en el iPad, o reinstala, no vuelve a ver la pantalla de consentimiento.",
    persists: "En la CUENTA: una fila en `groups_consents` con `(user_id, text_version)` y la fecha de aceptación, append-only **por el grant** (`select, insert`, sin `update` ni `delete`). En el DISPOSITIVO: el snapshot sellado y, mientras no haya 2xx, el intent durable con el `sub` de su dueño dentro.",
    exits: "Sin sesión no se arma nada (no hay cuenta a la que atribuirlo) y la caché local se escribe igual. Un intent cuyo `sub` no case con la sesión viva ni se intenta ni se descarta: espera a su dueño. Un rechazo permanente del servidor CONSERVA la prueba y emite canario en vez de tirarla. `clear()` es solo local: la cuenta sigue recordando su consent.",
    code: [
      { t: "GroupsConsentRegistrar.swift:179 `handleSignIn`", d: "las tres mitades en una llamada: adoptar el legacy, retomar el intent, traer el estado de la cuenta" },
      { t: "GroupsConsentRegistrar.swift:188 `adoptLegacyIfNeeded`", d: "sella con el `sub` vivo el consent que el device tenía sin identidad y ARMA su registro — para el grueso del parque esto CREA el registro, no lo mueve" },
      { t: "GroupsConsentRegistrar.swift:209 `refreshFromServer`", d: "un fallo de red nunca borra ni degrada la caché" },
      { t: "GroupsConsentRegistrar.swift:226 `applyServerState`", d: "solo sella si lo remoto es igual o más nuevo: lo local puede ser una aceptación de hace un segundo cuyo registro aún viaja" },
      { t: "GroupsMembershipClient.swift:506 `consentState`", d: "la lectura va por su propio RPC y NO por el canal de prefs — la frontera M1 sigue cerrada" },
      { t: "AppBootstrapper.swift:530-531", d: "el retome del boot, sin `awaitPersonalStoreReady`: aquí no hay `save()` que proteger" }
    ],
    notes: [
      "El problema que cierra: antes el permiso acababa en el iCloud del Apple ID de ESE teléfono —el `storageMode` por defecto es `.icloud` y Grupos va al 100 % sin exigir Modo Nube— y no llegaba nunca a Yala, así que el segundo dispositivo preguntaba otra vez.",
      "⚠︎ MEDIDO en el ORDEN del código, no cronometrado: en el mismo flujo, el sign-in dispara `handleSignIn()` dentro de un `Task` y acto seguido cierra el sheet; el `onDismiss` re-decide leyendo la caché LOCAL de forma síncrona, y no hay ningún `await` que ordene las dos cosas ⇒ la promesa «entras en tu iPad y la app ya lo sabe» se cumple en la evaluación SIGUIENTE, no necesariamente en esa.",
      "El canario de `resumeIfNeeded` va antes de todo early-return **de aplazamiento** (in-flight, sin sesión, `sub` que no casa, backoff); el `.idle` de «no había intent» queda fuera a propósito, y es lo que hace que «frenados» y «no había nada» se distingan en el dashboard. El docblock del método dice «antes de todo early-return» a secas — es impreciso, medido el 2026-08-12."
    ]
  },

  "onboarding-canalapagado": {
    title: "C4 · Crear grupo con el canal apagado: no nace nada",
    shot: "onboarding-canalapagado.png",
    sees: "Al tocar «crear grupo» (empty state, FAB simple, FAB desplegable o el formulario que deja la rama organizador), un aviso con vibración de advertencia: «Ahora mismo no podemos abrirte grupos». La lista sigue como estaba. Si el bloqueo se detecta ya DENTRO del formulario, el mismo texto sale como error de guardado y el formulario **no se cierra** — tras el dismiss no quedaría nadie que pudiera contárselo.",
    persists: "Nada, y eso es el chip entero: ni `SplitGroup`, ni `onboardingMode`, ni `groupsBetaUnlocked`, ni `hasCompletedOnboarding`.",
    exits: "«OK» cierra el aviso y devuelve al tab. El canal se re-mide EN EL PROPIO TAP: `refreshIfDue(force: true)` va antes de leer el flag, porque sin `force` es un no-op exactamente en el caso del bug.",
    code: [
      { t: "GroupCreateRoutingLogic.swift:77", d: "`guard flagOn else { return .channelOff }` — el canal es el PRIMER término" },
      { t: "GroupCreateRoutingLogic.swift:51 `case channelOff`", d: "la ruta que sustituye a `.cloudKit`, muerta desde `ad291c7f`" },
      { t: "GroupsContainerView.swift:706-711 `requestCreateGroup`", d: "choke-point de las CUATRO entradas de creación del tab, con el `force` dentro y no replicado" },
      { t: "GroupsContainerView.swift:321-328", d: "el alert, que reusa `welcome.groups.channelOff*`" },
      { t: "GroupFormView.swift:286-292", d: "la segunda superficie: dentro del formulario el bloqueo se dice como error de guardado y NO cede el anchor" }
    ],
    notes: [
      "⚠︎ Lo que había antes: este mismo tap acuñaba un grupo LOCAL con `isBackendGroup == false` — de una sola persona, no invitable y sin vía de migración, para siempre y sin ningún error visible, porque el camino funcionaba offline. Y no era una ventana de instalaciones nuevas: bajar el percent del canal a 0 —la respuesta operativa documentada a un incidente— dejaba a TODO el parque así en ≤6 h con la CTA intacta, o sea que el remedio encendía la fábrica de grupos zombis.",
      "⚠︎ NO es ejercitable en el harness, y está dicho para que nadie lo persiga: `CloudRemoteFlags.decide()` cortocircuita a `absentDefault` bajo `isRunningTests || isUITestHost`, y en `Yala Dev` ese default es `true` ⇒ el flag nace ON y `.channelOff` es inalcanzable desde un test de integración en los dos targets. La red es estructural (tabla + source-scan del orden), no un e2e.",
      "El dominio de la tabla es 2×2×2 = 8 celdas y cuatro rutas; las CUATRO celdas con el canal apagado devolvían `.cloudKit` y hoy devuelven `.channelOff`."
    ]
  },

  "onboarding-educativo": {
    title: "Educativo del tab Grupos + CTA de sign-in",
    shot: "onboarding-educativo.png",
    sees: "Sheet informativo de tres pasos. El último, «Tu privacidad, primero», abre desde C2 con el hecho SUSTANTIVO —dónde se guardan los gastos del grupo— y solo después tranquiliza. Sin sesión y con el canal ON, el botón principal es «Crear mi cuenta» si este móvil nunca tuvo sesión, o «Iniciar sesión» si ya la tuvo.",
    persists: "`hasShownGroupsOnboarding` solo si se COMPLETA —la «X» no la persiste, así que volverá a aparecer— tanto en «Ir a Grupos» como en el CTA de cuenta: el educativo terminó en los dos casos. Es la misma marca que escriben el educativo del invitado y el cover de las puertas A y B.",
    exits: "El CTA NO es un muro: quien lo salte cae en el empty state, que ya pide lo que falte. El intent se emite con el sheet YA desmontado (`onDismiss`) — emitirlo con el sheet puesto lo dejaría RETENIDO por peek-first.",
    code: [
      { t: "GroupsOnboardingLogic.swift:37 `hasSeenAnyGroupsEducational`", d: "C2: el hecho REAL que sustituye al corte por `onboardingMode == .groupInvite`, que suprimía el educativo justo a quien menos contexto tenía; ese modo queda solo como término LEGACY" },
      { t: "GroupsOnboardingLogic.swift:56 `shouldShow`", d: "AND-gating: educativo ya visto o deeplink de grupo pendiente bloquean" },
      { t: "GroupsOnboardingLogic.swift:84 `shouldShowSignInCTA`", d: "último paso ∧ canal ON ∧ sin sesión" },
      { t: "GroupsContainerView.swift:431", d: "el cableado, en el `onAppear` del tab" },
      { t: "GroupsOnboardingView.swift:312-315", d: "el copy del CTA lo decide el MISMO latch que el empty state, no una segunda fuente" }
    ],
    notes: [
      "⚠︎ Este nodo es el educativo del TAB (sheet). Las puertas A y B montan el MISMO contenido como fullScreenCover desde `GroupsBackendInviteModifier`, con otras salidas.",
      "⚠︎ Cerrar con la «X» deja el FAB y la CTA del empty state alcanzables, y la puerta del tab pasa `hasSeenEducational: true` LITERAL ⇒ **es la única puerta por la que se puede crear o firmar sin haber visto nunca el educativo**."
    ]
  },

  "onboarding-empty": {
    title: "Empty state del tab Grupos · CINCO casos (C2)",
    shot: "onboarding-empty.png",
    sees: "Cinco copys según lo que FALTE, en la misma precedencia que la tabla de las cuatro puertas: «¿Cómo funcionan los grupos?» (aún no vio el educativo) · «Crea tu cuenta de Yala» (sin sesión y nunca tuvo) · «Tus grupos están en tu cuenta» (sin sesión pero ya tuvo) · «Un último paso» (sesión viva sin consent) · «Sin grupos» con «Crear grupo» (no falta nada, solo el grupo).",
    persists: "Nada.",
    exits: "Cada caso lleva a lo que anuncia, y **esa correspondencia es el invariante**: educativo → el sheet del educativo · crear-cuenta y re-entrada → el MISMO intent de sign-in (la vista crea la cuenta además de recuperarla; lo que cambia es el copy) · consent → el mismo intent que emite crear grupo · estándar → el choke-point `requestCreateGroup`. Con el canal OFF SIEMPRE es el estándar ⇒ el shipping DARK queda byte-idéntico.",
    code: [
      { t: "GroupsEmptyStateLogic.swift:67 `decide`", d: "precedencia canal → educativo → identidad (crear vs. volver) → consent → estándar" },
      { t: "GroupsEmptyStateLogic.swift:74-78", d: "las cinco líneas que producen los cinco casos" },
      { t: "GroupsContainerView.swift:354", d: "el cableado, con la identidad de accesibilidad preservada por rama" },
      { t: "GroupsSessionHistoryMarker.swift:59 `hadSessionEver`", d: "el latch monotónico que separa «vuelve a tu cuenta» de «crea una cuenta»" },
      { t: "YalaEmptyState.swift:183", d: "las variantes nuevas y sus ids de accesibilidad" }
    ],
    notes: [
      "⚠︎ Lo que C2 arregla eran DOS mentiras, no una: con dos casos, todo el que no tenía sesión leía «tus grupos están en tu cuenta · inicia sesión». Para quien **nunca tuvo cuenta** —el caso dominante en un fresh install— eso es falso dos veces: no hay grupos suyos esperando en ninguna parte, y no hay sesión que «iniciar» porque la cuenta hay que CREARLA. Y faltaba un tercer estado real: sesión viva sin consent, donde el tap mandaba a una pantalla de consentimiento que el usuario no esperaba.",
      "MEDIDO antes de usarlo: `hadSessionEver` **no** puede ser `GroupsSignOutBannerMarker` — ese es one-shot (se quema en el `onAppear` del banner y se desarma al re-firmar), así que en cuanto el banner se muestra una vez, quien SÍ tuvo cuenta volvería a leer «crea una cuenta».",
      "⚠︎ El latch es per-device y no viaja: quien ya tiene cuenta y estrena móvil lee «Crea tu cuenta de Yala».",
      "⚠︎ El caso `.needsEducational` casi nunca se ve solo: la misma condición hace que el sheet del educativo se presente en el `onAppear` del tab. Queda a la vista tras cerrarlo con la «X», que no marca nada.",
      "Fuera de v1 y DOCUMENTADO: el caso «sin sesión + grupos CloudKit todavía visibles» no aplica aquí — el empty state solo se pinta con la lista VACÍA."
    ]
  },

  "onboarding-crear": {
    title: "Crear grupo · sign-in contextual",
    shot: "onboarding-crear.png",
    sees: "El formulario de grupo — o, antes, lo que la puerta del tab diga que falta: el sign-in de Grupos o el consent. Desde C4 hay una cuarta salida: con el canal apagado no se abre nada y sale el aviso.",
    persists: "Nada hasta guardar.",
    exits: "Residual DOCUMENTADO: no hay auto-continuación — tras el consent o el sign-in el usuario re-tapea «crear grupo».",
    code: [
      { t: "GroupCreateRoutingLogic.swift:76 `route`", d: "C4: canal OFF → `.channelOff` (antes `.cloudKit`, que acuñaba un grupo local irrecuperable); sin sesión → sign-in; sin consent → consent; listo → backend" },
      { t: "GroupCreateRoutingLogic.swift:78-84", d: "delega en la tabla de las cuatro puertas con `entry: .tab`, en vez de reimplementar la precedencia" },
      { t: "GroupsContainerView.swift:706 `requestCreateGroup`", d: "choke-point de las CUATRO entradas de creación del tab; cede el anchor a ContentView para presentar" }
    ],
    notes: [
      "⚠︎ La entrada `.tab` es la única de las cuatro que NO antepone el educativo: lo monta el sheet del `onAppear`. Quien lo cierre con la «X» puede crear o firmar sin haberlo visto nunca — ver el panel del educativo."
    ]
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
      { t: "CloudRemoteConfig.swift:134-148", d: "`cloudModeEnabled` · `cloudOnboardingChoiceEnabled` · `groupsBackendEnabled` (el remoto solo puede MATAR)" },
      { t: "CloudRemoteConfig.swift:120 `absentDefault`", d: "fail-closed en producción" },
      { t: "StorageRowGateLogic.swift:50", d: "engaged conserva la fila" },
      { t: "WelcomeFlowContainer.swift:199-205", d: "el refresh en la entrada; bajo uitest NO se toca red" }
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
      { t: "CloudMigrationController.swift:582 `refreshSyncBanner`", d: "cuenta las filas VIVAS del outbox" },
      { t: "CloudMigrationController.swift:601 `signInToResumeSync`", d: "el belt: si la sesión revivió por otra entrada, solo despierta la cadencia" }
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
      { t: "MigrationBootDecision.swift:85 `isPersonalMountMismatch`", d: "R1: persistido `.cloud` ∧ el mount ADJUNTA mirror (`attachesCloudKitMirror`) — antes preguntaba por un `StorageMode` de dos valores, que no podía expresar un mount sin mirror que no fuera el de modo nube ni la secundaria" },
      { t: "CloudSyncRuntime.swift:260-268", d: "el cableado" },
      { t: "CloudSyncEngine.swift:800", d: "el breadcrumb `personalMountMismatch`" }
    ],
    notes: [
      "⚠︎ ACOTADO por la tanda del relanzamiento cero (`339f7825`, medido el 2026-08-11): en una instalación FRESCA el mismatch ya no ocurre — el mount es neutro, no adjunta mirror, y tras escribir el par el guard DEJA PASAR ⇒ el motor arranca en sesión. La ventana sobrevive solo en el device que llega al alta CON archivo de store (o en el adopt), que es donde sigue habiendo un relanzamiento de por medio. El hueco de observabilidad no se cierra: se estrecha.",
      "⚠︎ HUECO DICHO, no silenciado: el chip F1 lo nombra como «la pantalla de relanzamiento pendiente» y MEDIDO no existe tal pantalla para este guard. Lo que sí pinta una card es `CloudMigrationUIStateDeriver` cuando el par está armado (`needsRelaunch(.toCloud)`), y esa card vive en Almacenamiento — inalcanzable durante el alta born-cloud, porque el onboarding aún no ha terminado.",
      "En la práctica el usuario del alta no puede escapar: la fase `.relaunch` es terminal, sin back y con `interactiveDismissDisabled()`. El guard es la red por si alguien mañana escribe el par sin relanzar: el motor se queda quieto en vez de duplicar escrituras.",
      "En `.icloud` el término es `false` por construcción ⇒ inerte para el 99 % del parque."
    ]
  },

  "degradado-neutro": {
    title: "R2/R4 · el mount NEUTRO (decisión, sin pantalla)",
    shot: null,
    sees: "Nada: es la decisión de qué store monta el proceso, y se toma antes de la primera pantalla. Lo único observable en la app es el panel DEBUG de nube, que desde R1 enseña la DECISIÓN de mount y, entre paréntesis, si el mirror está adjunto.",
    persists: "El mount en sí no persiste nada. Lo que lo HABILITA sí es durable, y son dos hechos distintos con dos evidencias distintas: en un fresh install, que NO exista el archivo del store (R2); tras un cierre de sesión, la marca `cloudSync.neutralMountArmed` que escribe el wipe (R4). Los dos exigen además `hasShownWelcomeChooser == false`, y ese término es lo que hace el bucle imposible: el neutro dura hasta que el usuario elige.",
    exits: "Elegir cualquier destino de nube (alta o re-entrada) no remonta nada — el neutro ya ES `cloudKitDatabase: .none`. Elegir un destino que vive DEL mirror (onboarding privado, restaurar de iCloud, recuperar invitación) pide reabrir la app.",
    code: [
      { t: "SwiftDataConfiguration.swift:242 `neutralNoMirror`", d: "la quinta salida de la tabla de mounts, con `.none` EXPLÍCITO — byte-idéntica a `.cloudMirrorOff` como `ModelConfiguration`, y esa identidad es la razón de ser del chip" },
      { t: "SwiftDataConfiguration.swift:266 `isFreshInstallForNeutralMount`", d: "los 4 términos PRE-MOUNT; el primero (sin archivo de store) es la protección ESTRUCTURAL: el parque actual no puede alcanzar el camino nuevo" },
      { t: "SwiftDataConfiguration.swift:296 `shouldMountNeutralDurable`", d: "R4: marca armada ∧ chooser no visto" },
      { t: "SwiftDataConfiguration.swift:333 `personalStoreDecision`", d: "el orden de la cadena: secundaria → par `.cloud`+armado → neutro → iCloud/local. Los dos términos nuevos van SIN default para obligar a todo llamador a pronunciarse" },
      { t: "SwiftDataConfiguration.swift:1049-1054", d: "la rama del mount, con el porqué del `.none` explícito medido en la auditoría R1(c)" },
      { t: "SwiftDataConfiguration.swift:1009 `shouldOfferICloudRestart`", d: "R1: el aviso «monté sin CloudKit y ahora hay iCloud» decide por el MOUNT (`isCloudModeMount`) y no por el modo persistido ⇒ al neutro SÍ le habla, que es lo que pedía §1.3" },
      { t: "CloudSyncDebugView.swift:530", d: "la única superficie que lo enseña dentro de la app" }
    ],
    notes: [
      "`.automatic` NO es un atajo de `.none`: la auditoría R1(c) MIDIÓ (sim sin cuenta iCloud, con control positivo y negativo) que `.automatic` adjunta el mirror igual —mismos eventos de `NSPersistentCloudKitContainer` que `.private`— mientras `.none` emite cero. Omitir el parámetro sería el mount CONTRARIO al que este caso declara.",
      "Corolario del testigo: el neutro NO es `isCloudModeMount` (eje C) pero sí es `!attachesCloudKitMirror` (eje A). Esa separación es lo que deja pasar el motor tras el alta y a la vez mantiene vivo el aviso de iCloud — un booleano colapsado no podía expresar las dos cosas."
    ]
  },

  "degradado-legacyretire": {
    title: "C3 · El barrido que retira los grupos de la era CloudKit",
    shot: null,
    sees: "**NADA en el momento en que ocurre.** Entre un arranque y el siguiente, los grupos creados en la etapa CloudKit dejan de aparecer en el tab Grupos y en «Más», y sus espejos «presté 40» / «debo 10» desaparecen de Panel, presupuestos y reportes. Si esos eran sus únicos grupos, el usuario aterriza en el empty state sin que nada le explique por qué.",
    persists: "Por cada zona sin canal vivo: el grupo se marca oculto **en todas sus filas —la fila jamás se borra—**, los tres punteros de grupo se nilean en las transacciones de cuenta real, las del espejo virtual se BORRAN y los borradores del grupo pasan a manuales o se borran. Un solo `save()`, y después el canario `legacyGroupsRetired` con recuentos y sin PII. Con el resultado vacío no hay ni `save()` ni canario.",
    exits: "No hay salida: es un `Task` del arranque. **Falla CERRADO en dos niveles** —el fetch global que lanza no retira nada; el fetch de UNA zona que lanza salta esa zona con el grupo todavía visible— porque ocultar un grupo sin soltar su puente dejaría las transacciones colgando de una zona invisible, que es el fantasma que esto viene a evitar. Es idempotente y SIN sentinel a propósito: un kill, un `save()` que lanza o una zona que se quedó fuera se reintentan en el arranque siguiente.",
    code: [
      { t: "AppBootstrapper.swift:458-464", d: "el único call-site de producción, detrás de `awaitPersonalStoreReady()`" },
      { t: "LegacyGroupsRetirement.swift:145 `legacyZones`", d: "un solo fetch agrupado por zona; el `catch` devuelve vacío (falla cerrado)" },
      { t: "LegacyGroupsRetirement.swift:160-165", d: "el predicado es la NEGACIÓN de «esta zona pertenece a algún canal vivo», ANY-row **por ZONA**: por fila se llevaría la copia congelada" },
      { t: "LegacyGroupsRetirement.swift:281-284", d: "la fila se OCULTA, jamás se borra: borrarla dejaría al editor deshabilitando Borrar y Duplicar sobre un gasto que sigue a la vista" },
      { t: "LegacyGroupsRetirement.swift:304-306", d: "el canario `legacyGroupsRetired`, la ÚNICA superficie de observación del barrido" },
      { t: "DevSeedGroups.swift:29", d: "el seed de Dev acuña sus grupos como backend a propósito: sin eso el barrido los ocultaría y dejaría sin datos a los XCUITest de Grupos" }
    ],
    notes: [
      "⚠︎ MEDIDO: el fichero entero **no tiene una sola key de l10n**, y `grep` no encuentra ninguna vista que lo cite. El barrido no tiene superficie de usuario: el canario es telemetría, no comunicación. Un usuario con grupos legacy ve desaparecer contenido sin explicación.",
      "MEDIDO: el grupo retirado sale además de los elegibles para apuntar un gasto, así que tampoco se puede seguir usando — que es el punto.",
      "INFERIDO del código y declarado en su cabecera, NO ejercitado contra el servidor: ocultar es seguro hacia fuera porque el drain solo traduce filas cuya zona esté en el canal backend ⇒ en una zona legacy el flip no sale del móvil.",
      "RESIDUAL declarado y no cerrado: el plan de congelación sigue sin mirar los gastos programados de grupo, así que en sus seis call-sites ese borrador sobrevive apuntando a una zona muerta. C3 lo cubre solo en su propio camino."
    ]
  },

  "degradado-ajustesdueno": {
    title: "M1/C3 · Los cuatro ajustes del dueño que una visita ya no te toca",
    shot: null,
    sees: "Nada propio. La invitada SÍ ve el efecto durante su sesión —la shell cambia en memoria—; lo que no ocurre es la escritura persistida en el dominio del dueño.",
    persists: "NADA de la invitada en las keys del dueño. **Cuatro puertas, una por escritor**: el modo de onboarding no se persiste · activar «Yala completo» no manda `.completed` por el canal sincronizado · entrar al tab Grupos no marca la adopción del dominio · el alta solo-grupos no escribe ninguna de sus seis preferencias. Las cuatro keys viven en el `UserDefaults.standard` COMPARTIDO y el wipe de salida repone solo tres flags de onboarding, así que sin los guards se quedaban pegadas.",
    exits: "No hay salida que tomar: son guards, no pantallas. Al cerrar la sesión de invitada el móvil vuelve al dueño con sus ajustes intactos, y lo que la invitada vio durante su sesión muere con el proceso porque solo existió en memoria.",
    code: [
      { t: "OnboardingMode.swift:60", d: "el embudo: el `didSet` del modo en sesión y los dos `setCurrent` directos pasan por aquí" },
      { t: "FullModeActivationView.swift:100", d: "`.completed` es rank 2 y el merge es never-downgrade: escribirlo dejaría al dueño una shell escalada que su propio valor del iKV ya no puede bajar" },
      { t: "GroupsDomainAdoptionMarker.swift:51", d: "la adopción del dominio Grupos es del DUEÑO; en un móvil sellado por «empiezo de cero» neutralizaría el sello del siguiente humano" },
      { t: "GroupsOrganizerOnboarding.swift:164", d: "C3: el guard subió de UNA key al MÉTODO entero — si no, las seis escrituras del alta caen en el dominio del dueño" },
      { t: "ContentView.swift:981", d: "el único sitio por el que pasan las DOS puertas de la rama organizador" }
    ],
    notes: [
      "⚠︎ Residual CONSCIENTE y escrito en el código: la invitada ve su shell nueva durante la sesión (memoria) pero un relanzamiento se la devuelve a la del dueño. Persistirla exigiría namespacear la key por sesión, y eso toca el merge never-downgrade.",
      "MEDIDO: el embudo del modo NO cubre a los tres escritores que van por el servicio de prefs con la misma key — de ahí que las puertas sean CUATRO y no una.",
      "MEDIDO: hay CUATRO escritores de la adopción del dominio en producción y **solo DOS llevan guard de sesión secundaria**.",
      "El tab Grupos SÍ es visible en secundaria cuando el canal backend está encendido (la invitada ve SUS grupos con SU identidad); con el canal apagado se filtra, porque entonces Grupos sería el iCloud del dueño.",
      "Lo pinnea una suite con DOS mitades —comportamiento y source-scan del cableado— y la mutación la caza el escáner: con el guard quitado, todo el comportamiento observable en el harness es idéntico, porque el descriptor está inactivo en cualquier test normal."
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
      { t: "CloudWelcomeSignInFlow.swift:196-199", d: "las constantes del auto-resume" },
      { t: "MigrationBootDecision.swift:150", d: "el re-kick de foreground" }
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
      { t: "MigrationBootDecision.swift:112-113", d: "el boot en `waitingForLeader` SONDEA, no retoma" }
    ],
    notes: []
  }
};
