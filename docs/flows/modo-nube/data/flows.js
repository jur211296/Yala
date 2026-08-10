// flows.js — los DIAGRAMAS del Atlas y su auto-auditoría de cobertura.
//
// Cada `graph` es Mermaid. Cada línea `click <id> call showNode("<screenshot-id>")` conecta un nodo del
// diagrama con su panel en `nodes.js`. Los ids del diagrama son cortos (Mermaid) y el id de screenshot es
// el estable (`<flujo>-<nodo>`), que es el que F2 usa para poblar `img/`.
//
// Medido el 2026-08-09 contra HEAD 9d6f0f1c (branch 2.0.5).

window.ATLAS_FLOWS = [
  {
    id: "alta",
    title: "1 · Alta born-cloud (A4 → A5)",
    lede: "«Soy nuevo» → chooser (con bypass y faro) → consent → sign-in → las cuatro salidas del claim → par + relanzamiento → post-relanzamiento. Incluye la matriz de cancelación de tres filas y el encaminamiento del 2º device por faro.",
    graph: `flowchart TD
  H["Welcome · Hero"] --> C["Chooser · 3 ramas"]
  C -->|Ya tengo cuenta| RE(["→ Flujo 2 · re-entrada"])
  C -->|Me invitaron a un grupo| INV(["Invite recovery<br/>fuera del alcance de F1"])
  C -->|Soy nuevo| F{"¿El faro dice que este Apple ID<br/>ya tiene cuenta nube?"}
  F -->|"vinculado ∧ entrada nube disponible"| RE
  F -->|"1 sola opción visible ⇒ bypass"| PRIV
  F -->|"≥2 opciones"| NC["Sub-chooser «Soy nuevo»"]
  NC -->|privacidad total| PRIV["Onboarding privado<br/>(limpia residuales)"]
  NC -->|cuenta en la nube| CON["Consentimiento · path .bornCloud"]
  PRIV -->|hay datos locales| WIPE["Alert de borrado<br/>del fresh start"]
  CON --> INT["Intro del alta<br/>Apple | Google"]
  INT --> SI{"Sign-in"}
  SI -->|cancel · fallo Apple| INT
  SI -->|fallo real de Google| ETR
  SI -->|"ok (o sesión ya viva)"| CR["«Creando tu cuenta…»"]
  CR --> CL{"POST /account/claim<br/>+ AccountClaimDecision"}
  CL -->|created| PAR["Par .cloud + mirrorOffArmed<br/>«Cierra y vuelve a abrir Yala»"]
  CL -->|existing_stable| RU["Continuar como returning-user"]
  CL -->|claiming_in_progress| WL["Esperar al líder"]
  CL -->|401| E401["Soltar sesión + error"]
  CL -->|403| E403["Cuenta no disponible<br/>sin reintentar"]
  CL -->|red · 5xx| ETR["Error transitorio<br/>con Reintentar"]
  CL -.->|"variante B · INALCANZABLE hoy"| MM(["Método equivocado"])
  RU --> RE
  PAR --> POST["Post-relanzamiento<br/>onboarding normal en modo nube"]
  ETR --> CR
  WL -->|Reintentar = re-claim| CR
  CANCEL{{"Matriz de cancelación · 3 filas"}}

  click H call showNode("alta-hero")
  click C call showNode("alta-chooser")
  click F call showNode("alta-faro")
  click NC call showNode("alta-newchooser")
  click PRIV call showNode("alta-privado")
  click WIPE call showNode("alta-privado")
  click CON call showNode("alta-consent")
  click INT call showNode("alta-intro")
  click SI call showNode("alta-signin")
  click CR call showNode("alta-creating")
  click CL call showNode("alta-claim")
  click PAR call showNode("alta-par-relaunch")
  click POST call showNode("alta-postrelaunch")
  click RU call showNode("alta-returning")
  click WL call showNode("alta-waitingleader")
  click E401 call showNode("alta-error-401")
  click E403 call showNode("alta-error-403")
  click ETR call showNode("alta-error-transient")
  click MM call showNode("alta-claim")
  click CANCEL call showNode("alta-cancel")

  classDef unreachable stroke-dasharray: 5 5,opacity:0.65
  class MM,INV unreachable`
  },

  {
    id: "reentry",
    title: "2 · Returning-user / re-entrada",
    lede: "«Ya tengo cuenta» → WelcomeCloudSignInView(.reentry) → exists → guard cross-cuenta → adopt. Incluye el guard R9 de provider y el poll con auto-resume.",
    graph: `flowchart TD
  EC["Sub-chooser «Ya tengo una cuenta»"] -->|Restaurar de iCloud| RES(["Restore iCloud<br/>fuera del alcance de F1"])
  EC -->|Apple · Google| RI["Intro de re-entrada"]
  RI --> CON2["Consentimiento · path .adopt"]
  CON2 --> SI2["Sign-in"]
  SI2 --> EX{"GET /account/exists<br/>(read-only)"}
  EX -->|"exists = false"| R9{"Guard R9 · sub-first"}
  EX -->|"sessionExpired · transient"| ERR2["Error con Reintentar"]
  EX -->|"exists = true"| G{"Guard cross-cuenta"}
  R9 -->|mismatch| MM2["«Método equivocado»<br/>sesión soltada, sin claim"]
  R9 -->|proceed| NF["«No encontramos una cuenta»"]
  G -->|"sin datos locales · misma cuenta"| AD["Adopt en curso"]
  G -->|"datos ajenos, sin salida M1"| BL["Bloqueado"]
  G -->|"datos ajenos + M1 encendido"| SEC["Confirmación de sesión secundaria"]
  AD --> POLL{"Poll del adopt"}
  POLL -->|"aparcado ≥4 ticks"| AR["Auto-resume<br/>3 intentos → botón manual"]
  AR --> POLL
  POLL -->|needsRelaunch · cloudActive| RL["«Cierra y reabre Yala»"]
  POLL -->|waitingForLeader| WL2["Esperar al líder"]
  POLL -->|"failed · fases imposibles"| ERR2
  SEC --> RLS["Relanzamiento de la secundaria"]

  click EC call showNode("reentry-chooser")
  click RI call showNode("reentry-intro")
  click CON2 call showNode("alta-consent")
  click SI2 call showNode("alta-signin")
  click EX call showNode("reentry-exists")
  click R9 call showNode("reentry-mismatch")
  click MM2 call showNode("reentry-mismatch")
  click NF call showNode("reentry-notfound")
  click G call showNode("reentry-guard")
  click BL call showNode("reentry-blocked")
  click SEC call showNode("reentry-secondary")
  click RLS call showNode("reentry-secondary")
  click AD call showNode("reentry-adopt")
  click POLL call showNode("reentry-adopt")
  click AR call showNode("reentry-autoresume")
  click RL call showNode("reentry-relaunch")
  click WL2 call showNode("alta-waitingleader")
  click ERR2 call showNode("alta-error-transient")

  classDef unreachable stroke-dasharray: 5 5,opacity:0.65
  class RES unreachable`
  },

  {
    id: "migracion",
    title: "3 · Migración iCloud → nube",
    lede: "Ajustes «Dónde viven tus datos»: dry-run → consent → sign-in → claim → upload → verify → cutover → relanzamiento. Con Retomar / re-kick y el rollback con copy por motivo.",
    graph: `flowchart TD
  ROW{"Fila «Dónde viven tus datos»<br/>StorageRowGateLogic"} -->|"oculta"| NADA(["Sin acceso"])
  ROW -->|"remoto ON · o usuario engaged"| IDLE["Almacenamiento · estado iCloud"]
  IDLE --> DRY["Ver qué se migraría<br/>(dry-run, no escribe nada)"]
  IDLE --> MARK{"¿Marcador de un líder<br/>en el mirror?"}
  MARK -->|sí| ADOPTC["Copy de ADOPTAR"]
  MARK -->|no| MIGC["Copy de MIGRAR"]
  ADOPTC --> CON3["Consentimiento"]
  MIGC --> CON3
  CON3 -->|".adopt ⇒ sin doble confirmación"| AUTH
  CON3 -->|".migration"| CONF["Doble confirmación destructiva"]
  CONF --> AUTH{"Paso de auth · C-7"}
  AUTH -->|"sesión viva"| RUN
  AUTH -->|"sin sesión"| CHOOSE["Chooser Apple | Google"]
  AUTH -->|"cuenta ajena"| BLK["Botón deshabilitado<br/>+ nota de cuenta ajena"]
  CHOOSE --> RUN["Migración en curso<br/>(fases journaleadas)"]
  RUN --> CUT["Cutover · 4 sub-estados"]
  RUN -->|"fallo pre-cutover"| FAIL["failedRollback<br/>copy por MOTIVO"]
  CUT -->|"veredicto bloquea la entrada"| FAIL
  CUT --> RLM["Card bloqueante<br/>«cierra y vuelve a abrir»"]
  RLM --> CA["Modo nube activo"]
  FAIL -->|Reintentar| IDLE
  RUN -.->|"kill · sin red"| RESUME["Retomar: boot resume,<br/>re-kick de foreground, empujón cada 30 s"]
  RESUME --> RUN

  click ROW call showNode("migracion-fila")
  click IDLE call showNode("migracion-idle")
  click DRY call showNode("migracion-idle")
  click MARK call showNode("migracion-adopt-copy")
  click ADOPTC call showNode("migracion-adopt-copy")
  click MIGC call showNode("migracion-idle")
  click CON3 call showNode("alta-consent")
  click CONF call showNode("migracion-confirm")
  click AUTH call showNode("migracion-signin-decision")
  click CHOOSE call showNode("migracion-signin-decision")
  click BLK call showNode("migracion-signin-decision")
  click RUN call showNode("migracion-progreso")
  click RESUME call showNode("migracion-progreso")
  click CUT call showNode("migracion-cutover")
  click RLM call showNode("migracion-relaunch")
  click FAIL call showNode("migracion-fallo")
  click CA call showNode("migracion-cloudactive")`
  },

  {
    id: "reversa",
    title: "4 · Reversa nube → iCloud",
    lede: "Las fases `reverse*` y el cuarteto de cierre, con lo que ve el usuario en cada una. La frontera del rollback es el montaje del mirror.",
    graph: `flowchart TD
  CA2["Modo nube activo"] --> RC{"Card «Volver a iCloud»<br/>gate de elegibilidad"}
  RC -->|no elegible| INE(["Texto de no elegible"])
  RC -->|elegible| RCONF["Doble confirmación"]
  RCONF --> P1["reverseClaimLeader"]
  P1 --> P2["reverseDrainAll"]
  P2 --> P3["reverseVerify"]
  P3 --> P4["reverseFreezeBackend"]
  P4 --> P5["reverseMountMirror"]
  P5 --> RLR["Relanzamiento (toICloud)"]
  RLR --> P6["reverseReconcile · 4 sub-estados"]
  P6 --> P7["reverseUpload"]
  P7 --> FIN["icloudActive<br/>(el deriver lo pinta como idle:<br/>vuelve a ofrecer migrar)"]
  P1 -.->|"fallo PRE-mount"| RFAIL["reverseFailedRollback<br/>el device sigue en nube limpia"]
  P3 -.-> RFAIL
  P6 -.->|"fallo POST-mount"| HOLD["Sostener + resume idempotente<br/>(el mirror ya está vivo)"]
  HOLD --> P6

  click CA2 call showNode("migracion-cloudactive")
  click RC call showNode("reversa-card")
  click INE call showNode("reversa-card")
  click RCONF call showNode("reversa-confirm")
  click P1 call showNode("reversa-fases")
  click P2 call showNode("reversa-fases")
  click P3 call showNode("reversa-fases")
  click P4 call showNode("reversa-fases")
  click P5 call showNode("reversa-fases")
  click P6 call showNode("reversa-fases")
  click P7 call showNode("reversa-fases")
  click HOLD call showNode("reversa-fases")
  click RLR call showNode("reversa-relaunch")
  click FIN call showNode("reversa-cierre")
  click RFAIL call showNode("reversa-cierre")`
  },

  {
    id: "signout",
    title: "5 · Sign-out en `.cloud` + las tres borradas",
    lede: "Camino de cierre por modo (drena el outbox, arma el wipe, la fila «Salir de Yala en este dispositivo») más eliminar cuenta y vaciar datos.",
    graph: `flowchart TD
  AJ["Ajustes · Seguridad y cuenta"] --> PATH{"Precedencia CONGELADA<br/>CloudSignOutFlowLogic.path"}
  PATH -->|"secundaria M1"| SEC2["signOutSecondary"]
  PATH -->|".cloud"| CLOUD["cloudSecureSignOut"]
  PATH -->|"flag ∧ sesión backend"| GRP["groupsOnlySignOut<br/>+ fila «Salir de Yala»"]
  PATH -->|else| PRIV2["privateReset<br/>no se toca nada"]
  CLOUD --> HOJA["Hoja de alcance · 3 filas"]
  SEC2 --> HOJA
  GRP --> HOJA
  PRIV2 --> HOJA
  HOJA --> PUSH{"Push-all previo<br/>(jamás descartar)"}
  PUSH -->|"outbox vivo = 0"| ARM["Armar el wipe<br/>+ cover terminal"]
  PUSH -->|"bloqueo transitorio"| RETRY["Retry interno<br/>45 s de presupuesto, cada 2 s"]
  PUSH -->|"bloqueo permanente 401/403"| PERM["Error inmediato<br/>sin reintentar"]
  RETRY --> PUSH
  RETRY -->|"presupuesto agotado"| TRANS["«Un momento más»"]
  ARM --> BOOT["Boot pre-mount:<br/>borra ARCHIVOS, nunca filas"]
  EXIT["Salir de Yala en este dispositivo"] --> PRIV2
  DEL["Eliminar mi cuenta"] --> HOJA2["Hoja + hasta 5 líneas condicionales"]
  HOJA2 --> FINAL["Segundo diálogo irreversible"]
  WIPE2["Vaciar mis datos"] --> HOJA3["Hoja de vaciado<br/>+ residual multi-device en copy"]

  click AJ call showNode("signout-path")
  click PATH call showNode("signout-path")
  click SEC2 call showNode("signout-path")
  click CLOUD call showNode("signout-path")
  click GRP call showNode("signout-path")
  click PRIV2 call showNode("signout-path")
  click HOJA call showNode("signout-hoja")
  click PUSH call showNode("signout-pushall")
  click RETRY call showNode("signout-pushall")
  click PERM call showNode("signout-pushall")
  click TRANS call showNode("signout-pushall")
  click ARM call showNode("signout-relaunch")
  click BOOT call showNode("signout-relaunch")
  click EXIT call showNode("signout-exityala")
  click DEL call showNode("signout-borrarcuenta")
  click HOJA2 call showNode("signout-borrarcuenta")
  click FINAL call showNode("signout-borrarcuenta")
  click WIPE2 call showNode("signout-vaciar")
  click HOJA3 call showNode("signout-vaciar")`
  },

  {
    id: "onboarding",
    title: "6 · Onboarding de propósito + alta solo-grupos",
    lede: "La card «Solo grupos» oculta en modo nube (A6) y el camino solo-grupos: educativo con su CTA (A1) → sign-in contextual al crear.",
    graph: `flowchart TD
  PUR["Paso «Propósito»"] --> SHOW{"¿Se pinta la card<br/>«Dividir gastos con amigos»?"}
  SHOW -->|"no es flujo inicial"| NO1(["No se pinta"])
  SHOW -->|"modo .cloud (A6)"| NO2(["No se pinta"])
  SHOW -->|"flujo inicial ∧ .icloud"| CARD["Card visible"]
  CARD --> BLOCK{"¿El tap queda bloqueado?"}
  BLOCK -->|"canal de Grupos ON"| SEL["selectedUsageMode = .groupsOnly"]
  BLOCK -->|"canal OFF ∧ sin cuenta iCloud"| MURO["Alert «necesitas iCloud»"]
  BLOCK -->|"canal OFF ∧ con cuenta"| SEL
  SEL --> GO["Cierre solo-grupos<br/>→ tab Grupos"]
  PUR --> OTRAS["Control · Solo gastos<br/>(selectedCard: 4 modos → 3 cards)"]
  OTRAS --> NORM["Cierre normal"]
  GO --> EDU["Educativo del tab Grupos"]
  EDU --> CTA{"¿CTA de sign-in<br/>en el último paso?"}
  CTA -->|"canal ON ∧ sin sesión"| SIGN["Sign-in de grupos"]
  CTA -->|"con sesión · canal OFF"| CONT(["Continuar"])
  EDU --> EMPTY{"Empty state del tab"}
  EMPTY -->|"canal ON ∧ sin sesión"| REENTRY["«Tus grupos están en tu cuenta»"]
  EMPTY -->|else| STD["«Aún no tienes grupos»"]
  STD --> CREATE{"Crear grupo · routing"}
  REENTRY --> SIGN
  CREATE -->|"flag OFF"| CK["Form (canal CloudKit)"]
  CREATE -->|"sin sesión"| SIGN
  CREATE -->|"sin consent"| CONS["Consent de grupos"]
  CREATE -->|"listo"| BE["Form (canal backend)"]

  click PUR call showNode("onboarding-purpose")
  click SHOW call showNode("onboarding-purpose")
  click CARD call showNode("onboarding-purpose")
  click OTRAS call showNode("onboarding-purpose")
  click BLOCK call showNode("onboarding-muro")
  click MURO call showNode("onboarding-muro")
  click SEL call showNode("onboarding-groupsonly")
  click GO call showNode("onboarding-groupsonly")
  click NORM call showNode("alta-postrelaunch")
  click EDU call showNode("onboarding-educativo")
  click CTA call showNode("onboarding-educativo")
  click EMPTY call showNode("onboarding-empty")
  click REENTRY call showNode("onboarding-empty")
  click STD call showNode("onboarding-empty")
  click CREATE call showNode("onboarding-crear")
  click CK call showNode("onboarding-crear")
  click BE call showNode("onboarding-crear")
  click CONS call showNode("onboarding-crear")
  click SIGN call showNode("onboarding-crear")`
  },

  {
    id: "degradado",
    title: "7 · Estados degradados (transversales)",
    lede: "Kill-switch remoto, sesión caducada, sin red, claim en progreso, provider mismatch y el guard de mount-mismatch — que NO tiene pantalla, y eso es un hallazgo.",
    graph: `flowchart TD
  KS["Kill-switch remoto puesto"] --> KS1["Desaparece la card nube de «Soy nuevo»"]
  KS --> KS2["Desaparecen las cards de sign-in de re-entrada"]
  KS --> KS3{"Fila de Almacenamiento"}
  KS3 -->|"usuario engaged"| KS4["Se CONSERVA<br/>(su panel de resume y reversa)"]
  KS3 -->|"no engaged"| KS5["Oculta"]
  KS --> KS6["El faro deja de encaminar<br/>⇒ residual del 2º device, declarado"]

  EXP["Sesión caducada"] --> EXP1{"¿Hay cambios pendientes?"}
  EXP1 -->|"pendientes = 0"| EXP2["Sin banner · «al día»"]
  EXP1 -->|"pendientes > 0"| EXP3["Banner S11 con el conteo<br/>+ CTA de re-firma determinista"]

  NET["Sin red"] --> NET1["Alta: error con Reintentar"]
  NET --> NET2["Adopt: auto-resume"]
  NET --> NET3["Migración: aparcada + re-kick;<br/>tope por TIEMPO, no por intentos"]

  CIP["claiming_in_progress"] --> CIP1["Esperar al líder<br/>(un seguidor nunca siembra ni adopta)"]

  PM["Provider mismatch"] --> PM1["Pantalla R9 · sesión soltada, sin claim"]

  MNT["Par .cloud escrito, proceso montado en .icloud"] --> MNT1["El motor NO arranca"]
  MNT1 --> MNT2(["SIN pantalla propia:<br/>solo el breadcrumb personalMountMismatch"])

  click KS call showNode("degradado-killswitch")
  click KS1 call showNode("degradado-killswitch")
  click KS2 call showNode("degradado-killswitch")
  click KS3 call showNode("migracion-fila")
  click KS4 call showNode("migracion-fila")
  click KS5 call showNode("migracion-fila")
  click KS6 call showNode("alta-faro")
  click EXP call showNode("degradado-sesion")
  click EXP1 call showNode("degradado-sesion")
  click EXP2 call showNode("degradado-sesion")
  click EXP3 call showNode("degradado-sesion")
  click NET call showNode("degradado-sinred")
  click NET1 call showNode("degradado-sinred")
  click NET2 call showNode("reentry-autoresume")
  click NET3 call showNode("migracion-progreso")
  click CIP call showNode("degradado-claiming")
  click CIP1 call showNode("degradado-claiming")
  click PM call showNode("reentry-mismatch")
  click PM1 call showNode("reentry-mismatch")
  click MNT call showNode("degradado-mount")
  click MNT1 call showNode("degradado-mount")
  click MNT2 call showNode("degradado-mount")

  classDef unreachable stroke-dasharray: 5 5,opacity:0.65
  class MNT2 unreachable`
  }
];

// ══════════════════════════════════════════════════════════════════════════════
// AUTO-AUDITORÍA DE COMPLETITUD
//
// `celdas` = clases de equivalencia de la tabla, contadas LEYENDO el `switch`/predicado del fichero.
// `tests`  = número de `@Test` MEDIDO con grep en la suite indicada el 2026-08-09 (no es el número de
//            celdas: una celda puede tener varios tests y un test puede barrer varias).
// `dibujados` = branches que aparecen como arista o nodo en algún diagrama de arriba.
// `delta` = celdas NO dibujadas. Un delta > 0 NO es un fallo: es un hueco DICHO, con su motivo.
// ══════════════════════════════════════════════════════════════════════════════

window.ATLAS_COVERAGE = [
  { logic: "AccountClaimDecision.decide", file: "Yala/Services/CloudSync/AccountClaimDecision.swift:71",
    cells: 10, tests: "6 · YalaTests/CloudSync/AccountClaimDecisionTests.swift", drawn: 4, flow: "alta",
    delta: "Las 3 celdas de la rama `.bornCloud` se dibujan como branches propios y la variante B va punteada (inalcanzable). Las 6 celdas de `.migration` y `.returningUser` NO se dibujan una a una: esos dos flujos entran por la máquina de migración y por `exists`, no por esta tabla, y dibujarlas ahí duplicaría la decisión." },

  { logic: "BornCloudSignUpFlow.step", file: "Yala/App/Logic/CloudWelcomeSignInFlow.swift:120",
    cells: 7, tests: "15 · YalaTests/CloudSync/BornCloudSignUpFlowTests.swift", drawn: 7, flow: "alta", delta: "" },

  { logic: "CloudWelcomeSignInFlow.route", file: "Yala/App/Logic/CloudWelcomeSignInFlow.swift:58",
    cells: 4, tests: "18 · YalaTests/CloudWelcomeSignInFlowTests.swift", drawn: 3, flow: "reentry",
    delta: "`sessionExpired` y `transient` colapsan en el diagrama a una sola arista porque la tabla los colapsa antes: los dos dan `failed(retryable: true)`." },

  { logic: "CloudWelcomeSignInFlow.phase(for:)", file: "Yala/App/Logic/CloudWelcomeSignInFlow.swift:70",
    cells: 8, tests: "18 · YalaTests/CloudWelcomeSignInFlowTests.swift", drawn: 8, flow: "reentry",
    delta: "" },

  { logic: "WelcomeAdoptAutoResume.tick", file: "Yala/App/Logic/CloudWelcomeSignInFlow.swift:178",
    cells: 5, tests: "18 · YalaTests/CloudWelcomeSignInFlowTests.swift", drawn: 3, flow: "reentry",
    delta: "Las dos celdas de reposición (avance real repone intentos; drive en curso corta la racha conservando intentos) están en el PANEL y no como arista: son transiciones del contador, no de pantalla." },

  { logic: "WelcomeAccountChoiceLogic.visibleNewOptions", file: "Yala/App/Logic/WelcomeAccountChoiceLogic.swift:42",
    cells: 6, tests: "21 · YalaTests/WelcomeAccountChoiceLogicTests.swift", drawn: 2, flow: "alta",
    delta: "El predicado tiene 5 términos y el diagrama solo puede dibujar «hay card» / «no hay card». Las 5 negaciones se enumeran en el panel del sub-chooser." },

  { logic: "WelcomeAccountChoiceLogic.visibleExistingOptions", file: "Yala/App/Logic/WelcomeAccountChoiceLogic.swift:60",
    cells: 4, tests: "21 · YalaTests/WelcomeAccountChoiceLogicTests.swift", drawn: 2, flow: "reentry",
    delta: "Mismo motivo: 3 términos, dos resultados visibles. Las negaciones van en el panel." },

  { logic: "WelcomeAccountChoiceLogic.routeNewBranch", file: "Yala/App/Logic/WelcomeAccountChoiceLogic.swift:103",
    cells: 4, tests: "21 · YalaTests/WelcomeAccountChoiceLogicTests.swift", drawn: 4, flow: "alta", delta: "" },

  { logic: "CrossAccountEntryGuardLogic.decide", file: "Yala/App/Logic/CrossAccountEntryGuardLogic.swift:47",
    cells: 4, tests: "7 · YalaTests/CrossAccountEntryGuardLogicTests.swift", drawn: 4, flow: "reentry", delta: "" },

  { logic: "ProviderMismatchLogic.decide", file: "Yala/App/Logic/ProviderMismatchLogic.swift:45",
    cells: 5, tests: "16 · YalaTests/ProviderMismatchLogicTests.swift", drawn: 2, flow: "reentry",
    delta: "Las 5 reglas EN ORDEN producen solo dos salidas; el diagrama dibuja las salidas y el panel lista las 5 reglas con su porqué (la señal primaria es el SUB, no el provider)." },

  { logic: "ProviderMismatchLogic.postClaimLinkedDifferentProvider", file: "Yala/App/Logic/ProviderMismatchLogic.swift:64",
    cells: 3, tests: "16 · YalaTests/ProviderMismatchLogicTests.swift", drawn: 0, flow: "—",
    delta: "NO se dibuja y no debe: es observabilidad pura (breadcrumb `claimProfileProviderDiffers`), nunca alerta ni cambia pantalla. Dibujarla sugeriría una superficie de usuario que no existe." },

  { logic: "ProviderMismatchLogic.displayName", file: "Yala/App/Logic/ProviderMismatchLogic.swift:74",
    cells: 3, tests: "16 · YalaTests/ProviderMismatchLogicTests.swift", drawn: 2, flow: "reentry",
    delta: "«apple» y «google» colapsan en «nombra el método»; el tercer caso (desconocido → copy genérico) sí se distingue en el panel." },

  { logic: "MigrationRuntimeGate.canRun", file: "Yala/Services/CloudSync/MigrationBootDecision.swift:55",
    cells: 4, tests: "6 · YalaTests/CloudSync/PersonalMountMismatchGuardTests.swift", drawn: 4, flow: "degradado", delta: "" },

  { logic: "MigrationRuntimeGate.isPersonalMountMismatch", file: "Yala/Services/CloudSync/MigrationBootDecision.swift:80",
    cells: 4, tests: "6 · YalaTests/CloudSync/PersonalMountMismatchGuardTests.swift", drawn: 2, flow: "degradado",
    delta: "En `.icloud` el predicado es `false` por construcción ⇒ dos de las cuatro celdas son inertes y se dicen en el panel en vez de dibujarse." },

  { logic: "MigrationRuntimeGate.isDomainStablePhase", file: "Yala/Services/CloudSync/MigrationBootDecision.swift:84",
    cells: 21, tests: "35 · YalaTests/CloudSync/CloudMigrationI14Tests.swift", drawn: 2, flow: "degradado",
    delta: "COLAPSO DECLARADO: las 21 fases se agrupan en «estable» (`done`, `notStarted`) y «transicional» (las otras 19). Las fases sí se dibujan una a una, pero en los flujos 3 y 4, que es donde son observables." },

  { logic: "MigrationBootDecision.decide", file: "Yala/Services/CloudSync/MigrationBootDecision.swift:117",
    cells: 22, tests: "35 · YalaTests/CloudSync/CloudMigrationI14Tests.swift", drawn: 3, flow: "migracion",
    delta: "Igual: 1 fila de «hay efectos pendientes» + 21 fases → 3 decisiones (`resume` · `pollLeader` · `none`). Se dibujan las 3 decisiones; el mapeo fase→decisión vive en el panel." },

  { logic: "MigrationForegroundRekick.shouldRekick", file: "Yala/Services/CloudSync/MigrationBootDecision.swift:144",
    cells: 2, tests: "35 · YalaTests/CloudSync/CloudMigrationI14Tests.swift", drawn: 2, flow: "migracion", delta: "" },

  { logic: "CloudMigrationUIStateDeriver.derive", file: "Yala/Services/CloudSync/CloudMigrationController.swift:66",
    cells: 10, tests: "35 · YalaTests/CloudSync/CloudMigrationI14Tests.swift", drawn: 8, flow: "migracion · reversa",
    delta: "Sus 8 estados de UI se dibujan todos. Las 2 celdas no dibujadas son la normalización de `dryRun` por modo, que no tiene pantalla propia (cae en `idle` o `cloudActive`)." },

  { logic: "CloudMigrationUIStateDeriver.fraction(for:)", file: "Yala/Services/CloudSync/CloudMigrationController.swift:111",
    cells: 21, tests: "35 · YalaTests/CloudSync/CloudMigrationI14Tests.swift", drawn: 0, flow: "—",
    delta: "NO se dibuja: es la fracción de la barra, presentación continua. Aparece en el panel del nodo de progreso (el 89 % del paso 4 tiene su propio caption por eso)." },

  { logic: "ICloudCutoverGateLogic.decide", file: "Yala/Services/CloudSync/ICloudCutoverGateLogic.swift:86",
    cells: 5, tests: "8 · YalaTests/CloudSync/ICloudCutoverGateLogicTests.swift", drawn: 5, flow: "migracion", delta: "" },

  { logic: "ICloudChannelVerdict.blocksCutoverEntry", file: "Yala/Services/CloudSync/ICloudCutoverGateLogic.swift:50",
    cells: 5, tests: "8 · YalaTests/CloudSync/ICloudCutoverGateLogicTests.swift", drawn: 2, flow: "migracion",
    delta: "Los 5 veredictos colapsan en «bloquea la entrada» / «no bloquea»; el reparto exacto está en el panel del cutover." },

  { logic: "ICloudChannelVerdict.stallCause", file: "Yala/Services/CloudSync/ICloudCutoverGateLogic.swift:63",
    cells: 5, tests: "8 · YalaTests/CloudSync/ICloudCutoverGateLogicTests.swift", drawn: 2, flow: "degradado",
    delta: "Igual: definitivo (presupuesto corto) vs desconocido (presupuesto largo)." },

  { logic: "StorageModePersistence.isCloudWithMirrorOn / writeCloudArmed", file: "Yala/Services/CloudSync/CloudSyncFlags.swift:91",
    cells: 4, tests: "14 · YalaTests/CloudSync/StorageModePersistenceTests.swift", drawn: 3, flow: "alta · migracion",
    delta: "La cuarta celda (`.icloud` + armado, mitad imposible en operación normal) no se dibuja: es el estado que el orden del par existe para no producir. Va en el panel." },

  { logic: "StorageRowGateLogic.isVisible", file: "Yala/App/Logic/StorageRowGateLogic.swift:26",
    cells: 4, tests: "5 · YalaTests/CloudSync/RemoteFlagDecisionLogicTests.swift (suite StorageRowGateLogicTests)", drawn: 4, flow: "migracion · degradado", delta: "" },

  { logic: "StorageMigrationSignInLogic.decide", file: "Yala/App/Logic/StorageMigrationSignInLogic.swift",
    cells: 3, tests: "14 · YalaTests/StorageMigrationSignInLogicTests.swift", drawn: 3, flow: "migracion", delta: "" },

  { logic: "CloudSignOutFlowLogic.path", file: "Yala/App/Logic/CloudSignOutFlowLogic.swift:51",
    cells: 4, tests: "28 · YalaTests/CloudSignOutFlowLogicTests.swift", drawn: 4, flow: "signout", delta: "" },

  { logic: "CloudSignOutFlowLogic.rowLayout", file: "Yala/App/Logic/CloudSignOutFlowLogic.swift:104",
    cells: 4, tests: "28 · YalaTests/CloudSignOutFlowLogicTests.swift", drawn: 3, flow: "signout",
    delta: "`.none` (ninguna fila) no se dibuja como nodo: es la ausencia de superficie. Se nombra en el panel." },

  { logic: "CloudSignOutFlowLogic.shouldShowRow / shouldShowExitYalaRow", file: "Yala/App/Logic/CloudSignOutFlowLogic.swift:71",
    cells: 4, tests: "28 · YalaTests/CloudSignOutFlowLogicTests.swift", drawn: 2, flow: "signout",
    delta: "Las dos funciones son mutuamente excluyentes y el diagrama dibuja el resultado (qué filas hay); las combinaciones intermedias las resuelve `rowLayout`, ya auditado arriba." },

  { logic: "CloudSignOutFlowLogic.pushAllVerdict", file: "Yala/App/Logic/CloudSignOutFlowLogic.swift:154",
    cells: 4, tests: "28 · YalaTests/CloudSignOutFlowLogicTests.swift", drawn: 4, flow: "signout", delta: "" },

  { logic: "CloudSignOutFlowLogic.classify", file: "Yala/App/Logic/CloudSignOutFlowLogic.swift:132",
    cells: 5, tests: "28 · YalaTests/CloudSignOutFlowLogicTests.swift", drawn: 2, flow: "signout",
    delta: "Los 5 outcomes de cadencia colapsan en transitorio/permanente; el reparto está en el panel del push-all." },

  { logic: "GroupsSignOutRetryDecision.decide", file: "Yala/App/Logic/CloudSignOutFlowLogic.swift:193",
    cells: 3, tests: "28 · YalaTests/CloudSignOutFlowLogicTests.swift", drawn: 3, flow: "signout", delta: "" },

  { logic: "AccountDeletionMessageLogic.lines", file: "Yala/App/Logic/AccountDeletionDebtLogic.swift:89",
    cells: 8, tests: "17 · YalaTests/AccountDeletionDebtLogicTests.swift", drawn: 1, flow: "signout",
    delta: "Las 2³ combinaciones de (deuda × modo × huella) producen un solo NODO de diálogo con hasta 5 líneas; el panel enumera las 5 líneas y cuándo aparece cada una. Dibujar 8 nodos idénticos salvo el texto sería ruido." },

  { logic: "DestructiveScopeLogic.model", file: "Yala/App/Logic/DestructiveScopeLogic.swift:115",
    cells: 11, tests: "21 · YalaTests/DestructiveScopeLogicTests.swift", drawn: 10, flow: "signout",
    delta: "Falta `deleteFrozenCopy` (borrar la copia CloudKit congelada, G6-C5): vive en la superficie de GRUPOS, que no es ninguno de los siete flujos del alcance de F1." },

  { logic: "DestructiveScopeLogic.wipeOperation / cloudLabel", file: "Yala/App/Logic/DestructiveScopeLogic.swift:96",
    cells: 4, tests: "21 · YalaTests/DestructiveScopeLogicTests.swift", drawn: 2, flow: "signout",
    delta: "La etiqueta ☁️ por modo se dice en el panel de la hoja en vez de duplicar cada nodo por modo." },

  { logic: "AccountDeletionDebtLogic.groupsWithOutstandingBalance", file: "Yala/App/Logic/AccountDeletionDebtLogic.swift:55",
    cells: 2, tests: "17 · YalaTests/AccountDeletionDebtLogicTests.swift", drawn: 1, flow: "signout",
    delta: "Es una AGREGACIÓN (cuenta grupos con |neto| > 0.01), no un ruteo: solo su resultado booleano llega al diagrama." },

  { logic: "OnboardingGroupsPurposeGateLogic.shouldShowGroupsCard", file: "Yala/App/Logic/OnboardingGroupsPurposeGateLogic.swift:97",
    cells: 3, tests: "8 · YalaTests/OnboardingGroupsPurposeGateLogicTests.swift", drawn: 3, flow: "onboarding", delta: "" },

  { logic: "OnboardingGroupsPurposeGateLogic.shouldBlockSelection", file: "Yala/App/Logic/OnboardingGroupsPurposeGateLogic.swift:56",
    cells: 3, tests: "8 · YalaTests/OnboardingGroupsPurposeGateLogicTests.swift", drawn: 3, flow: "onboarding", delta: "" },

  { logic: "OnboardingPurposeSelectionLogic.selectedCard / isSelected", file: "Yala/App/Logic/OnboardingPurposeSelectionLogic.swift:62",
    cells: 4, tests: "7 · YalaTests/OnboardingPurposeSelectionLogicTests.swift", drawn: 4, flow: "onboarding",
    delta: "" },

  { logic: "OnboardingPurposeSelectionLogic.shouldSelectFullControl", file: "Yala/App/Logic/OnboardingPurposeSelectionLogic.swift:82",
    cells: 4, tests: "7 · YalaTests/OnboardingPurposeSelectionLogicTests.swift", drawn: 0, flow: "—",
    delta: "NO se dibuja: decide si un tap CAMBIA el modo dentro del mismo paso, sin transición de pantalla. Desde `.dayToDay` el tap NO reasigna a propósito (reasignar cambiaría en silencio la respuesta del paso siguiente)." },

  { logic: "GroupsOnboardingLogic.shouldShow", file: "Yala/App/Logic/GroupsOnboardingLogic.swift:30",
    cells: 4, tests: "12 · YalaTests/GroupsOnboardingLogicTests.swift", drawn: 2, flow: "onboarding",
    delta: "AND-gating de 3 bloqueadores → se dibuja «se muestra» / «no se muestra»; los 3 bloqueadores se listan en el panel." },

  { logic: "GroupsOnboardingLogic.shouldShowSignInCTA", file: "Yala/App/Logic/GroupsOnboardingLogic.swift:60",
    cells: 4, tests: "12 · YalaTests/GroupsOnboardingLogicTests.swift", drawn: 2, flow: "onboarding",
    delta: "3 términos, dos resultados. Las negaciones van en el panel." },

  { logic: "GroupsEmptyStateLogic.decide", file: "Yala/App/Logic/GroupsEmptyStateLogic.swift:29",
    cells: 3, tests: "4 · YalaTests/GroupsEmptyStateLogicTests.swift", drawn: 2, flow: "onboarding",
    delta: "«flag OFF» y «flag ON con sesión» colapsan los dos en `.standard`, igual que en la tabla." },

  { logic: "GroupCreateRoutingLogic.route", file: "Yala/App/Logic/GroupCreateRoutingLogic.swift:28",
    cells: 4, tests: "4 · YalaTests/GroupCreateRoutingLogicTests.swift", drawn: 4, flow: "onboarding", delta: "" },

  { logic: "SessionExpiryPolicy.decide", file: "Yala/Services/CloudSync/SessionExpiryPolicy.swift:34",
    cells: 3, tests: "5 · YalaTests/CloudSync/SessionExpiryPolicyTests.swift", drawn: 2, flow: "degradado",
    delta: "«sin pendientes» y «sesión renovable» colapsan en `.ok`, igual que en la tabla." },

  { logic: "CloudRemoteFlags (cloudMode · onboardingChoice · groupsBackend)", file: "Yala/Services/CloudSync/CloudRemoteConfig.swift:127",
    cells: 6, tests: "5 · YalaTests/CloudSync/RemoteFlagDecisionLogicTests.swift", drawn: 3, flow: "degradado",
    delta: "Se dibuja el efecto de cada flag apagado. Las tres celdas de «encendido» son el camino normal, ya dibujado en los flujos 1, 2 y 6." }
];

// Hallazgos: lo que el Atlas encontró al derivarse del CÓDIGO y que el diseño no dice (o dice al revés).
window.ATLAS_FINDINGS = [
  {
    id: "F1-H1",
    sev: "hallazgo",
    title: "El guard de mount-mismatch NO tiene pantalla, al contrario de lo que sugiere el enunciado del chip",
    body: "El chip F1 lo describe como «el guard de mount-mismatch (la pantalla de relanzamiento pendiente)». MEDIDO: `MigrationRuntimeGate.isPersonalMountMismatch` solo apaga el motor y deja un breadcrumb; no pinta nada. La única card de relanzamiento la deriva `CloudMigrationUIStateDeriver` a partir del par armado, y vive en Almacenamiento — inalcanzable durante el alta born-cloud, porque el onboarding todavía no ha terminado. No es un bug: durante el alta la fase `.relaunch` es terminal, sin back y con `interactiveDismissDisabled()`, así que el usuario no puede escapar. Es un hueco de OBSERVABILIDAD, y queda dicho.",
    node: "degradado-mount"
  },
  {
    id: "F1-H2",
    sev: "corrección",
    title: "«Cancelar deja el device exactamente como estaba» es falso, y por eso la matriz tiene tres filas",
    body: "El criterio de hecho de A5 en el spec pide que cancelar no deje «ni par, ni faro, ni consent». Es insatisfacible: el consent se persiste al ACEPTARSE (registro append-only, precedente del repo) y el faro es TEMPRANO por diseño. Tras un `created` el estado es re-entrante, no virgen. Ya está corregido en la anotación 3 del punto de control; el Atlas lo dibuja.",
    node: "alta-cancel"
  },
  {
    id: "F1-H3",
    sev: "hallazgo",
    title: "La variante B del claim es INALCANZABLE desde la rama born-cloud",
    body: "`AccountClaimDecision.swift:83` acota la variante B a `branch == .returningUser`. Desde `.bornCloud` no la produce ninguna combinación del faro. `BornCloudSignUpFlow` y `BornCloudSignUpService` la mapean igual —con su canario— porque la tabla que decide vive en `AccountClaimDecision` y el `switch` es exhaustivo por el compilador. En el diagrama va punteada.",
    node: "alta-claim"
  },
  {
    id: "F1-H4",
    sev: "hallazgo",
    title: "El alta «Solo grupos» sigue dejando datos sin ninguna copia",
    body: "`completeGroupsOnlyOnboarding` NO toca `storageMode` ⇒ el device se queda `.icloud` y, sin cuenta iCloud del OS, el store personal monta local-sin-mirror: las `TransactionItem` puenteadas desde los gastos de grupo no tienen copia en ninguna parte. D-A7 da salida a los usuarios NUEVOS; la cohorte existente no se cura sola y está declarada fuera de alcance en §6.5 del spec. Medido de nuevo en este árbol.",
    node: "onboarding-groupsonly"
  },
  {
    id: "F1-H5",
    sev: "residual",
    title: "Bajo el kill-switch remoto, el faro deja de encaminar y el 2º device born-cloud puede divergir",
    body: "`routeNewBranch` solo encamina si `cloudEntryAvailable`, que se DERIVA de `visibleExistingOptions` y por tanto muere con el kill-switch. Es el mismo residual que ya acepta la card de re-entrada, ampliado a este camino, y está escrito en el propio código (`WelcomeAccountChoiceLogic.swift:100-102`). Sin kill —el caso normal— el faro cierra A26.",
    node: "alta-faro"
  },
  {
    id: "F1-H6",
    sev: "residual",
    title: "El cuarteto de cierre de la reversa conserva el bug-class que el abort del cutover ya arregló",
    body: "El abort del cutover emite `persistICloudMode` PRIMERO —el único efecto que no puede lanzar— para que la mitad peligrosa se deshaga antes de que corra nada que falle. El cierre de la reversa tiene el orden INVERSO y por eso conserva el mismo bug-class; está documentado como residual en `.claude/rules/swiftdata-cloudkit.md` con ticket aparte. El Atlas lo marca en el nodo de cierre para que la revisión del owner lo vea en su sitio.",
    node: "reversa-cierre"
  },
  {
    id: "F1-H7",
    sev: "nota",
    title: "El `case .bornCloud` de Almacenamiento es un camino muerto DELIBERADO",
    body: "`onConsentDismissed` tiene un `case .bornCloud` que hace `break`. Es inalcanzable (esa pantalla solo asigna `.adopt`/`.migration`) y existe porque el `switch` es exhaustivo: si algún día Almacenamiento ofreciera el alta, el compilador NO avisaría, y el `break` deja el camino muerto en vez de disparar una doble confirmación de migración sobre un flujo que no migra nada.",
    node: "migracion-confirm"
  }
];
