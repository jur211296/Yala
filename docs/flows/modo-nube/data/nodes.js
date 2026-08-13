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

  "onboarding-groupssignin": {
    title: "El sign-in de Grupos — el segundo escalón de las cuatro puertas",
    shot: "onboarding-groupssignin.png",
    sees: "«Conecta tu cuenta», un cuerpo que habla de unirse al grupo y seguir con la invitación, los dos botones de método y la nota de que esta será su cuenta de Yala. Es la pantalla que sale cuando la puerta dice que falta identidad — venga el usuario de una invitación, del tab, de la card «Solo grupos» o de crear su primer grupo.",
    persists: "Nada por sí misma: la sesión la escribe el proveedor al completarse. Es el escalón previo al consent, y hasta que la cadena termina no se persiste ninguna preferencia.",
    exits: "Cancelar no continúa nada: el invitado se queda como estaba (su intent sobrevive 7 días) y al organizador se le apaga la rama y vuelve al chooser de Grupos. En sim los dos métodos son inalcanzables de verdad —SIWA no completa sin cuenta de Apple— así que el recorrido se detiene aquí.",
    code: [
      { t: "GroupsSignInView.swift:77", d: "el botón de Apple: `ASAuthorizationAppleIDButton(type: .signIn)` (:174) ⇒ el sistema pinta «Iniciar sesión con Apple»" },
      { t: "GroupsSignInView.swift:89-90", d: "el de Google: `GoogleSignInButton(purpose: .signUp)` ⇒ «Crear cuenta con Google». **Los dos verbos conviven en la misma pantalla**" },
      { t: "GroupsGateLogic.swift:73-74 `.presentSignIn`", d: "el escalón que la monta; es el de GRUPOS y jamás una hermana de `WelcomeCloudSignInView`" }
    ],
    notes: [
      "⚠︎ MEDIDO EN PANTALLA el 2026-08-12 (sim, Yala Dev): **los dos botones se contradicen**. Apple dice «Iniciar sesión» y Google «Crear cuenta», uno encima del otro, para la misma acción. W4b desdobló el verbo por contexto en el Welcome —donde el alta dice crear y la re-entrada iniciar sesión— pero esta pantalla se quedó con uno de cada.",
      "⚠︎ MEDIDO: el cuerpo (`groups.signin.body`) está redactado SOLO para el invitado — «Para unirte al grupo… y sigue con tu invitación»— y es exactamente la pantalla que ve quien viene de «Crear mi primer grupo», que no tiene ninguna invitación que seguir ni grupo al que unirse. Es la misma clase de copy prestado que el bloqueo por datos ajenos de la puerta.",
      "La pantalla NO consulta el guard cross-cuenta (regla dura de su docblock) — y esa es justamente la razón de que la puerta del organizador tenga que comprobar los datos ajenos antes de llegar aquí."
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
  },

  // ══════════════════════════════════════════════════════════════════════════
  // R3 · Llego con una invitación a un grupo
  // ══════════════════════════════════════════════════════════════════════════

  "r3-enlace-origen": {
    title: "El enlace que recibo: qué lleva dentro y cuánto vive",
    shot: "r3-enlace-origen.png",
    sees: "Un enlace `https://yala-app.pe/invite?g=…&t=…&s=…&n=…&i=…&c=…&m=…&u=…` en WhatsApp. Quien lo genera es el admin, y hay DOS puertas: la fila «Invitar por enlace» de la pantalla «Miembros» (mientras acuña dice «Generando enlace…») y el `onInvite` del propio detalle del grupo. Las dos exigen ser owner Y admin. Si el grupo NO es del canal backend —o si el acuñado falla— el botón responde con «No se pudo crear el enlace de invitación. Revisa tu conexión e inténtalo de nuevo.», copy que MIENTE en el primer caso: no es la conexión, es que ese grupo es de la era CloudKit y ya no hay canal que lo sirva.",
    persists: "En el servidor: una fila en `group_invites` con `expires_at = now() + 7 días` y `max_uses = null` (usos ILIMITADOS). En el device del admin: nada durable — la URL se cachea en el `@State`/VM de la vista, así que re-tapear en la misma sesión reusa el token y salir y volver acuña uno nuevo (los dos siguen válidos).",
    exits: "Share sheet del sistema. El enlace se abre en un navegador o directamente en Yala si está instalada.",
    code: [
      { t: "GroupMembersView.swift:443-473", d: "`createShareLink` de la pantalla Miembros: `guard group.isOwner` (:444), el `if CloudSyncFlags.groupsBackendEnabled && group.isBackendGroup` (:459) que decide entre acuñar (:464-467) y el error de «conexión» (:470)" },
      { t: "GroupMembersView.swift:208-212", d: "el botón que lo dispara, tras `if group.isOwner && canActAsAdmin` (:208); su label alterna `groups.settings.generatingInvite`/`groups.settings.invite` (:219)" },
      { t: "GroupDetailView.swift:420-428", d: "la SEGUNDA superficie: el `onInvite` del detalle del grupo, gate `group.isOwner && viewModel.isCurrentUserAdmin` (:420), que llama a `viewModel.createShareLink()` en :423" },
      { t: "GroupDetailViewModel.swift:450-474", d: "el segundo call-site, misma TTL por defecto; su guard es MÁS COMPLETO —`guard group.isOwner, isCurrentUserAdmin` en :452— mientras que en la vista el término de admin vive en el botón (:208), no en la función" },
      { t: "GroupBackendInviteService.swift:20", d: "`nonisolated static let defaultTTLSeconds = 7 * 24 * 60 * 60` — 7 días" },
      { t: "GroupBackendInviteService.swift:31-37", d: "`createInviteLink(… ttlSeconds: Int = defaultTTLSeconds, maxUses: Int? = nil)` — los DOS call-sites dejan los dos por defecto" },
      { t: "InviteLinkService.swift:76-125", d: "`buildBackendInviteURL`: `g`+`t` al top, y `s` = base64URL de la forma MÍNIMA `…/invite?g=..&t=..` porque el AASA exige que `s` esté presente" },
      { t: "supabase-groups-staging.ddl:407-414", d: "`create_group_invite`: acepta TTL entre 300 s y 1 año y `max_uses` entre 1 y 1000; el token son 16 bytes hex" },
      { t: "apple-app-site-association:12-13", d: "el AASA solo casa `/invite` **con `?s=*`** — un enlace con solo `g`+`t` NO es universal link" }
    ],
    notes: [
      "⚠︎ MEDIDO: el docblock de `GroupBackendInviteService.swift:7` dice «DARK (G4): sin call-sites de UI — el \"compartir enlace\" backend lo cablea G5». Es FALSO desde hace tiempo: hay DOS call-sites de producción (`GroupMembersView` y `GroupDetailViewModel`). Es la misma familia del `AppAttestClient.ensureRegistered()`: un header que invita a archivar el caso como inalcanzable.",
      "⚠︎ El copy del fallo NO distingue las dos causas. `GroupMembersView.swift:470` (la rama `else`, grupo legacy) y el `catch` de `:480` (red, sesión, RPC) usan el MISMO `groups.errors.inviteFailed` («Revisa tu conexión»), y la primera es PERMANENTE y no tiene nada que ver con la conexión.",
      "Sin `max_uses`, el enlace es reutilizable por cuanta gente lo reciba durante 7 días. «Este enlace ya se usó» no es un estado alcanzable por defecto: solo lo produce un admin que revoque (`revoke_invite`) o un enlace de más de 7 días.",
      "MEDIDO para la captura: en el simulador con `-uitest-seed grupos` la fila SÍ aparece — el seed crea el grupo con `isOwner: true` (`DevSeedGroups.swift:24`), `isBackendGroup = true` (:29) y mi member `role: \"admin\", status: .active, isCurrentUser: true` (:46). Lo que el simulador NO puede es acuñar: sin sesión Nube ni App Attest válido el RPC lanza y el usuario ve el MISMO alert, pero por el `catch` de :480 y no por el `else` de :470. Visualmente son indistinguibles, que es justo el hallazgo de la nota anterior."
    ]
  },

  "r3-landing": {
    title: "Sin Yala instalada: la página web del enlace",
    shot: "r3-landing.png",
    sees: "Una página SSR con el logo de Yala, el icono del grupo en su color, el NOMBRE del grupo como titular, los chips de miembros bajo la etiqueta «Miembros», y dos botones: «Abrir en Yala» y «Descargar en App Store». Dos fallbacks INDEPENDIENTES: si el enlace no trae `n=`, el nombre cae a «Grupo» (`invite.astro:14`); si no trae `m=` o viene vacío, en lugar de los chips se pinta «Te invitaron a este grupo en Yala» (`invite.astro:175-177`). El nombre de QUIEN INVITA no aparece en la página.",
    persists: "Nada en el device. Es una página SSR (`prerender = false`) que lee los parámetros de la query.",
    exits: "«Abrir en Yala» → `yala://invite?s=<s>` (custom scheme, **solo `s`**, sin `g` ni `t`). «Descargar en App Store» → la ficha de la app.",
    code: [
      { t: "invite.astro:13-20", d: "lee `n`/`c`/`m`/`s`/`u`/`i` de la query server-side; `n` cae a `t.inviteFallbackGroupName` en :14" },
      { t: "invite.astro:22-25", d: "`pageTitle`/`pageDescription` — el ÚNICO consumo de `u=`; viajan al `<title>` (:135) y a las OG tags, nunca al cuerpo" },
      { t: "invite.astro:32", d: "`appDeepLink = shareParam ? `${scheme}://invite?s=${shareParam}` : null` — re-emite ÚNICAMENTE `s`, y es exactamente por eso que `extractBackendInvite` lleva su fallback de decodificar `s`" },
      { t: "invite.astro:138-198", d: "el cuerpo visible: logo, icono del grupo, `<h1>{groupName}` (:158), los chips de miembros (:161-173) o el fallback (:175-177), los CTA y el footer" },
      { t: "invite.astro:181-191", d: "los dos CTA, y el condicional es al revés de lo que parece: «Abrir en Yala» solo se pinta con `{appDeepLink && …}` (:181-186, y `appDeepLink` es null sin `s`); el `<a href={appStoreURL}>` (:188-191) se pinta SIEMPRE" },
      { t: "translations.ts:314-319", d: "los SEIS textos visibles en español (fallback de nombre, «Miembros», el fallback de invitación, los dos CTA y el footer); `:320-322` son el título de pestaña y la descripción OG, que no se ven en la página" },
      { t: "InviteLinkService.swift:148-156", d: "el fallback (2) de `extractBackendInvite`: decodifica `s`, parsea la URL interior y saca `g`+`t` de ahí" }
    ],
    notes: [
      "Es el ÚNICO sitio del recorrido donde el invitado ve el NOMBRE de su grupo. Dentro de la app no lo vuelve a ver hasta que el grupo baje por el pull (ver `r3-onboarding-nombre`).",
      "⚠︎ ASIMETRÍA MEDIDA: el nombre de quien invita viaja en el enlace (`u=`) y solo se ve en el título de la pestaña y en la preview del mensaje (OG tags) — nunca dentro de la página.",
      "⚠︎ NO hay deferred deep-link. Quien instala desde el App Store aterriza en el Welcome sin ninguna memoria del enlace: tiene que volver al mensaje y tapear otra vez, o entrar por «Vengo por un grupo» → «Tengo una invitación» y pegarlo. Lo único que suaviza eso es el auto-relleno del portapapeles de `InviteRecoveryView`.",
      "MEDIDO en el AASA: un enlace sin `s` no es universal link. Y `AppBootstrapper.handleIncomingURL` gatea por `isInviteLink`, que TAMBIÉN exige `s` — así que un `yala://invite?g=..&t=..` sin `s` cae al `switch url.host` y muere en el `default`, aunque `extractBackendInvite` sí sabría leerlo.",
      "El copy de esta pantalla NO vive en `es.lproj`: es la web, y sus strings están en `Web/src/i18n/translations.ts`. Por eso su entrada de l10n va vacía y con los valores anotados aparte."
    ]
  },

  "r3-tap": {
    title: "Toco el enlace con Yala instalada (decisión, sin pantalla)",
    shot: null,
    sees: "Nada: la app se abre y, durante un instante, no ocurre nada visible. Lo que pase después lo decide el enrutado por canal.",
    persists: "Nada todavía en este paso.",
    exits: "TRES puertas al MISMO método, y las tres exigen `s`: el universal link entra por el AppDelegate; el custom scheme (`yala://invite?s=…`, el que emite la landing web) entra por `onOpenURL` → `handleIncomingURL`; y el paste manual del Welcome llama directo a `handleInviteLink`.",
    code: [
      { t: "YalaAppDelegate.swift:88-101", d: "universal link: exige `NSUserActivityTypeBrowsingWeb` + `InviteLinkService.isInviteLink(url)` (:93-96), y devuelve `false` (no lo trata) si falla cualquiera de las dos" },
      { t: "YalaApp.swift:151-153", d: "`.onOpenURL { bootstrapper.handleIncomingURL(url) }`" },
      { t: "AppBootstrapper.swift:1858-1870", d: "`handleIncomingURL`: primero el SDK de Google (:1862, su scheme moriría en el guard de abajo), después `isInviteLink` → `handleInviteLink` (:1865-1868), y solo después el `guard url.scheme == urlScheme` (:1870)" },
      { t: "InviteLinkService.swift:221-228", d: "`isInviteLink` = (host alterno + path `/invite`, O host `invite` del custom scheme) **Y** presencia de `s`" },
      { t: "InviteLinkService.swift:20-24", d: "los SEIS hosts aceptados: `yala-app.pe`, `yala-pe.com`, `yala-app.com.pe` y sus tres `www.`" },
      { t: "ContentView.swift:622-627", d: "la TERCERA entrada al mismo método, y es la del Welcome: el `onSuccess` de `InviteRecoveryView` cierra el cover y llama a `AppBootstrapper.shared.handleInviteLink(url)` (:626)" }
    ],
    notes: [
      "El paste manual acepta los seis hosts a propósito: un universal link sigue los redirects HTTP a `yala-app.pe` solo, pero pegar un enlace a mano NO sigue redirects (`InviteLinkService.swift:16-19`).",
      "⚠︎ La exigencia de `s` en `isInviteLink` es una PUERTA MÁS ESTRECHA que el parser: `extractBackendInvite` sabe leer `g`+`t` directos sin `s` (`InviteLinkService.swift:147`), pero ningún camino llega a llamarlo si `s` falta. Hoy es inocuo porque `buildBackendInviteURL` siempre pone `s`; deja de serlo el día que alguien emita un enlace sin él."
    ]
  },

  "r3-canal": {
    title: "A qué canal va el enlace (decisión, sin pantalla) — se enruta por la FORMA, nunca por el flag",
    shot: null,
    sees: "Nada. Es la decisión que separa «este enlace funciona» de las tres formas de que no funcione.",
    persists: "En tres de las cuatro salidas, el join intent en `UserDefaults` (ver `r3-intent`) y `groupsBetaUnlocked = true`.",
    exits: "CUATRO: `.backend` (canal vivo) → `r3-puerta-invite` · `.refreshFlagsThenRetry` (fuerza `GET /config` y re-entra) · `.backendUnavailable` → `r3-err-canal` · `.ckShare` → `r3-err-ckshare`.",
    code: [
      { t: "GroupInviteChannelRoutingLogic.swift:61-71", d: "la tabla entera: `guard isBackendLink else { return .ckShare }` (:68) primero, y solo después el flag decide (:69-70)" },
      { t: "AppBootstrapper.swift:1945", d: "`let backendInvite = InviteLinkService.extractBackendInvite(from: url)` — el parser corre SIN gate, ANTES de todo lo demás. Ese orden ES el invariante" },
      { t: "AppBootstrapper.swift:1975-1989", d: "`.refreshFlagsThenRetry`: persiste el intent ANTES del `await` (:1984), fuerza `RemoteConfigClient.refreshIfDue(force: true)` (:1987) y re-entra con `didRefreshFlags: true` (:1988)" },
      { t: "AppBootstrapper.swift:2014-2024", d: "`persistBackendInviteIntent`: adopta el dominio (`groupsBetaUnlocked`, :2015), persiste el intent (:2016) y emite `canaryOnce(.groupJoinIntentPersisted, key: groupID)` (:2024)" },
      { t: "GroupInviteChannelRoutingLogic.swift:9-20", d: "el porqué medido en device el 2026-07-31: `extractShareURL` **acepta** un link backend, así que con el gate invertido el invite se colaba al canal CKShare disfrazado y moría sin una sola línea de UI" }
    ],
    notes: [
      "El `force: true` no es cosmético: sin él `refreshIfDue` es un no-op en el caso EXACTO del bug («fetcheé hace menos de 6 h»). La regla es que recibir un enlace del canal nuevo ES evidencia de que el canal está encendido.",
      "⚠︎ `GroupBackendInviteEntryLogic.routesToBackend` (`:77-79`) codifica la premisa REFUTADA («flag OFF ⇒ byte-idéntico al camino CKShare») y NO tiene ni un call-site de producción: MEDIDO con grep, sus cinco referencias vivas están todas en `YalaTests/`. Su propio docblock (:69-76) lo declara.",
      "El intent se persiste en `.refreshFlagsThenRetry` y en `.backendUnavailable`, y `persistIntent` es un upsert idempotente que preserva el `displayName`/moneda ya capturados."
    ]
  },

  "r3-frio": {
    title: "Toco el enlace con la app cerrada: el silencio deliberado",
    shot: null,
    sees: "NADA. La app arranca por su camino normal (splash → Welcome u onboarding) y el enlace no produce ninguna pantalla propia. La invitación no se ha perdido, pero el usuario no tiene forma de saberlo en ese momento.",
    persists: "El join intent completo (`zoneName == groupID`, `inviteToken`, `createdAt`) en `UserDefaults` bajo `yala.groups.pendingJoins`, más `groupsBetaUnlocked = true`.",
    exits: "Lo retoma el trigger `.boot` del reconciliador, DESPUÉS de que el import personal esté quiescente. Desde ahí re-entra en la cadena normal (sign-in → consent → onboarding → join).",
    code: [
      { t: "AppBootstrapper.swift:2028-2039", d: "`enterBackendInvite`: el `if !isInitialized` (:2029) persiste el intent (:2034) y RETORNA (:2038), sin UI" },
      { t: "AppBootstrapper.swift:482-488", d: "el trigger `.boot`, dentro de un `Task` con `guard await awaitPersonalStoreReady()`; si el import no asienta, se difiere al siguiente arranque" },
      { t: "GroupJoinReconciler.swift:53-57", d: "el segundo gate: todo trigger que no sea `.acceptShare` sale con `groupJoinIntentDeferred|importNotQuiescent` si el import personal no está quiescente" },
      { t: "ContentView.swift:497-499", d: "el cinturón: cada vuelta a foreground vuelve a intentarlo" }
    ],
    notes: [
      "MEDIDO: `enterBackendInvite` calcula `InviteLinkService.extractMetadata(from: url)` en el camino WARM (`AppBootstrapper.swift:2040`) pero en el frío ni siquiera lo mira — y da igual, porque el warm tampoco la usa (ver `r3-onboarding-nombre`).",
      "La adopción del dominio (`groupsBetaUnlocked`) se hace AQUÍ y no solo en el handler warm, a propósito: el reconciliador completa el join por `drive`, que no la toca, y sin ella un device sellado por «empiezo de cero» dejaría los gastos del grupo fuera del Panel para siempre.",
      "Esta pantalla-que-no-existe es el punto más frágil del recorrido para el usuario: si el import personal tarda, puede abrir la app varias veces sin ver nada relacionado con su invitación."
    ]
  },

  "r3-recovery": {
    title: "«Pega tu enlace de invitación» — la pantalla que el Atlas no tenía",
    shot: "r3-recovery.png",
    sees: "Un icono de enlace verde, «Pega tu enlace de invitación» y debajo «Si te invitaron a un grupo en Yala, pega aquí el enlace que recibiste.». Un campo de texto multilínea (2 a 5 líneas) con el placeholder «https://yala-app.pe/invite?...» y el teclado de URL, ya enfocado al abrir. Si el portapapeles trae una URL que ES un enlace de Yala, el campo aparece YA RELLENO. Si el texto no valida, bajo el campo aparece en rojo «Este enlace no parece de Yala. Verifica que copiaste el enlace completo.» y el borde se pone rojo. Abajo «Unirme al grupo», DESHABILITADO hasta que el texto valide. Arriba a la izquierda, «Atrás».",
    persists: "Nada. Ni el texto tecleado ni el resultado de la validación se escriben en ningún sitio.",
    exits: "«Unirme al grupo» → cierra el cover y llama a `AppBootstrapper.handleInviteLink(url)`, o sea entra por `r3-canal` como si hubiera tapeado el enlace. «Atrás» → vuelve al Welcome en el step `.chooser` (NO al `.groupsChooser` del que vino).",
    code: [
      { t: "InviteRecoveryView.swift:26-30", d: "`validatedURL`: trim + `URL(string:)` + `InviteLinkService.isInviteLink` — el mismo predicado que la puerta del universal link, así que también exige `s`" },
      { t: "InviteRecoveryView.swift:101-105", d: "`YalaPrimaryButton(L10n.Welcome.Invite.join, isDisabled: validatedURL == nil)`" },
      { t: "InviteRecoveryView.swift:117-120", d: "el `.task`: auto-relleno del portapapeles y `inputFocused = true` (el teclado sube solo)" },
      { t: "InviteRecoveryView.swift:126-134", d: "`updateValidation`: vacío ⇒ sin error; no-válido ⇒ `welcome.invite.invalidLink` bajo el campo y el borde en rojo" },
      { t: "InviteRecoveryView.swift:138-144", d: "auto-relleno del portapapeles gateado por `pb.hasURLs` (:140) — para NO disparar el toast «accedió al portapapeles» cuando no hay URL" },
      { t: "ContentView.swift:294", d: "`.fullScreenCover(isPresented: $showInviteRecovery) { inviteRecoveryCover }`" },
      { t: "ContentView.swift:622-634", d: "el cover: `onSuccess` cierra y enruta (:625-626); `onBack` llama a `returnToWelcomeChooser` (:630)" },
      { t: "ContentView.swift:765-769", d: "`returnToWelcomeChooser`: fuerza `welcomeFlowInitialStep = .chooser`" },
      { t: "ContentViewReadinessLogic.swift:140", d: "su blocker se llama `inviteRecovery` y está en `welcomeChainBlockers` (`:174`), o sea que un intent que supersede la cadena puede cerrarlo" }
    ],
    notes: [
      "⚠︎ El «Atrás» devuelve al chooser de NIVEL 1 («¿qué quieres hacer en Yala?»), no al step de dos vías del que salió («¿Cómo empiezas con tu grupo?»). `returnToWelcomeChooser` (`ContentView.swift:765-769`) está hardcodeado a `.chooser` y lo comparte con `WelcomeRestoreView`. Su hermano de la rama organizador sí vuelve al sitio correcto (`returnToGroupsChooser`, `ContentView.swift:751-761`).",
      "⚠︎ CORREGIDO tras medirlo: la key `welcome.invite.back` = «Volver» NO la usa esta pantalla —su botón es `L10n.Action.back` = «Atrás» (`InviteRecoveryView.swift:112`)— pero tampoco es copy muerto: `WelcomeBackButton.swift:29` la usa como `.accessibilityLabel`. O sea que solo la oye VoiceOver, y dice «Volver» donde la pantalla dice «Atrás».",
      "El auto-relleno del portapapeles es el único paliativo del «no hay deferred deep-link»: quien copió el enlace antes de instalar lo encuentra ya puesto.",
      "La validación es puramente de FORMA. Un enlace caducado, revocado o de un grupo borrado pasa el filtro sin una sola señal: el «no» lo dice el servidor varias pantallas después (`r3-err-enlace`)."
    ]
  },

  "r3-recovery-relanzamiento": {
    title: "La invitación es el ÚNICO camino de grupos que te pide reabrir la app (decisión)",
    shot: null,
    sees: "Nada en sí mismo: lo que se ve es el terminal `alta-mirrorrelaunch` («Un último paso: reabre Yala»), que esta decisión interpone entre el tap en «Tengo una invitación» y la pantalla de pegar el enlace.",
    persists: "`welcome.pendingMirrorRelaunchDestination = \"inviteRecovery\"` en `UserDefaults`, sin TTL y de consumo one-shot: el arranque siguiente lo lee, lo RETIRA y presenta el cover.",
    exits: "Si el mount de este proceso NO es `.neutralNoMirror`, no hay relanzamiento y se va directo a `r3-recovery`. Si lo es, la app pide cerrarse; al reabrir, `presentNextOnboardingScreen` consume el destino y monta el cover de pegar el enlace.",
    code: [
      { t: "WelcomeMirrorRelaunchLogic.swift:78-85", d: "`requiresMirror`: `inviteRecovery` cae en el lado `true` (:80), junto a `privateOnboarding` y `restoreICloud` — y `groupsOrganizer` en el lado `false` (:82)" },
      { t: "WelcomeMirrorRelaunchLogic.swift:69-72", d: "el porqué escrito: «no necesita el mirror para su propio trabajo —el CKShare va por el container de Grupos— pero su destino es usar la app con datos personales». Sesgo deliberado a pedir de más" },
      { t: "WelcomeMirrorRelaunchLogic.swift:94-99", d: "`shouldRelaunch` = `requiresMirror(destination) && mountedDecision == .neutralNoMirror`" },
      { t: "WelcomeMirrorRelaunchLogic.swift:115", d: "`WelcomePendingDestinationStore.key = \"welcome.pendingMirrorRelaunchDestination\"`; el «sin TTL y one-shot» está escrito en :110-112 y lo ejecuta `consume()` (:131-135)" },
      { t: "WelcomeFlowContainer.swift:163", d: "`leaveWelcome(to: .inviteRecovery) { onSelectBranch(.invite) }` — el portal único, en el `onJoin` del chooser de Grupos" },
      { t: "ContentView.swift:1358-1373", d: "el consumo al arrancar: `case .inviteRecovery: showInviteRecovery = true` (:1364-1365), ANTES del chooser y del onboarding" }
    ],
    notes: [
      "⚠︎ ASIMETRÍA MEDIDA y deliberada, y es la más contraintuitiva del Welcome: las DOS cards de la misma pantalla («¿Cómo empiezas con tu grupo?») caen en lados OPUESTOS. «Crear mi primer grupo» (`.groupsOrganizer`) NO relanza; «Tengo una invitación» (`.inviteRecovery`) SÍ. El porqué está en el docblock (`WelcomeMirrorRelaunchLogic.swift:73-77`): la del invitado desemboca en usar la app con datos personales, la del organizador es un alta solo-grupos.",
      "La razón que da el docblock —«el CKShare va por el container de Grupos»— habla de un canal que ya no existe (Fase 3). El razonamiento de destino sigue en pie; la coartada técnica caducó.",
      "El enlace tapeado DIRECTAMENTE nunca pasa por aquí: `handleInviteLink` no cruza el portal del Welcome. O sea que el mismo usuario, con el mismo enlace, ve o no ve la pantalla de relanzamiento según por dónde entre."
    ]
  },

  "r3-puerta-invite": {
    title: "La puerta `.invite`: la única de las cuatro que NO empieza por el educativo",
    shot: null,
    sees: "Nada: decide qué pantalla toca. Lo que el invitado nota es el orden — primero le piden la cuenta, después el permiso, y solo entonces su nombre.",
    persists: "Nada. Cada llamada re-evalúa condiciones VIVAS (`hasSession`, `isConsented`, `hasCompletedOnboarding`) en vez de recordar en qué paso iba.",
    exits: "CUATRO: `.presentSignIn` → el sign-in de Grupos · `.presentConsent` → el consent · `.presentInviteOnboarding` → `r3-onboarding-nombre` · `.join` → `r3-join`.",
    code: [
      { t: "GroupsGateLogic.swift:113-115", d: "la precedencia común: educativo → sign-in → consent, y ahí se bifurca por `entry`" },
      { t: "GroupsGateLogic.swift:120-121", d: "el terminal del invitado: `(!hasCompletedSetup && canPresentInviteOnboarding) ? .presentInviteOnboarding : .join`" },
      { t: "GroupsGateLogic.swift:135-140", d: "`showsEducationalFirst`: `.invite` y `.tab` devuelven `false`" },
      { t: "GroupsGateLogic.swift:28", d: "la fila de la tabla del encabezado que dice por qué: el educativo del invitado ES `GroupInviteOnboardingView`, contextual al enlace y DESPUÉS del consent; anteponer el general le daría dos seguidos" },
      { t: "GroupBackendInviteEntryLogic.swift:40-63", d: "el adaptador: delega en `GroupsGateLogic` con `entry: .invite` (:47) y colapsa a `.join` los tres casos inalcanzables (:61-62)" },
      { t: "GroupBackendInviteEntryHandler.swift:209-228", d: "`drive`: traduce cada paso a su `RouterEntryGate.submit` y loguea" },
      { t: "GroupBackendInviteEntryHandler.swift:214", d: "`canPresentOnboarding: source != .userAction` — el discriminador que impide que el tap de «Unirme» re-presente la pantalla desde la que se tapeó" }
    ],
    notes: [
      "⚠︎ CORREGIDO tras medirlo: el canal NO entra en esta tabla, y eso importa — `GroupsGateLogic` es pura y recibe todo ya leído, así que puede estar perfecta y verde mientras el llamador mide un snapshot de remote-config de hasta 6 h. Pero quien hace el `refreshIfDue(force: true)` para el invitado NO es `GroupInviteChannelRoutingLogic`, que es un `enum` puro de 72 líneas donde esa palabra no aparece: es el CALL-SITE del enrutado, `AppBootstrapper.handleInviteLink`, en su rama `.refreshFlagsThenRetry` (`AppBootstrapper.swift:1987`). El propio encabezado de `GroupsGateLogic` (:40-43) dice que para las otras puertas ese refresh vive en las VISTAS.",
      "La cadena vuelve aquí después de CADA sheet (`GroupsBackendInviteModifier.continueFlow` → `GroupBackendInviteEntryHandler.continueFlow(zoneName:)`, `:232-241` → `drive`), y por eso un sign-in ya hecho en otra pantalla, un consent aceptado en otro device o un kill-and-relaunch a mitad no desalinean nada."
    ]
  },

  "r3-onboarding-nombre": {
    title: "«Te invitaron a un grupo» → tu nombre → «Unirme al grupo»",
    shot: "r3-onboarding-nombre.png",
    sees: "Un círculo con el color de acento del tema y el icono `person.2.fill`, «Te invitaron a un grupo» y debajo «Yala te ayuda a dividir gastos y saber cuánto debes o te deben». Un campo con placeholder «Tu nombre» y, abajo, «Unirme al grupo».",
    persists: "Al tapear el botón, y ANTES de hablar con el servidor, `performSilentSetup` escribe de golpe: `onboardingMode = .groupInvite` (solo en el `UserDefaults` LOCAL), `hasShownGroupsOnboarding = true`, `userName`, `defaultCurrencyCode` (del grupo si ya bajó, si no por REGIÓN), `defaultPeriod = thisMonth`, el nombre en TODAS las entries del join intent, y —solo si el import de iCloud está quiescente— las categorías semilla, las categorías de grupo y las notificaciones por defecto. `hasCompletedOnboarding = true` lo escribe el cierre del cover, no esta pantalla.",
    exits: "«Unirme al grupo» (una sola vez: `guard !hasTappedJoin`) → arranca el soft-timeout de 20 s y lanza `GroupJoinReconciler.reconcile(trigger: .acceptShare)`, que es lo que dispara el join real. NO hay botón de cerrar ni de atrás en este step.",
    code: [
      { t: "GroupInviteOnboardingView.swift:85-134", d: "`welcomeStep` completo: círculo (:89-98), título y subtítulo (:100-109), campo (:111-123) y CTA con identifier `invite_join_button` (:127-130)" },
      { t: "GroupInviteOnboardingView.swift:454-459", d: "`welcomeTitle`: usa `welcomeWithGroup(name)` SOLO si `inviteMetadata?.groupName` no es vacío" },
      { t: "GroupInviteOnboardingView.swift:170-180", d: "`handleJoinTap`: `guard !hasTappedJoin` (:171) → `performSilentSetup()` (:172) → `reconcile(.acceptShare)` (:177) → `startSoftTimeout()` (:179)" },
      { t: "GroupInviteOnboardingView.swift:357-432", d: "`performSilentSetup`, los ocho pasos, con los seeds gateados por `iCloudSyncService.shared.isImportQuiescent` (:392)" },
      { t: "GroupInviteOnboardingView.swift:365-371", d: "C2: esta vista ES el educativo del invitado, y por eso marca `hasShownGroupsOnboarding` — sin esa línea vería el educativo general del tab justo después" },
      { t: "ContentView.swift:942-953", d: "el drain de `.presentGroupBackendInviteOnboarding`: **`pendingInviteMetadata = nil`** con el comentario «backend: sin CKShare metadata — visual genérico» (:947), y re-decide con condición viva si el onboarding ya se completó (:946, :949-953)" },
      { t: "ContentView.swift:2037-2050", d: "el cover y su cierre: escribe `hasCompletedOnboarding = true` (:2046) en CUALQUIER outcome" }
    ],
    notes: [
      "⚠︎ HALLAZGO MEDIDO: el invitado NUNCA ve el nombre de su grupo en esta pantalla, aunque el enlace lo lleve en `n=`. Dos causas independientes y ambas comprobadas: (1) `GroupBackendInviteEntryHandler.handle` declara el parámetro `branded: InviteLinkService.BrandedMetadata` en `:70` y **no lo referencia ni una vez** en el cuerpo (`:73-82`) — `AppBootstrapper.swift:2040` calcula la metadata y se la pasa para nada; (2) el drain fuerza `pendingInviteMetadata = nil` explícitamente. Resultado: título genérico, icono `person.2.fill` y color del tema. `welcomeWithGroup` (`:454-459`), `groupColor` (`:440-445`) y `groupIcon` (`:447-452`) son código vivo sin camino que los alcance en el canal backend.",
      "⚠︎ CORREGIDO tras medirlo: `onboardingMode = .groupInvite` se escribe SOLO en el `UserDefaults` local. La cadena es `performSilentSetup` (`GroupInviteOnboardingView.swift:363`) → `didSet` (`SessionState.swift:393-397`) → `OnboardingMode.setCurrent` (`OnboardingMode.swift:59-62`), cuyo cuerpo es un `guard !SecondarySessionStore.isActive(defaults)` + `defaults.set(...)`. Por ESTE camino no viaja al iKV del Apple ID; la key sí participa del merge never-downgrade cuando la escriben los otros tres escritores, que van por `PreferenceSyncService` y no pasan por aquí — lo dice su propio docblock (`OnboardingMode.swift:50-51`).",
      "⚠︎ En sesión secundaria (móvil de otra persona) esta pantalla es un riesgo medido: `PreferenceSyncService.local` es `UserDefaults.standard` HARDCODEADO (`:78`), así que en `.localOnly` los `sync.set` de nombre (`GroupInviteOnboardingView.swift:374`), divisa (`GroupInviteOnboardingView.swift:384`) y período (`GroupInviteOnboardingView.swift:385`) caen en el dominio del DUEÑO. Lo que sí está protegido es `onboardingMode`: `setCurrent` tiene su propio guard (`OnboardingMode.swift:60`). La precondición para llegar aquí en secundaria es `hasCompletedOnboarding == false`, que un borrado de datos en sesión reabre — el mismo hueco que `advanceGroupsOrganizerFlow` sí cierra para la rama organizador (`ContentView.swift:981-988`).",
      "El cierre del cover pone `hasCompletedOnboarding = true` pase lo que pase, incluido el abandono tras un fallo. Y en `ContentView.swift:2042-2043` queda un `if GroupInviteOnboardingLogic.shouldClearPendingInvite(outcome:) { }` con el CUERPO VACÍO — residuo del `PendingInviteStore` que se llevó la Fase 3."
    ]
  },

  "r3-join": {
    title: "El join contra el servidor (decisión, sin pantalla propia)",
    shot: null,
    sees: "Nada: por debajo del spinner de `r3-esperando`. Es la llamada `join_group`.",
    persists: "Server-side, la fila `group_members` con `status = 'pendingApproval'` y el contador `uses` del invite +1. En el device: nada nuevo — el intent ya estaba y se CONSERVA (solo lo limpia el reconciliador cuando el member baje por el pull).",
    exits: "Éxito → `GroupJoinIntentTracker.noteMemberResolved(status)` → la vista salta a «Solicitud enviada» (`r3-solicitud`). Fallo → las cinco ramas de `r3-err-enlace` / `r3-err-canal` / `r3-err-red`.",
    code: [
      { t: "GroupBackendInviteEntryHandler.swift:247-273", d: "`attemptJoin`: lee el `legacyMemberKey` del intent (:253), resuelve el displayName (:255-259) y llama al RPC (:261); un error que NO sea `GroupsRPCError` se trata como transitorio (:269-272)" },
      { t: "GroupBackendInviteEntryLogic.swift:85-95", d: "`resolveJoinDisplayName`: intent → perfil → «Usuario». JAMÁS vacío, porque `join_group` hace `btrim=''` → `yala_bad_input` PERMANENTE" },
      { t: "supabase-groups-staging.ddl:444-454", d: "las cinco condiciones que invalidan la invitación, todas con el MISMO código `yala_invalid_invite`: token inexistente, revocado, caducado, agotado (:445-449), o grupo con `deleted = true` (:452-453)" },
      { t: "supabase-groups-staging.ddl:514-521", d: "el INSERT del member nuevo: `'member', 'pendingApproval'` (:519) — literal, sin ninguna condición" },
      { t: "supabase-groups-staging.ddl:492-495", d: "la rama «ya-member»: si ya existía `active` o `pendingApproval`, devuelve su status SIN tocar nada" },
      { t: "GroupBackendInviteEntryHandler.swift:277-287", d: "`handleJoinSuccess`: `rehydrate` (:279) + `noteMemberResolved` (:281) + canario `groupJoinIntentReconciled` (:283); el intent se CONSERVA a propósito (:285-286)" }
    ],
    notes: [
      "⚠︎ HALLAZGO MEDIDO: para un invitado nuevo, `join_group` SIEMPRE devuelve `pendingApproval` — en las TRES ramas que puede tomar (rebind legacy `:483-484`, revive `:509-510`, insert `:523-524`). No existe auto-aprobación en ninguna. La pantalla «¡Todo listo!» es por tanto INALCANZABLE en el primer join.",
      "No hay límite de miembros en el DDL: ni `join_group` ni `create_group_invite` cuentan `group_members`, y MEDIDO con grep sobre todo el repo no existe ningún código `yala_group_full` (los únicos aciertos de «group_full» son el nombre de la migración `g3_01_create_group_full_meta`). «El grupo está lleno» NO es un estado que este producto pueda producir.",
      "La corrección R1 del nombre existe para un caso concreto: si el join se hizo con el placeholder «Usuario» y el silent-setup capturó el nombre real después, el reconciliador llama a `update_member_display_name` UNA vez y solo si el nombre actual del member es vacío o el default (`GroupBackendInviteEntryLogic.swift:101-111`)."
    ]
  },

  "r3-esperando": {
    title: "«Conectando con tu grupo…» y su salida digna a los 20 s",
    shot: "r3-esperando.png",
    sees: "Primero un spinner grande con «Conectando con tu grupo…» y «Estamos preparando todo para que puedas dividir gastos. Esto puede tardar un momento.». A los 20 segundos SIN fase terminal, la pantalla cambia —sin dejar de ser un spinner— a «Está tardando un poco más de lo normal» / «Seguimos conectando con tu grupo en segundo plano. Puedes usar Yala mientras tanto: el grupo aparecerá en la pestaña Grupos apenas esté listo.» y aparece un botón: «Seguir a la app».",
    persists: "Nada nuevo. El join intent sigue en disco y es lo que sostiene la promesa del copy.",
    exits: "«Seguir a la app» → `complete(.closedWhileSyncing)`: el tracker NO se limpia (sigue alimentando el banner del tab) y a los 300 ms navega al tab Grupos. Cualquier fase terminal que llegue mientras tanto DOMINA sobre el timeout y salta sola a la pantalla que toque.",
    code: [
      { t: "GroupInviteOnboardingLogic.swift:77", d: "`static let softTimeout: TimeInterval = 20`" },
      { t: "GroupInviteOnboardingLogic.swift:82-98", d: "`step`: las fases terminales (`pendingApproval`/`active`/`failed`) ganan siempre (:89-94); `idle`/`accepting`/`waitingForZone`/`creatingMember` caen a `takingLong` o `joining` según el timeout (:95-96)" },
      { t: "GroupInviteOnboardingView.swift:225-247", d: "`joiningStep`, con identifier `invite_joining_spinner`" },
      { t: "GroupInviteOnboardingView.swift:251-279", d: "`takingLongStep`, con sus identifiers `invite_slow_title` (:262) e `invite_slow_continue` (:276)" },
      { t: "GroupInviteOnboardingView.swift:67-80", d: "la llegada de una fase terminal cancela el `timeoutTask`" },
      { t: "GroupInviteOnboardingView.swift:199-221", d: "`complete`: `.closedWhileSyncing` no limpia el tracker (:209-214) y siempre navega a `.groups` a los 300 ms (:217-220)" }
    ],
    notes: [
      "`takingLong` es un estado de PRIMERA CLASE y no un error, y el copy lo respeta: no culpa a nadie y dice exactamente dónde aparecerá el grupo.",
      "La promesa «el grupo aparecerá en la pestaña Grupos apenas esté listo» es cierta pero incompleta: aparecerá con el chip «Esperando aprobación» y SIN sus gastos, porque la RLS del servidor los oculta a un miembro pendiente (ver `r3-solicitud`).",
      "Para la captura, el soft-timeout se puede acortar sin esperar 20 s: `-uitest-join-soft-timeout <segundos>` (`UITestHooks.swift:196-205`, leído por `GroupInviteOnboardingView.swift:192-196`)."
    ]
  },

  "r3-solicitud": {
    title: "«Solicitud enviada» — la sala de espera, y lo que NO se puede ver desde ella",
    shot: "r3-solicitud.png",
    sees: "Un reloj naranja, «Solicitud enviada» y «El admin del grupo debe aprobarte antes de que puedas participar. Te avisamos cuando esté listo.». Un botón, «Continuar». Al salir, en el tab Grupos: la tarjeta del grupo con el chip «Esperando aprobación» en vez del balance, y un banner flotante «Esperando aprobación del admin». Dentro del grupo, la misma frase en un banner naranja.",
    persists: "Nada que escriba esta pantalla. El `SplitMember` en `pendingApproval` baja por el pull; el intent sigue vivo hasta que ese member materialice.",
    exits: "«Continuar» → `complete(.pendingApproval)`: registra el nudge de unión, deja el tracker VIVO (por eso el banner del tab persiste) y navega al tab Grupos.",
    code: [
      { t: "GroupInviteOnboardingView.swift:138-166", d: "`pendingApprovalStep` completo, con identifier `invite_pending_continue` (:163)" },
      { t: "GroupsContainerView.swift:585-591", d: "el chip de banner del tab, identifier `invite_pending_banner`" },
      { t: "GroupCardView.swift:137-143", d: "el chip «Esperando aprobación» de la tarjeta, en lugar del balance" },
      { t: "GroupDetailView.swift:110-111", d: "`PendingApprovalBanner(state: .pending, onLeave: nil)` dentro del grupo, gateado por `currentUserMember?.isPendingApproval == true`" },
      { t: "supabase-groups-staging.ddl:810-821", d: "el endurecimiento: `split_expenses`/`split_shares`/`split_settlements` pasan a `is_group_writer` (solo `active`); `split_groups` y `group_members` se quedan en `is_group_member` (incluye `pendingApproval`) — dicho por escrito en :811-814" },
      { t: "supabase-groups-staging.ddl:71-81", d: "`is_group_member` acepta `active` y `pendingApproval` (:74); `is_group_writer` exige `active` (:80)" },
      { t: "gateway/src/groups/routes.ts:388", d: "el alcance del pull: `select=group_id&user_id=eq.<sub>&deleted=eq.false&status=in.(active,pendingApproval)` — por eso el grupo y el roster SÍ bajan" }
    ],
    notes: [
      "MEDIDO y es lo que el copy no dice: en la sala de espera el invitado ve el grupo y la lista de miembros, pero NO ve ni un gasto. No es un retraso de sincronización: es la RLS del servidor, cambiada a propósito para que un pendiente no lea el contenido financiero antes de ser aprobado.",
      "⚠︎ «Te avisamos cuando esté listo» — HUECO CERRADO CON MEDICIÓN, y la respuesta es que NO existe ese aviso. (1) `get_group_push_tokens` exige `and gm.status = 'active'` con el comentario «pendingApproval EXCLUIDO» (`supabase-groups-staging.ddl:1614`), así que mientras espera no recibe pushes de ese grupo. (2) Su ÚNICO consumidor en el gateway es `fanOutGroupPush` (`gateway/src/groups/routes.ts:190`), cuyo único call-site es el handler de `POST /groups/push` (`:145`) — los RPCs como `approve_member` no hacen fan-out. (3) El único payload que ese fan-out emite es `{ aps: { \"content-available\": 1 }, yala: { kind: \"groups-sync\" } }` (`:218`): un push SILENCIOSO de sincronización, sin ninguna rama de «te aprobaron». ⇒ el invitado se entera cuando la app vuelva a hacer pull, no por una notificación.",
      "Para el invitado NO hay salida de esta sala. El único CTA es «Continuar»; no hay «cancelar solicitud» ni «salir». Si el admin nunca actúa, el estado es permanente.",
      "Del panel, el simulador da la pantalla «Solicitud enviada» y el banner del tab (vía `-uitest-invite-onboarding -uitest-join-phase pendingApproval`), pero NO el chip de la tarjeta: `-uitest-seed grupos` siembra a todos los members como `.active` (`DevSeedGroups.swift:43-55`), así que `displayMode == .pendingApproval` no se alcanza con los seams de hoy."
    ]
  },

  "r3-listo": {
    title: "«¡Todo listo!» — la pantalla que casi nadie ve",
    shot: "r3-listo.png",
    sees: "Un check verde, «¡Todo listo!» y un botón «Ir al grupo». Es el ÚNICO final feliz del recorrido, y se pinta solo con el member confirmado `active`.",
    persists: "Nada. Al tapear, el tracker se limpia (`clear()`), que es lo que retira el banner del tab.",
    exits: "«Ir al grupo» → `complete(.joined)`: limpia el tracker, registra el nudge y a los 300 ms navega al tab Grupos.",
    code: [
      { t: "GroupInviteOnboardingView.swift:333-353", d: "`completionStep`, identifier `invite_ready_title` (:344)" },
      { t: "GroupInviteOnboardingLogic.swift:91-92", d: "`case .active: return .active` — el único camino a este step; el invariante del bug del 2026-07-11 está escrito en :68 («SOLO con phase == .active»)" },
      { t: "GroupJoinIntentTracker.swift:83-95", d: "`noteMemberResolved`: `active` → `.active`; `rejected`/`left`/`removed` → `clear()` (vuelve a idle, sin pantalla)" },
      { t: "GroupsSyncClient.swift:2093", d: "`publishTrackedJoinPhaseIfNeeded`, POST-SAVE del pull: es lo ÚNICO que puede mover la fase de `pendingApproval` a `active` con el cover abierto" },
      { t: "GroupInviteOnboardingLogic.swift:126-138", d: "`shouldRepublishPhase`: solo con zona trackeada y fase EN VUELO; `.idle` y las terminales no republican" }
    ],
    notes: [
      "⚠︎ Consecuencia medida de `r3-join`: como el servidor SIEMPRE devuelve `pendingApproval` en el primer join, esta pantalla exige que el admin apruebe MIENTRAS el cover sigue abierto y que un ciclo de pull la republique. En la práctica el invitado sale por «Continuar» desde la sala de espera y esta pantalla no se le muestra nunca.",
      "El caso en que sí es alcanzable de forma natural es el re-tap del enlace por alguien que YA es miembro activo: `join_group` devuelve su status sin tocar nada (`supabase-groups-staging.ddl:492-495`) y la vista salta directa a «¡Todo listo!».",
      "La pieza que la hace posible tras la aprobación es un fix de device del 2026-07-31: el canal backend no llamaba al reconciliador ni miraba al member tras el pull, y el banner de espera se quedaba puesto PARA SIEMPRE."
    ]
  },

  "r3-banner": {
    title: "El banner del tab Grupos: la continuidad del join cuando ya cerraste el cover",
    shot: "r3-banner.png",
    sees: "Una tira flotante sobre la lista de grupos, con CINCO caras según la fase: spinner + «Conectando con tu grupo…» · reloj + «Esperando aprobación del admin» · triángulo + «No pudimos unirte al grupo» con botón «Reintentar» · triángulo + «No pudimos conectar con el grupo. Pídele al admin un enlace nuevo.» con una «✕» para descartarlo · y NADA (`EmptyView`) cuando la fase es `idle` o `active`.",
    persists: "Nada: el tracker vive en memoria y arranca `.idle` en cada arranque. Lo que sobrevive al relanzamiento es el join intent en disco, y es el reconciliador quien re-hidrata la fase desde él.",
    exits: "«Reintentar» → `tracker.retry()`. La «✕» del expirado → `tracker.clear()` y el banner desaparece para siempre en esa sesión.",
    code: [
      { t: "GroupsContainerView.swift:571-621", d: "`joinIntentBanner`: el switch completo de las cinco caras (`idle/active` → EmptyView en :574-575; spinner :577-583; espera :585-591; error con Retry :595-605; expirado con ✕ :606-619)" },
      { t: "GroupJoinIntentTracker.swift:47-51", d: "`rehydrate`: solo si no hay zona trackeada, y sube de `.idle` a `.waitingForZone`" },
      { t: "GroupJoinIntentTracker.swift:119-130", d: "`retry`: `.memberSaveFailed` reconcilia (:122-124); **`.acceptFailed` degrada a `.expired`** (:125-126) porque su recuperación murió con el transporte CKShare; `.expired` no hace nada (:127-128)" },
      { t: "GroupJoinIntentTracker.swift:11-13", d: "por qué el tracker es `@Observable` y no `dataVersion`: con un cover abierto y el usuario quieto, el bump diferido puede no correr nunca" },
      { t: "GroupJoinReconciler.swift:235", d: "el productor VIVO de la cara de error con «Reintentar»: el `catch` del ensure llama a `noteMemberSaveFailed`" },
      { t: "GroupBackendInviteEntryHandler.swift:320", d: "el productor VIVO de la cara del expirado: la rama PERMANENTE llama a `noteAcceptFailed(zoneName:recoverable: false)`, y el banner pinta esa cara para `.acceptFailed(recoverable: false)` igual que para `.expired`" }
    ],
    notes: [
      "⚠︎ MEDIDO (y CORREGIDO respecto de la derivación): en un binario de RELEASE ningún camino de producción escribe la fase `.accepting` — `noteAcceptStarted` (`GroupJoinIntentTracker.swift:55`) no tiene NI UN call-site en `Yala/` fuera de su declaración, y lo único que la escribe es el hook `#if DEBUG` `_uitestForcePhase` (`:143-156`). Su hermano `noteAcceptSucceeded` (`:60`) está igual de muerto. Pero eso NO deja ninguna de las cinco caras sin superficie: los dos sub-casos que sí importan tienen productor vivo.",
      "⚠︎ CORRECCIÓN 1: la cara «No pudimos unirte al grupo» + «Reintentar» SÍ es alcanzable. Su `case` es `.acceptFailed(recoverable: true), .memberSaveFailed` (`GroupsContainerView.swift:595`) y `.memberSaveFailed` tiene un productor de producción: `GroupJoinReconciler.swift:235`. Lo inalcanzable es el sub-caso `.acceptFailed(recoverable: true)`, no el botón.",
      "⚠︎ CORRECCIÓN 2: «No pudimos conectar con el grupo. Pídele al admin un enlace nuevo.» tampoco es un caso sin productor. Su `case` es `.acceptFailed(recoverable: false), .expired` (`:606`) y `GroupBackendInviteEntryHandler.swift:320` escribe exactamente `noteAcceptFailed(recoverable: false)` en cada fallo PERMANENTE del join. (`noteExpired`, `:102`, sí está sin call-sites: a `.expired` solo se llega degradando desde `retry()`.)",
      "El banner del tab y el banner de DENTRO del grupo NO se alimentan de lo mismo: el del tab lee el tracker en memoria, el de dentro lee el `status` del `SplitMember` en el store. Esa asimetría fue el bug del 2026-07-31: al aprobar, el de dentro desaparecía y el del tab se quedaba pegado."
    ]
  },

  "r3-intent": {
    title: "Lo que queda escrito de tu invitación (decisión, sin pantalla)",
    shot: null,
    sees: "Nada. Es el mecanismo que hace que cerrar la app, quedarse sin red o tapear el enlace con la app cerrada no pierdan la invitación.",
    persists: "`UserDefaults` bajo `yala.groups.pendingJoins`: un JSON `[zoneName: PendingJoinEntry]` con `zoneName == backendGroupID == group_id`, el `inviteToken`, `createdAt`, el `displayName` tecleado, la moneda de fallback regional y, en un re-join de grupo migrado, el `legacyMemberKey`. TTL de **7 días** por entry, tope de **8** entries (evict de la más vieja). También `groupsBetaUnlocked = true`.",
    exits: "Lo consumen CUATRO triggers declarados del reconciliador. Se limpia SOLO cuando el `SplitMember` propio materializa por el pull, o al expirar (con canario `groupJoinIntentExpired`), o en un fallo PERMANENTE del join.",
    code: [
      { t: "PendingJoinStore.swift:84-91", d: "la key `yala.groups.pendingJoins` (:84), el TTL de 7 días (:88) y el cap de 8 entries (:91)" },
      { t: "PendingJoinStore.swift:115-124", d: "`all(now:)` purga las expiradas AL LEER y emite un canario por cada una (:119)" },
      { t: "GroupBackendInviteEntryHandler.swift:89-105", d: "`persistIntent`: upsert que PRESERVA `displayName` y moneda de un re-tap (:99-100)" },
      { t: "GroupJoinReconciler.swift:27-29", d: "los cuatro triggers declarados: `acceptShare, remoteInsert, boot, foreground`" },
      { t: "GroupJoinReconciler.swift:60-66", d: "el discriminador R5: una entry con token va SIEMPRE por el camino backend, con PRIORIDAD sobre el flag" },
      { t: "GroupJoinReconcileLogic.swift:66-77", d: "`decideBackend`: flag OFF ⇒ `.skipFlagOff` (conserva, :72) · member local ⇒ `.correctAndClear` (:73) · sin sesión ⇒ sign-in (:74) · sin consent ⇒ consent (:75) · listo ⇒ join (:76)" },
      { t: "GroupJoinReconciler.swift:165-186", d: "`backendCurrentUserMember`: match por `userID`/`memberKey == sub`, JAMÁS por `isCurrentUser` (que `applyMember` nunca setea)" }
    ],
    notes: [
      "⚠︎ MEDIDO con grep: de los cuatro triggers declarados, `.remoteInsert` **no tiene ni un call-site**. Las cinco llamadas vivas a `reconcile(trigger:)` en `Yala/` son exactamente `.boot` (`AppBootstrapper.swift:487`), `.foreground` (`ContentView.swift:498` y `:1314`) y `.acceptShare` (`GroupInviteOnboardingView.swift:177` y `GroupJoinIntentTracker.swift:124`). O sea: entre que el grupo baja por el pull y el siguiente foreground/arranque, nadie reconcilia.",
      "El TTL de 7 días coincide a propósito con el del token del servidor: cuando el intent caduca, el enlace también.",
      "`.correctAndClear` limpia el intent en cuanto el member existe localmente **aunque esté `pendingApproval`**. Por eso la fase pendiente ya no la sostiene el intent, y quien la mueve es `publishTrackedJoinPhaseIfNeeded` desde el pull."
    ]
  },

  "r3-aprobacion": {
    title: "El admin decide: y no hay «no» que el invitado pueda ver",
    shot: "r3-aprobacion.png",
    sees: "Si aprueban: el chip y el banner desaparecen y el grupo se abre entero, con sus gastos. Si el admin le saca del grupo en vez de aprobarle: el grupo desaparece de su lista, sin aviso, sin banner y sin explicación. Si nadie hace nada: la sala de espera es indefinida.",
    persists: "En la aprobación, el `SplitMember` pasa a `active` por el pull. En la baja, el reconciliador de membresías perdidas resetea el cursor del grupo y BORRA sus filas locales.",
    exits: "Aprobado → tab Grupos con el grupo usable. Dado de baja → el grupo simplemente ya no está.",
    code: [
      { t: "GroupService.swift:380-388", d: "`approveMember`: RPC `approve_member` (:384-385) y transición local a `.active` (:387)" },
      { t: "GroupService.swift:391-395", d: "`rejectMember`: **`guard !routesMembershipToBackend(group) else { throw .backendActionUnavailable }`** (:393) — en el canal backend no hay ninguna ACCIÓN de UI llamada «rechazar»" },
      { t: "supabase-groups-staging.ddl:564", d: "y sin embargo el rechazo SÍ se produce, y lo dice el encabezado de la función: «5. remove_member — admin expulsa. pendingApproval→rejected, active→removed»" },
      { t: "supabase-groups-staging.ddl:596", d: "dentro de `remove_member` (declarada en :566): `v_new := case when v_target.status = 'pendingApproval' then 'rejected' else 'removed' end;`, y ese `v_new` es lo que devuelve (:605). El vocabulario del DDL lista `rejected` entre los cinco status (:39)" },
      { t: "supabase-groups-staging.ddl:71-75", d: "por qué el rechazado no puede VER su rechazo: `is_group_member` solo admite `active`/`pendingApproval` (:74), así que un `rejected` pierde el SELECT" },
      { t: "gateway/src/groups/routes.ts:388", d: "el pull filtra igual (`status=in.(active,pendingApproval)`) ⇒ su `group_id` desaparece de `page.memberships`" },
      { t: "GroupsSyncClient.swift:1994-2036", d: "`reconcileLostMemberships`: la baja no manda ningún delta; lo único que la delata es la AUSENCIA del `group_id` en `page.memberships`. Breadcrumb (:2024) y canario `groupsMembershipLost` (:2025), reset del cursor (:2026) y limpieza (:2028-2035)" },
      { t: "GroupsSyncClient.swift:1997", d: "`guard let memberships = page.memberships else { return }` — ausencia ≠ vacío, fail-cerrado" },
      { t: "GroupDetailView.swift:112-116", d: "`PendingApprovalBanner(state: .rejected, onLeave:)`, cuyo cuerpo (`:636`, `:639`) pinta «Solicitud rechazada» y su explicación" }
    ],
    notes: [
      "⚠︎ CORREGIDO tras medirlo en el árbol — la derivación decía «el status `rejected` ni siquiera existe server-side» y es FALSO. Lo que no existe es una ACCIÓN de UI llamada «rechazar»: `rejectMember` lanza `backendActionUnavailable` para todo grupo backend (`GroupService.swift:393`). Pero el ESTADO existe y se alcanza: `remove_member` sobre un pendiente escribe `status = 'rejected'` (`supabase-groups-staging.ddl:596`, documentado en :564 y en el vocabulario de :39). Corolario: «remover» y «rechazar» no son dos actos distintos para un pendiente — son el MISMO RPC, y el servidor llama `rejected` a su resultado.",
      "⚠︎ Y por eso el copy del rechazo sigue sin superficie, pero por la vía de LECTURA y no por la de existencia: en cuanto el admin le saca, el rechazado deja de pasar `is_group_member` (`ddl:71-75`), sale del alcance del pull (`routes.ts:388`), su `group_id` desaparece de `page.memberships` y `reconcileLostMemberships` (`GroupsSyncClient.swift:1994-2036`) le borra las filas locales. `groups.invite.rejected.title` / `.body` (`GroupDetailView.swift:636`, `:639`) y `groups.card.rejectedChip` (`GroupCardView.swift:144-150`) están traducidos en los 16 locales y no los puede ver nadie: el grupo desaparece antes de que ninguna vista pueda pintarlos.",
      "⇒ El «no» es SILENCIOSO para el invitado: el grupo se va de su lista sin una sola pantalla que lo explique. La afirmación «Te avisamos cuando esté listo» solo se cumple en la mitad buena — y ni siquiera con un aviso (ver `r3-solicitud`).",
      "La lectura de `memberships` fue el hueco que costó el fix del 2026-08-04: el campo se decodificaba desde el primer día y no lo leía NADIE, mientras dos comentarios usaban «la limpieza llega por memberships del pull» como coartada para no remediar."
    ]
  },

  "r3-err-enlace": {
    title: "El enlace ya no vale: caducado, revocado o el grupo se borró",
    shot: "r3-err-enlace.png",
    sees: "DOS superficies según dónde te pille. Sin el cover abierto: un alert del sistema con el título «Enlace no válido» y el cuerpo «Este enlace ya no es válido o expiró. Pídele al admin que regenere uno.», con un solo botón «OK». Con el cover del onboarding abierto: su pantalla de error, y el copy NO es el del alert — dice «No pudimos unirte al grupo» / «Revisa tu conexión a internet e inténtalo de nuevo.», CON botón «Reintentar» y con «Salir por ahora». Solo después de tapear «Reintentar» una vez la pantalla pasa a «Este enlace ya no es válido o expiró…» y el botón desaparece.",
    persists: "El join intent se BORRA (`PendingJoinStore.clear`). Se emite el canario `groupJoinFailed` con el slug del kind.",
    exits: "«OK» cierra el alert y deja al usuario donde estuviera. «Salir por ahora» cierra el cover con `abandonedAfterFailure(recoverable:)`, que en el caso no-recuperable también limpia el tracker.",
    code: [
      { t: "GroupBackendInviteEntryHandler.swift:313-326", d: "la rama permanente: canario (:315) → `PendingJoinStore.clear` (:316) → `noteAcceptFailed(recoverable: false)` (:320) → alert; `invalidInvite` va por `.showInviteError` (:322), los otros dos kinds por `.showGroupSyncError(L10n.Groups.Errors.actionFailed)` (:324)" },
      { t: "GroupBackendAcceptErrorLogic.swift:42-53", d: "`classify`: `yala_invalid_invite` → `.invalidInvite` (:44); `.notAuthorized` (:46) y `.generic` (:49-51) también son permanentes" },
      { t: "supabase-groups-staging.ddl:444-454", d: "las CINCO causas que colapsan al mismo código: token inexistente, revocado, `expires_at <= now()`, `uses >= max_uses` (:445-448), y grupo con `deleted = true` (:452-453)" },
      { t: "ContentView.swift:2013-2025", d: "el alert: el TÍTULO está hardcodeado a `groups.invite.linkInvalidTitle` (:2014) y el cuerpo cae al mismo `linkInvalidDetail` si el detail viene vacío (:2022-2024)" },
      { t: "GroupInviteOnboardingView.swift:296-315", d: "la vista del invitado: el cuerpo solo usa `linkInvalidDetail` con `reason == .expired` (:296-298) y el botón de Reintentar solo se OCULTA con `.expired` (:307-315)" },
      { t: "GroupJoinIntentTracker.swift:125-126", d: "lo que convierte una cosa en la otra: `retry()` degrada `.acceptFailed` a `.failed(.expired)`" },
      { t: "ContentViewReadinessLogic.swift:133", d: "`inviteError` es un blocker de la matriz: mientras el alert esté puesto, nada más presenta" }
    ],
    notes: [
      "⚠︎ Las cinco causas son INDISTINGUIBLES para el usuario y para el cliente: el servidor devuelve el mismo `yala_invalid_invite` a propósito (sin oráculo). «Caducó», «lo revocaron» y «el grupo ya no existe» dan exactamente la misma pantalla, y el consejo —«pídele al admin que regenere uno»— es falso en el último caso.",
      "⚠︎ CORREGIDO tras medirlo: la derivación decía que con el cover abierto se ve «ese mismo texto y SIN botón de reintentar». Es FALSO en el primer momento. `noteAcceptFailed(zoneName:recoverable: false)` escribe `phase = .failed(.acceptFailed(recoverable: false))` (`GroupJoinIntentTracker.swift:66-70`), y `failedStep` solo usa `linkInvalidDetail` y esconde el botón cuando `reason == .expired` (`GroupInviteOnboardingView.swift:296-298`, `:307`). ⇒ el invitado ve primero «Revisa tu conexión a internet e inténtalo de nuevo.» con «Reintentar» —copy que MIENTE: la conexión está bien y el enlace está muerto— y solo al tapearlo, porque `retry()` degrada a `.expired`, aparece el mensaje correcto sin botón.",
      "⚠︎ CORREGIDO: «este es el ÚNICO error del recorrido que borra el intent» era impreciso. La rama PERMANENTE es la única que lo borra, y cubre TRES kinds: `invalidInvite` (este panel), `notAuthorized` y `generic`. Los dos últimos también limpian el intent pero pintan OTRO alert — «Hubo un problema con el grupo» + «No se pudo completar la acción. Vuelve a intentarlo.» (`GroupBackendInviteEntryHandler.swift:324`) —, una superficie que colisiona visualmente con la del canal apagado y que ningún panel del recorrido retrataba.",
      "Con `max_uses = null` por defecto, «el enlace ya se usó» no es alcanzable salvo que un admin ponga un tope a mano por una vía que la UI no expone."
    ]
  },

  "r3-err-canal": {
    title: "El canal de Grupos está apagado: «Guardamos tu solicitud»",
    shot: "r3-err-canal.png",
    sees: "Un alert titulado «Hubo un problema con el grupo» con el cuerpo «No pudimos abrir esta invitación ahora. Guardamos tu solicitud: vuelve a intentarlo en un momento.» y «OK».",
    persists: "El join intent SE CONSERVA (TTL 7 días). Canario `groupJoinIntentDeferred` con detail `backendChannelOff`.",
    exits: "«OK». El join se completa SOLO cuando el canal vuelva: lo retoma el reconciliador en el siguiente boot o foreground, sin que el usuario haga nada.",
    code: [
      { t: "AppBootstrapper.swift:1991-2005", d: "la rama `.backendUnavailable`: persiste el intent idempotente (:1995), canario (:1997) y `.showGroupSyncError(groups.invite.channelUnavailable)` (:2003-2005)" },
      { t: "GroupBackendInviteEntryHandler.swift:299-312", d: "el gemelo descubierto por el SERVIDOR (403 `yala_groups_disabled`): MISMO canario, MISMO detail y MISMA copy a propósito — es el mismo estado del mundo visto por el otro lado" },
      { t: "GroupBackendAcceptErrorLogic.swift:57-68", d: "`isPermanent`: `channelDisabled` devuelve `false` A PROPÓSITO (:61-66) — limpiar el intent aquí quemaría la invitación por una decisión de configuración que se revierte con un deploy" },
      { t: "ContentView.swift:2026-2036", d: "el alert de `.showGroupSyncError`, con el título `groups.bridge.alertTitle` (:2027)" },
      { t: "GroupJoinReconcileLogic.swift:72", d: "`guard flagEnabled else { return .skipFlagOff }` — el intent se conserva y JAMÁS se procesa por otro canal" }
    ],
    notes: [
      "El uso de `.showGroupSyncError` en vez de `.showInviteError` es deliberado y está escrito en el código (`AppBootstrapper.swift:1998-2002`): el título de aquel está hardcodeado a «Enlace no válido», que aquí sería FALSO —el enlace es perfecto— y mandaría al invitado a pedir uno nuevo que tampoco funcionaría.",
      "Hay DOS formas de llegar aquí y el usuario no las distingue: el snapshot local de remote-config dice OFF tras forzar un refresh, o el servidor responde 403 con el kill-switch bajado. La copy y el canario son los mismos para que en el dashboard sea UNA serie y no dos que haya que sumar.",
      "«Guardamos tu solicitud» es literalmente cierto: es lo único que distingue este mensaje del de enlace inválido."
    ]
  },

  "r3-err-ckshare": {
    title: "El enlace es de la era anterior: el canal que lo servía ya no existe",
    shot: "r3-err-ckshare.png",
    sees: "El alert «Enlace no válido» / «Este enlace ya no es válido o expiró. Pídele al admin que regenere uno.» — el mismo de un enlace caducado.",
    persists: "NADA. Esta es la única rama del enrutado que no persiste ningún intent, y el copy lo refleja: no dice «guardamos tu solicitud» porque no se guarda nada.",
    exits: "«OK». No hay recuperación: el enlace regenerado será del canal backend y ese sí funcionará.",
    code: [
      { t: "AppBootstrapper.swift:1952-1967", d: "la rama `.ckShare`: log (:1963), canario `groupJoinIntentDeferred|ckShareChannelRemoved` (:1964) y `.showInviteError(groups.invite.linkInvalidDetail)` (:1965-1967)" },
      { t: "GroupInviteChannelRoutingLogic.swift:66-68", d: "todo link NO-backend va aquí SIEMPRE, con el flag como esté" },
      { t: "InviteLinkService.swift:129-135", d: "un link CKShare (con `s` pero sin `g`/`t` ni al top ni dentro) devuelve `nil` de `extractBackendInvite`, y por eso cae aquí" }
    ],
    notes: [
      "El comentario del código (`AppBootstrapper.swift:1958-1962`) explica por qué esta rama SÍ reusa el copy de «enlace no válido» mientras `.backendUnavailable` no lo hace: aquí «pídele al admin que regenere uno» es LITERALMENTE cierto.",
      "Es también la rama que más fácil se produce en el simulador: basta pegar en `InviteRecoveryView` cualquier `https://yala-app.pe/invite?s=<lo-que-sea-base64url>` sin `g`/`t`. La validación de la pantalla lo da por bueno (solo mira la forma) y el alert llega un instante después. Y como el alert es byte-idéntico al de `r3-err-enlace`, esta es la vía barata de capturar los dos.",
      "Antes del fix del 2026-07-31 esta rama se tragaba también los links BACKEND, y sin decir nada: `extractShareURL` los acepta porque su `s` decodifica a una URL válida y el guard valida el URL exterior."
    ]
  },

  "r3-err-red": {
    title: "Sin red, o la sesión se cayó a mitad",
    shot: "r3-err-red.png",
    sees: "TRES caras distintas según dónde te pille. En el sign-in: bajo el título, en rojo, «Hmm, no pudimos conectar tu cuenta ahora. Tu grupo sigue aquí y no pierdes nada — inténtalo más tarde.». En el join, si el fallo es transitorio: **NADA** — ni alert ni cambio de pantalla; el cover se queda en «Conectando con tu grupo…» y a los 20 s pasa a «Está tardando un poco más de lo normal». Si la sesión caducó a mitad: reaparece el sheet de sign-in.",
    persists: "El join intent se CONSERVA en las tres. Nada más se escribe.",
    exits: "El reconciliador reintenta en el siguiente boot o foreground. Desde el cover, «Seguir a la app» sigue disponible a los 20 s.",
    code: [
      { t: "GroupBackendInviteEntryHandler.swift:296-298", d: "`.transient`: «Sin alerta; conserva intent (el reconciler reintenta)» — una sola línea de log y nada visible" },
      { t: "GroupBackendInviteEntryHandler.swift:292-295", d: "`.sessionRequired`: re-submitea `.presentGroupsSignIn`, intent conservado" },
      { t: "GroupBackendInviteEntryHandler.swift:269-272", d: "un error que NO sea `GroupsRPCError` se trata como transitorio: conserva el intent y calla" },
      { t: "GroupsSignInView.swift:58-68", d: "el texto de reintento bajo `if signInFailed` (:58): `L10n.Groups.SignIn.retryLater` en :62 e identifier `groups_signin_error` en :67; el comentario de :59-61 dice que C-10 lo cambió porque el anterior era terminal y no decía qué pasaba con el grupo" },
      { t: "GroupBackendAcceptErrorLogic.swift:57-68", d: "ni `transient` ni `sessionRequired` son permanentes (:61-66)" }
    ],
    notes: [
      "⚠︎ La rama transitoria es MUDA por diseño, y el usuario no puede distinguirla de «está tardando». Lo único que ve es el spinner y, a los 20 s, la salida digna. Si sale por ahí, la única señal de que sigue pasando algo es el banner del tab con «Conectando con tu grupo…».",
      "El copy del sign-in es el único de todo el recorrido que nombra explícitamente lo que NO se pierde («Tu grupo sigue aquí y no pierdes nada»), y es exactamente la promesa que sostiene el join intent."
    ]
  },

  "r3-otra-sesion": {
    title: "La invitación llega a un móvil donde ya hay sesión de otra persona",
    shot: null,
    sees: "Nada distinto: el recorrido corre IGUAL. Si esa sesión ya tiene consent y onboarding hechos, el enlace se une al grupo directamente **con la identidad de quien está firmado**, sin preguntar ni avisar.",
    persists: "El join intent, `groupsBetaUnlocked`, y —server-side— una membresía a nombre del `sub` de la sesión viva. Si el onboarding estuviera sin completar, además las preferencias del silent-setup, que en sesión secundaria caen en el `UserDefaults.standard` del DUEÑO.",
    exits: "Los mismos que el recorrido normal. No hay ninguna pantalla de bloqueo ni de confirmación de identidad.",
    code: [
      { t: "GroupBackendAcceptErrorLogic.swift:9-13", d: "lo declara el propio código: «ya no tiene caso de sesión secundaria — un join en secundaria hoy es una FEATURE (la invitada se une a SU grupo con SU identidad), no un bug»" },
      { t: "ContentView.swift:981-988", d: "la rama ORGANIZADOR sí tiene su guard: `if SecondarySessionStore.isActive()` la manda a la puerta del Welcome en vez de dejarla avanzar; el porqué está escrito en :971-980" },
      { t: "WelcomeGroupsGateView.swift:162", d: "la puerta del Welcome pasa `isSecondarySession: SecondarySessionStore.isActive()` a `GroupsOrganizerGateLogic` — la del invitado NO tiene puerta equivalente" },
      { t: "PreferenceSyncService.swift:78", d: "`private let local = UserDefaults.standard` — hardcodeado, no hay dominio por sesión" },
      { t: "OnboardingMode.swift:59-62", d: "`setCurrent` SÍ lleva su `guard !SecondarySessionStore.isActive(defaults)` (:60)" },
      { t: "GroupsSignInView.swift:11-13", d: "si ya hay sesión viva, esta vista JAMÁS se presenta: el docblock lo declara («`GroupBackendInviteEntryLogic.nextStep` lo garantiza en el productor») y el belt del `onAppear` la cierra de inmediato" }
    ],
    notes: [
      "⚠︎ MEDIDO con grep: `SecondarySessionStore.isActive()` no aparece ni una vez en `GroupBackendInviteEntryHandler.swift`, `GroupInviteChannelRoutingLogic.swift`, `InviteRecoveryView.swift` ni en la rama de invite de `AppBootstrapper.handleInviteLink`. La asimetría con la rama organizador —que tiene DOS puertas— es total y deliberada.",
      "⚠︎ La consecuencia que sí es un riesgo: si `hasCompletedOnboarding` está en `false` (lo reabre un borrado de datos en sesión), la puerta `.invite` devuelve `.presentInviteOnboarding` y `performSilentSetup` escribe nombre, divisa y período en el dominio del dueño. Es exactamente el hueco que `advanceGroupsOrganizerFlow` cierra para el organizador.",
      "La frontera que SÍ existe es la de la ENTRADA a la sesión secundaria (`reentry-slotocupado`), no la de la invitación. Y el veredicto que la rama organizador sí sabe pintar vive en las keys `welcome.groups.secondaryTitle` / `welcome.groups.secondaryBody`, que el Atlas ya retrata en el panel de esa puerta — no en este recorrido."
    ]
  },

  "r3-muertos": {
    title: "Las tres pantallas que este recorrido ya no puede mostrar",
    shot: null,
    sees: "Lo que se ve es lo que NO se ve. `GroupReconnectView` (la pantalla de reconexión, con sus OCHO modos), la oferta «carga tus datos de iCloud antes de unirte» y la ruta `.presentGroupInviteOnboarding` con metadata del grupo son código vivo, traducido y sin un solo camino que las alcance.",
    persists: "Nada: no se ejecutan.",
    exits: "N/A.",
    code: [
      { t: "ContentView.swift:907-915", d: "los tres `case` del drain que encienden `showGroupInviteOnboarding` (:907-909), `showGroupReconnect` (:910-912) y `showRestoreOffer` (:913-915)" },
      { t: "RouterIntent.swift:105-110", d: "los tres intents declarados: `presentGroupInviteOnboarding` (:105), `presentGroupReconnect` (:106) y `offerRestoreBeforeInvite` (:110)" },
      { t: "RouterIntent.swift:29-46", d: "`ReconnectMode` tiene OCHO casos: `standardReconnect`, `archived`, `alreadyMember`, `pendingDuplicate`, `rejectedRetry`, `leftRetry`, `removedRetry`, `deletedForAll`" },
      { t: "ContentView.swift:1953-1999", d: "`handleReconnectJoin` (declarada en :1954) cubre esos ocho modos en CINCO ramas del switch: `.archived/.deletedForAll` (:1959), `.alreadyMember` (:1963), `.pendingDuplicate` (:1970), los tres `*Retry` (:1973) y `.standardReconnect` (:1991)" },
      { t: "AppBootstrapper.swift:2051-2055", d: "`InviteRouteDecision` se declara «**HUÉRFANA en producción desde la Fase 3**» en su propio docblock (:2053); la función que la calcula es `inviteRouteDecision` (:2074) y el grep lo confirma: cero call-sites fuera de `YalaTests/AppBootstrapperTests.swift`" },
      { t: "ContentView.swift:1341-1347", d: "el ÚNICO otro camino a `showGroupInviteOnboarding = true`, y está bajo `#if DEBUG`" }
    ],
    notes: [
      "⚠︎ MEDIDO con grep sobre `Yala/`: los tres intents NO se submitean desde ningún sitio — sus únicas apariciones son la declaración (`RouterIntent.swift:105-110`), el drain (`ContentView.swift:907-915`) y las clasificaciones del propio enum (`:162`, `:201`, `:243-248`, `:306`). El único camino de producción al onboarding del invitado es `.presentGroupBackendInviteOnboarding` (`ContentView.swift:942-953`), que fuerza `pendingInviteMetadata = nil`.",
      "⇒ Los estados «ya eres miembro de este grupo», «tu solicitud está duplicada», «volviste tras salir» y «te habían quitado» no tienen HOY ninguna superficie. Lo que ocurre en su lugar: `join_group` devuelve el status existente sin tocar nada y el invitado ve «¡Todo listo!» o la sala de espera, según cuál sea.",
      "Es el mismo patrón que el Atlas ya retrató en `onboarding-adopcion`: una pantalla que existe en el binario y no en el producto. Aquí son tres a la vez, y todas del recorrido del invitado.",
      "El hook `#if DEBUG` que sí presenta el cover del invitado se llama `-uitest-invite-onboarding` (`UITestHooks.swift:183`), y se combina con `-uitest-join-phase <accepting|waitingForZone|creatingMember|pendingApproval|active|failed|failedMemberSave|expired>` (OCHO, los del `switch` de `GroupJoinIntentTracker.swift:143-156`; el docblock de `:185` solo documenta cinco) (`:185-194`, consumido por `GroupJoinIntentTracker._uitestForcePhase`, `:143-156`). Es la vía con la que se capturan `r3-onboarding-nombre`, `r3-esperando`, `r3-solicitud`, `r3-listo` y `r3-banner`."
    ]
  },


  // ══════════════════════════════════════════════════════════════════════════
  // R10 · Estoy de visita en el móvil de otra persona
  // ══════════════════════════════════════════════════════════════════════════

  "visita-stores": {
    title: "Decisión sin pantalla · de quién es cada cajón durante la visita",
    shot: null,
    sees: "Nada: decide, antes de que exista una sola pantalla, qué datos ve la invitada y cuáles son del dueño. Tres cajones de SwiftData y tres de preferencias, y NO caen del mismo lado.",
    persists: "Lo que se MONTA, no lo que se escribe. Personal → `YalaModel-Secondary`, archivo propio y mirror de iCloud JAMÁS adjunto. Sync-meta → `YalaSyncMeta-Secondary`, y este es INCONDICIONAL (no lo ANDea el flag de Grupos): cursor, journal e identidades de la invitada nunca caen en el archivo del dueño. **Grupos → SOLO es suyo si el canal de Grupos está ENCENDIDO**: `GroupsStoreDecision.decide` exige `flagOn && secondaryActive`, así que con el canal apagado la invitada monta el store de grupos del DUEÑO. Y los tres cajones de preferencias NO se desdoblan: `UserDefaults.standard`, el iCloud KV del Apple ID del dueño y el Keychain (este último sí lleva la sesión de la invitada). El modo efectivo del proceso pasa a `.cloud` por la sola presencia del descriptor.",
    exits: "No hay salida: es el suelo del recorrido. Todo lo que sigue se explica desde aquí — lo que la invitada ve en pantalla sale de sus cajones; lo que se escribe cae en los del dueño salvo que un guard lo impida.",
    code: [
      { t: "SwiftDataConfiguration.swift:216-220", d: "`.secondaryCloudSession` — el primer caso del enum de decisión de mount, y el que gana ANTES que todo" },
      { t: "SwiftDataConfiguration.swift:1036-1046", d: "la decisión se evalúa y su `case .secondaryCloudSession` devuelve `ModelConfiguration(secondaryDatabaseName, …, cloudKitDatabase: .none)`" },
      { t: "SwiftDataConfiguration.swift:458-459", d: "`GroupsStoreDecision.decide`: `(flagOn && secondaryActive) ? .secondary : .primary` — con el canal apagado, los grupos montados son los del DUEÑO" },
      { t: "SwiftDataConfiguration.swift:1103-1109", d: "el switch que lo aplica al `ModelConfiguration` de grupos" },
      { t: "SwiftDataConfiguration.swift:1135-1140", d: "el mount del sync-meta: con descriptor vivo es un archivo propio, y sin condicionar al flag de Grupos" },
      { t: "SwiftDataConfiguration.swift:1072-1077", d: "el porqué y el nombre del archivo: cursor, journal e identidades de la invitada jamás en el `YalaSyncMeta` del dueño" },
      { t: "PersonalContainerSwap.swift:84-89", d: "los tres stores son UN solo `ModelContainer` con tres configuraciones — por eso un `FetchDescriptor<SplitGroup>` desde el contexto personal alcanza el store de grupos montado" },
      { t: "CloudSyncFlags.swift:246-251", d: "`storageMode` devuelve `.cloud` en cuanto hay descriptor, sin mirar la key persistida" },
      { t: "PreferenceSyncService.swift:34-49", d: "`PrefsSyncBehavior.resolve`: la secundaria gana primero y da `.localOnly`, que corta iKV y outbox" },
      { t: "PreferenceSyncService.swift:78", d: "`private let local = UserDefaults.standard` — HARDCODEADO: `.localOnly` corta la PROPAGACIÓN, jamás la escritura local" },
      { t: "PreferenceSyncService.swift:162-173", d: "y se ve en el cuerpo: `local.set(...)` está en la línea 163, FUERA del switch de comportamiento" }
    ],
    notes: [
      "MEDIDO: no existe ningún dominio de `UserDefaults` por sesión. La frontera de preferencias no la da un contenedor separado, la dan guards uno a uno — y por eso se pueden contar (ver `degradado-ajustesdueno`) y por eso se puede medir cuáles faltan.",
      "⚠︎ El nodo `degradado-ajustesdueno` dice que «con el canal apagado el tab Grupos se filtra». Es cierto para el TAB (`TabBarConfiguration.swift:126-128`) y NO para el STORE: el archivo del dueño sigue montado en el mismo container, así que cualquier código que haga `FetchDescriptor<SplitGroup>()` lee sus grupos — y cualquiera que los borre, los borra.",
      "El Keychain sí es propio: la sesión Yala de la invitada vive ahí y sobrevive al relevo, que es la razón por la que el «empiezo de cero» del Welcome mata el outbox de Grupos y CONSERVA su cursor."
    ]
  },

  "visita-shell": {
    title: "M1 · La invitada ya dentro: la app que ve mientras baja su cuenta",
    shot: "visita-shell.png",
    sees: "La app normal, con tres diferencias. Arriba, mientras su cuenta se descarga, una píldora de cristal con un spinner: «Descargando tus datos…» (desaparece sola cuando el primer pull completa). En Ajustes desaparece «Tu cuenta de Yala», que describe la cuenta del dueño. Y la fila «Dónde viven tus datos» **depende del build**: en producción se oculta; en builds DEV se conserva a propósito —es la única puerta al panel de depuración, la única salida por producto de una sesión de prueba— y su pantalla degrada a «Algo no salió bien. Inténtalo de nuevo.» con el panel DEBUG debajo. **La barra de pestañas es la que configuró el DUEÑO** —se lee de la misma preferencia compartida—; lo único que se le recorta a la visita es Grupos, y solo cuando el canal de Grupos está apagado.",
    persists: "El banner no persiste nada (poll de 1 s en memoria) y las filas ocultas son decisiones de render. Lo que SÍ persiste es lo que la visita toque de la barra: si personaliza las pestañas, `tabConfigJSON` se escribe en el `UserDefaults.standard` del dueño sin guard y el wipe de salida no lo repone. El modo de onboarding es el contraste exacto: ahí sí hay guard y la escritura se descarta.",
    exits: "Se sale usando la app con normalidad. La salida real de la sesión vive en Ajustes → cerrar sesión (`signout-path`), y en builds DEV también en el panel de depuración.",
    code: [
      { t: "SecondaryHydrationBanner.swift:18-20", d: "la decisión pura: hay descriptor y el primer pull no ha completado" },
      { t: "SecondaryHydrationBanner.swift:32", d: "el copy del banner" },
      { t: "ProfileView.swift:939-946", d: "la fila «Dónde viven tus datos» pasa por `StorageRowGateLogic.isVisible`, con `devPanelOverride` en el call-site" },
      { t: "StorageRowGateLogic.swift:59", d: "`if isSecondaryActive { return devPanelOverride }` — oculta en release, abierta en DEV" },
      { t: "StorageRowGateLogic.swift:30-36", d: "`devPanelOverrideAvailable` es `true` bajo `#if DEV_BUILD` y `false` literal en producción" },
      { t: "StorageSettingsView.swift:50-56", d: "el acceso directo degrada al aviso genérico" },
      { t: "StorageSettingsView.swift:66-68", d: "…y el `cloudDebugPanel` cuelga FUERA de ese `if`, así que en DEV la pantalla muestra las dos cosas" },
      { t: "ProfileView.swift:220-221", d: "`showsYalaAccountRow` — «Tu cuenta de Yala» exige sesión backend **y** no estar de visita" },
      { t: "ContentView.swift:2094", d: "`tabConfigJSON` es `@AppStorage` del dominio COMPARTIDO ⇒ la visita hereda la barra del dueño" },
      { t: "ContentView.swift:2115-2125", d: "`visibleTabs` compone el modo del dueño con el recorte de secundaria" },
      { t: "TabBarConfiguration.swift:126-128", d: "el único recorte propio: sin canal de Grupos, fuera el tab (sería el iCloud del dueño)" },
      { t: "TabBarConfigView.swift:265", d: "la personalización de la visita escribe `appPreferences.tabConfigJSON`" },
      { t: "AppPreferences.swift:1182-1188", d: "`persistString` hace `defaults.set(...)` SIEMPRE, sea `synced` o no; el `defaults` de producción es `.standard` (init en :832, construido en `AppBootstrapper.swift:38`)" },
      { t: "OnboardingMode.swift:60", d: "el contraste que hace visible el hueco: el modo de onboarding SÍ tiene guard (`guard !SecondarySessionStore.isActive(defaults) else { return }`) y la barra no" }
    ],
    notes: [
      "MEDIDO, y con una corrección: la shell que ve es la del DUEÑO, pero no todo lo que ella cambie muere con el proceso. El MODO de onboarding sí (guard en `OnboardingMode.setCurrent`, residual declarado en su propio docblock); la BARRA no — se queda escrita durablemente en el dominio de él, y el wipe de salida solo repone los tres flags de onboarding.",
      "El banner es la única superficie que explica por qué la app se ve «en cero» los primeros segundos. Sin él, la invitada vería una app vacía sin motivo.",
      "La fila «Dónde viven tus datos» que se ve en una captura de simulador NO contradice el diseño: el simulador solo puede montar la sesión secundaria con el scheme `Yala Dev`, y ahí la fila está abierta a propósito."
    ]
  },

  "visita-frontera-prefs": {
    title: "M1 · La frontera de los cuatro guards: qué queda FUERA de ellos",
    shot: null,
    sees: "Nada: es el negativo del panel de los cuatro ajustes del dueño. Los guards existen y funcionan; lo que este panel cuenta es qué escrituras de la visita NO pasan por ninguno.",
    persists: "En el `UserDefaults.standard` del DUEÑO, medido y sin guard: las CINCO preferencias del onboarding privado (`userName`, `defaultCurrencyCode`, `defaultPeriod`, `expensesOnlyMode`, `financialMindset`) más `hasCompletedOnboarding`; las DOS que borra el «empiezo de cero» (`userName`, `defaultCurrencyCode`); `hasShownWelcomeChooser`; `tabBarConfiguration` si toca la configuración de pestañas; `usageFocus` si toca la pantalla de retención; y —si el alert de borrado llega a salir— el sello `groupsDomainSealedForFreshStart`, el borrado de `groupsBetaUnlocked` y del latch de sesión de Grupos. **Y en el iCloud KV del Apple ID del DUEÑO, sin guard y sin pasar siquiera por el switch de comportamiento**: `lastWipeTimestamp` (si la visita vacía sus datos) y `lastOnboardingTimestamp` (si completa el onboarding), más el `\"\"` que `OnboardingResetHelper` escribe en `userName`/`defaultCurrencyCode` y el que `clearHandoverOnboardingMode` escribe en `onboardingMode`. Todo eso sincroniza con los otros dispositivos de él.",
    exits: "No es una pantalla y no tiene salida. Lo que la cierra, cuando se cierra, es un `guard` en el escritor.",
    code: [
      { t: "OnboardingResetHelper.swift:25-28", d: "`safeKeysToClear` = `userName` + `defaultCurrencyCode`, y nada más" },
      { t: "OnboardingResetHelper.swift:34-46", d: "borra local y escribe `\"\"` al iKV; el fichero no conoce la sesión secundaria" },
      { t: "OnboardingView.swift:1779-1794", d: "las cinco `sync.set` del paso 8, sin guard" },
      { t: "OnboardingView.swift:1823", d: "`UserDefaults.standard.set(true, forKey: \"hasCompletedOnboarding\")`" },
      { t: "PreferenceSyncService.swift:481-484", d: "`signalWipeInitiated` — `iKV.set` + `synchronize()` DIRECTOS al Apple ID del dueño, fuera del switch de `PrefsSyncBehavior`" },
      { t: "PreferenceSyncService.swift:495-498", d: "`signalOnboardingCompleted` — la gemela, misma forma y mismo destino" },
      { t: "GroupsOrganizerOnboarding.swift:164", d: "el contraste: el alta del organizador SÍ tiene guard, y cubre el MÉTODO entero" },
      { t: "GroupsRetentionView.swift:64, 84", d: "`appPreferences.usageFocus` escrito por la visita en el dominio compartido" },
      { t: "DataWipeService.swift:321", d: "el sello del handover, escrito en el dominio del dueño" },
      { t: "DataWipeService.swift:397-408", d: "`clearHandoverOnboardingMode` escribe `\"\"` al `onboardingMode` del iKV del Apple ID del DUEÑO" }
    ],
    notes: [
      "⚠︎ HALLAZGO. El source-scan que sostiene los guards (`SecondaryOwnerDomainGuardsTests`, el test de las líneas 214-247) busca los escritores de UNA key —`set(string: OnboardingMode` y `setSynced(OnboardingMode`— y por eso ve dos y los dos llevan guard. `OnboardingView.completeOnboarding` no escribe el modo: escribe otras cinco preferencias por el mismo servicio, así que **queda fuera del inventario del escáner**. Es la regla que el propio repo escribió («el inventario que el escáner mira tiene que ser el inventario que la función escribe») una capa más arriba.",
      "⚠︎ Y la clase que más pesa no es `UserDefaults`: los dos señalizadores de `PreferenceSyncService` escriben DIRECTO al `NSUbiquitousKeyValueStore` sin consultar el switch de comportamiento. `.localOnly` no los ve, así que la visita puede emitir una señal de wipe y una de onboarding a los otros dispositivos del dueño.",
      "MEDIDO: `PreferenceSyncService.set` hace su `local.set(...)` FUERA del switch, así que `.localOnly` tampoco protege de nada local. La protección es siempre un guard en el llamador.",
      "La asimetría es exacta y vale la pena verla junta: el alta del ORGANIZADOR se bloquea antes de escribir una sola preferencia; el alta PRIVADA escribe seis sin que nadie pregunte."
    ]
  },

  "visita-vaciar": {
    title: "M1 · «Vaciar mis datos»: la puerta por la que la visita vuelve al Welcome",
    shot: "visita-vaciar.png",
    sees: "En Ajustes, la última fila de su sección: «Vaciar datos» · «Borra tus datos. Tu cuenta y tus grupos se conservan». Dentro, «Vaciar todos tus datos» y el botón «Vaciar mis datos». Al tocarlo sale la hoja de alcance de siempre (tres filas: dispositivo, cuenta y grupos, con su nota de conservación) y su botón «Vaciar definitivamente»; después, el alert corto «¿Seguro? Esto es definitivo.» con «Cancelar». Si hay grupos vivos, al terminar aparece la pantalla de retención: «Tus datos se vaciaron. Tus grupos siguen aquí.» · «¿Cómo quieres seguir usando Yala?» con «Solo mis grupos» y «Empezar de cero».",
    persists: "El borrado de filas cae en el store de la invitada. **El barrido de preferencias cae en el del dueño**: entre las decenas de keys que retira están `hasCompletedOnboarding` y `hasShownWelcomeChooser` —eso es lo que reabre el Welcome, porque el `@AppStorage` de la app ve la key ausente y encamina— y también `tabBarConfiguration`, o sea el layout de pestañas de él. **Y una escritura que sale del dispositivo**: el PASO 0 del wipe corre `signalWipeInitiated()` (el llamador no pasa `broadcastSignal`, cuyo default es `true`), que estampa `lastWipeTimestamp` en el iCloud KV del Apple ID del dueño y lo anuncia a sus otros dispositivos.",
    exits: "Con grupos vivos → pantalla de retención: «Solo mis grupos» deja la app reducida; «Empezar de cero» llama al encaminamiento inicial. Sin grupos → el encaminamiento corre directo. Y como `hasShownWelcomeChooser` ya no está, ese encaminamiento abre el **Hero del Welcome**, no el onboarding. La invitada aterriza en la pantalla de bienvenida, dentro del móvil de otra persona.",
    code: [
      { t: "ProfileView.swift:959-970", d: "la fila «Vaciar datos» — SIN guard de sesión secundaria, y comentada como «SIEMPRE al final»" },
      { t: "UserDataResetView.swift:246-249", d: "el wipe, con `reseedInitialData: false` y SIN pasar `broadcastSignal`" },
      { t: "DataWipeService.swift:28", d: "…cuyo default es `true`" },
      { t: "DataWipeService.swift:33-35", d: "PASO 0: `PreferenceSyncService.shared.signalWipeInitiated()` — la señal al iKV del dueño" },
      { t: "PreferenceSyncService.swift:481-484", d: "la escritura en sí, sin guard y fuera del switch de comportamiento" },
      { t: "ShellDataAlertsModifier.swift:67-70", d: "el contraste medido: el «empiezo de cero» del Welcome sí pasa `broadcastSignal: false`" },
      { t: "DataWipeService.swift:594-595", d: "`removeObject` de `hasCompletedOnboarding` y `hasShownWelcomeChooser` en el dominio COMPARTIDO" },
      { t: "DataWipeService.swift:494", d: "y en el mismo barrido, `tabConfigJSON` — el layout de pestañas del dueño" },
      { t: "ContentView.swift:241-253", d: "el `onChange` que encamina, con el freno de la retención" },
      { t: "ContentView.swift:427-431", d: "«Empezar de cero» de la retención → `presentNextOnboardingScreen()`" },
      { t: "ContentView.swift:1376-1381", d: "sin chooser visto ⇒ `welcomeFlowInitialStep = .hero` y el cover se abre" },
      { t: "SwiftDataConfiguration.swift:875-891", d: "la curación de esos flags existe (886-889), pero es ONE-SHOT: el guard de 880-881 la corta y su marker (891) ya está puesto desde la entrada" }
    ],
    notes: [
      "⚠︎ HALLAZGO, y es el que abre el recorrido entero. `performSecondaryEntryTasksIfNeeded` cura los flags de onboarding «si un kill se comió la ventana descriptor→flags», y su propio docblock nombra el peligro (`SwiftDataConfiguration.swift:856-859`): sin curación «el boot mostraría el Welcome sobre el store secundario vacío y un re-sign-in caería en el adopt CLÁSICO, que escribe el PAR global `.cloud`+`mirrorOffArmed` del dueño». La curación está marcada como hecha desde la entrada, y su marker (`cloudSync.secondarySession.entryPurgeDone`) está EXCLUIDO del barrido de prefs (`DataWipeService.swift:469-470`) ⇒ **el vaciado en sesión reabre exactamente ese estado y ya nadie lo cura**, ni en este arranque ni en los siguientes.",
      "⚠︎ Con el canal de Grupos APAGADO, «grupos vivos» son los del DUEÑO (el store montado es el suyo): la hoja de alcance le promete a la invitada que se conservan unos grupos que no son suyos, y la pantalla de retención le ofrece quedarse solo con ellos.",
      "MEDIDO: la hoja dice que la cuenta se borra porque en secundaria el modo efectivo es `.cloud` ⇒ el alcance que describe es la cuenta de la invitada, y añade la línea del residual multi-dispositivo. Esa parte es honesta.",
      "La pantalla de retención solo aparece con grupos vivos en el store montado; sin ellos, del alert corto se pasa directo al Welcome."
    ]
  },

  "visita-chooser": {
    title: "M1 · El chooser de tres ramas, con la sesión de la visita viva",
    shot: "visita-chooser.png",
    sees: "El Welcome de siempre: «¡Hola! ¿Qué quieres hacer en Yala?» con las tres cards —«Es mi primera vez en Yala», «Ya tengo una cuenta», «Vengo por un grupo»—. **Ni una palabra dice que esta sesión no es de este dispositivo.** El Hero de antes tampoco: promete «100% privado · Tu info siempre contigo».",
    persists: "Abrir el chooser no escribe nada. Cada una de sus salidas sí, y ahí es donde se separan: la de grupos se bloquea antes de escribir; las otras tres no tienen puerta.",
    exits: "Cuatro salidas y las cuatro son alcanzables con el descriptor vivo: (1) «Vengo por un grupo» → el sub-chooser y, en «Crear mi primer grupo», LA PUERTA; (2) «Ya tengo una cuenta» → restaurar de iCloud o entrar a la cuenta nube; (3) «Es mi primera vez» → cuenta nube nueva o privacidad total; (4) «Tengo una invitación» dentro de la card de grupos → recuperación de invitación. **Ninguna de las tres últimas pasa por relanzamiento**: el portal solo lo exige cuando el proceso montó el store NEUTRO, y aquí montó el secundario.",
    code: [
      { t: "WelcomeChooserView.swift:30-44", d: "de dónde sale el copy de las tres cards (título y cuerpo por rama)" },
      { t: "WelcomeChooserView.swift:75-80", d: "el título y el subtítulo de la pantalla" },
      { t: "WelcomeFlowContainer.swift:144-151", d: "el switch de las tres ramas del chooser: `.restore` y `.new` abren su 2º nivel, `.invite` desvía al sub-chooser de grupos" },
      { t: "WelcomeFlowContainer.swift:161", d: "la ida: la card de crear NO sale del cover, va al step de la puerta" },
      { t: "WelcomeFlowContainer.swift:177, 165", d: "la cadena de vuelta: puerta → sub-chooser de grupos → chooser (por aquí se llega al chooser aunque el cover se abriera en la puerta)" },
      { t: "WelcomeFlowContainer.swift:230-240", d: "`leaveWelcome`, el portal único de salida" },
      { t: "WelcomeMirrorRelaunchLogic.swift:94-99", d: "`shouldRelaunch`, segundo término: `mountedDecision == .neutralNoMirror` — en secundaria es `.secondaryCloudSession` ⇒ **jamás relanza**" },
      { t: "WelcomeMirrorRelaunchLogic.swift:78-85", d: "`requiresMirror`: privado, restore e invitación piden espejo… y en esta sesión no lo tendrán nunca" },
      { t: "ContentView.swift:981-988", d: "la segunda puerta al Welcome: el avance de la rama organizador con descriptor vivo remonta el cover EN la puerta" }
    ],
    notes: [
      "MEDIDO: el chooser es alcanzable de dos formas. La viva hoy es el vaciado en sesión (`visita-vaciar`); la otra es el propio choke-point de la rama organizador, que abre el cover en la puerta y desde ahí se camina hacia atrás hasta el chooser con los dos «Volver».",
      "⚠︎ Que los tres destinos que PIDEN espejo salgan sin relanzamiento no es un olvido del portal: su segundo término está escrito estrecho a propósito (`WelcomeMirrorRelaunchLogic.swift:89-93` — «los otros dos mounts sin mirror son devices que YA están en modo nube, donde este Welcome no se presenta»). La premisa es la que se rompió: aquí el Welcome sí se presenta.",
      "El copy del Hero («Tu info siempre contigo») y el de la card privada («Nadie más puede leerlos») describen un dispositivo que es tuyo. En esta pantalla, no lo es."
    ]
  },

  "visita-crear-grupo": {
    title: "Intento 1 · «Crear mi primer grupo»: la ÚNICA de las cuatro con puerta",
    shot: "visita-crear-grupo.png",
    sees: "Primero «Comprobando que todo esté listo…» con un spinner; después, la pantalla honesta: reloj sobre persona, «Aquí estás como invitado» y «Esta sesión vive en el dispositivo de otra persona, así que tu primer grupo se crea desde el tuyo. Cierra tu sesión de invitado y vuelve a intentarlo allí.», con «Volver».",
    persists: "NADA, y ese es el chip entero: la puerta se comprueba antes de pedir nombre, antes de firmar y antes de escribir una sola preferencia.",
    exits: "«Volver» → sub-chooser de grupos, con la otra vía intacta. La salida real que el copy nombra está fuera de la app: cerrar la sesión de invitado y volver desde el móvil propio.",
    code: [
      { t: "GroupsOrganizerGateLogic.swift:78-85", d: "los tres términos en orden (81-83): canal, visita, datos ajenos" },
      { t: "GroupsOrganizerGateLogic.swift:37-47", d: "por qué el término de la visita va DELANTE de los datos ajenos: el detector mide el store de la INVITADA, que está vacío" },
      { t: "WelcomeGroupsGateView.swift:157-163", d: "el veredicto se calcula con el descriptor y con un fetch VIVO del corpus" },
      { t: "WelcomeGroupsGateView.swift:66-74", d: "la celda con copy propio y su identificador `welcome_groups_gate_secondary_session`" },
      { t: "WelcomeGroupsGateView.swift:102", d: "el copy del spinner de comprobación" },
      { t: "ContentView.swift:971-988", d: "el choke-point: cualquier avance de la rama con descriptor vivo se manda a esta misma puerta" },
      { t: "GroupsOrganizerOnboarding.swift:164", d: "tercera red, en el escritor: el alta entera devuelve `false` sin escribir" }
    ],
    notes: [
      "MEDIDO: la segunda puerta (`ContentView.swift:981-988`) es defensa en profundidad y hoy no se alcanza por la UI — en secundaria el modo efectivo es `.cloud` y `OnboardingGroupsPurposeGateLogic.shouldShowGroupsCard` (`:97-103`) deja de pintar la card «Solo grupos». Lo afirma y lo prueba `YalaUITests/Flows/SecondarySessionGateUITests.swift:197` (`test_purposeStep_inSecondarySession_hidesGroupsOnlyCard`).",
      "El orden de los tres términos importa para lo que la invitada LEE: con el canal de Grupos apagado gana el copy de canal («Ahora mismo no podemos abrirte grupos»), que le cuenta un problema transitorio en vez del real.",
      "Esta es la comparación que hace valioso el resto del recorrido: mismo Welcome, mismo instante, misma sesión — un botón bloquea sin escribir y los otros tres escriben sin preguntar."
    ]
  },

  "visita-reentrar-cuenta": {
    title: "Intento 2a · «Ya tengo una cuenta → Entrar con Apple/Google» desde la visita",
    shot: "visita-reentrar-cuenta.png",
    sees: "Depende del kill-switch remoto de nube. Con él encendido (producción sirve `CLOUD_MODE` al 100), el sub-chooser de re-entrada muestra sus tres cards —«Restaurar desde iCloud», «Entrar con Apple», «Entrar con Google»— bajo «Elige cómo quieres recuperar tus datos.», y después la pantalla de sign-in de siempre. Con el kill en 0 —o bajo uitest sin el argumento del chooser— solo queda una opción visible, el chooser hace bypass y el tap va directo a restaurar: estas dos entradas ni se ofrecen. Ninguna pantalla menciona que ya hay una sesión de invitada viva en este móvil.",
    persists: "Depende de lo que decida el guard cross-cuenta, y el guard mide **el store MONTADO**, que es el de la invitada. Si su store tiene datos y su cuenta ya reclamó este corpus → sigue de largo (`.proceed`). Si su store está VACÍO —el estado exacto en que la deja el vaciado que la trajo al Welcome— el guard también devuelve `.proceed` en su primera línea, sin llegar a mirar nada más.",
    exits: "`.proceed` escribe el consent, marca el onboarding como completado y arranca el ADOPT clásico sobre la sesión viva. `.proceedSecondarySession` llevaría a la confirmación de sesión secundaria (que ya existe como nodo). `.blockedForeignData` pinta la pantalla honesta —«Este dispositivo tiene datos de otra cuenta»— y suelta la sesión.",
    code: [
      { t: "WelcomeAccountChoiceLogic.swift:60-70", d: "`visibleExistingOptions`: las dos cards de nube exigen backend configurado, no-uitest y el flag remoto" },
      { t: "WelcomeFlowContainer.swift:245-251", d: "`handleExistingBranch`: con una sola opción visible hace BYPASS y el sub-chooser no existe" },
      { t: "WelcomeCloudSignInView.swift:708-747", d: "el switch entero de `accountFound`" },
      { t: "CrossAccountEntryGuardLogic.swift:53", d: "`guard hasLocalData else { return .proceed }` — un store vacío pasa por la primera línea" },
      { t: "WelcomeCloudSignInView.swift:738-746", d: "`.proceed` escribe el consent (738), llama a `onAdoptStarted()` (739) y arranca `startAdoptWithExistingSession()` (745)" },
      { t: "ContentView.swift:1558-1565", d: "y es ESE callback el que marca el onboarding como completado, no la vista del sign-in" },
      { t: "WelcomeCloudSignInView.swift:766-774", d: "el guard de ocupación del hueco, que SÍ existe y se comprueba en la entrada" },
      { t: "SwiftDataConfiguration.swift:856-859", d: "el docblock que nombra este peligro por escrito: sin la curación de flags «el boot mostraría el Welcome sobre el store secundario vacío y un re-sign-in caería en el adopt CLÁSICO, que escribe el PAR global `.cloud`+`mirrorOffArmed` del dueño»" }
    ],
    notes: [
      "⚠︎ HALLAZGO. El repo ya identificó este daño y lo dio por cerrado con una curación de flags que corre UNA sola vez (marker `entryPurgeDone`, `SwiftDataConfiguration.swift:891`, excluido del barrido de prefs por `DataWipeService.swift:469-470`). Medido: tras un vaciado en sesión los flags vuelven a estar caídos y la curación ya no corre ⇒ el camino que el docblock describe vuelve a estar abierto.",
      "MEDIDO: el guard cross-cuenta pregunta por el corpus MONTADO, no por de quién es el dispositivo. En sesión secundaria esas dos cosas dejaron de coincidir — es la misma trampa que obligó a añadir el término de visita a la puerta de Grupos, en la pantalla de al lado.",
      "NO he medido qué escribe exactamente el adopt en esta configuración (par de storage, faro, journal): declarado como hueco."
    ]
  },

  "visita-restaurar-icloud": {
    title: "Intento 2b · «Restaurar desde iCloud» sobre un store que no tiene espejo",
    shot: "visita-restaurar-icloud.png",
    sees: "No hay UNA pantalla: `startSearch` bifurca en tres y la búsqueda es la ÚLTIMA salida, detrás de dos guards. (1) Sin cuenta iCloud en el dispositivo —el caso del simulador— sale «Activa iCloud para continuar» · «Necesitas tener iCloud activado para recuperar tus datos. Actívalo en Ajustes y vuelve a intentar.». (2) Con una señal de wipe más reciente que la de onboarding —el estado EXACTO en que deja el vaciado en sesión, que acaba de estampar esa señal— sale «Borraste tus datos» · «Eliminaste tus datos en este dispositivo. Empieza de nuevo cuando quieras.». (3) Solo con iCloud vivo y sin señal de wipe empieza la búsqueda de verdad: «Conectando con iCloud…» → «Trayendo tus datos…» con la barra de progreso, y un tope de 90 s. Como el store montado no tiene espejo de CloudKit adjunto —ni lo tendrá en esta sesión— el desenlace esperado es «No encontramos tus datos» · «No hay datos asociados a tu cuenta de iCloud. ¿Quieres empezar desde cero?». Las tres pantallas llevan el mismo botón: «Empezar desde cero».",
    persists: "La búsqueda no escribe nada. «Empezar desde cero» sí: borra `userName` y `defaultCurrencyCode` del dispositivo (los del DUEÑO) y escribe `\"\"` en los dos del iCloud KV de SU Apple ID; después abre el onboarding privado.",
    exits: "«Empezar desde cero» → onboarding de 8 pasos (ver `visita-privado-onboarding`). El back devuelve al chooser. **Este camino no pasa por el alert de borrado**: llama a la limpieza de residuales y abre el onboarding sin preguntar nada.",
    code: [
      { t: "WelcomeFlowContainer.swift:255-262", d: "la card de restaurar y su destino; el portal decide que no hay que relanzar" },
      { t: "WelcomeRestoreView.swift:113-127", d: "`startSearch`: dos guards ANTES de `.searching` — iCloud no disponible ⇒ `.iCloudDisabled`; wipe más reciente que el onboarding ⇒ `.wiped`" },
      { t: "RestoreOfferGate.swift:42-44", d: "`wasWiped = lastWipe > 0 && lastWipe >= lastOnboarding`" },
      { t: "PreferenceSyncService.swift:108, 111", d: "y los dos timestamps se leen del iKV del Apple ID del DUEÑO — el mismo al que la invitada acaba de escribir al vaciar" },
      { t: "WelcomeRestoreView.swift:54-57", d: "`.searching` monta `RestoreProgressView`; sin datos al asentar ⇒ `.notFound`" },
      { t: "RestoreProgressView.swift:53-58", d: "el copy que se ve durante la espera sale de `welcome.restore.progress.*`, no de `welcome.restore.searching`" },
      { t: "RestoreProgressView.swift:28, 150", d: "tope de 90 s esperando la quiescencia del import de iCloud" },
      { t: "WelcomeRestoreView.swift:276-285", d: "`notFoundView` y su botón principal" },
      { t: "WelcomeRestoreView.swift:288-299", d: "`iCloudDisabledView`" },
      { t: "WelcomeRestoreView.swift:314-324", d: "`wipedView`" },
      { t: "ContentView.swift:668-676", d: "`onStartFresh` — la SEGUNDA puerta al onboarding privado, sin alert de por medio" },
      { t: "WelcomeMirrorRelaunchLogic.swift:61-64", d: "lo que el propio código predice de esta pantalla sin espejo: «agotaría su timeout de 90 s y le diría al usuario que su cuenta está vacía»" }
    ],
    notes: [
      "⚠︎ El comentario de `requiresMirror` describe este desenlace como el motivo por el que este destino EXIGE relanzamiento — y en sesión secundaria el relanzamiento no se pide, porque el segundo término del predicado solo mira el mount neutro.",
      "⚠︎ El camino que el propio Atlas usa para traer a la invitada al Welcome —el vaciado en sesión— es justo el que hace `wasWiped` verdadero, así que en el recorrido narrado la pantalla que sale es `.wiped`, no la búsqueda. La cadena de 90 s solo se alcanza llegando al Welcome por la otra vía (el choke-point de la rama organizador) y con iCloud disponible.",
      "MEDIDO: `welcome.restore.searching` y `welcome.restore.searchingTip` existen en `es.lproj` y en `L10n.swift` pero NO tienen un solo call-site que las pinte — el estado `.searching` monta `RestoreProgressView`, cuyo texto sale de `welcome.restore.progress.*`. El Atlas las cita marcadas como inalcanzables.",
      "MEDIDO: hay DOS entradas al onboarding privado y solo una lleva el alert de borrado. Esta no lo lleva.",
      "NO he medido qué devuelve exactamente la espera de quiescencia con un store sin espejo adjunto (¿90 s exactos? ¿salida temprana?) ⇒ la pantalla final de la rama (3) es una inferencia razonada, no una captura. Declarado como hueco."
    ]
  },

  "visita-cuenta-nueva": {
    title: "Intento 3 · «Soy nuevo → cuenta en la nube» desde el móvil de otra persona",
    shot: "visita-cuenta-nueva.png",
    sees: "El sub-chooser «Elige dónde quieres guardar tus datos.» con las dos cards —«Tu cuenta en tu iCloud privado» y «Tu cuenta en la nube»— y, si elige la nube, el consentimiento y el alta de siempre. Antes de ofrecer nada, la rama consulta el FARO, que vive en el iCloud KV del Apple ID del DUEÑO: si el dueño ya tuvo cuenta nube, la invitada ni ve las cards — se la encamina directa al sign-in con el proveedor del dueño.",
    persists: "Si el alta llega a crear cuenta (`created`), **escribe el faro**: enlazado, proveedor, hash de cuenta y fecha… en el iCloud KV del Apple ID del DUEÑO, que sincroniza con SUS otros dispositivos.",
    exits: "El alta termina en la app con la cuenta nueva. En producción esta card no se pinta (su percent remoto es 0); en staging y en builds DEV se sirve al 100, que es exactamente donde la sesión secundaria también está encendida.",
    code: [
      { t: "WelcomeFlowContainer.swift:272-285", d: "`handleNewBranch` — el faro se consulta ANTES de ofrecer nada" },
      { t: "WelcomeAccountChoiceLogic.swift:42-55", d: "`visibleNewOptions`: la card nube exige backend configurado + no-uitest + los dos flags remotos" },
      { t: "CloudBeacon.swift:10-12, 57", d: "el faro ES el `NSUbiquitousKeyValueStore` del Apple ID del dispositivo" },
      { t: "BornCloudSignUpService.swift:249-251", d: "la escritura del faro en el alta, condicionada solo a `claimState == .created` y SIN guard de sesión secundaria" },
      { t: "MigrationWorkExecutor.swift:456-465", d: "el cinturón que sí existe —en el ADOPT— y que dice por qué: «escribirlo auto-encaminaría SUS otros devices a la cuenta de la invitada»" },
      { t: "gateway/wrangler.toml:130, 132, 176", d: "producción: modo nube 100 · elección de alta 0 · sesión secundaria 0" },
      { t: "gateway/wrangler.toml:51-56", d: "staging sirve los cuatro percents al 100 — es donde las dos cosas coexisten" }
    ],
    notes: [
      "⚠︎ HALLAZGO. El cinturón del faro está en el ADOPT y su comentario declara el caso «inalcanzable por diseño (la entrada secundaria no pasa por claim de migración)». Medido: el ALTA born-cloud es otro productor de la misma escritura, no pasa por ahí y no lleva cinturón.",
      "MEDIDO: el daño que el propio cinturón describe es el encaminamiento por faro de la pantalla de al lado — los otros dispositivos del dueño acabarían ofreciéndole entrar a la cuenta de la invitada.",
      "En producción la combinación no existe (los dos percents implicados están a 0). En staging y DEV coexisten al 100, que es donde se hace QA."
    ]
  },

  "visita-privado": {
    title: "Intento 4 · «Soy nuevo → privacidad total»: la rama SIN puerta",
    shot: "visita-privado.png",
    sees: "Si las dos cards son visibles, «Tu cuenta en tu iCloud privado» · «Tus datos viven en los dispositivos Apple de tu Apple ID y se sincronizan por tu iCloud privado. Nadie más puede leerlos, ni siquiera nosotros.». En producción esa pantalla ni se muestra: con una sola opción visible el chooser hace bypass y el tap en «Es mi primera vez en Yala» entra aquí directo. **No hay ninguna pantalla que diga que esta sesión no es de este dispositivo.**",
    persists: "En el instante del tap, y en el dominio del DUEÑO: `hasShownWelcomeChooser = true`, y la limpieza de residuales que borra `userName` y `defaultCurrencyCode` de su `UserDefaults` y les escribe `\"\"` en el iCloud KV de su Apple ID. Nada de esto pasa por ningún guard: `OnboardingResetHelper` no conoce la sesión secundaria.",
    exits: "Dos: con datos detectados en los stores montados sale el alert de borrado (`visita-privado-alert`); sin ellos, el Welcome se cierra y arranca el onboarding de 8 pasos (`visita-privado-onboarding`). El portal no interpone relanzamiento porque este proceso montó el store secundario, no el neutro.",
    code: [
      { t: "WelcomeFlowContainer.swift:287-300", d: "`handleNewOption`: `privateAccount` sale por el portal con destino `.privateOnboarding` — «es el bypass de producción» (comentario en :290-292)" },
      { t: "WelcomeMirrorRelaunchLogic.swift:94-99", d: "el predicado que NO dispara en secundaria" },
      { t: "ContentView.swift:1470-1475", d: "`onSelectPrivateAccount` marca el chooser como visto y llama al helper compartido" },
      { t: "ContentView.swift:1608-1623", d: "`startFreshPrivateOnboarding`: la limpieza de residuales y la bifurcación del alert; **cero comprobaciones de sesión secundaria**" },
      { t: "OnboardingResetHelper.swift:34-46", d: "lo que borra y a dónde escribe el `\"\"`" },
      { t: "GroupsOrganizerGateLogic.swift:78-85", d: "la comparación: la rama de al lado sí pregunta, y pregunta lo mismo que aquí falta" }
    ],
    notes: [
      "⚠︎ RESPUESTA A LA HIPÓTESIS: **el hueco es REAL**. La rama `.privateAccount` no pasa por ninguna puerta equivalente a la del organizador; el portal solo comprueba el mount neutro y en secundaria da `false`; y `checkHasExistingData` mide el store MONTADO, que puede estar vacío. No hay ningún término aguas abajo que lo cierre: ni en el portal, ni en `startFreshPrivateOnboarding`, ni en `OnboardingView`.",
      "MEDIDO: el fichero de la limpieza de residuales no aparece en la lista de ficheros que conocen `SecondarySessionStore` — no es que su guard falle, es que no existe.",
      "El copy es lo que remata la asimetría: la card promete «nadie más puede leerlos» mientras el modo efectivo del proceso sigue siendo `.cloud` y lo que se cree va a la cuenta de la invitada, no al iCloud de nadie."
    ]
  },

  "visita-privado-alert": {
    title: "Intento 4 (bis) · ¿Salta el alert de borrado? Depende de qué cajones estén montados",
    shot: "visita-privado-alert.png",
    sees: "Cuando salta: «Empezar desde cero» · «Detectamos datos previos en tu dispositivo. ¿Borrar todo para empezar como nuevo?» con «Borrar todo y continuar» y «Cancelar».",
    persists: "Si se confirma: se vacía el store personal MONTADO (el de la invitada) y, además, corre la purga del dominio Grupos, que escribe en el dominio del DUEÑO — el sello `groupsDomainSealedForFreshStart`, el borrado de `groupsBetaUnlocked`, el del latch de sesión de Grupos, el de la intención de puenteo pendiente y los prefijos por-grupo — y escribe `\"\"` en el `onboardingMode` de SU iCloud KV. Las filas de grupos borradas son las del store montado: las de la invitada con el canal encendido, **las del DUEÑO con el canal apagado**.",
    exits: "«Borrar todo y continuar» → onboarding privado. «Cancelar» → se queda en el chooser (el cover sigue abierto).",
    code: [
      { t: "ContentView.swift:1616-1622", d: "la bifurcación: `hasExistingData` decide si hay alert o paso directo" },
      { t: "ContentView.swift:1086-1109", d: "`checkHasExistingData` cuenta cuentas y categorías no-sistema **más `SplitGroup` (:1093) y las transacciones puenteadas (:1094-1096)**, sobre el contexto montado; el `catch` devuelve `true` (:1107)" },
      { t: "ShellDataAlertsModifier.swift:64-97", d: "el alert entero y sus dos llamadas de borrado (`wipeAllUserData` con `broadcastSignal: false` y `wipeLocalGroupsDomain`)" },
      { t: "DataWipeService.swift:283-287", d: "la purga borra TODAS las filas `Split*` del store montado" },
      { t: "DataWipeService.swift:310-321", d: "barrido de prefs de Grupos + `clearHandoverOnboardingMode` + sello, en el `UserDefaults` que se le pase (aquí, el compartido)" },
      { t: "SwiftDataConfiguration.swift:458-459", d: "de quién son esas filas: `flagOn && secondaryActive` o el store del dueño" }
    ],
    notes: [
      "MEDIDO, y la respuesta tiene dos mitades: **inmediatamente después del vaciado que la trajo al Welcome, el alert NO salta** —el store personal quedó vacío—, salvo que haya grupos, porque el detector los cuenta y `wipeAllUserData` los conserva a propósito. Con grupos, salta.",
      "⚠︎ HALLAZGO GRAVE. Con el canal de Grupos apagado el store de grupos montado es el del DUEÑO ⇒ el detector cuenta SUS grupos ⇒ el alert salta ⇒ confirmarlo **borra los grupos del dueño** y le deja el dominio sellado. Nada en la cadena pregunta de quién son esas filas.",
      "El alert habla de «datos previos en tu dispositivo»: en esta sesión, la palabra «tu» es falsa en las dos direcciones — ni el dispositivo es suyo ni los datos que el detector encontró tienen por qué serlo."
    ]
  },

  "visita-privado-onboarding": {
    title: "Intento 4 (final) · El onboarding de 8 pasos corriendo en el móvil de otra persona",
    shot: "visita-privado-onboarding.png",
    sees: "El onboarding completo de siempre: «¿Cómo quieres que te llamemos?» con el campo «Tu nombre», «¿Qué te gustaría hacer con Yala?», divisa, estilo, cuenta inicial, presupuesto. Con una diferencia que la invitada no ve venir: la card «Dividir gastos con amigos» · «Viajes, cenas y cuentas compartidas» del paso Propósito no se pinta (el modo efectivo es `.cloud`). Al terminar, la app.",
    persists: "En el paso final, y **todo en el `UserDefaults.standard` del DUEÑO**: `userName`, `defaultCurrencyCode`, `defaultPeriod`, `expensesOnlyMode`, `financialMindset` y `hasCompletedOnboarding`. Las cinco primeras van por el servicio de preferencias, que resuelve `.localOnly` —así que no viajan ni al iKV ni al outbox—, pero la escritura local ocurre igual, porque el espejo local es `.standard` hardcodeado. **Y hay una sexta escritura que sí cruza**: `signalOnboardingCompleted()` estampa `lastOnboardingTimestamp` en el iCloud KV del Apple ID del dueño, directo y fuera del switch de comportamiento — la misma key que gobierna el gate de la oferta de restauración. En SwiftData, la cuenta inicial, el presupuesto y las notificaciones se crean en el store de la INVITADA. **Las categorías no se crean**: el seed retorna en su primera línea cuando hay sesión secundaria.",
    exits: "La app, con el onboarding marcado como completo. Un relanzamiento devuelve la shell del dueño (pestañas y modo se leen de sus preferencias).",
    code: [
      { t: "OnboardingView.swift:1763-1833", d: "`completeOnboarding` — el cuerpo entero, sin un solo término de sesión secundaria" },
      { t: "OnboardingView.swift:1779-1794", d: "las cinco preferencias por el servicio de sync" },
      { t: "OnboardingView.swift:1823", d: "`hasCompletedOnboarding` directo a `UserDefaults.standard`" },
      { t: "OnboardingView.swift:1825", d: "`signalOnboardingCompleted()` — la sexta escritura, y la única que cruza al iKV del dueño" },
      { t: "PreferenceSyncService.swift:495-498", d: "…y lo hace con `iKV.set(...)` + `synchronize()` DIRECTOS, fuera del switch de `behavior`" },
      { t: "OnboardingView.swift:1796-1798", d: "`seedCategoriesIfNeeded` — la llamada existe" },
      { t: "CategorySeed.swift:375-378", d: "…y el cinturón M1 la vacía: «en sesión SECUNDARIA jamás sembrar»" },
      { t: "CategorySeed.swift:590-592", d: "lo mismo para las categorías de sistema del puente" },
      { t: "PreferenceSyncService.swift:78", d: "por qué las cinco caen en el dominio del dueño" },
      { t: "OnboardingView.swift:1800-1802", d: "sin seed y sin modo «solo gastos», solo se asegura la subcategoría de ajuste de saldo" },
      { t: "OnboardingView.swift:529-532", d: "el `if` que decide si la card de grupos existe" },
      { t: "OnboardingGroupsPurposeGateLogic.swift:97-103", d: "…y la decisión pura detrás: en `.cloud` la card no se pinta" }
    ],
    notes: [
      "⚠︎ El cinturón de las categorías está pensado para la invitada que entra por la puerta buena (su store lo puebla el pull de su cuenta). Combinado con este camino produce otra cosa: un onboarding que pregunta si quieres categorías de ejemplo, dice que sí y no crea ninguna.",
      "MEDIDO: seis escrituras en el dominio del dueño y una séptima en su iCloud KV, ninguna con guard. El alta del ORGANIZADOR, que escribe exactamente seis también, aborta entera y devuelve `false`.",
      "Lo que el dueño se encuentra al volver: su nombre y su divisa cambiados por los de la visita (los dos primeros los había borrado ya el tap del chooser), su período por defecto y su estilo financiero reescritos."
    ]
  },

  "visita-salida": {
    title: "M1 · La frontera de salida: cómo el móvil vuelve a ser del dueño",
    shot: "visita-salida.png",
    sees: "La salida se pide desde Ajustes y la cuenta el nodo del cierre de sesión; lo que este panel retrata es lo que pasa DESPUÉS, en el arranque siguiente, antes de que exista una sola vista. Y su única pantalla es la última: el dueño reabre y se encuentra el Hero del Welcome — «Tus finanzas personales,» · «sin esfuerzo.» con «Empezar»— porque el boot le dejó los flags de onboarding en `false`.",
    persists: "El cierre ARMA el wipe secundario; el boot lo ejecuta y es kill-safe. Borra los tres archivos `-Secondary` (personal, sync-meta y grupos), purga las superficies durables del App Group compartido —caché del widget, colas de Apple Pay/Siri e imágenes pendientes, los tres espejos de outbox, las intenciones de unirse a un grupo y el consent de Grupos—, cancela las notificaciones, limpia el descriptor y la marca de purga de entrada, y **pone a `false` los tres flags de onboarding del dispositivo**. El desarmado es siempre el último paso, para que un kill a mitad re-entre limpio.",
    exits: "El dueño reabre y la app arranca sin flags de onboarding: ve el Welcome. Sus datos personales siguen en su archivo intacto — el store secundario y el suyo nunca fueron el mismo fichero.",
    code: [
      { t: "SwiftDataConfiguration.swift:823-849", d: "`performSecondaryWipeIfArmed` — el orden completo, con el desarmado al final (:848)" },
      { t: "SwiftDataConfiguration.swift:844-846", d: "los tres flags de onboarding a `false`" },
      { t: "SecondarySessionBoundaryPurge.swift:24-50", d: "qué superficies del App Group se purgan, y por qué cada una" },
      { t: "PersonalContainerSwap.swift:76-80", d: "los cuatro hooks pre-mount en su orden congelado: primero desarmar la secundaria" },
      { t: "SwiftDataConfiguration.swift:875-891", d: "la gemela de ENTRADA, con su marker one-shot" },
      { t: "ContentView.swift:1273-1283", d: "lo que el dueño ve al reabrir: sin `hasCompletedOnboarding`, el boot llama a `presentNextOnboardingScreen()`" },
      { t: "ContentView.swift:1376-1381", d: "…y sin `hasShownWelcomeChooser`, ese encaminamiento abre el Hero" },
      { t: "DataWipeService.swift:337-372", d: "lo que el wipe de salida NO repone: `removeGroupsDomainPreferenceKeys` tiene un único call-site de producción (`DataWipeService.swift:310`), dentro del «empiezo de cero» del Welcome" }
    ],
    notes: [
      "MEDIDO: la purga corre en las DOS fronteras (entrada y salida) y es idempotente. Lo que no vuelve atrás son las preferencias que la visita escribió en el dominio compartido: el wipe de salida repone tres flags de onboarding y nada más.",
      "Por eso `groupsBetaUnlocked` es la key que más pesa de las seis del alta del organizador — nadie la repone al salir. La misma frase vale para las cinco del onboarding privado y para `tabBarConfiguration`.",
      "La entrada tiene curación de flags y la salida los repone: entre las dos, la ventana que queda abierta es la de la sesión VIVA, que es todo este recorrido."
    ]
  },


  // ══════════════════════════════════════════════════════════════════════════
  // R11 · El dueño recupera su móvil
  // ══════════════════════════════════════════════════════════════════════════

  "vuelta-salida-ajustes": {
    title: "La visita busca la salida: la única fila que tiene, y las tres que le faltan",
    shot: "vuelta-salida-ajustes.png",
    sees: "Ajustes, DOS secciones y un reparto que importa. En «Datos» falta «Dónde viven tus datos» —y detrás de esa fila vive el único aviso de «Inicia sesión para subir %d cambios»—, pero «Vaciar datos» sigue ahí, al final de la sección, con su subtítulo «Borra tus datos. Tu cuenta y tus grupos se conservan». En «Seguridad y cuenta», que viene después, la invitada tiene UNA salida: «Cerrar sesión», subtítulo «Este dispositivo, no tu cuenta», icono rojo — y le faltan «Tu cuenta de Yala» y «Eliminar mi cuenta», ocultas las dos por estar en sesión secundaria.",
    persists: "Nada. Tocar la fila solo abre la hoja de alcance.",
    exits: "Tap → hoja de alcance de cierre. El camino ya está decidido antes de pintar la fila: la precedencia CONGELADA pone la sesión secundaria por delante de TODO, incluso de `.cloud` — sin esa primera rama el cierre de la invitada armaría el wipe del dueño.",
    code: [
      { t: "ProfileView.swift:882 `datosSection`", d: "`SectionBox(title: L10n.Settings.data)`, cierra en :974 — aquí viven «Dónde viven tus datos» (:939-957) y «Vaciar datos» (:959-970)" },
      { t: "ProfileView.swift:976 `seguridadSection`", d: "`SectionBox(title: L10n.Settings.security)` — aquí viven «Cerrar sesión» (:1062, copy en :1070-1071), «Tu cuenta de Yala» (gate :1036, título :1049) y «Eliminar mi cuenta» (gate :1144, título :1157)" },
      { t: "ProfileView.swift:136 `signOutRowPath`", d: "pasa `SecondarySessionStore.isActive()` como `secondarySessionActive:` (:139); el ORDEN de precedencia no está aquí sino en `CloudSignOutFlowLogic.path`" },
      { t: "CloudSignOutFlowLogic.swift:55", d: "`if secondarySessionActive { return .secondaryCloudSignOut }` — la fila 1 de la precedencia; su porqué está escrito en :41-44 («sin esta rama primero el sign-out de la invitada iría a `.cloudSecureSignOut` → el boot borraría el `YalaModel` del DUEÑO»)" },
      { t: "ProfileView.swift:1061-1062", d: "`switch signOutRowLayout` → `case .plainSignOut`: fila única «Cerrar sesión» (la resuelve `CloudSignOutFlowLogic.rowLayout`, :107-110)" },
      { t: "ProfileView.swift:939 + :945", d: "`StorageRowGateLogic.isVisible(...)` recibe `devPanelOverride: StorageRowGateLogic.devPanelOverrideAvailable`" },
      { t: "StorageRowGateLogic.swift:59", d: "`if isSecondaryActive { return devPanelOverride }`, y `devPanelOverrideAvailable` (:30-36) es `false` LITERAL fuera de `DEV_BUILD` ⇒ la fila se oculta en producción" },
      { t: "ProfileView.swift:220 `showsYalaAccountRow`", d: "`deleteAccountRowHasSession && !SecondarySessionStore.isActive()` ⇒ sin «Tu cuenta de Yala»" },
      { t: "ProfileView.swift:1144", d: "`AccountDeletionRowLogic.shouldShow(hasSession:secondaryActive:isGroupInviteMode:)` ⇒ sin «Eliminar mi cuenta»" },
      { t: "ProfileView.swift:961-967", d: "«Vaciar datos» NO está gateada por secundaria — sigue alcanzable para la invitada" },
      { t: "StorageSettingsView.swift:52", d: "la SEGUNDA puerta del aviso: en secundaria la pantalla entera se degrada a `L10n.Storage.Errors.generic`, así que ni un acceso directo pinta `syncStatusSection` (:288-315)" }
    ],
    notes: [
      "MEDIDO: la invitada no tiene NINGUNA superficie que le diga que le quedan cambios sin subir, y son DOS puertas y no una: `StorageRowGateLogic.swift:59` oculta la fila y `StorageSettingsView.swift:52` degrada la pantalla entera. Se entera cuando intenta salir y el cierre se bloquea.",
      "La ausencia de «Dónde viven tus datos» es propiedad del binario de PRODUCCIÓN. `devPanelOverrideAvailable` es `true` bajo `DEV_BUILD` (StorageRowGateLogic.swift:31-32) y la única configuración del proyecto que compila esa condición es `Debug-Dev` (Yala.xcodeproj/project.pbxproj:998, scheme `Yala Dev`) ⇒ ahí la fila SÍ se pinta en secundaria, y a propósito: su docblock (:25-29) la llama «la puerta de servicio al panel DEBUG», la única salida por producto de una sesión FAKE. La captura tiene que salir del scheme `Yala`.",
      "MEDIDO y peligroso: «Vaciar datos» sigue disponible en secundaria y su camino llega a `DataWipeService.resetAllUserPreferences` (ProfileView.swift:961 → UserDataResetView.swift:246 → DataWipeService.swift:195), que hace `removeObject` en bloque sobre el `UserDefaults` del DUEÑO. No es una fila de salida, pero está en la misma pantalla."
    ]
  },

  "vuelta-hoja": {
    title: "La hoja de la despedida: tres filas y una frase que nombra al dueño",
    shot: "vuelta-hoja.png",
    sees: "Título «¿Cerrar tu sesión en este dispositivo?» y las tres filas de siempre. 📱 «En este dispositivo» → «Tus datos se eliminan de este dispositivo (siguen en tu cuenta)». ☁️ «En tu cuenta de Yala» → «Tus datos siguen seguros en tu cuenta». 👥 «En tus grupos» → «No se tocan». Debajo, la nota que solo existe para este caso: «Los datos del dueño de este dispositivo no se tocan.» Botones «Cerrar sesión» y «Cancelar», sin acciones secundarias.",
    persists: "Nada: la hoja es capa de presentación pura. El botón solo fija un flag y se cierra; el cierre lo dispara el `onDismiss` con la hoja ya fuera (anti-carrera).",
    exits: "«Cerrar sesión» → el coordinador arranca el push-all. «Cancelar» o swipe → no-op, vuelta a Ajustes.",
    code: [
      { t: "ProfileView.swift:123", d: "`case .secondaryCloudSignOut: return .signOutSecondary` — qué operación resuelve la hoja" },
      { t: "DestructiveScopeLogic.swift:198-208", d: "el modelo del caso: 📱 `.neutral` (cambia, sin pérdida), ☁️ y 👥 `.preserved`, `hasConservationNote: true`, `extraLines: []` y `secondaryActions: []`" },
      { t: "DestructiveScopeSheet.swift:367-372", d: "los tres detalles del caso secundario" },
      { t: "DestructiveScopeSheet.swift:443", d: "la nota de conservación PROPIA — es la única que menciona al dueño del móvil" },
      { t: "ProfileView.swift:407", d: "el `cloudLabel` de ESTA hoja (dentro del `.sheet(isPresented: $showCloudSignOutConfirm)` de :399-409): `DestructiveScopeLogic.cloudLabel(storageMode: CloudSyncFlags.storageMode)`. El `:421` es el de OTRA hoja, la de «Salir de Yala», que un cierre secundario nunca presenta" },
      { t: "DestructiveScopeLogic.swift:96-97 + DestructiveScopeSheet.swift:314-315", d: "`.cloud` → `.cloudAccount` → la fila ☁️ dice «En tu cuenta de Yala» y no «En iCloud»" },
      { t: "CloudSyncFlags.swift:249", d: "`if SecondarySessionStore.isActive() { return .cloud }` — el modo EFECTIVO que hace que esa etiqueta sea la correcta" },
      { t: "ProfileView.swift:399-403", d: "el `sheet(onDismiss:)` que ejecuta el cierre ya con la hoja fuera" },
      { t: "DestructiveScopeSheet.swift:406-407 y :421-422", d: "título y botón del caso: `signOutConfirmTitle` / `signOutConfirmAction`" }
    ],
    notes: [
      "MEDIDO: la fila 👥 dice «No se tocan» y es cierta desde el punto de vista de la CUENTA (los grupos de la invitada viven en el backend), pero el borrado del arranque siguiente SÍ se lleva su archivo local de grupos y su outbox de grupos sin haberlo subido — ver el panel del outbox de Grupos."
    ]
  },

  "vuelta-pushall": {
    title: "Antes de irse, Yala sube lo suyo (y jamás descarta nada)",
    shot: "vuelta-pushall.png",
    sees: "La fila «Cerrar sesión» se queda con un spinner y deshabilitada. Nada más: el caption honesto «Guardando tus cambios pendientes…» NO aparece en este camino.",
    persists: "Nada se descarta NUNCA. Si el outbox no llega a cero, el cierre se ABORTA y las filas pendientes siguen ahí.",
    exits: "Hasta 20 vueltas de ciclo con 250 ms entre ellas. `drained` (outbox vivo == 0 verificado por fetch) → sigue el cierre. `blocked` → aviso y vuelta a Ajustes. Tras el teardown hay una SEGUNDA verificación con la sesión aún viva: si un guardado se coló durante el push, se bloquea ahí y reintentar funciona.",
    code: [
      { t: "CloudSessionSignOut.swift:340 `performSecondaryCloudSignOut`", d: "el camino entero de la despedida" },
      { t: "CloudSessionSignOut.swift:351", d: "`controller.pushAllPendingForSignOut()` — el push-all del outbox PERSONAL" },
      { t: "CloudMigrationController.swift:376", d: "la firma con el tope: `maxIterations: Int = 20`" },
      { t: "CloudMigrationController.swift:382 y :397", d: "el `for iteration in 1...maxIterations` y el `Task.sleep(for: .milliseconds(250))` que impide quemar las 20 vueltas contra un ciclo coalescido" },
      { t: "CloudMigrationController.swift:410 `livePendingUploadCount`", d: "cuenta filas vivas (`rejectedReason == nil`); un conteo ilegible devuelve `Int.max` (:419) para no habilitar jamás un cierre con pendientes" },
      { t: "CloudSessionSignOut.swift:362-367", d: "la re-verificación S2 tras el teardown y ANTES de soltar credenciales" },
      { t: "ProfileView.swift:158", d: "`signOutWorkingCaption` solo pinta si `phase == .working && waitingForPending`; el texto es `L10n.Settings.signOutWorking` (:159)" },
      { t: "CloudSessionSignOut.swift:426 y :455", d: "las DOS escrituras de `waitingForPending = true` viven en el camino solo-grupos ⇒ el caption no alcanza a la invitada" }
    ],
    notes: [
      "MEDIDO: sin presupuesto de reintento. La escalera del solo-grupos (`GroupsSignOutRetryDecision`, CloudSignOutFlowLogic.swift:176-199: 45 s de presupuesto en :179, 2 s por vuelta en :182) es exclusiva de ESE camino; aquí un bloqueo se le muestra al usuario a la primera."
    ]
  },

  "vuelta-gruposnoempuja": {
    title: "Decisión · lo que la despedida NO sube: el outbox de Grupos de la invitada",
    shot: null,
    sees: "Nada: no hay pantalla. Lo que decide es qué cola se drena antes de borrar. Se drena la PERSONAL; la de GRUPOS no se toca, y el arranque siguiente borra el archivo donde vive.",
    persists: "Consecuencia medida: los gastos de grupo que la invitada creó sin red se pierden. Sus filas viven en `GroupSyncOutbox`, dentro de `YalaSyncMeta-Secondary`, y su espejo del App Group lo borra la purga de frontera — así que tampoco queda la red de rehidratación.",
    exits: "N/A. El camino `.cloud` sí hace las dos colas y bloquea si cualquiera de las dos no vacía; el secundario solo hace una.",
    code: [
      { t: "CloudSessionSignOut.swift:262", d: "el camino `.cloud` llama `pushAllPendingGroupsForSignOut` ANTES del teardown" },
      { t: "CloudSessionSignOut.swift:280-283", d: "y re-verifica los DOS: `residualPersonal` (:280) + `residualGroups` (:281), suma en :282 y `guard residual == 0` en :283" },
      { t: "CloudSessionSignOut.swift:351-367", d: "el camino secundario: ni `pushAllPendingGroupsForSignOut` ni `liveGroupsPendingCount` — solo el personal, dos veces" },
      { t: "SwiftDataConfiguration.swift:831-836", d: "el wipe de arranque borra los TRES archivos, incluidos `YalaGroups-Secondary` y `YalaSyncMeta-Secondary`" },
      { t: "GroupsSyncClient.swift:309", d: "`guard CloudSyncFlags.groupsBackendEnabled || !SecondarySessionStore.isActive()` — con el canal encendido la sesión secundaria SÍ corre el canal de Grupos sobre su propio store" },
      { t: "SwiftDataConfiguration.swift:1103 + :458", d: "`GroupsStoreDecision.decide(flagOn:secondaryActive:)` → `.secondary` ⇒ el archivo existe justo cuando el canal corre" },
      { t: "SecondarySessionBoundaryPurge.swift:38", d: "`GroupsOutboxMirror()?.purgeAll()` — el espejo del App Group también muere en la frontera" }
    ],
    notes: [
      "⚠︎ DIVERGENCIA MEDIDA: `CloudSessionSignOut.swift:357-358` dice «en secundaria el canal ni corre». Es FALSO cuando `groupsBackendEnabled` está ON, que es exactamente la condición en la que existe `YalaGroups-Secondary`.",
      "⚠︎ DIVERGENCIA MEDIDA: el docblock de `CloudSessionSignOut.swift:334` promete «Clon del camino `.cloud` con dos diferencias EXACTAS». Hay una tercera y no es cosmética: la cola de Grupos.",
      "No medí el impacto real (exige dos cuentas y build de distribución); lo que está medido es la ASIMETRÍA entre los dos caminos y que el wipe borra ese archivo."
    ]
  },

  "vuelta-bloqueado": {
    title: "«No pudimos cerrar tu sesión» — el único aviso que la visita puede recibir",
    shot: "vuelta-bloqueado.png",
    sees: "Alert con «No pudimos cerrar tu sesión» y el mensaje «Hay cambios sin subir a la nube y no queremos que pierdas nada. Revisa tu conexión e inténtalo de nuevo.» Un solo botón, «OK». La sesión sigue viva y la app sigue siendo suya.",
    persists: "Nada. El outbox queda intacto; el wipe NO se arma. Cerrar el aviso devuelve el coordinador a reposo.",
    exits: "«OK» → vuelta a Ajustes, con la fila «Cerrar sesión» de nuevo activa. Reintentar es la única acción.",
    code: [
      { t: "ProfileView.swift:424-430", d: "el alert de bloqueo permanente, con su `Button(L10n.Common.ok, role: .cancel)` que llama a `acknowledgeBlocked()`" },
      { t: "ProfileView.swift:93 `syncSignOutUI`", d: "`.transient` → aviso «Un momento más» (:97); `.permanent` → este (:98)" },
      { t: "CloudSessionSignOut.swift:344-345", d: "sin `CloudMigrationController` ⇒ `.blocked(pendingCount: 0, reason: .permanent)`" },
      { t: "CloudSessionSignOut.swift:353", d: "push-all bloqueado ⇒ `.permanent` FORZADO (el comentario de :350 lo dice: «conserva su alert de siempre»)" },
      { t: "CloudSessionSignOut.swift:364", d: "residual post-teardown ⇒ `.permanent` otra vez" },
      { t: "ProfileView.swift:434", d: "el alert «Un momento más», que este camino NUNCA enciende" }
    ],
    notes: [
      "MEDIDO: las TRES salidas de bloqueo del camino secundario construyen `reason: .permanent`, así que un bloqueo transitorio (writes del arranque aún asentándose) le dice a la invitada que revise su conexión aunque la conexión esté perfecta. El mapeo transitorio→permanente lo hace el consumidor: `CloudMigrationController.swift:404` devuelve `.transient` al agotar el tope y este camino lo re-escribe.",
      "MEDIDO: `ProfileView.onAppear` re-presenta este aviso si la hoja se cerró con el coordinador trabajando (:444-445) — es seguro, nada quedó armado."
    ]
  },

  "vuelta-sesioncaducada": {
    title: "La sesión de la visita caducó: se entera al intentar salir",
    shot: null,
    sees: "Nada mientras usa la app, y esa ausencia ES el panel. El aviso «Inicia sesión para subir %d cambios» vive dentro de «Dónde viven tus datos», y esa fila está oculta en sesión secundaria; la pantalla entera, además, está degradada. La primera señal es el aviso de bloqueo cuando toca «Cerrar sesión».",
    persists: "Nada se pierde: sus cambios siguen en el outbox local, y el wipe no se arma mientras haya pendientes.",
    exits: "Sin pendientes, un 401 no impide salir: el push-all devuelve `drained` con el outbox vacío y el cierre se consuma aunque la cuenta ya no responda. Con pendientes, queda encerrada en «Cerrar sesión → aviso → reintentar» hasta que la red o la sesión vuelvan.",
    code: [
      { t: "StorageRowGateLogic.swift:59", d: "la fila que contiene el banner S11 se oculta en secundaria" },
      { t: "StorageSettingsView.swift:52", d: "la segunda puerta: en secundaria la pantalla entera se degrada, así que ni por acceso directo se pinta el banner" },
      { t: "CloudMigrationController.swift:582 `refreshSyncBanner`", d: "el gate REAL del banner: exige `storageMode == .cloud` Y `CloudSyncRuntime.shared?.state == .stoppedUntilSignIn` (:583-584) y escribe `syncNeedsSignIn` en :591" },
      { t: "StorageSettingsView.swift:294-295", d: "dónde se pinta: `if controller.syncNeedsSignIn { Text(L10n.Storage.Sync.needsSignIn(controller.pendingUploadCount)) }`" },
      { t: "SessionExpiryPolicy.swift:34 `decide`", d: "la política UPSTREAM que produce el estado, no el gate del banner: su único consumidor de producción es `CloudSyncRuntime.swift:544`, un preflight que devuelve `.sessionExpired`" },
      { t: "CloudSignOutFlowLogic.swift:132 `classify`", d: "`.sessionExpired`/`.accountUnavailable` → `.permanent`; el camino secundario lo re-mapea igual" },
      { t: "CloudMigrationController.swift:379-380", d: "sin runtime, cerrar solo es seguro si no hay nada pendiente — y ahí sí sale" }
    ],
    notes: [
      "No hay ninguna pantalla propia para este estado: es la ausencia de una superficie lo que lo define, y por eso este panel no lleva shot. Su desenlace visible es el alert de `vuelta-bloqueado`.",
      "MEDIDO: no existe fila de escape equivalente a «Salir de Yala en este dispositivo» para la secundaria — `shouldShowExitYalaRow` es `isGroupInviteMode && !hasLiveSession` (CloudSignOutFlowLogic.swift:80-82), así que `rowLayout` le da `.plainSignOut` y punto.",
      "El copy «Inicia sesión para subir %d cambios» (`storage.sync.needsSignIn`) queda pinneado en la entrada de l10n de `vuelta-salida-ajustes`, que es el panel CON pantalla donde se cita."
    ]
  },

  "vuelta-armado": {
    title: "Decisión · qué se arma al cerrar, y las tres cosas que JAMÁS se arman",
    shot: null,
    sees: "Nada: ocurre entre el último spinner y el cover de reinicio.",
    persists: "En orden: se cierra la sesión de la cuenta, se escribe `cloudSync.secondaryWipeArmed = true`, y en la misma vuelta se limpian las superficies del sistema que aún mostrarían datos suyos — notificaciones pendientes y entregadas canceladas, caché del widget vaciada (el widget se redibuja vacío sin esperar al reinicio). Lo que NO se escribe nunca: `signOutWipeArmed` (el wipe del DUEÑO), `storageMode`/`mirrorOffArmed` (el par del dueño) y el reset masivo de preferencias.",
    exits: "Fase `.awaitingRelaunch` ⇒ el cover terminal entra en pantalla y el router queda contenido.",
    code: [
      { t: "CloudSessionSignOut.swift:368-372", d: "`signOut` → `armWipe` → breadcrumb → `clearLocalSurfacesForArmedWipe` → `.awaitingRelaunch`, en ese orden" },
      { t: "SecondarySessionStore.swift:65 `armWipe`", d: "escribe la única key que dispara el borrado" },
      { t: "SecondarySessionStore.swift:32-33", d: "«Paralelo a `signOutWipeArmed` pero JAMÁS toca los archivos ni las keys del dueño» (:32) sobre `wipeArmedKey = \"cloudSync.secondaryWipeArmed\"` (:33)" },
      { t: "CloudSignOutFlowLogic.swift:28-30", d: "la regla escrita en el enum: arma `SecondarySessionStore.armWipe` y jamás `armSignOutWipe` ni el reset masivo de prefs" },
      { t: "CloudSessionSignOut.swift:210 `clearLocalSurfacesForArmedWipe`", d: "la capa EN SESIÓN; su docblock (:185-209) explica que la ventana entre armar y reabrir «puede ser LARGA» (:189-190)" },
      { t: "CloudSessionSignOut.swift:213-215", d: "`WidgetDataCache.clearCache()` con su comentario: ya dispara `reloadAllTimelines()` ⇒ el widget se redibuja vacío sin esperar al relanzamiento" }
    ],
    notes: [
      "MEDIDO: el swap de persona sin reiniciar (R4) NO alcanza a este camino. `attemptSignOutSwap` tiene un solo call-site, en `performCloudSecureSignOut` (CloudSessionSignOut.swift:327) ⇒ la invitada SIEMPRE paga el reinicio.",
      "La limpieza de notificaciones aquí es defensa en profundidad, no la garantía: su propio docblock lo dice (:195-199) — «la red kill-safe es el boot-hook»."
    ]
  },

  "vuelta-cover": {
    title: "«Ya casi está — reinicia Yala»: la despedida de la visita",
    shot: "vuelta-cover.png",
    sees: "Pantalla completa sin botones, con una flecha circular: «Ya casi está — reinicia Yala» y debajo «Ve a la pantalla de inicio y vuelve a abrir Yala — todo quedará listo.» No se puede descartar deslizando.",
    persists: "Nada nuevo: todo lo persistente ya se escribió antes de que la pantalla apareciera.",
    exits: "Una sola salida real: irse a la pantalla de inicio. Al pasar a segundo plano el proceso termina solo, y el arranque siguiente ejecuta el borrado. Si iOS tumbara el cover, se vuelve a presentar — es terminal por diseño.",
    code: [
      { t: "SignOutRelaunchView.swift:11", d: "la decisión, en la cabecera del fichero: «Sin botones a propósito: no hay nada más que hacer en esta sesión del proceso»" },
      { t: "SignOutRelaunchView.swift:24-46", d: "la pantalla: icono (:27), título (:31), cuerpo (:34-36) y `.interactiveDismissDisabled()` (:45)" },
      { t: "SignOutRelaunchView.swift:22 y :34-36", d: "la variante de copy la decide `isGroupsOnly` = `StorageModePersistence.isGroupsOnlyWipeArmed()`; en secundaria es `false` ⇒ el texto genérico `bodyAutoExit`" },
      { t: "ContentView.swift:1628", d: "el docblock que declara `SignOutRelaunchNetModifier` (:1640) «DUEÑO ÚNICO del cover terminal»; ProfileView ya no presenta" },
      { t: "YalaApp.swift:179", d: "`RelaunchNetLogic.shouldExitOnBackground` con `signOutPhase: CloudSessionSignOut.shared.phase` (:181) ⇒ `exit(0)` al ir a segundo plano" },
      { t: "RelaunchNetLogic.swift:92", d: "`scenePhase == .background` — el término; el porqué está en :56-57 («jamás `.inactive`: app switcher/notification center no deben matar el proceso»)" }
    ],
    notes: [
      "MEDIDO: hay TRES presentadores de la MISMA `SignOutRelaunchView` — `YalaApp.swift:99` (container aún sin construir), `ContentView.swift:1671` (cover del cierre de sesión, el de este panel) y `ContentView.swift:1746` (`SecondaryEntryRelaunchNetModifier`, ventana de ENTRADA secundaria). Misma vista, mismo copy, tres orígenes.",
      "MEDIDO: es la MISMA pantalla que ve el cierre en modo nube, pero aquí nunca desaparece sola — allí puede irse si el swap in-process se consuma (`phase = .idle`, CloudSessionSignOut.swift:327-328), y ese camino no existe para la secundaria.",
      "ProfileView no presenta este cover: se limita a cerrarse ante la fase (`case .awaitingRelaunch: dismiss()`, ProfileView.swift:100) para despejar el anchor — dos presentaciones sobre el mismo anchor tumbaban ambas cadenas (ContentView.swift:1629-1632)."
    ]
  },

  "vuelta-kill": {
    title: "Decisión · salida a medias: las tres ventanas de un cierre de app",
    shot: null,
    sees: "Nada. Es qué pasa si el proceso muere en cada tramo de la despedida.",
    persists: "(1) Durante el push-all, antes de armar: no se escribió nada. El descriptor sigue vivo ⇒ el arranque siguiente REANUDA la sesión de la invitada (la sesión secundaria es persistente hasta el cierre explícito, no efímera) y hay que volver a intentarlo. (2) Entre armar y reabrir: la marca está puesta ⇒ el arranque siguiente completa el borrado; da igual si el proceso murió por `exit(0)`, por iOS o a mano. (3) A mitad del borrado: se re-entra completo y limpio, porque el desarme es SIEMPRE el último paso y cada operación intermedia es idempotente.",
    exits: "N/A.",
    code: [
      { t: "SwiftDataConfiguration.swift:829", d: "`guard SecondarySessionStore.isWipeArmed(defaults) else { return }` — la re-entrada empieza por preguntar si sigue armado" },
      { t: "SwiftDataConfiguration.swift:848", d: "`SecondarySessionStore.clearWipeArm(defaults)` AL FINAL: el desarme es lo último" },
      { t: "SecondarySessionStore.swift:73-76", d: "el contrato escrito: «Desarmar — SIEMPRE el ÚLTIMO paso del boot-cleanup (re-entrada idempotente tras kill)»" },
      { t: "SecondarySessionStore.swift:14-15", d: "decisión 5: «cold-launch REANUDA la sesión activa, no la descarta»" },
      { t: "SecondarySessionBoundaryPurge.swift:13-14", d: "«Todas las operaciones son idempotentes — el caller re-ejecuta completo tras un kill a mitad»" }
    ],
    notes: [
      "MEDIDO: en la ventana (1) la invitada vuelve a estar dentro con su sesión de nube ya cerrada si el kill cayó justo después del `signOut` y antes del `armWipe` — pero son DOS líneas contiguas, sin ningún `await` entre el `signOut` (CloudSessionSignOut.swift:368) y el `armWipe` (:369)."
    ]
  },

  "vuelta-boot": {
    title: "El arranque siguiente: lo que el móvil borra antes de pintar nada",
    shot: null,
    sees: "Nada durante el borrado — corre antes de que exista la primera pantalla, en el pre-mount del container. Lo que se ve al terminar es el Welcome, que es la pantalla del panel siguiente.",
    persists: "En orden estricto: (1) los TRES archivos de la invitada, personal → sync-meta → grupos; (2) la purga de superficies compartidas del App Group, una a una: caché del widget, colas de entrada de Apple Pay/Siri/imágenes, espejo del outbox personal, espejo del outbox de PREFERENCIAS, espejo del outbox de grupos, intenciones de unirse a un grupo (dos superficies) y el permiso de Grupos guardado; (3) las notificaciones de la invitada, pendientes y entregadas; (4) el descriptor de sesión y la marca de purga de entrada; (5) los tres flags de onboarding a `false` — y esto es lo que hace que el dueño se encuentre el Welcome; (6) el desarme. Los archivos del dueño y sus preferencias no se tocan.",
    exits: "Al terminar, el proceso monta el store del DUEÑO con normalidad y `ContentView` presenta el Welcome porque el chooser figura como no visto.",
    code: [
      { t: "SwiftDataConfiguration.swift:809 `performSecondaryWipeIfArmed`", d: "el wrapper de producción: `guard !isRunningTests, !isUITesting` (:810) ⇒ no corre bajo tests ni bajo `-uitest`" },
      { t: "SwiftDataConfiguration.swift:823-850", d: "la variante inyectable: el orden completo, del `guard` armado (:829) al `clearWipeArm` (:848)" },
      { t: "SwiftDataConfiguration.swift:844-846", d: "`hasCompletedOnboarding`, `hasShownWelcomeChooser` y `hasShownYalaAIOnboarding` a `false` — EN EL BOOT y jamás en sesión (con el proceso vivo montaría el Welcome DEBAJO del cover, ver el porqué en :799-801)" },
      { t: "SecondarySessionBoundaryPurge.swift:24-50 `purge`", d: "las superficies compartidas, una a una: ocho llamadas (:25, :31, :33, :34, :38, :47, :48, :49), incluido el espejo del outbox de PREFERENCIAS en :34" },
      { t: "SecondarySessionBoundaryPurge.swift:47-49", d: "intenciones de unirse a un grupo y permiso de Grupos: sin esto «un intent que sobreviva la frontera se ejecutaría bajo el DUEÑO al volver» (:43-44)" },
      { t: "PersonalContainerSwap.swift:76-80", d: "el orden CONGELADO de los cuatro hooks pre-mount: `performSecondaryWipeIfArmed` PRIMERO (:77)" },
      { t: "CloudSyncEngine.swift:463 `secondaryWipeExecuted`", d: "la señal de que se ejecutó, sin datos personales" }
    ],
    notes: [
      "Este panel no lleva shot porque no tiene pantalla: su `sees` es literalmente «nada», y su desenlace visible es el Welcome de `vuelta-welcome`.",
      "MEDIDO: la cancelación de notificaciones del paso 3 cierra un daño doble, y está escrito en el docblock (SwiftDataConfiguration.swift:803-808). Sin ella los recordatorios de la invitada sonarían con el dueño ya de vuelta Y, si dejó tantos como tenía él, la heurística del reconciler (`pending.count < activeItems.count`) sería falsa y los del dueño —cancelados al entrar ella— no se restaurarían nunca. Dejar `pending == 0` es justo la condición que dispara la reprogramación en el mismo arranque.",
      "MEDIDO: bajo `-uitest` este hook NO corre (:810) y ningún archivo `-Secondary` llega al disco del simulador; el estado que reproducen los XCUITest es el de la sesión ya montada (UITestEphemeralDefaults.swift:143-157)."
    ]
  },

  "vuelta-abort": {
    title: "Si el borrado falla: la visita sigue montada, y sin cuenta",
    shot: null,
    sees: "Sin pantalla propia. La app abre otra vez en la sesión de la invitada, con sus datos delante, pero su sesión de nube ya está cerrada — se cerró antes de armar el borrado.",
    persists: "La marca de borrado y el descriptor SOBREVIVEN, así que el arranque siguiente lo reintenta. Los archivos del dueño siguen intactos: el aborto es seguro para él por construcción.",
    exits: "El único camino es volver a intentarlo reabriendo la app. Basta con que falle el archivo BASE de CUALQUIERA de los tres para abortar los tres; los ficheros sueltos -wal/-shm sin base son inertes.",
    code: [
      { t: "SwiftDataConfiguration.swift:831-836", d: "el guard: si cualquiera de los tres borrados devuelve `false`, se aborta con breadcrumb y ANTES de purgar nada" },
      { t: "SwiftDataConfiguration.swift:788-797", d: "el docblock del hook: «(incl. patrón S3 de abort)» en :789 y, en :796-797, «el arm y el descriptor persisten, el mount sigue siendo el secundario y el próximo boot reintenta»" },
      { t: "SwiftDataConfiguration.swift:898-899 y :913", d: "por qué los sidecars huérfanos son inertes: `deleteStoreFiles` (:900-917) solo devuelve `false` cuando falla el índice 0, el archivo BASE" },
      { t: "CloudSyncEngine.swift:470 `secondaryWipeAborted`", d: "la señal, con su motivo; «>0 sostenido = disco/permisos» (:469)" }
    ],
    notes: [
      "MEDIDO: en este estado la app es usable como la invitada pero sin sesión de nube, y sin fila de Almacenamiento con la que diagnosticarlo. No hay copy que se lo explique a nadie.",
      "No lo pude provocar: forzar el fallo de borrado de un archivo no es fabricable desde el simulador ni desde el repo."
    ]
  },

  "vuelta-welcome": {
    title: "El dueño reabre y se encuentra el Welcome, no su app",
    shot: "vuelta-welcome.png",
    sees: "El Hero de bienvenida: logo, el carrusel de cards, «Tus finanzas personales, sin esfuerzo.» y el botón «Empezar». Sus datos siguen enteros en el móvil, pero la app le pregunta como si fuera nueva — porque el borrado de la visita puso los tres flags de onboarding a `false`. No hay ningún aviso que le diga «esto pasó porque alguien usó tu móvil».",
    persists: "Nada al llegar. `hasShownWelcomeChooser` lo escribe el callback cuando elige rama.",
    exits: "«Empezar» → chooser de tres cards. «Ya tengo una cuenta» es su camino: en producción, con una sola opción visible, hace bypass directo a «Restaurar de iCloud». ⚠︎ La card «Es mi primera vez en Yala» es la trampa: con datos en el dispositivo abre el alert «Empezar desde cero» / «Detectamos datos previos en tu dispositivo. ¿Borrar todo para empezar como nuevo?» con el botón destructivo «Borrar todo y continuar».",
    code: [
      { t: "ContentView.swift:1376-1381", d: "`if !hasShownWelcomeChooser { welcomeFlowInitialStep = .hero }` — la razón exacta de que vea el Welcome" },
      { t: "SwiftDataConfiguration.swift:266 `isFreshInstallForNeutralMount`", d: "el primer término es `!personalStoreFileExists` (:273): el archivo del dueño SÍ existe ⇒ no monta neutro" },
      { t: "SwiftDataConfiguration.swift:296 `shouldMountNeutralDurable`", d: "exige `neutralMountArmed`, y esa marca la escribe `StorageModePersistence.armNeutralMount` con un ÚNICO call-site de producción: SwiftDataConfiguration.swift:648, dentro de `performSignOutWipeIfArmed` (:598) — el wipe SECUNDARIO no la escribe" },
      { t: "SwiftDataConfiguration.swift:339-342 `personalStoreDecision`", d: "sin descriptor (:339) y sin par `.cloud` armado (:340), el dueño cae en `.iCloudMirror` (:342): su mirror vuelve adjunto" },
      { t: "WelcomeMirrorRelaunchLogic.swift:94 `shouldRelaunch`", d: "`requiresMirror(destination) && mountedDecision == .neutralNoMirror` ⇒ al dueño NO se le pide reabrir la app otra vez" },
      { t: "ContentView.swift:1455", d: "`onSelectExistingOption` escribe `hasShownWelcomeChooser = true` y, en producción, la sub-elección es siempre `.restoreICloud` (comentario :1453-1454)" },
      { t: "ContentView.swift:1617", d: "`startFreshPrivateOnboarding`: con `hasExistingData` enciende el alert de borrado en vez de seguir" },
      { t: "WelcomeHeroView.swift:286", d: "el botón «Empezar»; el chooser pinta sus dos cards en WelcomeChooserView.swift:32-33" }
    ],
    notes: [
      "MEDIDO y es la buena noticia del panel: el dueño NO paga un segundo reinicio. Su archivo existe y la marca de neutro no está puesta, así que su mirror vuelve adjunto en el mismo arranque.",
      "MEDIDO: el Hero ya no tiene alert de «detectamos tu cuenta» ni subtítulo — la reentrada es decisión del usuario y se toma en «Ya tengo una cuenta». Para el dueño eso significa que nada le sugiere el camino correcto.",
      "La pantalla es la MISMA que retrata `alta-hero`; lo que cambia es cómo se llega a ella (un borrado de salida, no una instalación fresca)."
    ]
  },

  "vuelta-restaurar": {
    title: "«Restaurar de iCloud»: el dueño vuelve a su app, con dos cosas de regalo",
    shot: "vuelta-restaurar.png",
    sees: "La pantalla de restauración: «¡Hola %@! Qué bueno verte de vuelta.», «Encontramos tus datos en iCloud:» y el resumen en chips («%d cuentas», «%d registros», «%d presupuestos», «%d grupos compartidos»), con el botón «Continuar» y, debajo, «Empezar desde cero». Al continuar aterriza directamente en su app, con todo en su sitio: sus datos nunca se movieron del disco.",
    persists: "`hasCompletedOnboarding = true`, el device queda marcado como INSTALACIÓN NUEVA para el checklist de puesta a punto y, si no es Pro, se arma la oferta de prueba post-onboarding. Esas TRES son las escrituras del helper. `hasShownWelcomeChooser` ya venía escrito de antes, al tapear «Ya tengo una cuenta».",
    exits: "Salta directo a la app porque su resumen está completo (nombre + cuentas + categorías). Si le faltara alguno, iría al onboarding con los campos prerrellenados. La rama «solo grupos» es otra celda distinta.",
    code: [
      { t: "ContentView.swift:1918-1924 `completeOnboardingAsRestoreSkip`", d: "las TRES escrituras: `needsPostOnboardingTrial` si no es Pro (:1920), `hasCompletedOnboarding` (:1922) y `markAsNewInstall()` (:1923). NO escribe `hasShownWelcomeChooser`" },
      { t: "ContentView.swift:1455", d: "quien SÍ escribe `hasShownWelcomeChooser = true`: el callback del chooser, un paso antes" },
      { t: "ContentView.swift:640-660", d: "el router del resumen: `RestoreRouter.decide` (:643) y el `case .directToApp` (:657-660), que es el caso del dueño" },
      { t: "RestoreDestination.swift:30 `RestoreRouter.decide`", d: "`.groupInvite` → solo grupos; si no, `isFullyPrefilled ? .directToApp : .onboarding`" },
      { t: "iCloudSyncService.swift:679 `isFullyPrefilled`", d: "nombre + cuentas + categorías, y el resumen se calcula del store LOCAL (que sigue siendo el suyo)" },
      { t: "ContentView.swift:1291", d: "el post-check de returning user que presenta la oferta de prueba" },
      { t: "SetupChecklistManager.swift:151 `markAsNewInstall`", d: "la marca que re-enciende el checklist" }
    ],
    notes: [
      "⚠︎ MEDIDO: el dueño vuelve a ver la oferta de prueba y el checklist de puesta a punto aunque lleve meses usando Yala. No es un caso pensado para él: es el helper compartido del atajo de restauración.",
      "No medí qué pinta esta pantalla en un simulador sin cuenta de iCloud: `WelcomeRestoreView` tiene estados propios para «no encontrada» (:281-283), «iCloud desactivado» (:292-296), error (:305-307) y «wiped» (:319-321), y cuál sale depende del fetch."
    ]
  },

  "vuelta-queda": {
    title: "Qué queda de la visita en el móvil del dueño (inventario medido)",
    shot: null,
    sees: "Nada visible en la app. Este panel es el inventario de lo que sobrevive en el `UserDefaults` COMPARTIDO, que es el único sitio donde las dos personas se tocan.",
    persists: "SE VA: los tres stores de la invitada, sus notificaciones, su caché de widget, sus colas del App Group, sus intenciones de unirse a grupos y el permiso de Grupos guardado. SE QUEDA, medido uno a uno: (1) su reclamo de cuenta `cloudSync.claimAction.<su sub>` — el cierre de sesión no lo borra a propósito, para que ella pueda volver a entrar; (2) su intención pendiente de registrar el permiso de Grupos (`yala.groups.pendingConsentRegistration`), con su identificador de cuenta y la hora exacta en que aceptó, si esa llamada nunca consiguió red — su NO borrado está escrito como decisión; (3) `groupsBetaUnlocked` si tocó un enlace de invitación a un grupo. Y las preferencias del DUEÑO sobreviven enteras por decisión de diseño — el borrado solo repone tres flags de onboarding.",
    exits: "N/A. Nada de esto tiene pantalla ni forma de inspeccionarse desde la app.",
    code: [
      { t: "CloudClaimActionStore.swift:16-17", d: "«`signOut` NO borra los registros» (:16) «(keyed por userID → el re-sign-in del MISMO usuario no se bloquea; AJUSTE review #1)» (:17)" },
      { t: "WelcomeCloudSignInView.swift:777", d: "la entrada secundaria estampa ese reclamo con su identificador de cuenta" },
      { t: "GroupsConsentState.swift:136-138", d: "«Lo que NO limpia, a propósito: el intent durable» — borrarlo destruiría la prueba de una aceptación real que solo esperaba a tener red" },
      { t: "GroupsConsentPendingIntent.swift:70", d: "la key que sobrevive: `userDefaultsKey = \"yala.groups.pendingConsentRegistration\"`" },
      { t: "DataWipeService.swift:337 `removeGroupsDomainPreferenceKeys`", d: "el barrido que repondría `groupsBetaUnlocked` (:338)" },
      { t: "DataWipeService.swift:310", d: "su ÚNICO call-site de producción, dentro del «empiezo de cero» del Welcome ⇒ el cierre de la visita no lo llama" },
      { t: "GroupBackendInviteEntryHandler.swift:74", d: "escribe `groupsBetaUnlocked = true` SIN guard de sesión secundaria (tap de enlace con la app viva)" },
      { t: "AppBootstrapper.swift:2015", d: "el segundo escritor sin guard (camino frío / canal apagado)" },
      { t: "GroupsDomainAdoptionMarker.swift:51", d: "el escritor de entrar al tab SÍ lleva guard: `guard !SecondarySessionStore.isActive(defaults) else { return }`" },
      { t: "GroupsOrganizerOnboarding.swift:146", d: "el alta solo-grupos también, y a nivel de método entero (`isSecondarySession:` como parámetro con default vivo)" },
      { t: "FullModeActivationView.swift:109-114", d: "`usageFocus = .full` y la configuración del tab bar se escriben SIN guard ⇒ cruzan al dominio del dueño" },
      { t: "ProfileView.swift:961 → UserDataResetView.swift:246 → DataWipeService.swift:195", d: "la cadena de «Vaciar datos» en secundaria hasta `resetAllUserPreferences()` (declarada en :431), que borra las preferencias del DUEÑO en bloque" }
    ],
    notes: [
      "El docblock de `GroupsOrganizerGateLogic.swift:37-47` NO está caducado: es el PORQUÉ del tercer término que C3 (2026-08-12) añadió al gate y que hoy bloquea la rama organizador en secundaria. Su premisa sigue viva y medida —`removeGroupsDomainPreferenceKeys` tiene un único call-site de producción, DataWipeService.swift:310— y por eso la única vía MEDIDA que le deja al dueño el dominio Grupos adoptado es el enlace de invitación (GroupBackendInviteEntryHandler.swift:74 / AppBootstrapper.swift:2015, ambos sin guard).",
      "MEDIDO: `groupsBetaUnlocked` está EXCLUIDA a propósito del barrido general de preferencias (el porqué, en DataWipeService.swift:327-332), así que ni siquiera un «Vaciar datos» la repone — solo el «empiezo de cero».",
      "No medí si «Yala completo» es alcanzable dentro de una sesión secundaria; lo medido es que sus dos escrituras de presentación no llevan guard y que el borrado de salida no las repone."
    ]
  },

  "vuelta-consent": {
    title: "El permiso de Grupos del dueño se va con la visita",
    shot: null,
    sees: "Nada en el momento. Se ve después: cuando el dueño vuelve a abrir Grupos, la app le pide otra vez que acepte el permiso de compartir con su grupo, como si nunca lo hubiera dado. La pantalla que reaparece es la del consent, ya retratada en el Atlas.",
    persists: "La purga de frontera borra el registro LOCAL del permiso —snapshot nuevo y las dos keys del formato antiguo— y lo hace en las DOS fronteras, entrada y salida, sin mirar de quién es. En el servidor no se borra nada: el registro contra la cuenta es de solo-añadir, así que quien tenga sesión lo recupera al firmar.",
    exits: "Sin registro local, la comprobación de «¿ya aceptó?» devuelve `false` y la pantalla del permiso vuelve a salir.",
    code: [
      { t: "SecondarySessionBoundaryPurge.swift:49", d: "`GroupsConsentState.clear()` en la purga que corre en ambas fronteras" },
      { t: "GroupsConsentState.swift:139 `clear`", d: "borra las tres keys locales (:140-142); su docblock (:129-131) dice que «no puede alcanzar el servidor por construcción»: el grant de `groups_consents` no tiene `delete`" },
      { t: "GroupsConsentDecisionLogic.swift:58", d: "`guard let snapshot else { return false }` dentro de `isAccepted` — sin registro local, no hay permiso" },
      { t: "GroupsConsentRegistrar.swift:88 `register`", d: "escribe el snapshot local (:90-91) y, con sesión, arma el intent para registrarlo contra la CUENTA (:93-95)" },
      { t: "GroupsConsentRegistrar.swift:10-13", d: "la premisa de C1: el modo por defecto es `.icloud` y Grupos va al 100 % sin exigir Modo Nube ⇒ «para casi todos lo CREA»" }
    ],
    notes: [
      "Este panel no lleva shot: su consecuencia visible es la pantalla del consent de Grupos, que el Atlas ya retrata en su propio nodo. Duplicar la imagen no añadiría nada.",
      "⚠︎ DIVERGENCIA MEDIDA: `SecondarySessionBoundaryPurge.swift:46` justifica el borrado con «el dueño en `.icloud` no tiene consent backend legítimo que pisar». La cabecera del registrador dice lo contrario en general (:10-13). No medí si un dueño concreto puede llegar a la frontera con uno vivo, pero el borrado no distingue.",
      "⚠︎ DIVERGENCIA MEDIDA contra `qa/coverage-index.json`: su residual (a) dice que el permiso de la invitada «es .localOnly y nunca llega a su backend» y «muere en el wipe», citando `GroupsConsentState.swift:58-61`. Desde C1 el registro SÍ viaja a la cuenta por RPC. Lo que muere en el borrado es la copia local, que es lo correcto."
    ]
  },


  // ══════════════════════════════════════════════════════════════════════════
  // R6 · Soy privada y salgo de Yala
  // ══════════════════════════════════════════════════════════════════════════

  "signout-fila-privada": {
    title: "Ajustes · la fila por la que se sale (y las CUATRO distribuciones que existen)",
    shot: "signout-fila-privada.png",
    sees: "Al final de la sección «Seguridad y cuenta», una fila con icono rojo de salida (`rectangle.portrait.and.arrow.right`). Para una persona PRIVADA dice **«Cerrar sesión»** con el subtítulo «Este dispositivo, no tu cuenta» — ⚠︎ no dice «Salir de Yala», aunque esa persona no tenga ninguna sesión que cerrar. Las otras tres distribuciones que `rowLayout` puede pintar: (a) `.exitYalaOnly` — «Salir de Yala en este dispositivo» / «Volverás a la pantalla de inicio. Tus grupos siguen en tu iCloud.», que es la del solo-grupos legado 5a; (b) `.groupsSignOutPlusExitYala` — DOS filas, «Cerrar sesión de grupos» / «Este dispositivo olvidará tus grupos; tus finanzas no se tocan» y debajo «Salir de Yala en este dispositivo» / «Volver a la pantalla de inicio; tus datos no se borran»; (c) `.none` — ninguna fila. Mientras un cierre trabaja, la fila lleva spinner y queda deshabilitada, y puede aparecer bajo ella el caption «Guardando tus cambios pendientes…».",
    persists: "Nada: pintar la fila no escribe. La decisión se recalcula en cada render leyendo el modo de storage, el descriptor de sesión secundaria, la sesión backend y la capacidad COMPILADA de Grupos.",
    exits: "Tap → hoja de alcance destructiva. `.plainSignOut` y `.exitYalaOnly` abren la MISMA hoja (`showCloudSignOutConfirm`) y su `onDismiss` despacha `signOut(context:)`, que resuelve el camino por la precedencia congelada; la 2ª fila del split abre una hoja PROPIA (`showExitYalaGroupsConfirm`) y despacha `exitYalaOnThisDevice`. En el recorrido privado los dos primeros resuelven `.privateReset`.",
    code: [
      { t: "CloudSignOutFlowLogic.swift:104", d: "`rowLayout(path:isGroupInviteMode:hasLiveSession:)` — las cuatro distribuciones y su orden: `.groupsSignOutPlusExitYala` primero (107), luego `shouldShowRow` → `.plainSignOut` (108-109), luego `shouldShowExitYalaRow` → `.exitYalaOnly` (111-112), y `.none` (114)" },
      { t: "CloudSignOutFlowLogic.swift:72", d: "`!isGroupInviteMode || hasLiveSession` — para una persona privada da `true` ⇒ la fila SIEMPRE es «Cerrar sesión», nunca «Salir de Yala»" },
      { t: "CloudSignOutFlowLogic.swift:58", d: "`return .privateReset` — la cuarta fila de la precedencia, la que le toca a quien está en `.icloud`, sin secundaria y sin sesión backend" },
      { t: "ProfileView.swift:977", d: "`SectionBox(title: L10n.Settings.security)` — la sección «Seguridad y cuenta» que aloja la fila (fichero en `Yala/App/Views/Profile/`, NO en `Views/Settings/`)" },
      { t: "ProfileView.swift:1061", d: "`switch signOutRowLayout` — el único sitio que pinta estas filas" },
      { t: "ProfileView.swift:1070", d: "título/subtítulo de la fila privada (`L10n.Settings.signOut` / `signOutSubtitle`, 1070-1071); id de accesibilidad `profile_security_signout` en 1077" },
      { t: "ProfileView.swift:1130", d: "título/subtítulo de la fila del legado 5a (`exitYala` / `exitYalaSubtitle`, 1130-1131); id `profile_security_exit_yala` en 1137" },
      { t: "ProfileView.swift:141", d: "`groupsBackendEnabled: CloudSyncFlags.groupsBackendCompiledCapability` dentro de `signOutRowPath` (declarado en 136) — la capacidad COMPILADA, lo mismo que lee el coordinador (CloudSessionSignOut.swift:97). Su docblock (131-135) dice qué pasa si divergen: la hoja prometería lo contrario de lo que hace el dispatch" },
      { t: "ProfileView.swift:157", d: "`signOutWorkingCaption` — la condición está en 158: `phase == .working && waitingForPending`, que en `.privateReset` no ocurre (no hay push-all)" }
    ],
    notes: [
      "⚠︎ CORRECCIÓN medida contra el árbol actual: la premisa de que esta persona sale por «Salir de Yala en este dispositivo» es FALSA. Esa fila la pinta `.exitYalaOnly` (group-invite SIN sesión) o la 2ª mitad del split D2; la persona privada ve «Cerrar sesión». Las dos filas comparten destino (`.privateReset`) y por eso se confunden, pero el copy que lee el usuario es distinto.",
      "⚠︎ El nombre de la fila privada nombra algo que ese usuario no tiene: no hay sesión que cerrar (backend DARK en producción). Lo único que corrige el malentendido es el subtítulo «Este dispositivo, no tu cuenta» y las tres filas de la hoja, todas en tono «no se toca».",
      "Los `accessibilityIdentifier` NO distinguen los dos caminos: `profile_security_exit_yala` lo llevan tanto la fila del legado 5a (1137) como la 2ª del split (1118), y `profile_security_signout` tanto la privada (1077) como la de grupos (1099). Una captura de XCUITest no dice por sí sola qué distribución estaba en pantalla."
    ]
  },

  "signout-hoja-privada": {
    title: "La hoja de una persona privada: tres filas y ninguna en rojo",
    shot: "signout-hoja-privada.png",
    sees: "Pantalla completa (`.large`, con drag indicator) titulada **«¿Cerrar tu sesión en este dispositivo?»** y las tres filas de siempre, cada una con su símbolo de sistema y en tono «no se toca» (ninguna en rojo): iPhone (`iphone`) «En este dispositivo» → «No se borra nada; vuelves a la pantalla de inicio» · nube (`icloud`) «En iCloud» → «Tus datos siguen en iCloud» · dos personas (`person.2`) «En tus grupos» → «No se tocan». El gris secundario del tono `.preserved` tiñe el ICONO y el DETALLE; la etiqueta de cada fila va siempre en `.primary`. Debajo, la nota de conservación **«Puedes volver a entrar cuando quieras; tus datos seguirán aquí.»**. Al pie, dos controles: «Cerrar sesión» (botón secundario en estilo destructivo) y «Cancelar». **Ninguna acción secundaria** — no hay «Exportar antes» ni «Ver mis grupos»: este camino no destruye nada de lo que desviar.",
    persists: "Nada. La hoja es capa de presentación pura; ni el modelo estructural ni la factory tocan disco.",
    exits: "«Cerrar sesión» fija `pendingSignOut` y cierra la hoja; el sign-out corre en el `onDismiss`, ya con la hoja fuera (anti-carrera, crítico justo aquí porque el destino es el Welcome EN SESIÓN). «Cancelar» y el swipe solo cierran: como no se fijó ningún flag, el `onDismiss` es un no-op.",
    code: [
      { t: "DestructiveScopeLogic.swift:175", d: "`case .signOutPrivate` (175-184) — las tres filas `.preserved` y `hasConservationNote: true`, sin líneas extra ni secundarias" },
      { t: "DestructiveScopeSheet.swift:300", d: "`icon(for:)` (300-306) — los iconos son SF Symbols: `iphone`, `icloud`, `person.2`. El 📱/☁️/👥 de los docblocks es taquigrafía interna, no lo que ve la persona" },
      { t: "DestructiveScopeSheet.swift:355", d: "el detalle de cada fila del caso privado (355-360): `signOutScopeDevicePrivate` / `signOutScopeCloudPrivate` / `scopeUntouchedShort`" },
      { t: "DestructiveScopeSheet.swift:141", d: "`rowView(_:)` — `Image(systemName: row.icon)` con `toneColor` (143-145), la etiqueta en `.primary` (149-151) y el detalle con `toneColor` (152-154)" },
      { t: "DestructiveScopeSheet.swift:406", d: "título compartido por los cuatro sign-out: `case .signOutPrivate, .signOutCloud, .signOutSecondary, .signOutGroupsOnly` (406) → `settings.signOutConfirmTitle` (407)" },
      { t: "DestructiveScopeSheet.swift:441", d: "nota de conservación de este caso: `signOutScopeConservationPrivate`" },
      { t: "DestructiveScopeSheet.swift:179", d: "los dos controles: `YalaSecondaryButton(config.confirmLabel, destructive: true)` con id `destructive_scope_confirm` (179-183) y «Cancelar» con id `destructive_scope_cancel` (185-189)" },
      { t: "DestructiveScopeSheet.swift:127", d: "`presentationDetents([.large])` — una decisión destructiva ocupa pantalla completa, no un alert estirado" },
      { t: "ProfileView.swift:118", d: "`signOutScopeOperation` — `.privateReset` mapea a `.signOutPrivate` (121); `isExitYalaContext` (108) es lo que desvía al legado 5a" },
      { t: "ProfileView.swift:399", d: "el `.sheet(isPresented: $showCloudSignOutConfirm, onDismiss:)` compartido, que es quien llama a `signOut(context:)` (402)" }
    ],
    notes: [
      "La etiqueta de la fila de nube la calcula `DestructiveScopeLogic.cloudLabel(storageMode:)` (DestructiveScopeLogic.swift:96): en `.icloud` dice «En iCloud», en `.cloud` diría «En tu cuenta de Yala». Para esta persona es siempre la primera.",
      "El botón destructivo lleva `accessibilityIdentifier(\"destructive_scope_confirm\")` y el de cancelar `destructive_scope_cancel` — los mismos que usa la hoja de Vaciar (el switch de `confirmIdentifier`, DestructiveScopeSheet.swift:431-436, solo separa el borrado de cuenta), así que un test que los busque no distingue la operación."
    ]
  },

  "signout-privado-ejecucion": {
    title: "Decisión · qué hace `.privateReset` (y por qué no hay pantalla que enseñar)",
    shot: null,
    sees: "Nada: entre el «Cerrar sesión» de la hoja y el Welcome no se presenta ninguna pantalla propia. La fila de Ajustes muestra su spinner una fracción de segundo (`phase = .working` → `.idle`) y acto seguido la app entera cambia debajo: `hasCompletedOnboarding` a `false` desmonta `MainTabView`, con él se va la hoja de Ajustes, y `ContentView` presenta el Welcome desde el Hero. **No hay cover de relanzamiento y no se pide reabrir la app** — eso es exclusivo de los caminos que arman un wipe.",
    persists: "TRES flags de onboarding (`hasCompletedOnboarding`, `hasShownWelcomeChooser`, `hasShownYalaAIOnboarding`) **y además, vía `AppRouter.resetAll()`, tres borrados más en `UserDefaults`**: el buffer DURABLE de intents diferidos (`DeferredIntentBuffer.clear()` es `save([])` sobre `UserDefaults`), el store de joins pendientes (`PendingJoinStore.clearAll()` es un `removeObject`) y el tracker de intención de grupo. Y si esa persona tenía período personalizado, `SessionState.resetToDefaults()` asigna `customDateRange = nil`, cuyo `didSet` borra `customPeriodStart` y `customPeriodEnd`. **NADA de SwiftData se toca** (ni una fila borrada, ni el store personal, ni el de grupos), no se arma ningún wipe de boot, y las preferencias del usuario —nombre, divisa, tema, `onboardingMode`, `groupsBetaUnlocked`— SOBREVIVEN. Credenciales: `CloudAuthService.signOut()` **no es un no-op en producción** — borra el perfil capturado, el provider almacenado, hace `GIDSignIn.sharedInstance.signOut()`, tira la caché del entitlement de cuenta (que re-deriva `isProUser` y toca el App Group) y llama a `client.signOut(scope: .local)`; lo que no hay es sesión que cerrar. Más el teardown del runtime de nube y del canal de Grupos, y el desregistro best-effort del push token.",
    exits: "Una sola salida: el Welcome. No hay error posible en este camino — no hay push-all, así que la fase nunca llega a `.blocked` y los dos alerts que Ajustes tiene cableados («No pudimos cerrar tu sesión» y «Un momento más») pertenecen a los caminos `.cloud`, secundario (M1) y solo-grupos, no a éste.",
    code: [
      { t: "CloudSessionSignOut.swift:91", d: "`signOut(context:)` (91-108) resuelve la precedencia con la capacidad COMPILADA (97) y despacha; para esta persona cae en `performPrivateReset()` (99-100)" },
      { t: "CloudSessionSignOut.swift:161", d: "`performPrivateReset` completo (161-183): teardown del runtime (166), teardown del canal de Grupos (170), push token (171), `CloudAuthService.signOut()` (172), los tres flags (174), `SessionState.resetToDefaults()` (175), `AppRouter.resetAll()` (176), `phase = .idle` (179)" },
      { t: "CloudSessionSignOut.swift:221", d: "`resetOnboardingFlagsPreservingData` (221-226) — las tres claves, y el comentario de 219-220 que dice que las prefs sobreviven «a diferencia del camino `.cloud`»" },
      { t: "CloudSessionSignOut.swift:180", d: "el comentario que describe el aterrizaje (180-182): «ContentView.onChange(hasCompletedOnboarding=false) desmonta MainTabView y re-presenta el Welcome»" },
      { t: "AppRouter.swift:151", d: "`resetAll()` (151-158) — y su docblock (147-150) lo dice: «Nukes everything: queue, readiness, revision, AND the persistent DeferredIntentBuffer»" },
      { t: "DeferredIntentBuffer.swift:73", d: "`clear()` = `save([])` (73-75), que escribe en `UserDefaults` (83-87). No es memoria" },
      { t: "PendingJoinStore.swift:163", d: "`clearAll()` = `defaults.removeObject(forKey: userDefaultsKey)` (163-165)" },
      { t: "SessionState.swift:376", d: "`resetToDefaults()` (376-387): `customDateRange = nil` en 378 dispara el `didSet` de 94-105, cuya rama `else` hace `removeObject` de `customPeriodStart`/`customPeriodEnd` (103-104)" },
      { t: "CloudAuthService.swift:460", d: "`signOut()` (460-487): `clearCapturedProfile` (462), `clearStoredProvider` (465), `GIDSignIn.sharedInstance.signOut()` (470), `AccountEntitlementService.handleSignOut()` (477) y `client.signOut(scope: .local)` (479)" },
      { t: "CloudAuthService.swift:14", d: "la cabecera (14-17) que refuta el «no-op sin backend»: «Desde D-R1 paso 1 producción SÍ construye el subsistema; lo que lo mantiene quieto ya no es la ausencia de cliente»" },
      { t: "ContentView.swift:174", d: "`if hasCompletedOnboarding && isInitialCheckDone { MainTabView() }` — el desmontaje que se lleva por delante la hoja de Ajustes" },
      { t: "ContentView.swift:241", d: "`onChange(of: hasCompletedOnboarding)` → `presentNextOnboardingScreen()`" },
      { t: "ContentView.swift:1376", d: "`if !hasShownWelcomeChooser { welcomeFlowInitialStep = .hero }` (1376-1378) — por eso se aterriza en el Hero y no en el chooser" },
      { t: "ProfileView.swift:93", d: "`syncSignOutUI` (93-103) — solo cierra Ajustes con `.awaitingRelaunch` (100); en `.idle`/`.working` no hace nada (101), así que aquí la hoja de Ajustes NO se cierra sola: se la lleva el desmontaje" }
    ],
    notes: [
      "⚠︎ `SessionState.resetToDefaults()` NO toca `onboardingMode`: quien llegó en modo solo-grupos sigue en modo solo-grupos tras salir, porque esa preferencia es never-downgrade y viaja por el iKV del Apple ID.",
      "El breadcrumb de este camino es `signOutPrivateReset()`; la variante encadenada del split escribe `signOutStarted(path: \"exit-yala-groups-session\")` (CloudSessionSignOut.swift:158). Es la única forma de distinguirlos en la telemetría.",
      "MEDIDO: `phase = .blocked` se pone en `performCloudSecureSignOut` (243, 253, 264, 284), en `performSecondaryCloudSignOut` (345, 353, 364) y en `performGroupsOnlySignOut` (417, 421, 431) — nunca en `performPrivateReset` (161-183). Los dos alerts de Ajustes (ProfileView.swift:424 y 434) son por tanto inalcanzables desde este camino, aunque su copy sí exista y sea alcanzable desde los otros tres."
    ]
  },

  "signout-welcome-condatos": {
    title: "El Welcome sobre un móvil lleno: la misma pantalla, otro significado",
    shot: "signout-welcome-condatos.png",
    sees: "El Hero de siempre: logo, carousel de cards, «Tus finanzas personales, sin esfuerzo.», el botón «Empezar» y, bajo él en pequeño, «100% privado · Tu info siempre contigo». Después el chooser con sus tres ramas («Es mi primera vez en Yala», «Ya tengo una cuenta», «Vengo por un grupo»). **Nada en pantalla dice que los datos siguen ahí**: ni un aviso, ni un «hola de nuevo», ni el nombre de la persona. Visualmente es idéntico a una instalación recién hecha; lo único que cambia es lo que hará cada botón.",
    persists: "Nada al llegar. El Hero no escribe y el chooser tampoco: `hasShownWelcomeChooser` lo escriben los callbacks de `ContentView` al elegir rama.",
    exits: "Las tres ramas del chooser y sus segundos niveles, que desembocan en las seis salidas del portal. **En la MISMA sesión el portal NUNCA relanza**, y la razón no es la que parece: el testigo que lee `shouldRelaunch` es el que capturó ESTE proceso al arrancar (`.iCloudMirror`, o `.localNoMirror` sin cuenta iCloud del OS), y `.privateReset` no lo reabre — el único que lo reabre es `PersonalContainerSwap`, cuyo único call-site vive dentro del camino `.cloud`. ⇒ las seis salidas llaman a `proceed()` directo. **Pero el arranque SIGUIENTE puede ser otro**: `personalStoreDecision` devuelve `.neutralNoMirror` también por la rama DURABLE (`freshInstall || neutralDurable`), y `shouldMountNeutralDurable` NO mira si el archivo del store existe — su docblock dice literalmente «aquí el archivo SÍ existe». La marca la arma el hook de wipe del cierre de sesión y **nadie la limpia** (`clearNeutralMountArm` no tiene ni un call-site en `Yala/`), mientras `.privateReset` repone `hasShownWelcomeChooser = false` ⇒ si la persona MATA la app sobre este Welcome, el arranque siguiente puede montar NEUTRO sobre un store lleno, y entonces tres de las seis salidas —«Es mi primera vez», «Restaurar de iCloud» y «Tengo una invitación»— SÍ interponen el «Un último paso: reabre Yala».",
    code: [
      { t: "WelcomeMirrorRelaunchLogic.swift:94", d: "`shouldRelaunch(destination:mountedDecision:)` (94-99); el predicado está en 98: `requiresMirror(destination) && mountedDecision == .neutralNoMirror`" },
      { t: "WelcomeMirrorRelaunchLogic.swift:78", d: "`requiresMirror` (78-85) — `privateOnboarding`/`restoreICloud`/`inviteRecovery` sí (80-81); `cloudAccount`/`cloudSignIn`/`groupsOrganizer` no (82-83)" },
      { t: "SwiftDataConfiguration.swift:341", d: "`if freshInstall || neutralDurable { return .neutralNoMirror }` dentro de `personalStoreDecision` (333-343) — DOS productores del mount neutro, no uno" },
      { t: "SwiftDataConfiguration.swift:296", d: "`shouldMountNeutralDurable(neutralMountArmed:hasShownWelcomeChooser:)` (296-301) y su docblock (290-295), que dice «aquí el archivo SÍ existe —lo acaba de crear el remonte del swap—»" },
      { t: "SwiftDataConfiguration.swift:266", d: "`isFreshInstallForNeutralMount` (266-277) — el OTRO productor, cuyo primer término sí es «no existe el archivo del store personal» (273). Es el que un móvil con datos falla siempre" },
      { t: "SwiftDataConfiguration.swift:648", d: "`StorageModePersistence.armNeutralMount(defaults)` dentro de `performSignOutWipeIfArmed`, pegado al `write(.icloud)` de 630" },
      { t: "CloudSyncFlags.swift:188", d: "`clearNeutralMountArm` (188-190) — **cero call-sites en `Yala/`**; lo único que la nombra es la aserción `src.contains(\"clearNeutralMountArm\") == false` de YalaTests/CloudSync/PersonalSwapReleaseTests.swift:390" },
      { t: "SwiftDataConfiguration.swift:516", d: "`capturePersonalStoreMountedDecisionOnce` (516-521): el testigo se captura UNA vez por proceso; solo `reopenPersonalStoreMountedDecisionCaptureForSwap` (534-536) lo reabre" },
      { t: "CloudSessionSignOut.swift:327", d: "`PersonalContainerSwap.attemptSignOutSwap()` — único call-site del swap, dentro de `performCloudSecureSignOut` (que abre en 230). El camino privado no pasa por aquí" },
      { t: "WelcomeFlowContainer.swift:230", d: "`leaveWelcome(to:proceed:)` (230-240) — el portal único; con `shouldRelaunch == false` llama a `proceed()` (235)" },
      { t: "ContentView.swift:1376", d: "`presentNextOnboardingScreen` — con `hasShownWelcomeChooser` recién puesto a `false`, el paso inicial es `.hero`" }
    ],
    notes: [
      "⚠︎ Trampa de lectura del Atlas: el nodo `alta-privado` dice «con un relanzamiento por delante si este proceso montó el store NEUTRO». En este recorrido eso es cierto SOLO tras matar la app y solo si la marca durable está puesta — dentro de la sesión es imposible.",
      "ALCANZABILIDAD de la rama durable, medida: `StorageModePersistence.armSignOutWipe()` tiene TRES call-sites en `Yala/` — `CloudSessionSignOut.swift:306` (camino `.cloud`), `CloudSessionSignOut.swift:529` (`closeLocalAfterAccountDeletionCloud`, el cierre local tras borrar la cuenta) y `CloudSyncDebugView.swift:922` (botón del panel de debug). Con `.cloud` DARK en producción, hoy la rama se alcanza en `Yala Dev` / panel de debug; el mecanismo, en cambio, es permanente porque la marca no se limpia nunca.",
      "⚠︎ HALLAZGO derivado de esa rama, MEDIDO EN CÓDIGO y no ejercitado: el callback del relanzamiento (`ContentView.swift:1517-1533`) marca `hasShownWelcomeChooser = true` (1528), limpia residuales si el destino es el privado (1529-1531) y **no monta el alert de fresh-start**, con un comentario que lo justifica diciendo que «el mount neutro exige que no haya archivo de store, así que en este camino no puede haber datos que confirmar» (1526-1527) — falso bajo la rama durable. Y tras reabrir, `ContentView.swift:1358-1361` encamina `.privateOnboarding` a `showOnboarding = true` directo. ⇒ esa persona puede empezar el onboarding de 8 pasos ENCIMA de sus datos sin que nadie le pregunte nada.",
      "La captura de esta pantalla es indistinguible de `alta-hero.png` / `alta-chooser.png`: lo que cambia es el estado del disco, no los píxeles.",
      "⚠︎ CINCO de las seis salidas escriben `hasShownWelcomeChooser = true` ANTES de hacer nada (la del organizador no, a propósito). Matar la app justo ahí manda el siguiente arranque directo al onboarding, saltándose el Welcome, con los datos aún en disco. La escapatoria existe y es el «atrás» del paso 1 del onboarding (ContentView.swift:697-704), que repone el flag a `false`."
    ]
  },

  "signout-salidas-matriz": {
    title: "Decisión · las SEIS salidas del Welcome sobre un móvil CON datos",
    shot: null,
    sees: "Nada: es la tabla que decide qué le pasa a los datos que siguen en el móvil según la rama que se elija. Los seis destinos se producen en SEIS sitios, todos dentro de `WelcomeFlowContainer`, y todos cruzan el mismo portal. (1) **«Es mi primera vez» → privacidad total** (el bypass de producción): limpia residuales SIEMPRE y, si hay datos, pide confirmación para BORRARLO TODO. (2) **«Ya tengo una cuenta» → Restaurar de iCloud**: no borra nada, cuenta lo que hay y devuelve a la app. (3) **«Ya tengo una cuenta» → entrar a la cuenta nube**: Apple y Google NO son dos salidas, son un solo `Destination` (`cloudSignIn`) producido en un solo sitio; solo cambia el provider que se fija. (4) **El encaminamiento por FARO**: si el faro dice que este Apple ID ya tiene cuenta nube, se reusa ese mismo `cloudSignIn` sin limpiar prefs. (5) **«Es mi primera vez» → cuenta en la nube** (alta born-cloud): no limpia, no pregunta y no borra. (6) **«Vengo por un grupo» → «Tengo una invitación»** (`inviteRecovery`): es la rama que faltaba en la lectura anterior, y cae del lado que EXIGE mirror. Y la séptima que no llega a salir: **«Vengo por un grupo» → «Crear mi primer grupo»**, que pasa por una puerta de TRES términos y en este recorrido se cierra.",
    persists: "Cada salida lo suyo; la tabla en sí no escribe. Cinco de las seis marcan `hasShownWelcomeChooser = true` en su callback antes de continuar; la del organizador no lo hace y su comentario explica por qué (todavía no ha escrito nada y un abandono tiene que poder volver).",
    exits: "El destino se produce en seis sitios y todos cruzan el MISMO portal (`leaveWelcome`), que en esta sesión nunca interpone relanzamiento. `Destination` es `CaseIterable` a propósito: una salida nueva está obligada a declarar de qué lado del mirror cae.",
    code: [
      { t: "WelcomeMirrorRelaunchLogic.swift:38", d: "`enum Destination: String, CaseIterable` (38-54) — SEIS casos, y el `String` es lo que viaja en `UserDefaults` para sobrevivir al relanzamiento" },
      { t: "WelcomeFlowContainer.swift:163", d: "sitio 1 — `leaveWelcome(to: .inviteRecovery) { onSelectBranch(.invite) }`, la card «Tengo una invitación» del sub-chooser de grupos" },
      { t: "WelcomeFlowContainer.swift:175", d: "sitio 2 — `leaveWelcome(to: .groupsOrganizer) { onSelectGroupsOrganizer() }`, y es el ÚNICO que llega desde una puerta (`onProceed` de `WelcomeGroupsGateView`)" },
      { t: "WelcomeFlowContainer.swift:261", d: "sitio 3 — `handleExistingOption` (255-262): `restoreICloud` → `.restoreICloud`; `cloudSignIn` y `googleSignIn` comparten `.cloudSignIn` (259)" },
      { t: "WelcomeFlowContainer.swift:279", d: "sitio 4 — `leaveWelcome(to: .cloudSignIn) { onBeaconRoutesToCloudSignIn(provider) }`, el encaminamiento por faro dentro de `handleNewBranch`" },
      { t: "WelcomeFlowContainer.swift:293", d: "sitio 5 — `leaveWelcome(to: .privateOnboarding) { onSelectPrivateAccount() }`, **el bypass de producción** según su propio comentario (290-292)" },
      { t: "WelcomeFlowContainer.swift:298", d: "sitio 6 — `leaveWelcome(to: .cloudAccount) { onSelectCloudAccount() }`, el alta born-cloud" },
      { t: "WelcomeMirrorRelaunchLogic.swift:78", d: "`requiresMirror` — `privateOnboarding`/`restoreICloud`/`inviteRecovery` sí (80-81); las tres del Modo Nube y el organizador no (82-83)" },
      { t: "ContentView.swift:1493", d: "`onSelectGroupsOrganizer` (1493-1505) — la única que NO marca `hasShownWelcomeChooser`, con el porqué escrito en 1497-1502" },
      { t: "ContentView.swift:1452", d: "`onSelectExistingOption` (1452-1469): marca el flag (1455) y fija `welcomeCloudEntry = .reentry(.apple)` / `.reentry(.google)` EXPLÍCITO (1461, 1465)" },
      { t: "ContentView.swift:1476", d: "`onSelectCloudAccount` (1476-1492): **no** llama a `startFreshPrivateOnboarding()` y el comentario dice por qué (1482-1487: aquí no se limpia nada ni se pregunta por el wipe)" },
      { t: "GroupsOrganizerGateLogic.swift:78", d: "`decide(channelEnabled:isSecondarySession:hasExistingData:)` (78-85): TRES guards EN ORDEN — canal (81), sesión secundaria (82), datos ajenos (83). El primero manda" },
      { t: "ContentView.swift:311", d: "`hasLocalDataNow: { checkHasExistingData() }` — fetch VIVO (no snapshot), el mismo closure que alimenta la puerta del organizador" },
      { t: "ContentView.swift:1086", d: "`checkHasExistingData()` (1086-1109): cuenta `Account` no-sistema, `Category` no-sistema, TODO `SplitGroup` y las `TransactionItem` bridgeadas; su `catch` devuelve `true` (1107) — falla CERRADO" },
      { t: "ContentView.swift:1608", d: "`startFreshPrivateOnboarding` (1608-1623) — limpia residuales SIEMPRE (1611) y solo después mira `hasExistingData` (1616)" }
    ],
    notes: [
      "⚠︎ La salida cerrada le dice a esta persona que sus PROPIOS datos son «de otra cuenta»: con el canal encendido y sin sesión secundaria, la puerta cae en `blockedForeignData` y `WelcomeGroupsGateView.swift:79-83` pinta el copy prestado del guard de sign-in de nube («Este dispositivo tiene datos de otra cuenta» / «Para proteger esos datos, no podemos conectar una cuenta distinta aquí. Su dueño puede volver a entrar cuando quiera.»). El bloqueo es DELIBERADO —el docblock de `GroupsOrganizerGateLogic` (24-30) nombra literalmente esta ventana— pero el texto describe una acción que la persona no está haciendo.",
      "MEDIDO: el ORDEN de la puerta importa para lo que se ve. Con el canal de Grupos APAGADO gana el primer término y la pantalla dice «Ahora mismo no podemos abrirte grupos» / «Es algo de nuestro lado y dura poco…», no lo de los datos ajenos. El estado del canal en producción es remoto (`CloudSyncFlags.groupsBackendEnabled` tras un `refreshIfDue(force: true)`) y NO se puede medir desde este árbol.",
      "La salida 5 (alta born-cloud) es la única que no pregunta NADA sobre los datos que hay: ni limpia residuales ni ofrece borrar. Su red es posterior — el guard cross-cuenta, si el claim acaba encaminando a returning-user.",
      "MEDIDO: el detector `checkHasExistingData` falla CERRADO, así que un error de lectura convierte «Es mi primera vez» y la puerta del organizador en «hay datos» aunque no los haya."
    ]
  },

  "signout-freshstart-alert": {
    title: "«Empezar desde cero» · el único alert que borra, y lo que ya borró antes de preguntar",
    shot: "signout-freshstart-alert.png",
    sees: "Alert del sistema sobre el Welcome: título **«Empezar desde cero»**, mensaje **«Detectamos datos previos en tu dispositivo. ¿Borrar todo para empezar como nuevo?»**, botón destructivo **«Borrar todo y continuar»** y **«Cancelar»**. El cover del Welcome sigue visible detrás hasta que se resuelve.",
    persists: "Con «Borrar todo y continuar»: `DataWipeService.wipeAllUserData(broadcastSignal: false)` borra el corpus personal y, acto seguido, `wipeLocalGroupsDomain` borra el dominio Grupos LOCAL (las 5 tablas `Split*`), purga el espejo del outbox en el App Group, limpia las preferencias del dominio —incluida `groupsBetaUnlocked` y el latch de historial de sesión— y pone el sello `groupsDomainSealedForFreshStart`. Con «Cancelar»: no se borra nada… **salvo lo que ya se borró antes de abrir el alert** — `clearResidualPreferencesForFreshStart()` corre incondicionalmente al tapear la rama y quita `userName` y `defaultCurrencyCode` de `UserDefaults` (y escribe «» en el iKV para no pisar las prefs de otros dispositivos).",
    exits: "Confirmar → `showWelcomeFlow = false` + `showOnboarding = true` (onboarding de 8 pasos). Cancelar → se queda en el Welcome, con las otras dos ramas intactas.",
    code: [
      { t: "ShellDataAlertsModifier.swift:64", d: "el alert entero: título (64), botón destructivo (65), wipe personal (67-70), wipe del dominio Grupos (76), salto al onboarding (88-89), «Cancelar» (93) y el mensaje (96)" },
      { t: "ContentView.swift:1616", d: "`if hasExistingData { showFreshStartWipeAlert = true }` — el disparador; el alert NO vive aquí" },
      { t: "ContentView.swift:1611", d: "`OnboardingResetHelper.clearResidualPreferencesForFreshStart()` — corre ANTES del `if` de 1616, así que cancelar no lo deshace" },
      { t: "OnboardingResetHelper.swift:25", d: "`safeKeysToClear` = exactamente `userName` y `defaultCurrencyCode` (25-28); el bucle hace `removeObject` en local y escribe «» al iKV (38-44)" },
      { t: "DataWipeService.swift:269", d: "`wipeLocalGroupsDomain` (269-322): borra las 5 tablas `Split*` (283-287), purga el espejo del App Group vía el seam `resetSyncState` (273-279, 312) y escribe el sello AL FINAL (321)" },
      { t: "DataWipeService.swift:337", d: "`removeGroupsDomainPreferenceKeys` — su único llamador es `wipeLocalGroupsDomain` (DataWipeService.swift:310), y ÉSE tiene DOS call-sites: este alert (ShellDataAlertsModifier.swift:76) y el «Empezar de cero» del alert de oferta de restaurar (ShellDataAlertsModifier.swift:118)" }
    ],
    notes: [
      "⚠︎ HALLAZGO · el fallo del borrado es SILENCIOSO: si `wipeAllUserData` o `wipeLocalGroupsDomain` lanzan, el `catch` (ShellDataAlertsModifier.swift:83-87) solo imprime bajo `#if DEBUG` y el flujo continúa igual a `showOnboarding = true` ⇒ la persona empieza un onboarding «de cero» encima de datos que NO se borraron, y en pantalla nada lo dice.",
      "MEDIDO, con el porqué corregido: la limpieza de residuales no se nota EN SESIÓN, pero **no porque `loadFromDefaults()` corra solo en el `init`** — tiene TRES call-sites (AppPreferences.swift:844 en el init, 898 en el observer de `UserDefaults.didChangeNotification` y 908 en el del iKV), así que re-corre constantemente. Lo que salva el nombre vivo es que `clearResidualPreferencesForFreshStart` hace `removeObject` en el dominio local (OnboardingResetHelper.swift:39) y la recarga lee `if let raw = defaults.string(forKey: Keys.userName), !raw.isEmpty` (AppPreferences.swift:972): sin key no entra y no pisa el valor en memoria. El efecto de haber tapeado-y-cancelado aparece un arranque en frío después.",
      "El copy no menciona los grupos y el borrado sí los toca (localmente). Lo que se borra es la copia local: las zonas CloudKit del Apple ID siguen ahí y el motor puede re-descargarlas, que es justo la razón de que exista el sello `groupsDomainSealedForFreshStart`.",
      "El alert es además blocker de la matriz de readiness (`freshStartWipeAlert`): mientras está en pantalla, ningún intent del router presenta debajo."
    ]
  },

  "signout-restaurar-vuelta": {
    title: "«Ya tengo una cuenta → Restaurar de iCloud» · la vuelta a casa por la puerta de al lado",
    shot: "signout-restaurar-vuelta.png",
    sees: "Primero una pantalla de progreso con círculo, barra por fases y conteos en vivo: «Conectando con iCloud…» → «Trayendo tus datos…» → «Sincronización completada» (o «Listo lo esencial. Seguiremos sincronizando mientras usas la app.»). Después, la pantalla de reencuentro: **«¡Hola %@! Qué bueno verte de vuelta.»** (con el nombre; sin nombre, «¡Qué bueno verte de vuelta!»), **«Encontramos tus datos en iCloud:»** y las tarjetas de conteo —«%d cuentas», «%d registros», «%d presupuestos», «%d grupos compartidos»—, con «Continuar» y, en pequeño, «Empezar desde cero».",
    persists: "Al tocar «Continuar» con el perfil completo: `hasCompletedOnboarding = true`, `SetupChecklistManager.markAsNewInstall()` y —si no eres Pro— `needsPostOnboardingTrial = true`. ⇒ **la vuelta re-arma el checklist de bienvenida y vuelve a poner en cola la oferta de prueba**, aunque la persona lleve meses usando la app. La pantalla en sí no escribe nada mientras se mira.",
    exits: "`RestoreRouter.decide`: si el `onboardingMode` restaurado es solo-grupos → modo solo-grupos; si el resumen está completo (nombre + cuentas + subcategorías) → directo a la app; si falta algo → onboarding con los pasos prellenados. «Empezar desde cero» abre un `confirmationDialog` («¿Empezar desde cero?» / «Esto creará una cuenta nueva sin tus datos previos. ¿Continuar?» / «Sí, empezar desde cero» · «Cancelar») que **no borra nada**: limpia residuales y abre el onboarding encima de los datos.",
    code: [
      { t: "ContentView.swift:638", d: "`welcomeRestoreCover` (638-687) — los cuatro callbacks y el reparto por destino (643-666)" },
      { t: "RestoreDestination.swift:30", d: "`RestoreRouter.decide(onboardingMode:isFullyPrefilled:)` (30-34) — las tres salidas: solo-grupos gana (32), luego prefilled → directo, si no → onboarding (33)" },
      { t: "iCloudSyncService.swift:679", d: "`isFullyPrefilled` (679-681) = nombre ≠ nil ∧ cuentas > 0 ∧ categorías > 0" },
      { t: "iCloudSyncService.swift:688", d: "`func iCloudAccountSummary(appPreferences:)`, dentro del `extension ModelContext` que abre en 685: los cinco `fetchCount` (692-709) salen del contexto LOCAL, no de una consulta a CloudKit — en este recorrido los datos ya están en disco" },
      { t: "ContentView.swift:1918", d: "`completeOnboardingAsRestoreSkip()` (1918-1924) — el trío que escribe la vuelta: `needsPostOnboardingTrial` (1919-1921), `hasCompletedOnboarding` (1922) y `markAsNewInstall()` (1923). Sus call-sites son 654 y 658" },
      { t: "RestoreProgressView.swift:28", d: "`init(timeout: TimeInterval = 90, onSettled:)` — el presupuesto de la espera de quiescencia" },
      { t: "WelcomeRestoreView.swift:170", d: "«Empezar desde cero» (170-176) solo hace `showStartFreshConfirm = true` (171); el diálogo vive en 93-104" },
      { t: "ContentView.swift:668", d: "`onStartFresh` (668-676): limpia residuales (672), anula el prefill (673) y abre el onboarding (675). **No borra nada**" }
    ],
    notes: [
      "⚠︎ El botón pequeño «Empezar desde cero» de esta pantalla NO borra: llama a `onStartFresh`, que limpia dos preferencias y abre el onboarding. El que borra es el alert de la otra rama. Dos textos casi iguales, dos efectos distintos.",
      "⚠︎ Efecto colateral medido de la ida y vuelta: quien sale y vuelve por aquí se re-encuentra el checklist de configuración («recién instalada») y, si no es Pro, la oferta de prueba en cola. Nada lo advierte.",
      "El conteo de «categorías» del resumen usa `Subcategory` no-sistema (iCloudSyncService.swift:707-709), mientras que el detector de «hay datos» del Welcome usa `Category` no-sistema (ContentView.swift:1090-1092): son dos preguntas distintas y pueden discrepar."
    ]
  },

  "signout-restaurar-errores": {
    title: "Los cuatro finales no-felices de «Restaurar de iCloud»",
    shot: "signout-restaurar-errores.png",
    sees: "Cuatro pantallas hermanas, decididas ANTES de buscar nada. **Sin cuenta de iCloud en el dispositivo**: «Activa iCloud para continuar» / «Necesitas tener iCloud activado para recuperar tus datos. Actívalo en Ajustes y vuelve a intentar.» con «Abrir Ajustes». **Tras un vaciado reciente**: «Borraste tus datos» / «Eliminaste tus datos en este dispositivo. Empieza de nuevo cuando quieras.». **Sin datos**: «No encontramos tus datos» / «No hay datos asociados a tu cuenta de iCloud. ¿Quieres empezar desde cero?». **Fallo**: «Hubo un problema» / «No pudimos buscar tus datos en iCloud. Intenta de nuevo o configura desde cero.». En los dos últimos aparece además el botón de reintento en la barra, con etiqueta de accesibilidad «Reintentar búsqueda».",
    persists: "Nada en ninguna de las cuatro. El estado `.wiped` deja un breadcrumb (`RestoreBreadcrumb.wiped()`, WelcomeRestoreView.swift:122).",
    exits: "«Abrir Ajustes» sale a los Ajustes del sistema (ContentView.swift:677-681). El reintento vuelve a `.searching` y relanza la búsqueda (WelcomeRestoreView.swift:82-83). El «atrás» devuelve al chooser del Welcome. Desde `.notFound`/`.error` también se puede ir a «Empezar desde cero», que abre el onboarding sin borrar.",
    code: [
      { t: "WelcomeRestoreView.swift:113", d: "`startSearch()` — el orden: primero `isAccountAvailable` (114-117), después el gate de wipe (118-125), y solo entonces `.searching` (126)" },
      { t: "SwiftDataConfiguration.swift:36", d: "`isICloudAvailable()` = `FileManager.default.ubiquityIdentityToken != nil` (36-38) — sin sesión de iCloud en el dispositivo, esta rama es la que sale SIEMPRE" },
      { t: "WelcomeRestoreView.swift:17", d: "`enum ViewState` (17-24) — los seis estados de la máquina, cuatro de ellos no-felices" },
      { t: "WelcomeRestoreView.swift:55", d: "`RestoreProgressView { summary in state = summary.hasAnyData ? .found(summary) : .notFound }` (55-57) — al asentar decide `.found` o `.notFound`" },
      { t: "WelcomeRestoreView.swift:76", d: "`showRefreshToolbar` (41-46) es `true` solo en `.notFound`/`.error`; el botón de la barra vive en 76-90" }
    ],
    notes: [
      "⚠︎ TRAMPA DE SIMULADOR: un simulador sin sesión de iCloud no puede llegar nunca a la pantalla de reencuentro — cae siempre en «Activa iCloud para continuar». Es la captura barata de este nodo y la razón por la que la feliz cuesta. La captura de este panel retrata por tanto la variante `.iCloudDisabled`; las otras tres no son alcanzables sin cuenta iCloud porque el guard de 114 corta antes.",
      "En este recorrido `.notFound` es improbable (los datos están en disco y el resumen los cuenta desde ahí), pero `.iCloudDisabled` es perfectamente posible: se puede tener datos locales y la cuenta de iCloud desactivada.",
      "`.wiped` se decide con las marcas de tiempo del iKV (último vaciado vs último onboarding, WelcomeRestoreView.swift:118-121), no con el estado del disco: describe lo último que hizo la persona, no lo que hay."
    ]
  },

  "signout-hoja-legado5a": {
    title: "La hoja del solo-grupos legado 5a: otro humano, la misma salida",
    shot: "signout-hoja-legado5a.png",
    sees: "La misma hoja de tres filas con los mismos símbolos de sistema (`iphone` / `icloud` / `person.2`), pero con otro título y otro copy: **«¿Salir de Yala en este dispositivo?»** · «En este dispositivo» → «Vuelves a la pantalla de inicio; tus datos no se tocan» · «En iCloud» → «Tus grupos siguen en tu iCloud» · «En tus grupos» → «Siguen en tu iCloud». Nota de conservación: **«Puedes volver a entrar cuando quieras; tus grupos siguen en tu iCloud.»**. Botones «Salir de Yala» y «Cancelar». Las tres filas en tono «no se toca», como en la privada.",
    persists: "Nada al confirmar más allá de lo que escribe `.privateReset` (ver ese panel: los tres flags de onboarding y los borrados de `AppRouter.resetAll`). Los grupos de la era CloudKit no se tocan (viven en el iCloud de esa persona) y `onboardingMode` sigue siendo `.groupInvite`, así que el dispositivo recuerda que llegó por un grupo.",
    exits: "«Salir de Yala» → misma hoja compartida que la privada (`showCloudSignOutConfirm`) → `signOut(context:)` → la precedencia resuelve `.privateReset` (no es secundaria, no es `.cloud`, no hay sesión backend) → Welcome. «Cancelar» → no-op.",
    code: [
      { t: "CloudSignOutFlowLogic.swift:80", d: "`shouldShowExitYalaRow` (80-82): `isGroupInviteMode && !hasLiveSession` — mutuamente excluyente con la fila «Cerrar sesión»" },
      { t: "CloudSignOutFlowLogic.swift:75", d: "el docblock que explica por qué existe esta fila (75-77): el solo-grupos legado 5a «no tenía ninguna salida — ni \"Cerrar sesión\" ni \"Exportar\"»" },
      { t: "ProfileView.swift:1120", d: "`case .exitYalaOnly` (1120-1137) — la fila, y su tap abre la MISMA hoja compartida (1126)" },
      { t: "ProfileView.swift:108", d: "`isExitYalaContext` (108-112) — el flag que hace que la hoja compartida resuelva `.exitYalaLegacy` (119) en vez de `.signOutPrivate`" },
      { t: "DestructiveScopeLogic.swift:221", d: "`case .exitYalaLegacy` (221-230) — tres filas `.preserved` + nota de conservación" },
      { t: "DestructiveScopeSheet.swift:379", d: "los tres detalles propios del legado (379-384): `exitYalaScopeDeviceLegacy` / `exitYalaScopeCloudLegacy` / `exitYalaScopeGroupsLegacy`" },
      { t: "DestructiveScopeSheet.swift:408", d: "título propio: `case .exitYalaLegacy, .exitYalaGroups` (408) → `L10n.Settings.exitYalaConfirmTitle` (409)" },
      { t: "DestructiveScopeSheet.swift:423", d: "acción propia: dentro de `confirmLabel(for:)` (abre en 415), `case .exitYalaLegacy, .exitYalaGroups` (423) → `L10n.Settings.exitYalaConfirmAction` (424) = «Salir de Yala»" },
      { t: "DestructiveScopeSheet.swift:446", d: "`case .exitYalaLegacy: return L10n.Settings.exitYalaScopeConservationLegacy` — la nota de conservación propia" }
    ],
    notes: [
      "Esta persona y la privada terminan en el MISMO sitio (`.privateReset` → Welcome con todo intacto) leyendo dos textos distintos. La diferencia de copy es correcta: a una le hablan de sus datos, a la otra de sus grupos.",
      "⚠︎ Esta hoja es la única del recorrido cuyo botón destructivo NO dice «Cerrar sesión»: dice «Salir de Yala». Un test que busque el texto del botón —y no el identifier, que sigue siendo `destructive_scope_confirm`— no cubre las dos.",
      "Al volver al Welcome, esta persona conserva `onboardingMode = .groupInvite`: si vuelve a entrar, la app sigue siendo la reducida a Grupos. `SessionState.resetToDefaults()` no toca esa preferencia."
    ]
  },


  // ══════════════════════════════════════════════════════════════════════════
  // R5 · Vuelvo a Yala en un móvil nuevo
  // ══════════════════════════════════════════════════════════════════════════

  "reentry-arranque": {
    title: "El primer arranque en el móvil nuevo: qué sobrevivió y qué no (decisión, sin pantalla)",
    shot: null,
    sees: "Nada: ocurre antes del splash. Pero lo que este arranque encuentra decide TODO el recorrido, y no es lo mismo una reinstalación que un móvil nuevo.\n\nSOBREVIVE en los dos casos (viaja con el Apple ID por iCloud-KV): el faro `yala.cloud.accountLinked` / `accountProvider` / `accountHash` / `accountLinkedAt`, y las preferencias sincronizadas (`PreferenceSyncService`), entre ellas los dos timestamps de onboarding/wipe cuyo docblock dice literalmente que sobreviven al uninstall — son los que decide `RestoreOfferGate`.\n\nSOBREVIVE SOLO EN EL MISMO MÓVIL (Keychain, y los items son `ThisDeviceOnly` ⇒ no viajan a otro teléfono ni por backup de iCloud): la sesión de Supabase (service `com.yala.cloudauth`), el perfil capturado + `cloudauth.provider`, y el `appattest.keyId`.\n\nNO SOBREVIVE NUNCA: todo `UserDefaults` — el modo de almacenamiento (vuelve a `.icloud` por contrato), el par `mirrorOffArmed`, el `CloudClaimActionStore` (la prueba de «este corpus es mío»), `hasShownWelcomeChooser` y `hasCompletedOnboarding` (los dos `synced: false`, así que no viajan por el iKV) — y los ficheros de los stores (personal, grupos, syncMeta, con el journal de migración dentro).",
    persists: "Este panel no escribe nada: describe el estado encontrado. La consecuencia que más pesa aguas abajo es que el `CloudClaimActionStore` se fue: sin él, `CrossAccountEntryGuardLogic` no puede reconocer un corpus local como propio.",
    exits: "Sin par y sin archivo de store, `personalStoreDecision` cae en la rama NEUTRA y el proceso monta el store personal con `cloudKitDatabase: .none`. De ahí sale el Welcome.",
    code: [
      { t: "SwiftDataConfiguration.swift:266-277 `isFreshInstallForNeutralMount`", d: "los 4 términos PRE-MOUNT; el primero (no existe el archivo del store) es el que una reinstalación y un móvil nuevo cumplen igual" },
      { t: "SwiftDataConfiguration.swift:333-343 `personalStoreDecision`", d: "la cadena en orden: secundaria → par `.cloud`+armado → neutro (`freshInstall` ∨ `neutralDurable`, la rama de R5 es la primera) → iCloud/local" },
      { t: "SwiftDataConfiguration.swift:261-265", d: "el docblock que declara por qué R5 y el final de R4 comparten arranque: un device que acaba de ejecutar el wipe del cierre de sesión llega aquí INDISTINGUIBLE de una reinstalación" },
      { t: "CloudSyncFlags.swift:51-57 `StorageModePersistence.read`", d: "key ausente ⇒ `.icloud`: la reinstalación borra la elección de modo, no la conserva" },
      { t: "CloudAuthKeychainStorage.swift:6-11 · :43", d: "service Keychain propio (`com.yala.cloudauth`, declarado en :26) con `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`; el docblock declara que la sesión JAMÁS viaja al Keychain de iCloud" },
      { t: "AppPreferences.swift:413-418 · :424-429", d: "`hasCompletedOnboarding` y `hasShownWelcomeChooser` se persisten con `synced: false` (:416 y :427) ⇒ son per-device y no cruzan por el iKV: en el móvil nuevo los dos nacen en `false`" },
      { t: "PreferenceSyncService.swift:106-111", d: "lo contrario: `lastOnboardingTimestamp` y `lastWipeTimestamp` se leen del iKV y su docblock dice «Sobrevive al uninstall → señal rápida de returning user»" },
      { t: "CloudBeacon.swift:46-52 `Keys`", d: "las 4 keys del faro en `NSUbiquitousKeyValueStore` — junto con las prefs sincronizadas, el único estado que cruza de un teléfono a otro" },
      { t: "CloudBeacon.swift:64-72 `writeCloudAccountLinked`", d: "quién lo escribió en el móvil viejo: el efecto `.writeBeacon` del claim y el alta born-cloud, los dos con el `sub` ⇒ el `accountHash` normalmente está presente (`:67-69` solo lo omite con `sub` nil/vacío)" },
      { t: "AttestKeyRecoveryLogic.swift:8-16", d: "MEDIDO en device el 2026-07-31 (la fecha está en :8, el hecho en :10-11): la key de App Attest muere con la INSTALACIÓN y su keyId SOBREVIVE en el Keychain — la prueba, en este repo, de que los items de Keychain no se van con la app" }
    ],
    notes: [
      "⚠︎ La supervivencia del Keychain está MEDIDA en este repo para `appattest.keyId` (`KeychainService`, service `com.yala.app`), no para `com.yala.cloudauth`. Que la sesión de nube sobreviva igual es una INFERENCIA por ser el mismo mecanismo (`kSecClassGenericPassword`); es el supuesto del que cuelga el panel `reentry-mismomovil` y está declarado como hueco allí también.",
      "Corrección aplicada: la coordenada de `AttestKeyRecoveryLogic` iba a `:9-16` y dejaba la fecha «medido en device el 2026-07-31» FUERA del rango citado. Ahora es `:8-16`."
    ]
  },

  "reentry-movilnuevo": {
    title: "Móvil NUEVO de verdad: hay sign-in, y el faro puede llegar tarde",
    shot: "reentry-movilnuevo.png",
    sees: "El recorrido completo, con la pantalla intermedia que la app SÍ pinta: «¡Hola! ¿Qué quieres hacer en Yala?» → «Ya tengo una cuenta» → el sub-chooser «Ya tengo una cuenta / Elige cómo quieres recuperar tus datos.» con sus TRES cards («Restaurar desde iCloud» · «Entrar con Apple» · «Entrar con Google») → la pantalla «Entra a tu cuenta» con «Usa el mismo Apple ID con el que creaste tu cuenta de la nube.» (o la variante de Google) → el sheet del consent («Tus datos en la nube de Yala», con «Entiendo y quiero activar la nube» abajo) → **la hoja nativa de Apple/Google con Face ID** → «Verificando tu cuenta…».\n\nSi el usuario elige en cambio «Es mi primera vez en Yala», quien decide es el faro: vinculado ∧ entrada de nube disponible ⇒ se le encamina a esta MISMA pantalla sin ofrecerle nunca la elección.",
    persists: "`hasShownWelcomeChooser = true` en el callback de la sub-elección (ContentView.swift:1455) y el provider EXPLÍCITO del cover. La sesión, cuando el sign-in completa (Keychain propio). Nada más hasta que el guard cross-cuenta decida.",
    exits: "Cancelar en la hoja de Apple devuelve al intro en silencio (ASAuthorization no distingue cancel de fallo). Cancelar en Google también, pero un fallo REAL de Google sí pinta el error con Reintentar — la asimetría es deliberada.",
    code: [
      { t: "WelcomeFlowContainer.swift:180-186", d: "el step `.existingChooser`: la pantalla intermedia real, con `onBack` de vuelta al chooser. Es la que desaparece bajo el kill-switch (ver `reentry-killswitch`)" },
      { t: "WelcomeExistingChooserView.swift:36-41 · :63-69", d: "la cabecera («Ya tengo una cuenta» + «Elige cómo quieres recuperar tus datos.») y los títulos de las tres cards en `title(for:)`" },
      { t: "ContentView.swift:1460-1467", d: "donde el provider queda FIJADO explícito: `.cloudSignIn` ⇒ `.reentry(.apple)`, `.googleSignIn` ⇒ `.reentry(.google)`, con el comentario «jamás heredar el previo»" },
      { t: "WelcomeCloudSignInView.swift:599-625 `ensureSignedIn`", d: "aquí SÍ se firma: en un móvil nuevo no hay sesión en el Keychain, así que el `guard` de la línea 601 no corta y se llama a `signIn(with:)`" },
      { t: "WelcomeCloudSignInView.swift:613-622", d: "la asimetría Apple/Google de los catches, compartida por el alta y la re-entrada a propósito" },
      { t: "WelcomeAccountChoiceLogic.swift:103-116 `routeNewBranch`", d: "el faro va ANTES de ofrecer nada; provider desconocido ⇒ `.apple` (el faro solo ENCAMINA)" },
      { t: "WelcomeFlowContainer.swift:272-285 `handleNewBranch`", d: "construye `CloudBeacon()` y lo lee SÍNCRONO en el momento del tap: no hay espera ni observador del iKV en este camino" },
      { t: "PanelPreferencesMigration.swift:52-54", d: "el propio repo documenta el hazard para otro consumidor: «un device nuevo cuyo iKV aún no bajó (`NSUbiquitousKeyValueStore.synchronize` no bloquea por red)»" },
      { t: "ContentView.swift:1506-1516 `onBeaconRoutesToCloudSignIn`", d: "el faro reusa el MISMO cover que la card, con el provider seteado EXPLÍCITO; aquí NO se limpian prefs residuales (no es un fresh start)" }
    ],
    notes: [
      "⚠︎ HALLAZGO: **el faro puede estar MUDO justo en el móvil donde más falta hace.** Se lee síncrono al tapear y nada espera a que el iCloud-KV baje en una instalación recién estrenada. Con el faro mudo, «Es mi primera vez» NO encamina y el usuario puede elegir «privacidad total», que es exactamente el dataset divergente que A26 existe para impedir. No queda cerrado del todo: la card «Ya tengo una cuenta» sigue ahí, y si el usuario cae en el alta nube el claim devuelve `existing_stable` y lo reencamina (ver `alta-returning`).",
      "No MEDÍ cuánto tarda el iKV en bajar en un device nuevo ni con qué frecuencia llega a tiempo. Lo medido es que la lectura no espera.",
      "Corrección aplicada: la versión anterior de este panel se saltaba el sub-chooser `.existingChooser` y se contradecía con `reentry-killswitch`, que retrata su desaparición."
    ]
  },

  "reentry-mismomovil": {
    title: "Reinstalación en el MISMO móvil: la sesión sobrevive y el sign-in no se pide",
    shot: "reentry-mismomovil.png",
    sees: "Lo mismo que en el móvil nuevo **hasta el consent**, y entonces algo que sorprende: al aceptar «Entiendo y quiero activar la nube» **no aparece ninguna hoja de Apple ni de Google, ni Face ID**. La pantalla salta directa a «Verificando tu cuenta…» y de ahí al adopt.\n\nEl motivo es que la sesión de Supabase vive en un Keychain propio de la app; el SDK la recarga al construir el cliente, así que `hasSession` ya es `true` antes de que el usuario toque nada.",
    persists: "Nada nuevo por el sign-in (no lo hay). El consent queda PENDIENTE de escritura hasta que el guard cross-cuenta diga la ruta — igual que en el móvil nuevo.",
    exits: "Sigue por `exists` → guard → adopt. No hay salida propia: para quien mira la pantalla, este camino es el mismo con un paso menos. El botón «Cancelar» del sheet del consent sigue estando.",
    code: [
      { t: "WelcomeCloudSignInView.swift:601", d: "`guard !CloudAuthService.shared.hasSession else { return true }` — el retorno temprano que se salta el sign-in entero, escrito para no re-pedir Face ID en un retry" },
      { t: "CloudAuthService.swift:176-186", d: "el `AuthClient` se construye con `localStorage: CloudAuthKeychainStorage()` y `autoRefreshToken: true` ⇒ la sesión persistida se recarga sola al primer uso del servicio" },
      { t: "CloudAuthService.swift:213-218 `hasSession`", d: "`client?.currentSession != nil` (con un seam `UITestHooks.fakeCloudSession` bajo `#if DEBUG` en :214-216) — es lo único que mira el guard de arriba" },
      { t: "CloudAuthKeychainStorage.swift:43", d: "`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`: por eso sobrevive a la reinstalación en ESTE teléfono y no viaja a otro" },
      { t: "CloudAuthService.swift:271 `storedProvider()`", d: "el provider REAL de la sesión viva, también en el Keychain — existe, y este camino no lo consulta" },
      { t: "WelcomeCloudSignInView.swift:684-690", d: "la única rama que invoca el guard de provider-mismatch es `.accountMissing`, y entra con `accountExists: false` LITERAL en :690" },
      { t: "ProviderMismatchLogic.swift:53", d: "regla 1: `if accountExists { return .proceed }` — con la cuenta existente el veredicto es `.proceed` SIEMPRE, así que la pantalla de mismatch no se pinta" }
    ],
    notes: [
      "⚠︎ **El método que el usuario tapea se IGNORA cuando hay sesión viva.** Tapear «Entrar con Apple» sobre una sesión de Google reinstalada no cambia nada: `ensureSignedIn` retorna en :601. Es inofensivo en el caso normal porque `ProviderMismatchLogic` ni siquiera se consulta: solo corre en la rama `.accountMissing` (:684-690) y su regla 1 sale por `.proceed` con la cuenta existente. La pantalla «Esa cuenta usa otro método» solo es alcanzable si `GET /account/exists` devuelve 404 —cuenta borrada server-side con faro stale— y además el faro no lleva `accountHash`: entonces la regla 4 (:56) no corta y la 5 (:57) pinta «Tu cuenta de Yala se creó con Google». DERIVADO del código, no reproducido.",
      "⚠︎ INFERIDO, no medido: que los items de `com.yala.cloudauth` sobrevivan al borrado de la app se deduce de que usan el mismo mecanismo (`kSecClassGenericPassword`) que el `appattest.keyId`, cuya supervivencia SÍ está medida en device el 2026-07-31 (AttestKeyRecoveryLogic.swift:8-16, service `com.yala.app`). Sin sesión superviviente, este camino es idéntico al del móvil nuevo y el panel no aplica.",
      "Consecuencia buena y poco obvia: en una reinstalación el 401 de sesión caducada es MENOS probable de lo que parece, porque el SDK auto-refresca (`autoRefreshToken: true`, CloudAuthService.swift:184) y solo limpia el storage cuando el refresh falla terminal."
    ]
  },

  "reentry-adoptvacio": {
    title: "El adopt sobre un store VACÍO: qué hace de verdad la máquina (decisión, sin pantalla)",
    shot: null,
    sees: "Nada distinto: en pantalla es «Conectando con tu cuenta…» con su barra. Pero por dentro un adopt en un móvil recién instalado NO se parece al adopt para el que se escribió el flujo — no hay corpus que reconciliar.\n\nCinco pasos y un 5-bis, en el orden en que los numera el código: (1) quiescencia del import —trivialmente cierta, no hay mirror que importe—; (2) reconcile de huérfanas contra el backend: sin filas locales no sube NADA; (3) fast-forward del baseline del History sobre un store vacío; (4) belt del marcador de CloudKit: **no hay marcador y no puede haberlo**, así que deja un breadcrumb y sigue; (5) escritura del par `.cloud` + `mirrorOffArmed` y estampado del claim-store; (5-bis) re-emisión de las dos keys del consent al outbox de prefs, con el timestamp PERSISTIDO de la aceptación, jamás `now()`.",
    persists: "`cloudSync.storageMode = cloud` + `cloudSync.migration.relaunchRequested = true` (escritor único `writeCloudArmed`), el `CloudClaimActionStore` con `.routeReturningUser` para este `userID` —que es lo que repone la prueba de propiedad que la reinstalación había borrado— y el epoch del consent.",
    exits: "El journal queda en `notStarted` (device ADOPTADO). La pantalla siguiente la decide el testigo de mount, no la máquina (ver `reentry-relanzamientoR5`).",
    code: [
      { t: "MigrationWorkExecutor.swift:1141-1207 `runAdoptFlow`", d: "los cinco pasos y el 5-bis, en este orden. El código NO numera ningún paso 6" },
      { t: "MigrationWorkExecutor.swift:1164-1170", d: "el belt del marcador: `markerCount == 0` ⇒ breadcrumb `marker absent (belt)`, no bloquea" },
      { t: "MigrationWorkExecutor.swift:1179-1187", d: "`StorageModePersistence.writeCloudArmed` + `claimStore.record(.routeReturningUser, forUserID:)`, con su rama de ruido explícito si falta el `userID`" },
      { t: "MigrationWorkExecutor.swift:1189-1204", d: "el 5-bis literal: re-persistir las 2 keys de consent al outbox, reusando el timestamp guardado (`cloudConsentAcceptedAt`) y avisando por breadcrumb si tiene que caer al fallback `now()`" },
      { t: "CrossAccountEntryGuardLogic.swift:53", d: "`guard hasLocalData else { return .proceed }` — en un móvil recién instalado el primer término ya decide y el guard es un no-op" },
      { t: "WelcomeCloudSignInView.swift:734-746", d: "la rama `.proceed`: consent → flags de onboarding → `.adopting` → `startAdoptWithExistingSession` → poll" },
      { t: "CloudMigrationController.swift:354-370 `startAdoptWithExistingSession`", d: "conduce la máquina con la sesión ya viva (sin re-SIWA); `consent`/`authenticating` son fases no-durables" }
    ],
    notes: [
      "⚠︎ El comentario del paso 4 dice «la ruta ya validó el marcador al abrir la pantalla». MEDIDO: eso es cierto para la puerta de **Ajustes** (la card de adopt sale de `markerDecision() == .secondaryDeviceCloudLogin`, StorageSettingsView.swift:181) y **FALSO para la puerta del Welcome**, que llega aquí sin haber mirado ningún marcador. En un móvil recién instalado el marcador no existe —vive en el mirror de CloudKit y este proceso montó sin mirror— así que el breadcrumb «marker absent» es el caso NORMAL de R5, no una anomalía.",
      "El paso 2 es el que hace segura la puerta de Ajustes (sube lo que el corpus restaurado tenga y el backend no); en la puerta del Welcome no tiene nada que hacer. Es la diferencia real entre las dos puertas.",
      "Panel sin pantalla propia: el copy que cita («Conectando con tu cuenta…» = `welcome.cloud.adopting`, con su pie `welcome.cloud.adoptingHint`) es el de la pantalla de `reentry-adopt`, y su pin de l10n vive allí y en `reentry-errores`.",
      "Corrección aplicada: la versión anterior decía «los seis pasos» y numeraba hasta (6); el código numera 1-5 y **5-bis** (rótulo literal en :1189)."
    ]
  },

  "reentry-falsobloqueo": {
    title: "⚠︎ Volver atrás desde «Restaurar» y entrar por la cuenta: el bloqueo que acusa al dueño",
    shot: "reentry-falsobloqueo.png",
    sees: "«Este dispositivo tiene datos de otra cuenta» con el icono de candado con escudo, y debajo: «Para proteger esos datos, no podemos conectar una cuenta distinta aquí. Su dueño puede volver a entrar cuando quiera.»\n\nY los datos son SUYOS. La cadena que lleva ahí es corta y natural: reinstalo → «Ya tengo una cuenta» → «Restaurar desde iCloud» → la app pide reabrirse (el restore necesita el mirror) → al reabrir empieza a bajar la copia de iCloud → me arrepiento y toco «atrás» → vuelvo al chooser → «Entrar con Apple» → el guard mira el store, ve filas que ya importaron y no encuentra ningún claim que las reclame.",
    persists: "Nada, y esa es la parte buena: la sesión recién firmada se suelta antes de pintar la pantalla, y en esta rama el consent NO se registra en este device (la tabla dice `.never`).",
    exits: "Back permitido. La salida real es la otra puerta: con la copia de iCloud restaurada, el marcador del líder baja con ella y Ajustes → «Dónde viven tus datos» ofrece adoptar. Es un rodeo, no un callejón — pero nadie se lo dice al usuario en esta pantalla.",
    code: [
      { t: "CrossAccountEntryGuardLogic.swift:53-56 `decide`", d: "`hasLocalData` ∧ ¬`sameAccountClaimExists` ∧ ¬secundaria ⇒ `.blockedForeignData`" },
      { t: "CloudSyncFlags.swift:315-318 `secondarySessionEntryAvailable`", d: "el término de la secundaria = compilado ∧ backend ∧ runtime ∧ DOS flags remotos; el percent es 0 en producción y `absentDefault` es false fail-closed (CloudRemoteConfig.swift:120-126) ⇒ la salida secundaria está DARK y el guard cae en `.blockedForeignData`. El docblock (:312-314) lo dice con todas sus letras" },
      { t: "WelcomeCloudSignInView.swift:709-713", d: "`sameAccountClaimExists` sale de `CloudClaimActionStore.shared.action(forUserID:)`, que vive en `UserDefaults` y la reinstalación se llevó" },
      { t: "ContentView.swift:1086-1109 `checkHasExistingData`", d: "el fetch VIVO (cableado en :311 y pasado a la pantalla en :1557): cuenta `Account` no-sistema, `Category` no-sistema, `SplitGroup` y transacciones puenteadas — justo lo que un import de CloudKit materializa" },
      { t: "ContentView.swift:765-769 `returnToWelcomeChooser`", d: "el «atrás» del restore devuelve al chooser con el store ya montado CON mirror e importando" },
      { t: "WelcomeCloudSignInView.swift:715-720", d: "`signOut()` y fase `.blockedForeignData`, con el comentario que declara por qué el consent no se escribe aquí" },
      { t: "CrossAccountEntryGuardLogic.swift:19-21", d: "el docblock declara la premisa: «La MISMA cuenta re-entra libre: su claim persistido […] es la prueba de que el corpus local le pertenece» — premisa que una reinstalación invalida" }
    ],
    notes: [
      "⚠︎ HALLAZGO. La cadena está DERIVADA DEL CÓDIGO, no reproducida en sim ni en device. Requiere además que el usuario venga de MIGRAR (si nació en la nube, su CloudKit está vacío, el restore dice «No encontramos tus datos» y no importa nada ⇒ el guard pasa).",
      "⚠︎ Con la sesión secundaria ENCENDIDA (DEV/staging al 100 %) la MISMA cadena rutea a `.proceedSecondarySession` y el usuario ve la confirmación de sesión secundaria, no esta pantalla. Quien reproduzca esto en un build DEV verá otra cosa y creerá que el panel miente.",
      "La ventana depende del import: `hasLocalDataNow` es un fetch vivo precisamente porque el mirror puede estar re-importando durante el Welcome. Cuanto más tarde el usuario en volver atrás, más probable es el bloqueo.",
      "No es un bug del guard: es la degradación F0-C funcionando con una evidencia que la reinstalación borró. Lo que falta es que el copy contemple este caso o que exista otra prueba de propiedad que sobreviva a la reinstalación."
    ]
  },

  "reentry-attestmuerta": {
    title: "La llave de este móvil murió con la app anterior: hoy no se ve, y se cura sola (decisión, sin pantalla)",
    shot: null,
    sees: "**NADA.** Y esa es la respuesta a la pregunta, medida en el árbol de hoy.\n\nAl reinstalar, la key de App Attest —que vive en el Secure Enclave atada a la instalación— desaparece mientras su `keyId` sigue en el Keychain. El primer intento de firmar un request falla LOCALMENTE con `DCErrorInvalidInput`. Desde el fix del 2026-07-31, `AttestKeyRecoveryLogic` reconoce ese error, borra los dos slots del Keychain y re-registra en el mismo intento: el usuario no ve nada porque no hay nada que ver — funciona.\n\nLas dos únicas superficies son el canario `attestKeyDiscardedAfterAssertFailure` (FUERA de `#if DEBUG` a propósito) y el botón «refresh attest» del panel de nube en builds DEV.",
    persists: "Se BORRAN `appattest.keyId` y `appattest.pendingKeyId` del Keychain, y el registro nuevo escribe un keyId fresco. No se toca nada más.",
    exits: "Si el re-registro también falla (sin red, gateway caído), el fallo vuelve a ser invisible: `AttestSessionProvider.live` lo convierte en `nil` con un `try?` deliberado y el request sale sin cabecera. En R5 eso muerde en el ADOPT —`/sync/pull` y `/sync/push` sí exigen attest— y el usuario ve exactamente lo mismo que si no tuviera red: la pantalla «Conectando con tu cuenta…» aparcada, el auto-resume y el botón Reintentar.",
    code: [
      { t: "AttestKeyRecoveryLogic.swift:46-67 `decide`", d: "UN solo punto de decisión para las dos procedencias; el descarte va ACOTADO a `.invalidInput` y `.invalidKey` (`serverUnavailable` propaga: quemar keys es peor que perder un refresh)" },
      { t: "AppAttestClient.swift:120-155 `performRefresh`", d: "el cuerpo entero: lectura del keyId con `!isEmpty` (:127) → assert (:129) → `catch` (:130) → `AttestKeyRecoveryLogic.decide` (:135) → borrado de los DOS slots (:139/:143) → canario (:147) → `runRegister` en el mismo intento (:150)" },
      { t: "AppAttestClient.swift:147-149", d: "`MetricsService.canary(.attestKeyDiscardedAfterAssertFailure, detail:)` con el código de error, sin PII" },
      { t: "MetricsService.swift:85-87", d: "lo que el canario significa en el dashboard: «un pico tras un release = usuarios reinstalando (esperado, se auto-cura)»" },
      { t: "AttestSessionProvider.swift:38-55 `live`", d: "el `try?` deliberado: `nil` degrada a request sin cabecera, que bajo `enforce` es 401 y bajo `observe` pasa" },
      { t: "CloudMigrationController.swift:229-233", d: "el adopt SÍ depende de attest: `push`/`pull`/`merkle` reciben el proveedor (el claim y `migration` no, van por `requireUser` — el comentario de :223-226 lo declara)" },
      { t: "AppAttestClient.swift:20-32", d: "por qué no hay calentador al launch, y por qué proponer uno exige una medición" }
    ],
    notes: [
      "Antes del fix esto NO se curaba nunca: cada intento releía el mismo keyId muerto y el device quedaba sin Grupos, sin IA y sin proxy de tipos de cambio para siempre. Hoy la reinstalación es el caso ESPERADO del canario.",
      "⚠︎ Lo que sigue sin superficie es el SEGUNDO fallo: si el re-registro no puede completarse, nada en la interfaz nombra a App Attest. En el adopt es indistinguible de «sin red», y en producción no hay logs (`#if DEBUG`).",
      "Un build de Xcode no puede validar nada de esto contra producción: el AAGUID de desarrollo da 401 SIEMPRE (`.claude/rules/gateway-attest.md`).",
      "Panel sin pantalla propia: «Conectando con tu cuenta…» es `welcome.cloud.adopting`, pinneado en `reentry-adopt` y `reentry-errores`.",
      "Corrección aplicada: la coordenada de `performRefresh` iba a `:127-154`, que empieza en la lectura del keyId; el método se declara en :120."
    ]
  },

  "reentry-errores": {
    title: "Los errores de la re-entrada, en una tabla — y el 403 que no se distingue de quedarse sin red",
    shot: "reentry-errores.png",
    sees: "Una sola pantalla para casi todo: el icono de wifi con exclamación, «Algo no salió bien», «No pudimos verificar tu cuenta. Revisa tu conexión e inténtalo de nuevo.» y el botón «Reintentar» cuando el fallo se considera reintentable.\n\nLo que hay detrás, por punto del recorrido:\n· **Sin red en `exists`** → `transient` → esa pantalla, con Reintentar.\n· **401 en `exists`** → `sessionExpired` → **la misma pantalla, con Reintentar, y la sesión NO se suelta**.\n· **403 en `exists`** → cae en el `default` del cliente ⇒ `transient` ⇒ Reintentar (hoy sin usuarios que lo alcancen; ver la nota).\n· **Cualquier fallo del claim DENTRO del adopt** (401, 403, sin red) → la máquina para SIN emitir evento: la pantalla se queda en «Conectando con tu cuenta…» con «Esto puede tardar unos minutos. Mantén Yala abierta.», entran los auto-resumes y luego el botón manual.\n· **`claiming_in_progress`** → la pantalla de espera «Tu cuenta se está preparando en otro dispositivo», con «Reintentar» y «Continuar a la app».\n· **Kill-switch** → no hay error: las cards de nube sencillamente no existen.",
    persists: "Nada en ninguna de las ramas. El journal es durable y todo paso es idempotente.",
    exits: "«Reintentar» re-ejecuta `runFlowAfterConsent()`: el consent ya está aceptado, el sign-in se salta si hay sesión y se repite `exists`. En la pantalla de espera, el Reintentar de la RE-ENTRADA sondea al líder (`retryLeaderPoll` → `pollLeader`), no re-claima — al revés que en el alta.",
    code: [
      { t: "WelcomeCloudSignInView.swift:262-267", d: "la fase `.error`: icono `wifi.exclamationmark`, título `errorTitle`, cuerpo `errorBody`, y el botón Reintentar solo si `retryable` (:268-273)" },
      { t: "CloudAccountClient.swift:250-260 `exists`", d: "200 → `exists`; 401 → `sessionExpired`; **todo lo demás, 403 incluido → `transient`** (:258-259)" },
      { t: "CloudAccountClient.swift:31", d: "el docblock del caso `accountUnavailable`: el 403 es DEFENSIVO — «`/account/*` no lo emite hoy». Es lo que degrada el hallazgo del 403 a divergencia estructural" },
      { t: "CloudWelcomeSignInFlow.swift:80-87 `route`", d: "`sessionExpired` y `transient` COLAPSAN a `.failed(retryable: true)`: la pantalla no puede distinguirlos" },
      { t: "WelcomeCloudSignInView.swift:706-707", d: "la rama `.failed` pinta el error **sin `signOut()`** — asimetría deliberada con el alta" },
      { t: "CloudWelcomeSignInFlow.swift:140-143", d: "el alta SÍ suelta la sesión en el 401 (`releaseSessionAndShowError`), y su docblock explica el porqué: si no, el retry la reusaría muerta" },
      { t: "MigrationRunner.swift:526 `driveClaim`", d: "su `switch` sobre `executor.performClaim()` (:533-546): `sessionExpired` / `accountUnavailable` / `transient` → los TRES `return false` sin evento, cada uno con su breadcrumb (:538, :541, :544)" },
      { t: "CloudWelcomeSignInFlow.swift:92-112 `phase(for:)`", d: "`.failed` de la máquina → `.error(retryable: true)`; `.waitingForLeader` → pantalla de espera; `reverting`/`needsRelaunch(.toICloud)` son imposibles aquí y degradan a error no reintentable" },
      { t: "WelcomeCloudSignInView.swift:462-470", d: "la bifurcación del Reintentar de la espera: re-entrada → `retryLeaderPoll()` (:872-876, que llama a `pollLeader`); alta → re-claim" }
    ],
    notes: [
      "⚠︎ Asimetría de mapeo, hoy NO observable: `CloudAccountClient.swift:31` declara el 403 defensivo —`/account/*` no lo emite—, así que ningún usuario actual ejercita esta rama. Si el gateway empezara a emitirlo, el claim lo trataría como `accountUnavailable` (:225-226) y `exists` como `transient` (:258-259): un Reintentar que no puede funcionar en la re-entrada, mientras el alta born-cloud, correctamente, no lo ofrece. La única señal sería el breadcrumb `migrationAccountUnavailable`.",
      "⚠︎ El 401 de `exists` no suelta la sesión, al contrario que su gemelo del alta. La recuperación existe pero cuesta una vuelta de más: el SDK limpia el storage cuando el refresh falla terminal, así que el SEGUNDO Reintentar sí vuelve a pedir el sign-in.",
      "«Sin red durante el claim» y «403 durante el claim» son, dentro del adopt, literalmente la misma pantalla.",
      "⚠︎ TRAMPA DEL SIMULADOR, medida: esta pantalla no se puede alcanzar en el sim. El único seam que finge sesión (`UITestHooks.fakeCloudSession`) pasa por `hasArg`, que exige `-uitest` (UITestHooks.swift:274-280); y bajo `-uitest` las dos cards de nube desaparecen (`WelcomeAccountChoiceLogic.visibleExistingOptions` pide `!isUITest`, :60-70) y el faro deja de encaminar porque `cloudEntryAvailable` se deriva de ellas. Los dos seams son mutuamente excluyentes por construcción.",
      "Corrección aplicada: el icono era `wifi.exclamationmark`, no el de wifi tachado; y la coordenada :533-546 es el `switch` de `driveClaim` (declarado en :526), no de `performClaim`, que es el método del executor."
    ]
  },

  "reentry-killmidadopt": {
    title: "Maté la app a mitad del adopt: al volver aterrizo en la app, no en el Welcome",
    shot: "reentry-killmidadopt.png",
    sees: "La app normal, con sus tabs y sin datos todavía. **No vuelve el Welcome**, y es a propósito: los flags de onboarding se marcan TEMPRANO, antes de conducir la máquina.\n\nLo que retoma el trabajo no se ve: al arrancar, el coordinador lee el journal y decide retomar (fase transicional o efectos pendientes) o sondear al líder. Si el usuario entra en Ajustes → «Dónde viven tus datos», la card refleja el estado REAL del adopt, no una ficción.",
    persists: "Lo que hubiera escrito la máquina hasta el kill; el journal es durable y cada efecto es idempotente. `hasCompletedOnboarding` ya estaba puesto desde antes del primer paso.",
    exits: "Además del resume del arranque, cada vuelta a primer plano re-kickea si la máquina quedó aparcada, y la propia pantalla de Almacenamiento lo intenta cada 30 ticks del poll de 1 s.",
    code: [
      { t: "WelcomeCloudSignInView.swift:738-740", d: "el orden: consent → `onAdoptStarted()` → `.adopting`; los flags se marcan ANTES de conducir nada" },
      { t: "ContentView.swift:1558-1565 `onAdoptStarted`", d: "`completeOnboardingAsRestoreSkip()` + `hasCompletedOnboarding = true` — cierra el hazard de sembrar el onboarding sobre una cuenta existente" },
      { t: "WelcomeCloudSignInView.swift:38-42", d: "el docblock que declara el porqué del orden: un kill a mitad aterriza en MainTab con la card de Almacenamiento reflejando el estado real, y el seed del onboarding JAMÁS corre sobre una cuenta existente" },
      { t: "AppBootstrapper.swift:305-308", d: "paso 14.6: `CloudMigrationController.configureShared` + `resumeIfNeeded()`, ANTES de arrancar el runtime" },
      { t: "MigrationBootDecision.swift:123-136 `decide`", d: "efectos pendientes ⇒ resume aunque la fase sea estable; `waitingForLeader` ⇒ sondear; terminales de fallo NO auto-resumen" },
      { t: "MigrationBootDecision.swift:150-153 `MigrationForegroundRekick`", d: "el re-kick de foreground reusa el mismo contrato del boot" },
      { t: "StorageSettingsView.swift:93", d: "el watchdog de la pantalla: `if tick % 30 == 0 { await controller?.rekickIfParked() }` — un empujón cada 30 s para quien se queda mirando la barra" },
      { t: "CloudMigrationController.swift:549-557 `startRuntimeIfStable`", d: "cuando el resume deja la fase estable, el runtime arranca desde aquí (sus tres call-sites son :450 `resume`, :475 `pollLeader` y :494 `resumeIfNeeded`)" }
    ],
    notes: [
      "Es la razón por la que los flags se marcan temprano y no al terminar: un kill a mitad deja al usuario dentro de la app con una card honesta, en vez de en un onboarding que sembraría categorías sobre una cuenta que ya tiene las suyas.",
      "No MEDÍ el caso de matar la app entre aceptar el consent y el veredicto del guard: ahí el pendiente vive en `@State` y muere con la vista (ver `reentry-consentwrite`, que ya lo declara como inferido)."
    ]
  },

  "reentry-relanzamientoR5": {
    title: "⚠︎ Por qué la re-entrada SÍ paga el relanzamiento que el alta ya no paga (decisión, sin pantalla)",
    shot: null,
    sees: "Nada; decide qué pantalla cierra el adopt. Y el resultado sorprende: en un móvil recién instalado el store montado YA es el que el modo nube pide (`cloudKitDatabase: .none`), igual que en el alta born-cloud… y aun así la re-entrada termina en «Ya casi está — reinicia Yala».\n\nEl camino exacto: `runAdoptFlow` escribe el par; el testigo de mount dice que este proceso NO lleva mirror adjunto, así que la regla del relanzamiento no dispara; con la fase en `notStarted` y el modo `.cloud`, el estado derivado es `cloudActive`; y el mapa de la pantalla del Welcome traduce `cloudActive` a la MISMA terminal de relanzamiento.",
    persists: "El par `.cloud` + `mirrorOffArmed` y el claim estampado (los escribió el paso 5 del adopt). El journal queda `notStarted`.",
    exits: "Terminal, sin back y sin auto-kill. El usuario cierra la app y la reabre.",
    code: [
      { t: "MigrationWorkExecutor.swift:1128-1136", d: "el docblock del adopt declara el reparto: «El relaunch asistido NO se hace aquí: la UI lo deriva del par persistido»" },
      { t: "CloudMigrationController.swift:77-83 `derive`", d: "regla 1: `mirrorOffArmed && mirrorStillAttached` ⇒ `needsRelaunch(.toCloud)`. En un móvil recién instalado `mirrorStillAttached` es FALSE ⇒ la regla NO dispara" },
      { t: "CloudMigrationController.swift:110-112", d: "`notStarted` + `.cloud` ⇒ `.cloudActive` (device ADOPTADO estable)" },
      { t: "CloudWelcomeSignInFlow.swift:99-103", d: "`needsRelaunch(.toCloud)` **y** `cloudActive` mapean los DOS a `.relaunch`, con el comentario «El relaunch ya se resolvió en otro proceso — terminal equivalente»" },
      { t: "BornCloudSignUpService.swift:178-183", d: "lo que el ALTA sí tiene y el adopt no: EL call-site de producción del arranque del motor EN SESIÓN (`CloudSyncRuntime.startShared`) tras escribir el par" },
      { t: "CloudMigrationController.swift:354-370", d: "`startAdoptWithExistingSession` NO llama a `startRuntimeIfStable()` — sus tres call-sites son :450 `resume`, :475 `pollLeader` y :494 `resumeIfNeeded`" },
      { t: "WelcomeMirrorRelaunchLogic.swift:10-16", d: "la regla madre de R2: «El relanzamiento sobrevive si y solo si hay que ENCENDER el mirror de CloudKit» — que aquí no se cumple y el relanzamiento sigue" }
    ],
    notes: [
      "⚠︎ HALLAZGO doble. (1) **El relanzamiento cero llegó al ALTA y no a la RE-ENTRADA**: con el mismo mount neutro, el alta termina en «¡Tu cuenta está lista!» sin reabrir nada y el adopt pide reabrir. (2) **La razón real no es el store, es el MOTOR**: el par ya coincide con el mount, pero nadie arranca el runtime en esta sesión, así que sin el relanzamiento nada subiría ni bajaría — la pantalla es honesta en el efecto aunque su etiqueta interna diga otra cosa. Cerrar el hueco pide exactamente lo que el alta ya tiene: un `startShared` tras escribir el par.",
      "⚠︎ El comentario de `CloudWelcomeSignInFlow.swift:101-102` («el relaunch ya se resolvió en otro proceso») describe MAL este caso: en un móvil recién instalado ningún proceso resolvió nada, simplemente nunca hizo falta remontar. Es la clase de comentario que hace perder una vuelta de diagnóstico.",
      "MEDIDO leyendo las tablas y los call-sites; no reproducido en device.",
      "Panel sin pantalla propia: «Ya casi está — reinicia Yala» es `storage.relaunch.title` (pinneada en `reentry-relaunch`), y «¡Tu cuenta está lista!» del alta es `welcome.bornCloud.readyTitle` = \"¡Tu cuenta está lista!\"."
    ]
  },

  "reentry-nuevainstalacion": {
    title: "Volver cuenta como instalación nueva: checklist de cero y oferta de prueba",
    shot: "reentry-nuevainstalacion.png",
    sees: "Tras reabrir la app, el usuario que acaba de recuperar su cuenta de años se encuentra tratado como recién llegado: en el Panel aparece la card «Primeros pasos» con su contador «%d de %d completados» arrancando de cero y, si no es Pro, el router le presenta la hoja «Prueba Yala Pro gratis · 30 días con todas las funciones. Sin compromiso, cancela cuando quieras.»\n\nNo es un descuido suelto: sale del mismo helper que marca el onboarding como completado para saltárselo.",
    persists: "`hasCompletedOnboarding = true`, `needsPostOnboardingTrial = true` (persistida en `UserDefaults`, sobrevive al kill) y `setup.isNewInstall = true` en `SetupChecklistManager`.",
    exits: "La oferta de prueba se encola en el router y se presenta tras el bootstrap; el flag se limpia en la presentación real, no en los productores. En modo invitación de grupo no se presenta nada.",
    code: [
      { t: "ContentView.swift:1918-1924 `completeOnboardingAsRestoreSkip`", d: "los tres efectos juntos: trial pendiente si no es Pro, `hasCompletedOnboarding` y `markAsNewInstall()`" },
      { t: "ContentView.swift:709-713", d: "el OTRO call-site de los mismos tres efectos: el final del onboarding normal. Es lo que hace que el estado de pantalla sea idéntico al de un usuario recién llegado" },
      { t: "SessionState.swift:515-516", d: "`needsPostOnboardingTrial` se persiste en `UserDefaults` en su `didSet`: sobrevive a un kill durante la animación de dismiss" },
      { t: "ContentView.swift:1288-1300 `runReturningUserPostChecks`", d: "`RouterEntryGate.shared.submit(.presentTrialOffer)` tras esperar al bootstrap, y solo si no es modo invitación de grupo" },
      { t: "ContentView.swift:898-903", d: "el drain: `showProTrialOffer = true` y la limpieza del flag en la presentación REAL (el sheet es `ProTrialOfferSheet`, montado en :388-393)" },
      { t: "SetupChecklistManager.swift:151-153 `markAsNewInstall`", d: "lo único que hace es poner el flag `setup.isNewInstall`; el auto-detect por datos existentes es otra función" },
      { t: "SetupChecklistManager.swift:92-103 · :107-110", d: "por qué eso basta para que la card salga: `shouldShow` es true salvo para `isExistingUser`, que se define como «no tiene `setup.isNewInstall`»" },
      { t: "SetupChecklistCard.swift:28-29 · :74-78", d: "el gate de la card (`if manager.shouldShow`) y su cabecera: título `setup.title` + progreso `setup.progress`" }
    ],
    notes: [
      "⚠︎ El helper se llama «restore-skip» y lo comparte con el camino de restaurar de iCloud, donde «instalación nueva» describe mejor la situación. En R5 el efecto es que la app pide configurar cosas que el usuario ya tiene y que están BAJANDO en ese mismo momento (ver `reentry-vacio`).",
      "`SetupChecklistManager.autoDetect(...)` existe y corrige el checklist contando transacciones, presupuestos y pagos programados; no MEDÍ si corre después del primer pull ni con qué disparador, así que no afirmo que se auto-cure.",
      "La captura es fiel aunque se produzca por el camino corto: MEDIDO que el final del onboarding normal (ContentView.swift:709-713) escribe los MISMOS tres efectos que el helper del adopt (:1918-1924), así que el estado de pantalla es el mismo."
    ]
  },

  "reentry-vacio": {
    title: "⚠︎ Post-relanzamiento: la app aparece VACÍA mientras baja tu cuenta, y nadie lo dice",
    shot: "reentry-vacio.png",
    sees: "La app abre en su pantalla principal **con cero datos**: sin cuentas, sin movimientos, con los empty states de siempre. Y encima —si no eres Pro— la hoja «Prueba Yala Pro gratis».\n\nNada explica que la cuenta está bajando. El store personal nace vacío (el móvil es nuevo o la reinstalación se lo llevó) y el runtime lo puebla con el pull normal desde el cursor 0, que tarda lo que tarde según el corpus y la red.\n\nEl detalle que lo convierte en hallazgo: **ese banner existe, y solo se le enseña a otra persona.** «Descargando tus datos…» está implementado, con su spinner, para la sesión SECUNDARIA —la invitada en el móvil de otra persona—, cuyo store también nace vacío por la misma razón. Su gate exige descriptor secundario activo, así que el dueño que vuelve a su cuenta en un móvil nuevo nunca lo ve.",
    persists: "Lo que el pull vaya aplicando. La app no bloquea nada mientras tanto: la espera del primer pull solo gatea los guardados automáticos del arranque, no la interfaz.",
    exits: "Se resuelve solo cuando el pull completa. La única superficie que da señal es Ajustes → «Dónde viven tus datos», si al usuario se le ocurre entrar.",
    code: [
      { t: "SecondaryHydrationBanner.swift:5-8", d: "el docblock dice el problema con todas sus letras: «el store secundario nace VACÍO […] la invitada vería una app \"en cero\" sin explicación»" },
      { t: "SecondaryHydrationBanner.swift:17-21 `SecondaryHydrationLogic.showBanner`", d: "`secondaryActive && !firstPullCompleted` — el primer término es el que deja fuera al dueño" },
      { t: "SecondaryHydrationBanner.swift:10-11 · :43-53", d: "el docblock declara el porqué («Costo cero para el dueño: sin descriptor, el task sale en el primer chequeo.», :11) y el rango, el mecanismo: el poll de 1 s. El texto es `welcome.cloud.secondaryHydrationBanner` (:32)" },
      { t: "ContentView.swift:2187", d: "dónde se monta: `.overlay(alignment: .top) { SecondaryHydrationBanner() }` — la posición donde cabría el banner del dueño sin inventar nada" },
      { t: "SyncQuiescenceCoordinator.swift:55 · :106", d: "`hasCompletedFirstPull` es GENÉRICO, no secundario (lo escribe `markFirstPullCompleted`): la señal para el banner del dueño ya existe" },
      { t: "AppBootstrapper.swift:1152-1176 `awaitPersonalStoreReady`", d: "en `.cloud` espera primer pull + apply quieto con tope de 120 s, pero solo para los boot-saves — no retiene la UI" },
      { t: "SyncStatusBanner.swift:27-45", d: "el otro banner de la app NO cubre esto: su `Style.make` solo devuelve estilo para `.failed`/`.stalled` del sync de **iCloud**, y ese `nil` ES el gate de visibilidad" },
      { t: "ContentView.swift:1288-1300", d: "y encima llega la oferta de prueba, encolada en el mismo arranque" }
    ],
    notes: [
      "⚠︎ HALLAZGO: asimetría medida entre la sesión secundaria (tiene banner) y la re-entrada primaria (no lo tiene), con el agravante de que la señal que el banner necesita (`hasCompletedFirstPull`) no es específica de la secundaria y ya está disponible.",
      "No MEDÍ cuánto dura la ventana (depende del tamaño de la cuenta y de la red). Lo medido es que ninguna superficie la nombra.",
      "Es el momento más frágil del recorrido: quien vuelve a su cuenta de años ve una app vacía y una oferta de suscripción. Un usuario que concluya «se perdieron mis datos» y toque «empezar de cero» estaría a un tap de un daño real.",
      "El copy del banner se cita a propósito aunque hoy nadie pueda verlo: en producción la entrada secundaria está DARK (percent 0 + `absentDefault` false) y los ÚNICOS dos escritores del descriptor son `WelcomeCloudSignInView.swift:778` —tras `.proceedSecondarySession`, que exige el flag— y `CloudSyncDebugView.swift:1004`, que es solo DEV."
    ]
  },

  "reentry-puertaequivocada": {
    title: "Elegí «Restaurar desde iCloud»: qué pasa según cómo naciera mi cuenta",
    shot: "reentry-puertaequivocada.png",
    sees: "La card dice «Restaurar desde iCloud — Tus datos guardados con tu iCloud vuelven a este dispositivo». Es la opción que suena bien, y para una cuenta de la nube significa cosas distintas:\n\n· **Nací en la nube (born-cloud).** Mi corpus nunca estuvo en CloudKit —el mirror lleva apagado desde el primer día—, así que la búsqueda termina sin encontrar nada: «No encontramos tus datos · No hay datos asociados a tu cuenta de iCloud. ¿Quieres empezar desde cero?», con el botón «Empezar desde cero» debajo. La única salida buena es volver y entrar por la cuenta.\n\n· **Migré a la nube desde iCloud.** CloudKit conserva la copia CONGELADA de antes de la migración, así que el restore sí encuentra datos… los de aquel día. Con ellos baja el marcador que el líder dejó, y a partir de ahí Ajustes → «Dónde viven tus datos» cambia su copy a «Activar la nube en este dispositivo» y ofrece adoptar de verdad.\n\n· **Y una tercera, que el Atlas no tenía**: si mi último acto en este Apple ID fue BORRAR mis datos, la pantalla ni siquiera busca — sale directa «Borraste tus datos · Eliminaste tus datos en este dispositivo. Empieza de nuevo cuando quieras.»",
    persists: "El restore escribe el corpus importado. Antes de todo eso, el paso por el portal del Welcome persiste el destino elegido y `hasShownWelcomeChooser = true`, porque este camino sí exige reabrir la app (necesita el mirror).",
    exits: "Desde «No encontramos tus datos» y desde «Borraste tus datos» solo hay «Empezar desde cero» y el back de la barra. Desde la copia restaurada se sale por Ajustes, adoptando.",
    code: [
      { t: "WelcomeMirrorRelaunchLogic.swift:78-85 `requiresMirror`", d: "`restoreICloud` es `true`; las dos filas del Modo Nube (`cloudAccount`, `cloudSignIn`) son `false`" },
      { t: "WelcomeMirrorRelaunchLogic.swift:61-64", d: "el porqué, y por qué no admite matices: sin mirror `RestoreProgressView` agota su timeout de 90 s y le dice al usuario que su cuenta está vacía" },
      { t: "WelcomeRestoreView.swift:113-127 `startSearch`", d: "el orden real de las salidas: sin cuenta de iCloud ⇒ `.iCloudDisabled`; último acto = wipe ⇒ `.wiped`; si no, `.searching`" },
      { t: "RestoreOfferGate.swift:42-44 `wasWiped`", d: "`lastWipe > 0 && lastWipe >= lastOnboarding` — y sus dos entradas viajan por el iKV del mismo Apple ID (PreferenceSyncService.swift:106-111, «Sobrevive al uninstall»), así que esta rama SÍ es alcanzable en un móvil nuevo" },
      { t: "WelcomeRestoreView.swift:53-57", d: "`summary.hasAnyData ? .found(summary) : .notFound` — el veredicto sale de contar filas tras la quiescencia del import" },
      { t: "WelcomeRestoreView.swift:276-286 `notFoundView`", d: "la pantalla y su CTA «Empezar desde cero» (la gemela `wipedView` está en :314-324, con el mismo CTA)" },
      { t: "MigrationStateMachine.swift:701-726 `markerReconciliation`", d: "marcador presente + sin traza de cutover propio ⇒ `.secondaryDeviceCloudLogin`, que es lo que enciende el copy de ADOPTAR" },
      { t: "StorageSettingsView.swift:181-189", d: "el copy de la card conmuta por esa decisión: `isAdopt` elige entre `Storage.Adopt.*` y `Storage.Migrate.*`" },
      { t: "MigrationWorkExecutor.swift:1150-1158", d: "lo que hace segura esta puerta: el reconcile de huérfanas sube al backend lo que la copia restaurada tenga y el servidor no" }
    ],
    notes: [
      "⚠︎ «CloudKit congelado» es el término del propio código para la copia post-cutover, y sus residuales están declarados: un borrado hecho después del cutover se re-materializa al adoptar (resurrección benigna).",
      "No verifiqué en device ninguna de las tres ramas; la cadena está medida en el código.",
      "Para el usuario born-cloud esta card es un rodeo caro: un relanzamiento, una espera y una pantalla que dice que no tiene datos. La pantalla no le sugiere la otra card.",
      "La tercera rama (`.wiped`) cierra un hueco que la pasada anterior había dejado abierto («no comprobé si `RestoreOfferGate.wasWiped` puede disparar en un móvil nuevo»). MEDIDO que sí: se decide ANTES de `.searching` y sus dos timestamps se leen del iKV."
    ]
  },

  "reentry-killswitch": {
    title: "⚠︎ Con el kill-switch puesto, quien reinstala se queda fuera: las DOS puertas se cierran",
    shot: "reentry-killswitch.png",
    sees: "Un chooser que parece normal y no lo es. «Ya tengo una cuenta» ya no ofrece tres opciones sino una —«Restaurar desde iCloud»— y con una sola opción visible ni siquiera se muestra la pantalla intermedia: se va directo al restore. Si el usuario nació en la nube, el final es «No encontramos tus datos · No hay datos asociados a tu cuenta de iCloud. ¿Quieres empezar desde cero?».\n\nY la segunda puerta tampoco está: la fila «Dónde viven tus datos» de Ajustes exige o el flag remoto encendido o un usuario «engaged», y una reinstalación no puede ser engaged —el modo persistido volvió a `.icloud` y el journal se fue con el store—. Sin fila no hay card de adopción.\n\nAdemás el faro deja de encaminar, porque su disponibilidad se DERIVA de la misma card que acaba de desaparecer.",
    persists: "Nada. El snapshot de remote-config se refresca como mucho cada 6 h y, ausente, vale `false` en producción (fail-closed).",
    exits: "No hay salida por producto: se re-entra cuando el flag se vuelve a encender. Es un residual RATIFICADO, escrito en el código.",
    code: [
      { t: "WelcomeAccountChoiceLogic.swift:60-70 `visibleExistingOptions`", d: "las dos cards de nube exigen `remoteCloudEnabled` (y `!isUITest`); queda solo `restoreICloud`" },
      { t: "WelcomeAccountChoiceLogic.swift:57-59", d: "el residual, escrito por su autor: «un usuario nube que REINSTALA bajo el kill no ve la card → no re-entra hasta re-encendido»" },
      { t: "WelcomeFlowContainer.swift:245-251 `handleExistingBranch`", d: "con una sola opción visible hace BYPASS (`WelcomeAccountChoiceLogic.bypass`, :73-75): el usuario ni ve que había más caminos" },
      { t: "WelcomeFlowContainer.swift:127-129 `cloudEntryAvailable`", d: "el faro se apaga con la card, porque su disponibilidad se deriva de `visibleExistingOptions`" },
      { t: "StorageRowGateLogic.swift:50-62 `isVisible`", d: "`remoteEnabled || isEngaged` — la segunda puerta" },
      { t: "ProfileView.swift:939-945", d: "`isEngaged` = modo persistido `.cloud` ∨ `uiState != .idle`: una reinstalación no cumple ninguna de las dos" },
      { t: "WelcomeFlowContainer.swift:199-205", d: "la entrada del Welcome fuerza `refreshIfDue()` (salvo bajo uitest), así que el snapshot es lo más fresco que se puede tener" },
      { t: "CloudRemoteConfig.swift:182-196 `decide`", d: "el orden que importa para reproducirlo: tests/uitest cortan a `absentDefault` (:186) ANTES de leer la key DEBUG (:188), y solo después se consulta el snapshot" }
    ],
    notes: [
      "⚠︎ El residual documentado dice «no ve la card». MEDIDO, la consecuencia completa es mayor: **se cierran las dos puertas** —la del Welcome y la de Ajustes— porque el gate de la fila pide una prueba de compromiso que la reinstalación borró. El panel general del kill-switch no lo dice.",
      "El caso peor es el born-cloud reinstalando: la única card que le queda le dice que no tiene datos, y sus datos existen y están intactos en el backend.",
      "⚠︎ Trampa al reproducirlo: bajo `-uitest` el kill-switch DEBUG ni se lee (`CloudRemoteConfig.swift:186` corta a `absentDefault`, que en `Yala Dev` es `true` ⇒ todo ENCENDIDO). La receta que sí funciona es `simctl spawn <udid> defaults write … cloudSync.debug.remoteFlagsForceOff -bool YES` y relanzar SIN args de uitest — la misma con la que `data/f2.js:193` declara haber fabricado `img/alta-groupsgate-blocked.png` el 2026-08-12. (`img/degradado-killswitch.png` es de un lote anterior y su receta es OTRA: el toggle del panel DEBUG in-app, `data/f2.js:214`.)"
    ]
  }
};
