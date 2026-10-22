# «Migrar a la nube» no debe adoptar en silencio una cuenta que ya tiene datos

## Contexto
Ticket: `tickets/backlog/settings-migrate-to-cloud-adopts-silently-instead-of-migrating.md` (high).
Must-fix 2.1 (nube sin callejones / mentiras). Hoy, tras dos confirmaciones destructivas, si la cuenta de Google/Apple ya tenía datos en la nube, Yala **adopta** (descarga lo remoto, no sube el corpus local) y no lo dice. El usuario cree que migró.

Medido: `StorageMigrationSignInLogic.decide` solo mira local; `existing_stable` → `.adoptBackendAccount` / NEVER re-migrate. Correcto para anti-reseed, incorrecto frente a la promesa de «Migrar».

## DIURNO (6:00–21:00 Lima)
Puedes AskUserQuestion a Jürgen para producto/acceso.

## Decisión recomendada si no preguntas
Detectar cuenta remota poblada **antes o en el claim** y **decirlo**: no completar una «migración» falsa; ofrecer opciones honestas (usar lo de la nube / cancelar / flujo explícito de adopción). No subir a ciegas pisando remoto sin decisión.

## Que se pide
1. Que «Migrar» no adopte en silencio: copy + salida/decisión cuando el backend ya tiene cuenta estable con datos.
2. Tests según el repo.
3. Gate, commit, `tickets/` + `docs/TICKETS.md`, PR, merge a 2.1 si OK, `/cerrar-total`. Bugs → ticket. No Kanban/store.

## MODO AUTÓNOMO HASTA TERMINAR
Gate/commit/board/merge/`/cerrar-total` sin preguntar. Solo parar ante decisión/acceso real. UI tests CI advisory.

## Que NO
marketing/; no ensanchar a otros highs salvo ticket propio.

## Como se sabe que esta bien
Con cuenta remota ya poblada, el usuario no cree que migró cuando solo adoptó. Board + `/cerrar-total`.

## Avisos Frank
Webhook Mini (URL/key local): (1) decisión/acceso; (2) PR/preview; (3) `/cerrar-total` + resumen usuario; (4) sin siguiente — una vez. NO: test rojo a reclasificar, build retry, CI advisory.

## Paso 0 — decisiones

> Sesión diurna. D2, D3, D4 y D10 las contestó Jürgen (2026-09-16, entre las 17:5x y las 18:1x de Lima), las cuatro
> con la recomendada; D13, D14 y D15, tras la review adversarial (19:3x); D18, tras la segunda pasada (19:5x). El resto
> son técnicas y mías, con lo medido.

### Lo medido que cambia el ticket

**Hoy no «adopta sin subir»: mezcla.** `existing_stable` → `.adoptBackendAccount` → `runAdoptFlow` →
`runAdoptOrphanReconcile`, que sube a la cuenta toda fila local que el backend no conoce. Las 6 entidades de identidad
sintética sin `syncID` reciben uno fresco y caen a huérfanas; las 10 de identidad propia (`Budget.id`,
`Account.shortcutID`…) no están en el backend de otra cuenta. Mecanismo medido con
`adoptReconcile_nilIdentity_backfilledAndUploaded` (`MigrationWorkExecutorTests.swift:1121`) y el inventario de
`collectAdoptInventory` (`MigrationWorkExecutor.swift:1416`); que en un iPhone que nunca migró eso sea el corpus entero
es inferido de ahí. Único freno: un backend enumerado vacío. ⇒ la persona mezcla sus datos con los de esa cuenta, y la
mezcla llega a todos los dispositivos de la cuenta. Es la fusión que el ADR del 9-sep descartó.

**Y el claim sí distingue lo que `/account/exists` no dice** (`qa/cloud/g15_01_account_kind.sql`, `claim_account`):
fila ligera de grupos → promoción y `created`; cuenta con lo personal reclamado (completa, o la que volvió a iCloud) →
`existing_stable`. `/account/exists` solo da `exists` + `kind` (`gateway/src/sync/account.ts:273`).

### Decisiones

**D1 · Dónde vive la puerta** → en `CloudMigrationController.startMigration`, solo con `consentPath == .migration`,
después de firmar (o de validar la sesión viva) y ANTES de `submit(.signInSucceeded)`. Si no se sigue:
`submit(.signInFailed)` (arista existente `authenticating → notStarted`, sin efectos).
Por qué: el runner encadena claim y adopt dentro de ese mismo `submit` y `claimingMigration` es durable; en
`authenticating` no hay nada journaleado que deshacer. Cero claim, cero escrituras. La comprobación sola no basta: ver
D10.

**D2 · Cuándo se comprueba (Jürgen)** → sin sesión en la nube, tras las dos confirmaciones, justo después de firmar. Con
sesión viva (cuenta de grupos asociada) se comprueba al tocar «Activar la nube», antes del consentimiento; ese adelanto
solo para en un bloqueo seguro: si no se pudo comprobar, sigue y decide la puerta de D1.
Descartada: firmar antes de las confirmaciones, que deja una sesión abierta mientras se leen los diálogos y, si Yala se
cierra ahí, el registrador del arranque (`AppBootstrapper.swift:625`) la convierte en cuenta de grupos asociada.

**D3 · Solo grupos sin ninguna asociada (Jürgen)** → migra a esa cuenta (el claim la promueve, como hoy). La tabla pasa a
bloquear solo con `isAssociatedGroupsAccount == false`. El `nil` bloqueaba porque el 10-sep «ningún call-site podía
probarlo»; hoy `GroupsAccountAssociation.isAssociated(sub:)` devuelve `nil` cuando no hay asociación, y bloquear ahí no
protege nada que una cuenta nueva no deje pasar igual.

**D4 · Salidas del bloqueo (Jürgen)** → «Usar otra cuenta» (abre Apple/Google sin repetir consentimiento ni
confirmaciones) + «Entendido». Si ya había sesión antes del intento, solo «Entendido»: cambiar de cuenta exige
desasociar primero (decisión del 9-sep). Usar los datos de esa cuenta aquí va en el texto: cerrar sesión y entrar con
ella. El botón que lo hace en un gesto queda fuera.

**D5 · La sesión al no seguir** → se cierra solo si la abrió este intento, en todas las salidas (bloqueo y «no pudimos
comprobar»). Por qué: una sesión viva en un iPhone con sesión privada se registra como cuenta de grupos asociada en el
siguiente arranque, aunque sea completa. La de antes del intento no se toca: es la de sus grupos.

**D6 · Forma del aviso** → hoja propia con `onDismiss`, no `.alert`: «Usar otra cuenta» encadena con la hoja de Apple/Google,
y la cadena segura es por `onDismiss` (regla 4 de presentaciones; un `.alert` no tiene). El bloqueo lo publica el
controller y la vista lo consume con `.onChange(…, initial: true)`, así que sale también si la persona volvió a la
pantalla. «No pudimos comprobar tu cuenta» usa el `lastError` de siempre.

**D7 · `kind` ausente** → bloquea, como ya dice la tabla. Los dos entornos lo sirven desde el 10-sep.

**D8 · La tarjeta de adopt (marcador del líder)** → no cambia. Ahí `complete` es lo esperado.

**D9 · Lo que queda abierto, con ticket** → el adopt no tiene guarda de linaje. Tras D10 le llegan dos caminos raros con
un corpus ajeno: un relanzamiento con `claimingMigration` journaleado (la intención de D10 vive en memoria) y un seguidor
(`claiming_in_progress` → `leaderCompleted`) de un líder con otro corpus. El seguidor del mismo Apple ID es el caso
diseñado, y no se distinguen.

**D10 · La cuenta que volvió a iCloud (Jürgen: cerrarlo aquí)** → `/account/exists` la da como `groups_only`, así que
pasa la puerta; el claim contesta `existing_stable` y sigue congelada (`reverse_complete` no toca `reverse_frozen_at`,
medido en `g15_01` §5 y en `qa/cloud/README.md`: `/sync/push` la rechaza con 409). Se cierra en el claim: con la intención
«Migrar» puesta, `existing_stable` ya no adopta. Arista nueva `claimingMigration → notStarted` sin efectos (la rama
`existing_stable` del RPC no escribe) y aviso propio: «Esta cuenta volvió a iCloud. Volver a la nube con ella todavía no
está disponible. No cambiamos nada.» La intención vive en el runner y en memoria (`adoptIfExisting` por defecto, así que
nada más cambia); la ponen las entradas del controller. El motivo del aviso sale de lo que dijo la puerta: `groups_only`
⇒ volvió a iCloud; si no, ya tiene finanzas personales (una cuenta que se completó entre la puerta y el claim). Descartada:
journalear la intención (campo nuevo en `MigrationState`), que solo añade el caso del relanzamiento a mitad del claim.

**D11 · Observación** → canario `cloudMigrationExistingAccountBlocked` con el motivo y dónde se paró (puerta o claim). El
gateway valida el nombre por forma, no por lista (`gateway/src/metrics.ts:53`): no hace falta desplegar.

**D12 · Tests** → lógica pura nueva (`StorageMigrationIdentityGateLogic`) con la tabla de Ajustes de punta a punta; la
celda del `nil` actualizada en `CloudIdentityRoutingLogicTests`; source-scan del orden en `startMigration` y del cableado
de la vista; tests del runner con el executor falso (con «Migrar», `existing_stable` vuelve al inicio sin ejecutar el adopt;
sin la intención, adopta como hoy); la arista nueva en `MigrationStateMachineTests`; XCUITest con un seam DEBUG que fija
la respuesta de la puerta para ver la hoja, sus botones y que no se abre nada detrás (la decisión la cubren los unit, no
el seam). Mutantes sobre cada pieza. Review adversarial: sí (identidad y
migración).

### Tras la review adversarial (cuatro lentes, 2026-09-16)

**D13 · Otra cuenta asociada y una cuenta NUEVA (Jürgen: bloquear también)** → con la asociada A registrada, migrar a una
cuenta nueva C también para con «Ya usas otra cuenta para tus grupos». La hoja lo decía y «Usar otra cuenta» llevaba a
romperlo. El texto gana la salida que ya existía: desasociar antes en «Grupos» (decisión del 9-sep).

**D14 · El segundo dispositivo del mismo iCloud antes de que llegue la marca (Jürgen: ticket aparte)** → queda bloqueado
en esa ventana. Antes adoptaba bien, porque son los mismos datos. El aviso ya da la salida buena («cierra sesión y entra
con ella»), y al llegar la marca la tarjeta pasa sola a «Activar en este dispositivo».

**D15 · Apple no deja elegir otra cuenta en el iPhone (Jürgen: permitir otro Apple ID, en ticket aparte)** → el inicio de
sesión web de Apple va en su ticket. Mientras tanto, si la cuenta rechazada era de Apple, la hoja lo dice junto a «Usar
otra cuenta».

**D16 · Lo técnico que cambió la review** (juzgado contra el código, uno a uno):
- **«Reintentar» tras un fallo quedaba bloqueado (alta, regresión).** La cuenta que creó el intento ya es `complete` y el
  servidor se la devuelve al mismo líder como `created`. Si este dispositivo tiene el sello `.proceedMigration` de esa
  cuenta, la comprobación sigue y decide el claim; cualquier otro `existing_stable` lo sigue parando la intención.
- **La intención se journalea** (`MigrationState`, schema 6). La ventana del relanzamiento no era «una petición»: dura
  todo lo que el claim pase aparcado. Y en la cuenta que volvió a iCloud, adoptar la dejaba en modo nube sobre un backend
  que rechaza todo push.
- **La sesión rechazada se cierra antes** de devolver el runner al inicio, que espera quiescencia. Y si el `submit` que
  lleva al claim no hace nada —quiescencia vencida, u otra acción en vuelo—, se para con aviso y se cierra la sesión.
- **El aviso se consume en el `onAppear` de la hoja**, no al pedirla: si no monta, sigue en el controller para la
  próxima vez. El botón enseña que trabaja durante toda la parada, cierre de sesión incluido.
- **La comprobación no lee el eje del dispositivo**: la fila de Ajustes no lo usa, y leerlo añadía un consumidor a
  `PrivateSessionMark`, que tiene sus lectores contados.
- **Copy**: «No pudimos comprobar tu cuenta» deja de mandar a revisar la conexión (sale también con un 401 o un 502); el
  aviso con la sesión de sus grupos dice cómo llevar sus datos a otra cuenta; cinco traducciones retocadas.
- **Tests más duros**: cuerpos enteros fijados donde un `contains` dejaba pasar mutantes, el caso `claimingInProgress`,
  títulos emparejados por motivo, y un XCUITest de «Usar otra cuenta» → elección de Apple/Google con un seam que publica
  el aviso.

**D17 · Lo que va a tickets** → `adopt-uploads-a-foreign-corpus-without-a-lineage-check` (el seguidor de otro corpus), el
segundo dispositivo del mismo iCloud (D14), otro Apple ID (D15), la sesión que sobrevive a «Empezar de cero» y que
«Migrar» promueve (preexistente: `2.1` ya la promovía), y los pendientes que `userActivated` tira al entrar
(preexistente).

### Tras la segunda pasada de la review (dos lentes, 2026-09-16)

Las dos lentes dieron por cerrados los arreglos de D16 y encontraron esto:

**D18 · «Migrar» y otro dispositivo migrando la misma cuenta (Jürgen: parar y avisar)** → con la intención de migrar,
`claiming_in_progress` también vuelve al inicio, con «Esa cuenta ya tiene finanzas personales». Seguir al líder acababa
en un adopt, y relevarle a los 60 min subía lo local encima de lo que él dejó: con el mismo iCloud es lo correcto, con
otro mezcla dos corpus, y el teléfono no puede distinguirlos. Se acepta a sabiendas que una migración abandonada por su
líder, o por el mismo iPhone tras reinstalar, ya no tiene salida desde «Activar la nube» con esa cuenta: va al ticket de
D14, que lo recoge.

**D19 · Lo técnico de la segunda pasada** (juzgado contra el código):
- **La migración TERMINADA deja de abrir la comprobación**: al confirmar `complete`, el líder cambia el sello
  `.proceedMigration` por `.routeReturningUser`. Sin eso, tras cerrar sesión y volver a iCloud, «Migrar» con esa cuenta
  pasaba la comprobación, cobraba el consentimiento y lo paraba el claim, o un error genérico si vencía la quiescencia.
- **«Usar otra cuenta» solo abre la elección sin sesión viva**: el aviso espera en el controller, y si entretanto la
  persona entró con otra cuenta desde Grupos, la elección se cerraba sola y migraba con esa sesión sin enseñarla.
- **Un rechazo se avisa una sola vez**: un `resume` que empezó antes del toque lo veía nuevo respecto a su foto y lo volvía
  a publicar, sin el intento y encima del aviso bueno.
- **Fuera un flag que nadie veía** (`isCheckingMigrationIdentity` dentro de `continueToClaim`): con la fase en
  `authenticating` la pantalla pinta «Activando la nube…», así que D16 decía de más.
- **Docblocks**: el intento vive en memoria y la intención no; los escritores del sello; `isAssociated` sin `userID`.
- **Tickets nuevos**: `storage-groups-section-stays-active-during-the-migrate-check`,
  `migrate-card-keeps-promising-an-account-the-check-refused` y
  `migrate-before-the-groups-association-arrives-splits-the-accounts`. El copy de «desasocia en Grupos» en una sesión
  solo-grupos se añadió a `groups-only-session-storage-screen-says-data-lives-in-icloud`.
