// flows.js — los DIAGRAMAS del Atlas y su auto-auditoría de cobertura.
//
// Cada `graph` es Mermaid. Cada línea `click <id> call showNode("<screenshot-id>")` conecta un nodo del
// diagrama con su panel en `nodes.js`. Los ids del diagrama son cortos (Mermaid) y el id de screenshot es
// el estable (`<flujo>-<nodo>`), que es el que F2 usa para poblar `img/`.
//
// Medido el 2026-08-09 contra HEAD 9d6f0f1c (branch 2.0.5).
//
// F3 (2026-08-11): los diagramas 1, 2, 5 y 7 están re-derivados contra HEAD 24b4bc91 (tanda del
// relanzamiento cero). Los diagramas 3, 4 y 6 siguen anclados al 2026-08-09 — la tanda no toca su código,
// comprobado con `git diff f4d10fa6..HEAD`.
//
// F5 (2026-08-12, HEAD 6c6eb3fe): re-derivados los diagramas 1, 2, 6 y 7 tras las olas W/G/C/M. El 1 gana
// la vía del organizador (chooser de grupos → PUERTA → nombre → alta), el 6 las cuatro puertas unificadas
// y los cinco casos del empty state, el 2 la frontera de sesión secundaria y el registro del consent, y el
// 7 el barrido de grupos legacy y los ajustes del dueño. Los diagramas 3 y 4 siguen anclados al 2026-08-09:
// `git diff 724f661e..HEAD` no roza un solo fichero suyo.

window.ATLAS_FLOWS = [
  {
    id: "r1",
    title: "1 · Empiezo de cero · cuenta privada",
    lede: "Móvil nuevo, sin nada dentro, y elijo «privacidad total». **Es el recorrido que hace HOY todo usuario nuevo de producción**, porque el percent remoto de la elección de nube está en 0 y el sub-chooser ni se muestra. Es también el que PAGA el relanzamiento que el alta en la nube dejó de pagar.",
    graph: `flowchart TD
  MT{"Mount de este proceso<br/>¿existe el archivo de store?"} -->|"no · monta NEUTRO"| H["Welcome · Hero"]
  H --> C["Chooser · 3 ramas"]
  C -->|"Es mi primera vez"| F{"¿El faro dice que este Apple ID<br/>ya tiene cuenta nube?"}
  F -->|"1 sola opción ⇒ bypass"| PRIV["«Soy nuevo → privacidad total»"]
  F -->|"≥2 opciones"| NC["Sub-chooser «Soy nuevo»"]
  NC -->|"privacidad total"| PRIV
  PRIV --> MR["«Un último paso: reabre Yala»<br/>destino persistido"]
  MR --> OB["Onboarding · paso Propósito"]
  OB -->|"card «Solo grupos»"| MURO["Muro iCloud del selector"]
  MURO --> GO["El alta solo-grupos"]
  KS{{"Kill-switch remoto puesto:<br/>la elección de nube desaparece"}}
  click MT call showNode("degradado-neutro")
  click H call showNode("alta-hero")
  click C call showNode("alta-chooser")
  click F call showNode("alta-faro")
  click NC call showNode("alta-newchooser")
  click PRIV call showNode("alta-privado")
  click MR call showNode("alta-mirrorrelaunch")
  click OB call showNode("onboarding-purpose")
  click MURO call showNode("onboarding-muro")
  click GO call showNode("onboarding-groupsonly")
  click KS call showNode("degradado-killswitch")`
  },

  {
    id: "r2",
    title: "2 · Empiezo de cero · cuenta en la nube",
    lede: "El alta born-cloud: consent → sign-in → claim → dentro. Desde el relanzamiento cero **no pide reabrir la app** —salvo que el mount llevara mirror—, que es justo lo contrario que el camino privado. Incluye las cuatro salidas del claim, los tres errores y la matriz de cancelación de tres filas.",
    graph: `flowchart TD
  MT{"Mount NEUTRO"} --> H["Welcome · Hero"]
  H --> C["Chooser · 3 ramas"]
  C -->|"Es mi primera vez"| F{"¿faro vinculado?"}
  F --> NC["Sub-chooser «Soy nuevo»"]
  NC -->|"cuenta en la nube"| CON["Consentimiento informado"]
  CON --> INT["Intro del alta · Apple | Google"]
  INT --> SI["Sign-in"]
  SI --> CR["«Creando tu cuenta…»"]
  CR --> CL{"POST /account/claim"}
  CL -->|"created"| ACT{"¿El mount ADJUNTA mirror?"}
  ACT -->|"no · neutro"| RDY["«¡Tu cuenta está lista!»<br/>motor arrancado EN SESIÓN"]
  ACT -->|"sí"| PAR["«Cierra y vuelve a abrir Yala»"]
  RDY --> POST["Onboarding en modo nube"]
  PAR --> MM{"Guard de mount-mismatch<br/>(sin pantalla)"}
  MM --> POST
  POST --> OB["Paso Propósito"]
  CL -->|"existing_stable"| RU["Continuar como returning-user"]
  CL -->|"claiming_in_progress"| WL["Esperar al líder"]
  WL --> CLM["Otro device lidera"]
  CL -->|"401"| E401["Sesión no viva"]
  CL -->|"403"| E403["Cuenta no disponible"]
  CL -->|"red · 5xx"| ETR["Transitorio"]
  ETR --> SR["Sin red"]
  CAN{{"Matriz de cancelación · TRES filas"}}
  KS{{"Kill-switch remoto"}}
  SES{{"Sesión caducada con cambios pendientes"}}
  click MT call showNode("degradado-neutro")
  click H call showNode("alta-hero")
  click C call showNode("alta-chooser")
  click F call showNode("alta-faro")
  click NC call showNode("alta-newchooser")
  click CON call showNode("alta-consent")
  click INT call showNode("alta-intro")
  click SI call showNode("alta-signin")
  click CR call showNode("alta-creating")
  click CL call showNode("alta-claim")
  click ACT call showNode("alta-par-relaunch")
  click RDY call showNode("alta-bornready")
  click PAR call showNode("alta-par-relaunch")
  click MM call showNode("degradado-mount")
  click POST call showNode("alta-postrelaunch")
  click OB call showNode("onboarding-purpose")
  click RU call showNode("alta-returning")
  click WL call showNode("alta-waitingleader")
  click CLM call showNode("degradado-claiming")
  click E401 call showNode("alta-error-401")
  click E403 call showNode("alta-error-403")
  click ETR call showNode("alta-error-transient")
  click SR call showNode("degradado-sinred")
  click CAN call showNode("alta-cancel")
  click KS call showNode("degradado-killswitch")
  click SES call showNode("degradado-sesion")`
  },

  {
    id: "r3",
    title: "3 · Llego con una invitación a un grupo",
    lede: "**El recorrido que el Atlas no tenía.** Del tap en el enlace de WhatsApp a la sala de espera de la aprobación, pasando por la página web, las tres puertas de entrada al mismo método y el sign-in de Grupos. Aquí viven cuatro hallazgos medidos: el «no» del admin no tiene pantalla, la sala de espera no deja ver ni un gasto, «¡Todo listo!» casi no se alcanza y tres pantallas del invitado no tienen productor.",
    graph: `flowchart TD
  ORI["El enlace: qué lleva y cuánto vive"] --> LAND["Página web del enlace<br/>(sin Yala instalada)"]
  ORI --> TAP{"Toco el enlace<br/>¿app instalada?"}
  LAND -->|"Abrir en Yala"| TAP
  TAP -->|"app cerrada"| FRIO["El silencio deliberado"]
  TAP --> CAN{"¿A qué canal va?"}
  CAN -->|"backend"| PIN{"Puerta .invite<br/>la única que NO empieza por el educativo"}
  CAN -->|"era CloudKit"| ECK["El canal que lo servía ya no existe"]
  PIN --> PUER{"Tabla de las CUATRO puertas"}
  PUER --> GSI["Sign-in de Grupos"]
  GSI --> CONS["Consent de Grupos"]
  CONS --> CC{"Dónde se registra el consent"}
  CC --> NOM["«Te invitaron a un grupo» → tu nombre"]
  NOM --> JOIN{"join_group contra el servidor"}
  JOIN --> ESP["«Conectando con tu grupo…»"]
  ESP --> SOL["«Solicitud enviada»"]
  SOL --> BAN["Banner del tab Grupos"]
  BAN --> EMPTY["Empty state del tab"]
  EMPTY --> ADOP["Entrar al tab ES la adopción"]
  ADOP --> INT{"Lo que queda escrito"}
  INT --> APR["El admin decide"]
  APR --> LISTO["«¡Todo listo!»"]
  H["Welcome · Hero"] --> C["Chooser · 3 ramas"]
  C -->|"Vengo por un grupo"| GC["¿Cómo empiezas con tu grupo?"]
  GC -->|"Tengo una invitación"| RREL{"La ÚNICA vía de grupos<br/>que pide reabrir la app"}
  RREL --> MT{"Mount NEUTRO"}
  MT --> MR["«Un último paso: reabre Yala»"]
  MR --> REC["«Pega tu enlace de invitación»"]
  REC --> CAN
  EENL["El enlace ya no vale"]
  ECAN["Canal apagado: «Guardamos tu solicitud»"]
  ERED["Sin red o sesión caída"]
  OSES{"Llega a un móvil con sesión de otra persona"}
  SLOT["El hueco de invitada ya es de otra"]
  MUE{{"Las tres pantallas sin productor"}}
  KS{{"Kill-switch remoto"}}
  SES{{"Sesión caducada"}}
  SR{{"Sin red"}}
  click ORI call showNode("r3-enlace-origen")
  click LAND call showNode("r3-landing")
  click TAP call showNode("r3-tap")
  click FRIO call showNode("r3-frio")
  click CAN call showNode("r3-canal")
  click PIN call showNode("r3-puerta-invite")
  click ECK call showNode("r3-err-ckshare")
  click PUER call showNode("onboarding-puertas")
  click GSI call showNode("onboarding-groupssignin")
  click CONS call showNode("onboarding-consent")
  click CC call showNode("onboarding-consentcuenta")
  click NOM call showNode("r3-onboarding-nombre")
  click JOIN call showNode("r3-join")
  click ESP call showNode("r3-esperando")
  click SOL call showNode("r3-solicitud")
  click BAN call showNode("r3-banner")
  click EMPTY call showNode("onboarding-empty")
  click ADOP call showNode("onboarding-adopcion")
  click INT call showNode("r3-intent")
  click APR call showNode("r3-aprobacion")
  click LISTO call showNode("r3-listo")
  click H call showNode("alta-hero")
  click C call showNode("alta-chooser")
  click GC call showNode("alta-groupschooser")
  click RREL call showNode("r3-recovery-relanzamiento")
  click MT call showNode("degradado-neutro")
  click MR call showNode("alta-mirrorrelaunch")
  click REC call showNode("r3-recovery")
  click EENL call showNode("r3-err-enlace")
  click ECAN call showNode("r3-err-canal")
  click ERED call showNode("r3-err-red")
  click OSES call showNode("r3-otra-sesion")
  click SLOT call showNode("reentry-slotocupado")
  click MUE call showNode("r3-muertos")
  click KS call showNode("degradado-killswitch")
  click SES call showNode("degradado-sesion")
  click SR call showNode("degradado-sinred")`
  },

  {
    id: "r4",
    title: "4 · Solo quiero grupos · creo el primero",
    lede: "El organizador: «Vengo por un grupo → Crear mi primer grupo». La PUERTA comprueba tres cosas —canal, visita, datos ajenos— **antes de escribir nada**, y el alta entera escribe sus seis preferencias juntas y al final. Incluye la otra vía a lo mismo (la card «Solo grupos» del onboarding de 8 pasos) y las cuatro puertas de Grupos en una sola tabla.",
    graph: `flowchart TD
  MT{"Mount NEUTRO"} --> H["Welcome · Hero"]
  H --> C["Chooser · 3 ramas"]
  C -->|"Vengo por un grupo"| GC["¿Cómo empiezas con tu grupo?"]
  GC -->|"Crear mi primer grupo"| GG{"LA PUERTA<br/>canal → visita → datos ajenos"}
  GG -->|"cerrada · 3 copys"| GBLK["Puerta cerrada"]
  GBLK -->|"Volver"| GC
  GG -->|"abre"| PUER{"Tabla de las CUATRO puertas"}
  PUER --> EDU["Educativo del tab Grupos"]
  EDU --> GSI["Sign-in de Grupos"]
  GSI --> CONS["Consent de Grupos"]
  CONS --> CC{"El consent viaja con la cuenta"}
  CC --> NAME["«¿Cómo te llamas?»"]
  NAME --> WRITE{"El alta: 6 keys, y solo aquí"}
  WRITE --> ADOP["Entrar al tab ES la adopción"]
  ADOP --> EMPTY["Empty state · CINCO casos"]
  EMPTY --> CREAR["Crear grupo · sign-in contextual"]
  OB["Onboarding · paso Propósito"] -->|"card «Solo grupos»"| MURO["Muro iCloud del selector"]
  MURO --> GO["La card ya no cierra el alta: la CEDE"]
  GO --> PUER
  CANC{{"Matriz de cancelación del organizador"}}
  COFF["Crear grupo con el canal apagado"]
  LEG["El barrido de los grupos de la era CloudKit"]
  SP{"Camino de sign-out"} --> SH["Hoja de alcance"]
  SH --> PA["Push-all previo"]
  PA --> REL["Cover terminal de cierre"]
  EXIT["«Salir de Yala en este dispositivo»"]
  VAC["Vaciar mis datos"]
  DEL["Eliminar mi cuenta"]
  click MT call showNode("degradado-neutro")
  click H call showNode("alta-hero")
  click C call showNode("alta-chooser")
  click GC call showNode("alta-groupschooser")
  click GG call showNode("alta-groupsgate")
  click GBLK call showNode("alta-groupsgate-blocked")
  click PUER call showNode("onboarding-puertas")
  click EDU call showNode("onboarding-educativo")
  click GSI call showNode("onboarding-groupssignin")
  click CONS call showNode("onboarding-consent")
  click CC call showNode("onboarding-consentcuenta")
  click NAME call showNode("alta-organizername")
  click WRITE call showNode("alta-organizerwrite")
  click ADOP call showNode("onboarding-adopcion")
  click EMPTY call showNode("onboarding-empty")
  click CREAR call showNode("onboarding-crear")
  click OB call showNode("onboarding-purpose")
  click MURO call showNode("onboarding-muro")
  click GO call showNode("onboarding-groupsonly")
  click CANC call showNode("alta-organizercancel")
  click COFF call showNode("onboarding-canalapagado")
  click LEG call showNode("degradado-legacyretire")
  click SP call showNode("signout-path")
  click SH call showNode("signout-hoja")
  click PA call showNode("signout-pushall")
  click REL call showNode("signout-relaunch")
  click EXIT call showNode("signout-exityala")
  click VAC call showNode("signout-vaciar")
  click DEL call showNode("signout-borrarcuenta")`
  },

  {
    id: "r5",
    title: "5 · Vuelvo a Yala en un móvil nuevo",
    lede: "Segundo dispositivo o reinstalación: el faro, el guard cross-cuenta y el adopt. **Aquí la app se ve VACÍA tras el relanzamiento y ninguna superficie lo explica** —el banner que lo diría excluye justo a quien vuelve—, y encima el arranque re-arma el checklist de instalación nueva. Incluye la reinstalación con la llave de App Attest muerta y las dos puertas que el kill-switch cierra a la vez.",
    graph: `flowchart TD
  ARR{"Primer arranque:<br/>qué sobrevivió y qué no"} --> MT{"Mount NEUTRO"}
  MT --> H["Welcome · Hero"]
  H --> C["Chooser · 3 ramas"]
  C --> F{"El faro"}
  F --> MN["Móvil NUEVO: hay sign-in"]
  MN --> RC["Sub-chooser «Ya tengo una cuenta»"]
  RC --> RI["Intro de re-entrada"]
  RI --> CON["Consentimiento"]
  CON --> SI["Sign-in"]
  SI --> CW{"Dónde se registra el consent"}
  CW --> EX{"GET /account/exists"}
  EX --> GU{"Guard cross-cuenta"}
  GU --> AV{"El adopt sobre un store VACÍO"}
  AV --> AD["Adopt en curso"]
  AD --> RR{"Por qué la re-entrada SÍ relanza"}
  RR --> REL["«Cierra y reabre Yala»"]
  REL --> MM{"Guard de mount-mismatch"}
  MM --> VAC["La app aparece VACÍA"]
  VAC --> NI["Cuenta como instalación nueva"]
  NI --> ACT["Modo nube activo"]
  RE["Reinstalación en el MISMO móvil"] --> AT["La llave de attest murió con la app"]
  RE --> F
  PE{"Elegí «Restaurar desde iCloud»"} --> MR["«Un último paso: reabre Yala»"]
  MR --> ADC["Marcador de un líder en el mirror"]
  ADC --> SD{"Paso de auth"}
  SD --> PROG["Migración en curso"]
  PROG --> MREL["Card BLOQUEANTE de relanzamiento"]
  MIS["Firmaste con el método equivocado"]
  NF["Sin cuenta para este Apple ID"]
  FB["Falso bloqueo: restaurar → atrás → cuenta"]
  BLK["Bloqueado · datos de otra identidad"]
  RU["Continuar como returning-user"]
  WL["Esperar al líder"]
  CLM["Otro device lidera"]
  AR["Detector de adopt aparcado"]
  ERR{"Los errores de la re-entrada"}
  E401["401"]
  E403["403"]
  ETR["Transitorio"]
  SR["Sin red"]
  KMA["Maté la app a mitad del adopt"]
  RKS["Con el kill-switch, quien reinstala se queda fuera"]
  KS{{"Kill-switch remoto puesto"}}
  click ARR call showNode("reentry-arranque")
  click MT call showNode("degradado-neutro")
  click H call showNode("alta-hero")
  click C call showNode("alta-chooser")
  click F call showNode("alta-faro")
  click MN call showNode("reentry-movilnuevo")
  click RC call showNode("reentry-chooser")
  click RI call showNode("reentry-intro")
  click CON call showNode("alta-consent")
  click SI call showNode("alta-signin")
  click CW call showNode("reentry-consentwrite")
  click EX call showNode("reentry-exists")
  click GU call showNode("reentry-guard")
  click AV call showNode("reentry-adoptvacio")
  click AD call showNode("reentry-adopt")
  click RR call showNode("reentry-relanzamientoR5")
  click REL call showNode("reentry-relaunch")
  click MM call showNode("degradado-mount")
  click VAC call showNode("reentry-vacio")
  click NI call showNode("reentry-nuevainstalacion")
  click ACT call showNode("migracion-cloudactive")
  click RE call showNode("reentry-mismomovil")
  click AT call showNode("reentry-attestmuerta")
  click PE call showNode("reentry-puertaequivocada")
  click MR call showNode("alta-mirrorrelaunch")
  click ADC call showNode("migracion-adopt-copy")
  click SD call showNode("migracion-signin-decision")
  click PROG call showNode("migracion-progreso")
  click MREL call showNode("migracion-relaunch")
  click MIS call showNode("reentry-mismatch")
  click NF call showNode("reentry-notfound")
  click FB call showNode("reentry-falsobloqueo")
  click BLK call showNode("reentry-blocked")
  click RU call showNode("alta-returning")
  click WL call showNode("alta-waitingleader")
  click CLM call showNode("degradado-claiming")
  click AR call showNode("reentry-autoresume")
  click ERR call showNode("reentry-errores")
  click E401 call showNode("alta-error-401")
  click E403 call showNode("alta-error-403")
  click ETR call showNode("alta-error-transient")
  click SR call showNode("degradado-sinred")
  click KMA call showNode("reentry-killmidadopt")
  click RKS call showNode("reentry-killswitch")
  click KS call showNode("degradado-killswitch")`
  },

  {
    id: "r6",
    title: "6 · Soy privada y salgo de Yala",
    lede: "La fila dice **«Cerrar sesión»**, no «Salir de Yala en este dispositivo» —esa es de otro humano— y su camino no toca ni un dato: devuelve al Welcome en la misma sesión. Lo interesante empieza ahí: **las SEIS salidas del Welcome tienen políticas distintas sobre los datos que siguen en el móvil**, y una de ellas ya borró dos preferencias antes de preguntar.",
    graph: `flowchart TD
  FILA["Ajustes · la fila por la que se sale"] --> SP{"Camino de sign-out"}
  SP --> SH["Hoja de alcance"]
  SH --> HP["La hoja de una persona privada"]
  HP --> EJ{"Qué hace .privateReset"}
  EJ --> WC["El Welcome sobre un móvil LLENO"]
  WC --> H["Welcome · Hero"]
  H --> C["Chooser · 3 ramas"]
  C --> MX{"Las SEIS salidas<br/>sobre un móvil CON datos"}
  MX -->|"Es mi primera vez"| AL["«Empezar desde cero» · el alert que borra"]
  AL --> PRIV["Onboarding privado"]
  MX -->|"Ya tengo cuenta"| RC["Sub-chooser existente"]
  RC --> RV["Restaurar de iCloud · la vuelta a casa"]
  RV --> RE["Los cuatro finales no-felices"]
  MX -->|"Vengo por un grupo"| GB["«Este dispositivo tiene datos de otra cuenta»"]
  MX -->|"cuenta nube"| GU{"Guard cross-cuenta"}
  GU --> BLK["Bloqueado · datos de otra identidad"]
  L5["La hoja del solo-grupos legado 5a"] --> EXIT["«Salir de Yala en este dispositivo»"]
  click FILA call showNode("signout-fila-privada")
  click SP call showNode("signout-path")
  click SH call showNode("signout-hoja")
  click HP call showNode("signout-hoja-privada")
  click EJ call showNode("signout-privado-ejecucion")
  click WC call showNode("signout-welcome-condatos")
  click H call showNode("alta-hero")
  click C call showNode("alta-chooser")
  click MX call showNode("signout-salidas-matriz")
  click AL call showNode("signout-freshstart-alert")
  click PRIV call showNode("alta-privado")
  click RC call showNode("reentry-chooser")
  click RV call showNode("signout-restaurar-vuelta")
  click RE call showNode("signout-restaurar-errores")
  click GB call showNode("alta-groupsgate-blocked")
  click GU call showNode("reentry-guard")
  click BLK call showNode("reentry-blocked")
  click L5 call showNode("signout-hoja-legado5a")
  click EXIT call showNode("signout-exityala")`
  },

  {
    id: "r7",
    title: "7 · Soy de la nube y cierro sesión",
    lede: "El cierre `.cloud`: drena el outbox —**jamás descarta lo que no subió**—, arma el wipe por archivos y, desde R4, intenta el cambio de persona sin reiniciar. El cover «cierra y reabre» sigue existiendo como camino DEGRADADO, con el canario `swapReleaseAborted` como firma. Con las otras dos filas de la misma pantalla: vaciar datos y eliminar la cuenta.",
    graph: `flowchart TD
  ACT["Modo nube activo"] --> SES["Sesión caducada con cambios pendientes"]
  ACT --> SP{"Camino de sign-out<br/>precedencia CONGELADA"}
  SP --> SH["Hoja de alcance · 3 filas"]
  SH --> PA["Push-all previo al cierre"]
  PA --> SW{"¿Swap de persona sin relanzar?"}
  SW -->|"sí"| SWAP["Cambio de persona in-process"]
  SW -->|"no · degradado"| REL["Cover terminal + wipe al boot"]
  REL --> MT{"Al reabrir: mount NEUTRO"}
  VAC["Vaciar mis datos"]
  DEL["Eliminar mi cuenta"]
  click ACT call showNode("migracion-cloudactive")
  click SES call showNode("degradado-sesion")
  click SP call showNode("signout-path")
  click SH call showNode("signout-hoja")
  click PA call showNode("signout-pushall")
  click SW call showNode("signout-swap")
  click SWAP call showNode("signout-swap")
  click REL call showNode("signout-relaunch")
  click MT call showNode("degradado-neutro")
  click VAC call showNode("signout-vaciar")
  click DEL call showNode("signout-borrarcuenta")`
  },

  {
    id: "r8",
    title: "8 · Paso de privada a la nube",
    lede: "La migración desde Ajustes → «Dónde viven tus datos»: dry-run → consent → sign-in → claim → upload → verify → cutover → relanzamiento. Con el Retomar, el re-kick y el rollback con copy por MOTIVO. El cutover tiene cuatro sub-estados en orden estricto y es la frontera del rollback.",
    graph: `flowchart TD
  FILA["Ajustes · «Dónde viven tus datos»"] --> IDLE["Almacenamiento · estado iCloud"]
  IDLE --> SD{"Paso de auth"}
  SD --> SI["Sign-in"]
  SI --> CON["Consentimiento"]
  CON --> CONF["Doble confirmación destructiva"]
  CONF --> ADC["Variante ADOPT · marcador de líder"]
  ADC --> PROG["Migración en curso · fases journaleadas"]
  PROG --> CUT["Cutover · 4 sub-estados"]
  CUT --> REL["Card BLOQUEANTE de relanzamiento"]
  REL --> MM{"Guard de mount-mismatch"}
  MM --> ACT["Modo nube activo"]
  PROG -->|"falla"| FALL["Rollback · copy por MOTIVO"]
  SR["Sin red"]
  CLM["Otro device lidera"]
  SES["Sesión caducada"]
  KS{{"Kill-switch remoto"}}
  click FILA call showNode("migracion-fila")
  click IDLE call showNode("migracion-idle")
  click SD call showNode("migracion-signin-decision")
  click SI call showNode("alta-signin")
  click CON call showNode("alta-consent")
  click CONF call showNode("migracion-confirm")
  click ADC call showNode("migracion-adopt-copy")
  click PROG call showNode("migracion-progreso")
  click CUT call showNode("migracion-cutover")
  click REL call showNode("migracion-relaunch")
  click MM call showNode("degradado-mount")
  click ACT call showNode("migracion-cloudactive")
  click FALL call showNode("migracion-fallo")
  click SR call showNode("degradado-sinred")
  click CLM call showNode("degradado-claiming")
  click SES call showNode("degradado-sesion")
  click KS call showNode("degradado-killswitch")`
  },

  {
    id: "r9",
    title: "9 · Vuelvo de la nube a privada",
    lede: "La reversa: las fases `reverse*` y el cuarteto de cierre, con lo que ve el usuario en cada una. **La frontera del rollback es el montaje del mirror**: antes se puede volver atrás, después ya no.",
    graph: `flowchart TD
  ACT["Modo nube activo"] --> FILA["Ajustes · «Dónde viven tus datos»"]
  FILA --> CARD["Card «Volver a iCloud»"]
  CARD --> CONF["Doble confirmación de reversa"]
  CONF --> FAS["Fases de la reversa"]
  FAS --> REL["Relanzamiento de reversa"]
  REL --> MM{"Guard de mount-mismatch"}
  MM --> CIE["Cuarteto de cierre + terminal"]
  CIE --> IDLE["Almacenamiento · estado iCloud"]
  click ACT call showNode("migracion-cloudactive")
  click FILA call showNode("migracion-fila")
  click CARD call showNode("reversa-card")
  click CONF call showNode("reversa-confirm")
  click FAS call showNode("reversa-fases")
  click REL call showNode("reversa-relaunch")
  click MM call showNode("degradado-mount")
  click CIE call showNode("reversa-cierre")
  click IDLE call showNode("migracion-idle")`
  },

  {
    id: "r10",
    title: "10 · Estoy de visita en el móvil de otra persona",
    lede: "La sesión secundaria y sus fronteras. De las **cuatro cosas que la visita puede intentar desde el Welcome, solo UNA tiene puerta**: crear un grupo. Las otras tres —entrar a su cuenta, crear una cuenta nueva y «privacidad total»— pasan, y la última escribe en el dominio del dueño sin que nada la detenga. Cuatro hallazgos medidos viven aquí.",
    graph: `flowchart TD
  GU{"Guard cross-cuenta"} --> SEC["Confirmación de sesión secundaria"]
  SEC --> SLOT["El hueco de invitada ya es de otra"]
  SEC --> REL["Adopt completo · «Cierra y reabre»"]
  REL --> ST{"De quién es cada cajón"}
  ST --> SHELL["La app que ve mientras baja su cuenta"]
  SHELL --> AJU["Los cuatro ajustes del dueño que no toca"]
  AJU --> FRO{"La frontera de los cuatro guards"}
  FRO --> VAC["«Vaciar mis datos»: la puerta de vuelta"]
  VAC --> C["Chooser · 3 ramas"]
  C --> VC["El chooser con la sesión de visita viva"]
  VC -->|"Vengo por un grupo"| GC["¿Cómo empiezas con tu grupo?"]
  GC --> CG["Intento 1 · «Crear mi primer grupo»"]
  CG --> GBLK["La ÚNICA con puerta: bloqueada"]
  VC -->|"Ya tengo una cuenta"| RE["Intento 2a · entrar a MI cuenta"]
  RE --> BLK["Bloqueado · datos de otra identidad"]
  VC -->|"Restaurar de iCloud"| RI["Intento 2b · sobre un store sin espejo"]
  VC -->|"cuenta nube nueva"| CN["Intento 3 · escribe el FARO del dueño"]
  VC -->|"privacidad total"| PRIV["Intento 4 · la rama SIN puerta"]
  PRIV --> PAL["¿Salta el alert de borrado?"]
  PAL --> PON["El onboarding en el móvil del dueño"]
  SP{"Camino de sign-out"} --> SH["Hoja de alcance"]
  SH --> SAL["La frontera de salida"]
  click GU call showNode("reentry-guard")
  click SEC call showNode("reentry-secondary")
  click SLOT call showNode("reentry-slotocupado")
  click REL call showNode("reentry-relaunch")
  click ST call showNode("visita-stores")
  click SHELL call showNode("visita-shell")
  click AJU call showNode("degradado-ajustesdueno")
  click FRO call showNode("visita-frontera-prefs")
  click VAC call showNode("visita-vaciar")
  click C call showNode("alta-chooser")
  click VC call showNode("visita-chooser")
  click GC call showNode("alta-groupschooser")
  click CG call showNode("visita-crear-grupo")
  click GBLK call showNode("alta-groupsgate-blocked")
  click RE call showNode("visita-reentrar-cuenta")
  click BLK call showNode("reentry-blocked")
  click RI call showNode("visita-restaurar-icloud")
  click CN call showNode("visita-cuenta-nueva")
  click PRIV call showNode("visita-privado")
  click PAL call showNode("visita-privado-alert")
  click PON call showNode("visita-privado-onboarding")
  click SP call showNode("signout-path")
  click SH call showNode("signout-hoja")
  click SAL call showNode("visita-salida")`
  },

  {
    id: "r11",
    title: "11 · El dueño recupera su móvil",
    lede: "La salida de la visita y la vuelta del dueño. El cierre secundario **solo empuja UN outbox de los dos** mientras el wipe borra los dos archivos, cualquier bloqueo se le presenta a la visita como permanente («revisa tu conexión»), y el dueño reabre encontrándose el Welcome en vez de su app. Con el inventario medido de lo que la visita deja atrás.",
    graph: `flowchart TD
  AJU["La visita busca la salida"] --> SP{"Camino de sign-out"}
  SP --> SH["Hoja de alcance"]
  SH --> HJ["La hoja de la despedida"]
  HJ --> PA["Push-all previo"]
  PA --> VPA["Lo que Yala sí sube"]
  VPA --> NOG{"Lo que NO sube: el outbox de Grupos"}
  NOG --> ARM{"Qué se arma, y qué JAMÁS"}
  ARM --> COV["«Ya casi está — reinicia Yala»"]
  COV --> REL["Cover terminal de cierre"]
  REL --> BOOT{"El arranque siguiente"}
  BOOT --> WEL["El dueño se encuentra el Welcome"]
  WEL --> MT{"Mount NEUTRO"}
  MT --> RES["«Restaurar de iCloud»: vuelve a su app"]
  RES --> QUE{"Qué queda de la visita"}
  QUE --> AJD["Los cuatro ajustes del dueño"]
  AJD --> CONS["El permiso de Grupos se va con la visita"]
  BLQ["«No pudimos cerrar tu sesión»"]
  CAD{"La sesión de la visita caducó"}
  KILL{"Salida a medias: las tres ventanas"}
  AB{"Si el borrado falla"}
  click AJU call showNode("vuelta-salida-ajustes")
  click SP call showNode("signout-path")
  click SH call showNode("signout-hoja")
  click HJ call showNode("vuelta-hoja")
  click PA call showNode("signout-pushall")
  click VPA call showNode("vuelta-pushall")
  click NOG call showNode("vuelta-gruposnoempuja")
  click ARM call showNode("vuelta-armado")
  click COV call showNode("vuelta-cover")
  click REL call showNode("signout-relaunch")
  click BOOT call showNode("vuelta-boot")
  click WEL call showNode("vuelta-welcome")
  click MT call showNode("degradado-neutro")
  click RES call showNode("vuelta-restaurar")
  click QUE call showNode("vuelta-queda")
  click AJD call showNode("degradado-ajustesdueno")
  click CONS call showNode("vuelta-consent")
  click BLQ call showNode("vuelta-bloqueado")
  click CAD call showNode("vuelta-sesioncaducada")
  click KILL call showNode("vuelta-kill")
  click AB call showNode("vuelta-abort")`
  }
];

window.ATLAS_COVERAGE = [
  { logic: "AccountClaimDecision.decide", file: "Yala/Services/CloudSync/AccountClaimDecision.swift:71",
    cells: 10, tests: "6 · YalaTests/CloudSync/AccountClaimDecisionTests.swift", drawn: 4, flow: "alta",
    delta: "Las 3 celdas de la rama `.bornCloud` se dibujan como branches propios y la variante B va punteada (inalcanzable). Las 6 celdas de `.migration` y `.returningUser` NO se dibujan una a una: esos dos flujos entran por la máquina de migración y por `exists`, no por esta tabla, y dibujarlas ahí duplicaría la decisión." },

  { logic: "BornCloudSignUpFlow.step", file: "Yala/App/Logic/CloudWelcomeSignInFlow.swift:146",
    cells: 7, tests: "15 · YalaTests/CloudSync/BornCloudSignUpFlowTests.swift", drawn: 7, flow: "alta", delta: "" },

  { logic: "CloudWelcomeSignInFlow.route", file: "Yala/App/Logic/CloudWelcomeSignInFlow.swift:80",
    cells: 4, tests: "18 · YalaTests/CloudWelcomeSignInFlowTests.swift", drawn: 3, flow: "reentry",
    delta: "`sessionExpired` y `transient` colapsan en el diagrama a una sola arista porque la tabla los colapsa antes: los dos dan `failed(retryable: true)`." },

  { logic: "CloudWelcomeSignInFlow.phase(for:)", file: "Yala/App/Logic/CloudWelcomeSignInFlow.swift:92",
    cells: 8, tests: "18 · YalaTests/CloudWelcomeSignInFlowTests.swift", drawn: 8, flow: "reentry",
    delta: "" },

  { logic: "WelcomeAdoptAutoResume.tick", file: "Yala/App/Logic/CloudWelcomeSignInFlow.swift:204",
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

  { logic: "MigrationRuntimeGate.isPersonalMountMismatch", file: "Yala/Services/CloudSync/MigrationBootDecision.swift:85",
    cells: 10, tests: "6 · YalaTests/CloudSync/PersonalMountMismatchGuardTests.swift", drawn: 2, flow: "degradado",
    delta: "R1 cambió el segundo parámetro de un `StorageMode` de dos valores a la DECISIÓN de mount (5 casos) ⇒ 2 modos × 5 decisiones. Se dibujan las dos salidas; el reparto lo da el eje `attachesCloudKitMirror` y vive en los paneles de mount-mismatch y del mount neutro. En `.icloud` el predicado es `false` por construcción ⇒ las 5 celdas de ese modo son inertes." },

  { logic: "SwiftDataConfiguration.personalStoreDecision", file: "Yala/Utils/SwiftDataConfiguration.swift:333",
    cells: 5, tests: "25 · YalaTests/CloudSync/NeutralMountRelaunchZeroTests.swift (+14 en StorageModePersistenceTests)", drawn: 3, flow: "alta · degradado",
    delta: "R2/R4: las 5 salidas de la tabla de mounts. Se dibujan las tres que el Welcome puede observar (neutro, mirror adjunto, y el par `.cloud` ya armado); `secondaryCloudSession` vive en el flujo 2 (M1, DARK) y `localNoMirror`/`iCloudMirror` colapsan en «el mount adjunta mirror», que es lo que decide el eje." },

  { logic: "SwiftDataConfiguration.isFreshInstallForNeutralMount", file: "Yala/Utils/SwiftDataConfiguration.swift:266",
    cells: 5, tests: "25 · YalaTests/CloudSync/NeutralMountRelaunchZeroTests.swift", drawn: 2, flow: "degradado",
    delta: "4 términos AND ⇒ el diagrama dibuja «es fresh» / «no es fresh»; los 4 términos y por qué el primero (sin archivo de store) es la protección estructural del parque van en el panel del mount neutro." },

  { logic: "SwiftDataConfiguration.shouldMountNeutralDurable", file: "Yala/Utils/SwiftDataConfiguration.swift:296",
    cells: 4, tests: "26 · YalaTests/CloudSync/PersonalSwapReleaseTests.swift", drawn: 2, flow: "degradado · signout",
    delta: "2 términos ⇒ 4 celdas, 2 salidas dibujadas. El segundo (`hasShownWelcomeChooser == false`) es lo que hace el bucle imposible y se explica en el panel." },

  { logic: "PersonalStoreDecision · los 3 ejes (attachesCloudKitMirror · mirrorsToICloud · isCloudModeMount)", file: "Yala/Utils/SwiftDataConfiguration.swift:377",
    cells: 15, tests: "20 · YalaTests/CloudSync/PersonalMountWitnessTests.swift", drawn: 3, flow: "degradado",
    delta: "5 decisiones × 3 ejes. Los ejes NO se dibujan uno a uno: son la traducción que cada consumidor hace del testigo, y dibujarlos convertiría una lectura en una pantalla. El reparto completo está en los paneles del mount neutro y del guard de mount-mismatch, con la medición de `.automatic` que decide la celda de `localNoMirror`." },

  { logic: "WelcomeMirrorRelaunchLogic.requiresMirror", file: "Yala/App/Logic/WelcomeMirrorRelaunchLogic.swift:78",
    cells: 5, tests: "25 · YalaTests/CloudSync/NeutralMountRelaunchZeroTests.swift", drawn: 5, flow: "alta · reentry", delta: "" },

  { logic: "WelcomeMirrorRelaunchLogic.shouldRelaunch", file: "Yala/App/Logic/WelcomeMirrorRelaunchLogic.swift:94",
    cells: 10, tests: "25 · YalaTests/CloudSync/NeutralMountRelaunchZeroTests.swift", drawn: 2, flow: "alta · reentry",
    delta: "5 destinos × «mount neutro sí/no». Se dibujan las dos salidas del portal; el reparto por destino ya está dibujado en `requiresMirror`, y comparar contra `.neutralNoMirror` y no contra `!attachesCloudKitMirror` es la decisión que el panel explica." },

  { logic: "RelaunchNetLogic.shouldExitOnBackground", file: "Yala/App/Logic/RelaunchNetLogic.swift:86",
    cells: 24, tests: "17 · YalaTests/RelaunchNetLogicTests.swift", drawn: 1, flow: "alta · signout",
    delta: "3 fases de escena × los 3 términos durables (sign-out en `awaitingRelaunch`, entrada secundaria armada sin montar, destino del Welcome pendiente). R0 la volvió EXHAUSTIVA en tests porque antes cada término tenía su test suelto y la combinatoria no existía. En el diagrama es una arista —el auto-exit— porque no cambia de pantalla: mata el proceso." },

  { logic: "PersonalSwapReleaseLogic.verdict / authorizesWipe / mountAdmitsSwap", file: "Yala/App/Logic/PersonalSwapReleaseLogic.swift:57",
    cells: 8, tests: "26 · YalaTests/CloudSync/PersonalSwapReleaseTests.swift", drawn: 4, flow: "signout",
    delta: "3 veredictos (`released` · `abortObjectAlive` · `abortDescriptorsOpen`) + la admisión por mount. Se dibujan las 4 salidas del swap; que «release verificado» exija los DOS instrumentos —sentinel y descriptores— es lo que carga el peso y va en el panel." },

  { logic: "MigrationRuntimeGate.isDomainStablePhase", file: "Yala/Services/CloudSync/MigrationBootDecision.swift:90",
    cells: 21, tests: "35 · YalaTests/CloudSync/CloudMigrationI14Tests.swift", drawn: 2, flow: "degradado",
    delta: "COLAPSO DECLARADO: las 21 fases se agrupan en «estable» (`done`, `notStarted`) y «transicional» (las otras 19). Las fases sí se dibujan una a una, pero en los flujos 3 y 4, que es donde son observables." },

  { logic: "MigrationBootDecision.decide", file: "Yala/Services/CloudSync/MigrationBootDecision.swift:123",
    cells: 22, tests: "35 · YalaTests/CloudSync/CloudMigrationI14Tests.swift", drawn: 3, flow: "migracion",
    delta: "Igual: 1 fila de «hay efectos pendientes» + 21 fases → 3 decisiones (`resume` · `pollLeader` · `none`). Se dibujan las 3 decisiones; el mapeo fase→decisión vive en el panel." },

  { logic: "MigrationForegroundRekick.shouldRekick", file: "Yala/Services/CloudSync/MigrationBootDecision.swift:150",
    cells: 2, tests: "35 · YalaTests/CloudSync/CloudMigrationI14Tests.swift", drawn: 2, flow: "migracion", delta: "" },

  { logic: "CloudMigrationUIStateDeriver.derive", file: "Yala/Services/CloudSync/CloudMigrationController.swift:71",
    cells: 10, tests: "35 · YalaTests/CloudSync/CloudMigrationI14Tests.swift", drawn: 8, flow: "migracion · reversa",
    delta: "Sus 8 estados de UI se dibujan todos. Las 2 celdas no dibujadas son la normalización de `dryRun` por modo, que no tiene pantalla propia (cae en `idle` o `cloudActive`)." },

  { logic: "CloudMigrationUIStateDeriver.fraction(for:)", file: "Yala/Services/CloudSync/CloudMigrationController.swift:117",
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

  { logic: "StorageRowGateLogic.isVisible", file: "Yala/App/Logic/StorageRowGateLogic.swift:50",
    cells: 4, tests: "11 · YalaTests/CloudSync/RemoteFlagDecisionLogicTests.swift (suites StorageRowGateLogicTests + DevSecondaryDescriptorSignalTests)", drawn: 4, flow: "migracion · degradado", delta: "" },

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

  { logic: "GroupsOnboardingLogic.shouldShow", file: "Yala/App/Logic/GroupsOnboardingLogic.swift:56",
    cells: 4, tests: "14 · YalaTests/GroupsOnboardingLogicTests.swift", drawn: 2, flow: "onboarding",
    delta: "AND-gating de 3 bloqueadores → se dibuja «se muestra» / «no se muestra»; los 3 bloqueadores se listan en el panel." },

  { logic: "GroupsOnboardingLogic.shouldShowSignInCTA", file: "Yala/App/Logic/GroupsOnboardingLogic.swift:84",
    cells: 4, tests: "14 · YalaTests/GroupsOnboardingLogicTests.swift", drawn: 2, flow: "onboarding",
    delta: "3 términos, dos resultados. Las negaciones van en el panel." },

  { logic: "GroupsEmptyStateLogic.decide", file: "Yala/App/Logic/GroupsEmptyStateLogic.swift:67",
    cells: 3, tests: "8 · YalaTests/GroupsEmptyStateLogicTests.swift", drawn: 2, flow: "onboarding",
    delta: "«flag OFF» y «flag ON con sesión» colapsan los dos en `.standard`, igual que en la tabla." },

  { logic: "GroupCreateRoutingLogic.route", file: "Yala/App/Logic/GroupCreateRoutingLogic.swift:28",
    cells: 4, tests: "13 · YalaTests/GroupCreateRoutingLogicTests.swift", drawn: 4, flow: "onboarding", delta: "" },

  { logic: "SessionExpiryPolicy.decide", file: "Yala/Services/CloudSync/SessionExpiryPolicy.swift:34",
    cells: 3, tests: "5 · YalaTests/CloudSync/SessionExpiryPolicyTests.swift", drawn: 2, flow: "degradado",
    delta: "«sin pendientes» y «sesión renovable» colapsan en `.ok`, igual que en la tabla." },

  { logic: "CloudRemoteFlags (cloudMode · onboardingChoice · groupsBackend)", file: "Yala/Services/CloudSync/CloudRemoteConfig.swift:134",
    cells: 6, tests: "11 · YalaTests/CloudSync/RemoteFlagDecisionLogicTests.swift", drawn: 3, flow: "degradado",
    delta: "Se dibuja el efecto de cada flag apagado. Las tres celdas de «encendido» son el camino normal, ya dibujado en los flujos 1, 2 y 6." },

  // ── F5 (2026-08-12): la lógica que trajeron las olas W · G · C · M ──────────────────────────────

  { logic: "GroupsOrganizerGateLogic.decide", file: "Yala/App/Logic/GroupsOrganizerGateLogic.swift:78",
    cells: 8, tests: "25 · YalaTests/Groups/GroupsOrganizerBranchTests.swift", drawn: 4, flow: "alta",
    delta: "3 booleanos ⇒ 8 celdas, 4 clases por cortocircuito. Se dibujan las 4 salidas; las 8 celdas las barre `proceedNeedsAllThreeTerms` con un bucle 2×2×2 y la PRECEDENCIA la fijan dos tests propios, que es lo que de verdad carga el peso aquí." },

  { logic: "GroupsGateLogic.nextStep", file: "Yala/App/Logic/GroupsGateLogic.swift:105",
    cells: 18, tests: "20 · YalaTests/GroupsGateLogicTests.swift", drawn: 7, flow: "onboarding",
    delta: "4 entradas × sus escalones alcanzables = 18 clases (5 organizador + 5 card «Solo grupos» + 5 invitación + 3 tab). Se dibujan los 7 `Step`; el reparto por entrada vive en el panel, porque dibujar las cuatro columnas sería el mismo grafo cuatro veces." },

  { logic: "GroupsGateLogic.Entry.showsEducationalFirst", file: "Yala/App/Logic/GroupsGateLogic.swift:135",
    cells: 4, tests: "20 · YalaTests/GroupsGateLogicTests.swift", drawn: 2, flow: "onboarding",
    delta: "Las dos entradas que dicen `false` NO se saltan el educativo: lo montan en otro sitio del recorrido (el invitado, el suyo contextual después del consent; el tab, el sheet que ya presenta al montarse). Esa tabla de cuatro filas está en el panel." },

  { logic: "GroupsEmptyStateLogic.decide", file: "Yala/App/Logic/GroupsEmptyStateLogic.swift:67",
    cells: 6, tests: "8 · YalaTests/GroupsEmptyStateLogicTests.swift", drawn: 5, flow: "onboarding",
    delta: "C2 la llevó de 3 a 6 clases (canal OFF · educativo · nunca-tuvo-cuenta · ya-tuvo · sin consent · completo). Se dibujan los 5 casos con copy; la sexta es «canal OFF ⇒ estándar», que colapsa en el mismo nodo porque pinta exactamente lo mismo." },

  { logic: "GroupCreateRoutingLogic.route", file: "Yala/App/Logic/GroupCreateRoutingLogic.swift:76",
    cells: 8, tests: "13 · YalaTests/GroupCreateRoutingLogicTests.swift", drawn: 4, flow: "onboarding",
    delta: "C4 · 2×2×2 = 8 celdas y cuatro rutas. Las CUATRO celdas con el canal apagado devolvían `.cloudKit` —que acuñaba un grupo local irrecuperable— y hoy devuelven `.channelOff`. Se dibujan las 4 rutas." },

  { logic: "CloudConsentRegistrationLogic.placement / persistIfDue", file: "Yala/App/Logic/CloudConsentRegistrationLogic.swift:44",
    cells: 3, tests: "11 · YalaTests/CloudSync/CloudConsentRegistrationTests.swift", drawn: 3, flow: "reentry",
    delta: "M0 · total sobre las TRES salidas del guard cross-cuenta: añadir una cuarta obliga a decidir aquí su destino. Las tres se dibujan como un nodo de decisión; las 8 combinaciones de `persistIfDue` no, porque son la mecánica del consumo (`pending` como `inout`), no una bifurcación de pantalla." },

  { logic: "SecondarySlotOccupancyLogic.decide", file: "Yala/App/Logic/SecondarySlotOccupancyLogic.swift:46",
    cells: 3, tests: "7 · YalaTests/CloudSync/SecondaryOwnerDomainGuardsTests.swift", drawn: 2, flow: "reentry",
    delta: "M1 · hueco libre · misma cuenta · ocupado por otra. Se dibujan las dos salidas visibles (pasa / bloquea); «misma cuenta» comparte arista con «libre» porque las dos siguen, y su porqué —la re-entrada idempotente de quien murió entre el descriptor y el relanzamiento— va en el panel." },

  { logic: "GroupsConsentDecisionLogic.isAccepted", file: "Yala/App/Logic/GroupsConsentDecisionLogic.swift:53",
    cells: 3, tests: "26 · YalaTests/GroupsConsentStateTests.swift", drawn: 1, flow: "onboarding",
    delta: "C1 · las tres reglas del sello (sin snapshot · versión por debajo de la sustantiva · sello que contradice al `sub` vivo) producen un solo booleano, que es el término `isConsented` de la tabla de puertas. No se dibujan una a una: van en el panel del consent." },

  { logic: "WelcomeNewChooserView.displayOrder", file: "Yala/App/Views/Onboarding/WelcomeNewChooserView.swift:100",
    cells: 2, tests: "7 · YalaTests/WelcomeNewChooserOrderTests.swift", drawn: 0, flow: "—",
    delta: "NO se dibuja y no debe: es el ORDEN de dos cards en una pantalla, no una bifurcación. Está aquí porque W3 lo convirtió en contrato con test propio, y porque el sitio donde vive —la vista, no `visibleNewOptions`— es justo lo que el yo-futuro se equivocaría al buscar." }
];

// Hallazgos: lo que el Atlas encontró al derivarse del CÓDIGO y que el diseño no dice (o dice al revés).
window.ATLAS_FINDINGS = [
  {
    id: "F5-H1",
    sev: "alto · contradice el consent",
    title: "La pantalla de novedades de la 2.0 sigue diciendo que los gastos de grupo viajan «por tu iCloud privado, sin servidores nuestros» — y es alcanzable hoy",
    body: "MEDIDO el 2026-08-12 contra `6c6eb3fe`, con la key delante: `whatsNew.v20.groups.description` = «Crea grupos para compartir gastos y Yala calcula quién le debe a quién. Y tranquilo: **todo viaja por tu iCloud privado, sin servidores nuestros**.», y su título es «Grupos (Beta)». La entrada sigue viva en `WhatsNewConfig.swift:92-98` (bloque `version2_0`), así que la ve cualquiera que actualice a una 2.0.x desde una versión anterior. Con el canal backend encendido al 100 % y el consent de Grupos afirmando lo contrario en la misma app —«viven en la nube de Yala», `groups.consent.point1`—, la app se contradice a sí misma sobre dónde están los datos del usuario, y la afirmación falsa es la que no pide confirmación. El «(Beta)» del título es además el último rastro visible de un gate que `9e504480` retiró. No es un hueco del Atlas: es copy de producción que caducó y ningún test lo mira.",
    node: "onboarding-adopcion"
  },
  {
    id: "F5-H2",
    sev: "cierre de F2-H1",
    title: "El gate beta de Grupos ya no existe: entrar al tab ES el acto de adopción",
    body: "El hallazgo F2-H1 (chip F2) decía que «el flujo 6 tiene una capa previa que el Atlas no dibuja: el GATE BETA de Grupos (código 1050)». **Queda CERRADO por `9e504480`**, y se comprobó en vez de asumirse: cero ocurrencias de `GroupsBetaGateView`, del campo del código y del gate de la opción «Grupo» del FAB, y las 6 keys del gate retiradas de los 16 idiomas. Lo único que sobrevive es el STRING de la key `groupsBetaUnlocked`, que conserva su nombre histórico a propósito —renombrarla obligaría a migrar el parque sin ganar nada— pero hoy significa otra cosa: que este dispositivo ADOPTÓ el dominio Grupos. El Atlas lo dibuja como lo que es, un nodo de decisión sin pantalla.",
    node: "onboarding-adopcion"
  },
  {
    id: "F5-H3",
    sev: "alto · sigue abierto",
    title: "El agujero de datos del alta «Solo grupos» no se cerró: cambió de dueño",
    body: "F1-H4 apuntaba a `completeGroupsOnlyOnboarding`, que `3a960fd9` **borró entera**. Sin re-medirlo, el borrado haría parecer que el problema se fue con la función. RE-MEDIDO el 2026-08-12: el sustituto `GroupsOrganizerOnboarding.completeSetup` **tampoco toca `storageMode`** —no aparece ni en su inventario publicado de keys ni en su cuerpo— y ninguno de los escritores del modo de storage está en la cadena de Grupos ⇒ el device sigue quedando `.icloud` y, sin cuenta iCloud del OS, monta local-sin-mirror: las `TransactionItem` puenteadas desde los gastos de grupo continúan sin ninguna copia. Lo que C2 SÍ cierra es otra cosa, y está cerrada: que el trío se escribiera sin cuenta, sin consent y sin canal comprobado. Y el retiro de los grupos de la era CloudKit no lo toca: su barrido solo alcanza zonas sin canal vivo, y un alta solo-grupos de hoy nace en el canal backend.",
    node: "onboarding-groupsonly"
  },
  {
    id: "F5-H4",
    sev: "hallazgo",
    title: "La puerta del organizador no emite un solo canario: sus tres bloqueos son invisibles en producción",
    body: "MEDIDO: en las CUATRO salidas de `GroupsOrganizerGateLogic` no hay una sola llamada a `MetricsService`. La pantalla existe justamente para rebotar al usuario antes de escribir nada —lo cual es correcto— pero «cuántos organizadores rebotan aquí, y por cuál de los tres motivos» no se puede responder desde el dashboard. El motivo del canal es transitorio y observable por otra vía (el percent remoto), pero los de sesión de visita y datos ajenos no: si el bloqueo por visita se disparara más de lo previsto, nada lo diría. Es el mismo patrón que el Atlas ya anotó en `swapReleaseAborted`, pero al revés: allí el canario ES la superficie de observación; aquí no hay ninguna.",
    node: "alta-groupsgate"
  },
  {
    id: "F5-H5",
    sev: "hallazgo",
    title: "El barrido que retira los grupos de la era CloudKit no tiene NINGUNA superficie de usuario",
    body: "MEDIDO: `LegacyGroupsRetirement.swift` no contiene una sola key de l10n, y ninguna vista lo cita. Entre un arranque y el siguiente, los grupos de la etapa CloudKit dejan de aparecer y sus espejos «presté 40» / «debo 10» desaparecen de Panel, presupuestos y reportes. Si esos eran los únicos grupos del usuario, aterriza en el empty state sin que nada le explique por qué. La única superficie es el canario `legacyGroupsRetired`, que es telemetría y no comunicación. El único sitio donde el usuario se entera de que sus grupos legacy existieron es —a propósito— el caveat GDPR de la hoja de borrado de cuenta.",
    node: "degradado-legacyretire"
  },
  {
    id: "F5-H7",
    sev: "medio · copy",
    title: "El sign-in de Grupos pide «iniciar sesión» y «crear cuenta» a la vez, y le habla solo al invitado",
    body: "MEDIDO EN PANTALLA el 2026-08-12 (sim, Yala Dev): la pantalla que sirve a las CUATRO puertas tiene el botón de Apple con `type: .signIn` («Iniciar sesión con Apple», `GroupsSignInView.swift:174`) justo encima del de Google con `purpose: .signUp` («Crear cuenta con Google», `:89-90`). Dos verbos contradictorios, uno sobre otro, para la misma acción — precisamente lo que W4b vino a arreglar en el Welcome, donde el alta dice crear y la re-entrada iniciar sesión. Y el cuerpo (`groups.signin.body`) está escrito solo para el invitado: «Para unirte al grupo… y sigue con tu invitación», que es lo que lee quien acaba de tapear «Crear mi primer grupo» y no tiene ninguna invitación. Es la misma clase de copy prestado que el bloqueo por datos ajenos de la puerta, y aquí lo ve todo el que entra a Grupos sin sesión.",
    node: "onboarding-groupssignin"
  },
  {
    id: "F5-H6",
    sev: "estado del Atlas · RESUELTO el mismo día",
    title: "OCHO capturas retrataban pantallas que la app ya no pinta, y el pin no puede verlo",
    body: "El bloque 7 de `check.mjs` comprueba que la imagen EXISTA, no que siga siendo cierta ⇒ una pantalla re-escrita deja una captura que miente en verde. F5 identificó ocho: el Hero (perdió el subtítulo), el chooser (seis de sus ocho valores), el sub-chooser de «Soy nuevo» (orden invertido y copy nuevo), el consent de nube (de siete puntos a tres), los dos intros de sign-in (cambiaron de verbo), el educativo de Grupos (punto nuevo y CTA de crear cuenta) y el cierre solo-grupos (el nodo cambió de significado). **Las OCHO se re-capturaron el 2026-08-12** en el simulador, así que `stale` queda vacío; el mecanismo se conserva porque el problema volverá a aparecer en cuanto una pantalla se re-escriba. Lo que NO se resolvió es la causa estructural: sigue sin haber nada que detecte una captura caducada, y esa detección no es barata (exigiría comparar el copy visible de la imagen con el `.strings`).",
    node: "alta-hero"
  },
  {
    id: "F1-H1",
    sev: "acotado por `339f7825`",
    title: "El guard de mount-mismatch NO tiene pantalla — y desde el relanzamiento cero su ventana se estrecha al device que YA tenía store",
    body: "El chip F1 lo describe como «el guard de mount-mismatch (la pantalla de relanzamiento pendiente)». MEDIDO: `MigrationRuntimeGate.isPersonalMountMismatch` solo apaga el motor y deja un breadcrumb; no pinta nada. La única card de relanzamiento la deriva `CloudMigrationUIStateDeriver` a partir del par armado, y vive en Almacenamiento — inalcanzable durante el alta born-cloud, porque el onboarding todavía no ha terminado. No es un bug: durante el alta la fase `.relaunch` es terminal, sin back y con `interactiveDismissDisabled()`, así que el usuario no puede escapar. **ACOTADO el 2026-08-11 (F3): en una instalación fresca la ventana ya no existe** — el mount es neutro, el guard pregunta por el eje `attachesCloudKitMirror` y DEJA PASAR, así que el motor arranca en la misma sesión. Sobrevive en el device que llega al alta con archivo de store y en el adopt, donde sigue habiendo relanzamiento. El hueco de observabilidad no se cierra: se estrecha, y ahora afecta a menos recorridos que superficie tiene.",
    node: "degradado-mount"
  },
  {
    id: "F3-H1",
    sev: "hallazgo",
    title: "El recorrido de producción de hoy —el privado— es el que PAGA el relanzamiento que el alta nube deja de pagar",
    body: "MEDIDO en sim el 2026-08-11 con una instalación limpia: «Soy nuevo → privacidad total» monta el terminal «Un último paso: reabre Yala». Con `CLOUD_ONBOARDING_CHOICE_ROLLOUT_PERCENT = 0` el sub-chooser ni se muestra, así que **el 100 % de las altas de producción entra por esa rama** mientras la que deja de relanzar (born-cloud) sigue DARK ⇒ el saldo neto para el parque, hoy, es **+1 relanzamiento**. No es un defecto de la implementación —el predicado de fresh no puede consultar el remote-config, porque en un fresh install el snapshot no existe y su `absentDefault` es fail-closed— y el punto de control lo ratificó con una regla de secuencia: ningún build que contenga R2 se distribuye con ese percent en 0. Se dibuja aquí porque es exactamente lo que la revisión de flujos del owner tiene que ver en su sitio: el reparto aprobado (+0 nube / +1 iCloud) depende del flip del percent, no del código.",
    node: "alta-privado"
  },
  {
    id: "F3-H2",
    sev: "corrección",
    title: "El alta nube no va «directa al onboarding»: hay una pantalla de continuidad con CTA",
    body: "El enunciado del chip F3 daba por hecho que, sin relanzamiento, el alta seguía directo al onboarding. MEDIDO en `24b4bc91`: `activateBornCloudStorage` devuelve la fase `.bornCloudReady` y la vista pinta «¡Tu cuenta está lista!» con un botón «Empezar» (`welcome_born_cloud_ready`); es ese CTA el que cierra el cover y enciende el onboarding, y tiene que hacerlo EXPLÍCITAMENTE porque la rama de respaldo del `onDismiss` devolvería al chooser. El Atlas dibuja la pantalla que existe, con su nodo propio. Es la regla madre aplicada al propio chip: el código ya aterrizado gana también sobre el prompt que ordena el trabajo.",
    node: "alta-bornready"
  },
  {
    id: "F3-H3",
    sev: "verificación",
    title: "El auto-exit del terminal del Welcome, su destino durable y su consumo one-shot funcionan — medidos en sim, no inferidos",
    body: "El chip R0 dejó el auto-exit como «no verificable desde el repo, lo ve el owner en TestFlight» porque el call-site corta en `isRunningTests`. Eso vale para un unit test, no para el simulador: con un build normal de Yala Dev, pulsar Inicio en la pantalla «Un último paso: reabre Yala» **hace desaparecer el proceso** (`launchctl list` sin la app), el plist del contenedor conserva `welcome.pendingMirrorRelaunchDestination = privateOnboarding` y `hasShownWelcomeChooser = true`, y al relanzar la app aterriza en el **onboarding** con la key del destino ya retirada. Las tres piezas que R0 y R2 no podían ejercitar juntas —auto-exit, durabilidad y consumo— quedan verificadas de punta a punta en sim. Lo que sigue siendo device-only es el alta contra producción (App Attest rechaza los builds de desarrollo por AAGUID) y el swap de persona de R4.",
    node: "alta-mirrorrelaunch"
  },
  {
    id: "F1-H2",
    sev: "corrección",
    title: "«Cancelar deja el device exactamente como estaba» es falso, y por eso la matriz tiene tres filas",
    body: "El criterio de hecho de A5 en el spec pide que cancelar no deje «ni par, ni faro, ni consent». Es insatisfacible: el consent se persiste al ACEPTARSE (registro append-only, precedente del repo) y el faro es TEMPRANO por diseño. Tras un `created` el estado es re-entrante, no virgen. Ya está corregido en la anotación 3 del punto de control; el Atlas lo dibuja. Re-medido el 2026-08-11: las tres filas siguen intactas y la tanda del relanzamiento cero no las toca — lo único que cambia es que, en una instalación fresca, la fila 3 ya no deja además un relanzamiento pendiente.",
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
    sev: "hallazgo · re-anclado en F5-H3",
    title: "El alta «Solo grupos» sigue dejando datos sin ninguna copia",
    body: "La función que este hallazgo señalaba —`completeGroupsOnlyOnboarding`— **ya no existe**: `3a960fd9` la borró entera. El hallazgo NO se fue con ella: el sustituto `GroupsOrganizerOnboarding.completeSetup` tampoco toca `storageMode`, así que el device sigue quedando `.icloud` y, sin cuenta iCloud del OS, el store personal monta local-sin-mirror: las `TransactionItem` puenteadas desde los gastos de grupo no tienen copia en ninguna parte. Ver **F5-H3**, que lo re-ancla con la medición del 2026-08-12. La cohorte existente no se cura sola y está declarada fuera de alcance en §6.5 del spec.",
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
