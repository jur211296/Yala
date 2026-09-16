# Si el backend rechaza «Volver a iCloud», no quedarse al 15 % sin salida

## Contexto
Ticket: `tickets/backlog/reverse-claim-rejection-has-no-way-out-in-the-client.md` (high).
Must-fix 2.1 (nube sin callejones). Hermano #185 ya dio techo/salida al upload al 95 %. Aquí el claim rechazado deja la barra al 15 % entre arranques, «Retomar» reintenta lo mismo, sin mensaje honesto ni terminal (salvo `other_leader` → `reverseOtherLeader`).

Reutilizar el patrón de salida/copy del #185 donde encaje (cancelar y seguir en la nube / mensaje claro / no journal eterno).

## DIURNO (6:00–21:00 Lima)
Puedes AskUserQuestion a Jürgen para producto/acceso.

## Que se pide
1. Ante `.rejected(reason)` del claim de reversa: salida usable (evento/terminal, copy, descongelar o cancelar según el patrón medido del #185) — no `return false` eterno.
2. Tests según el repo.
3. Gate, commit, `tickets/` + `docs/TICKETS.md`, PR, merge a 2.1 si OK, `/cerrar-total`. Bugs → ticket. No Kanban/store.

## MODO AUTÓNOMO HASTA TERMINAR
Gate/commit/board/merge/`/cerrar-total` sin preguntar. Solo parar ante decisión/acceso real. UI tests CI advisory.

## Que NO
marketing/; no ensanchar a otros highs salvo ticket propio.

## Como se sabe que esta bien
Un rechazo del claim no deja la UI al 15 % para siempre sin explicación ni salida. Board + `/cerrar-total`.

## Avisos Frank
Webhook Mini (URL/key local): (1) decisión/acceso; (2) PR/preview; (3) `/cerrar-total` + resumen usuario; (4) sin siguiente — una vez. NO: test rojo a reclasificar, build retry, CI advisory.

## Paso 0 — decisiones

> Sesión diurna (15:10 Lima). Las cuatro de producto (D1–D4) las contestó Jürgen con AskUserQuestion, las cuatro con
> la recomendada. Las técnicas (D5–D12) son de Frank, sobre lo medido.

### Lo medido antes de decidir

- **Cuerpo vivo de `migration_progress` en producción** (solo lectura, md5 `14fc5e2c…`, el final de `g15_02`). La rama
  `reverse_claim` rechaza por tres motivos, y **todos salen antes de cualquier UPDATE**: `no_profile`, `not_complete`
  (permanente) y `migration_in_progress` (lease de la ida vigente: pasajero, hasta 60 min sin latido). `other_leader`
  ya tenía salida (`reverseOtherLeader`).
- **El daño es mayor que el que cuenta el ticket.** `reverseClaimLeader` no es fase estable
  (`MigrationRuntimeGate.isDomainStablePhase`), así que con la fase clavada **el motor de la nube no arranca**
  (`CloudSyncRuntime.canRunDomain`): tras cerrar y abrir Yala, ese teléfono deja de sincronizar con la nube. El bucle que
  ya corría no re-mira la fase en cada ciclo, así que en el mismo proceso sigue; lo que dura es lo de entre arranques,
  que es justo lo que describe el ticket. Y los BGTasks se difieren (`BGTaskMigrationGate`).
- **El 409 del congelado depende solo de `reverse_frozen_at`** (`gateway/src/sync/routes.ts`), y el cliente no lee
  `reverse_in_progress` en ningún sitio.
- **Hay una carrera que deja la reserva puesta:** en una cuenta ya revertida (2.º dispositivo), un claim fresco con
  éxito cuya respuesta se pierde resetea `reverted_at`; el reintento recibe `not_complete` con `rip=true` y este
  dispositivo como líder. Sin congelar, así que no bloquea la sync. La raíz es del backend y va al ticket hermano
  `reverse-exit-on-a-reverted-account-rejects-the-retry`, que además pedía medir este cuerpo.

### Producto (Jürgen)

**D1 · Qué hace la app ante el motivo pasajero (`migration_in_progress`)** → vuelve a la nube al momento y avisa
«vuelve a intentarlo en un rato».
Por qué: esperando, si Yala se cierra y se abre en ese rato el motor de la nube no arranca, y el lease puede durar
60 min o más. Descartada: esperar al 15 % con mensaje y
«Cancelar».

**D2 · Qué texto ve la persona** → dos notas: una para el pasajero y otra para el permanente, con el correo de soporte
(molde de `welcome.cloud.accountBlockedBody`).
Por qué: el permanente no se arregla reintentando y la persona necesita a quién acudir. Descartadas: una nota genérica,
y dos notas sin correo.

**D3 · Dónde se dice** → alerta en el momento, si el rechazo viene del toque, y la nota fija en la tarjeta «Volver a
iCloud» hasta el siguiente intento, como la de #185.
Por qué: la barra solo parpadea y la tarjeta puede quedar fuera de pantalla; sin alerta el toque parece no hacer nada.
Descartadas: solo la nota, o solo la alerta (se pierde, y un rechazo en segundo plano no lo vería nadie).

**D4 · `other_leader`, que hoy vuelve en silencio** → también lleva su nota y su alerta: «Otro de tus dispositivos ya
está volviendo a iCloud. Cuando termine, podrás hacerlo en este.»
Por qué: las dos salidas del mismo paso se explican igual. Descartada: dejarlo como está.

### Técnicas (Frank)

**D5 · Cómo sale el rechazo** → evento nuevo `reverseClaimRejected(returnTo:)`: `reverseClaimLeader` → fase origen,
**sin efectos**. Por qué: en un rechazo el servidor no reservó nada (medido), así que no hay `reverse_abort` que
mandar; con efecto de red, un abort sin red quedaría pendiente y, con él, el motor parado. Descartadas:
`reverseFailedRollback` (el motor no arranca hasta un toque, lo mismo que descartó #185) y añadir `.reverseRollback`
«por si acaso» (abriría la carrera de arriba a abortar la reversa abandonada de OTRO dispositivo).

**D6 · Qué rechazos salen** → todos los `.rejected`. Solo `migration_in_progress` es pasajero; `not_complete`,
`no_profile` y cualquier motivo futuro son permanentes. Por qué: un motivo desconocido que se quedara al 15 % es el bug
de este ticket con otro nombre.

**D7 · Dónde vive el porqué** → en `MigrationState.reverseAbortReasonRaw`, el mismo campo de #185: sobrevive a la vuelta
al origen y se limpia al empezar otra vuelta o al completarla. El enum pasa de `ReverseUploadAbortReason` a
`ReverseAbortReason`, con tres casos nuevos (`claimRetryLater`, `claimRefused`, `otherDeviceReverting`). Por qué: ya no
es solo el porqué de la subida. El `rawValue` es lo que viaja y no cambia; el nombre del tipo no se persiste.

**D8 · Qué dispara la alerta** → solo una salida del claim producida por ESE toque. El runner guarda en memoria la
última salida con un número de secuencia, y `startReverse` compara antes y después. Por qué: leer el journal no
distingue un rechazo de este toque de una nota que ya estaba. El texto de la nota y el de la alerta salen de una sola
función, `L10n.Storage.ReverseAbort.note(for:)`, que usan la vista y el controlador.

**D9 · El botón «Volver a iCloud» tras un rechazo permanente** → se sigue ofreciendo. Por qué: si se arregla el backend
del ticket hermano, reintentar funcionaría sin actualizar la app, y esconderlo pediría un estado nuevo para volver a
enseñarlo.

**D10 · Observación** → breadcrumb `reverseClaimRejected(reason:)` y canario `cloudReverseClaimRejected`, con el motivo
del servidor como detalle (también `other_leader`). Por qué: es la única forma de saber cuántos teléfonos chocan con el
`not_complete` del ticket hermano.

**D11 · Fuera de alcance, con ticket nuevo** → la sesión caducada (y la red) en las fases de la reversa anteriores al
montaje: siguen clavadas al 15/30/50/62 % sin decir por qué y con el motor parado.

**D12 · Cómo se prueba** → tabla de la máquina (arista nueva e inválidas), runner (cada motivo → origen, nota,
`reverseOriginRaw` limpio, fase estable para el motor y los BGTasks, cero efectos pendientes), `other_leader` con nota,
la clasificación y el copy. Mutantes: quitar la salida, leer el pasajero como permanente y no journalear el motivo
tienen que dar rojo. El controlador no se puede instanciar en un test (singleton sobre el `mainContext`): su cableado va
por source-scan, como en #185.

### Tras la review adversarial (tres lentes: estado, backend y pantalla)

Cada hallazgo se juzgó contra el código antes de tocar nada. 13 mutantes de la primera versión, los 13 cazados.

**D13 · Los pendientes del origen se reponen (hallazgo de dos lentes por separado)** → `reverseActivated` reemplaza los
pendientes del origen, y mi salida no los devolvía. El `.runLeaderReconcileFromFrozenCloudKit` de un líder es lo ÚNICO que
manda `complete` (medido: `MigrationWorkExecutor`, un solo llamador). Un líder cuyo `complete` aún no había llegado y que
tocaba «Volver a iCloud» recibía `migration_in_progress`, volvía a la nube sin el reconcile y `migration_in_progress` se
quedaba puesto en el backend para siempre: otro dispositivo que entrara esperaba al líder sin fin (`claim_account` solo
hace takeover para quien migra). Antes lo curaba el takeover de la reversa a los 60 min. Ahora la vuelta guarda esos
pendientes (`MigrationState.reverseOriginPendingEffectsData`, schema v5) y **toda vuelta al origen antes de que el servidor
conceda la reserva los repone** (`ReverseOriginPendingEffects.restoresOnReturn`: rechazo, otro líder, declinar y un kill en
la confirmación). Con la reserva concedida se descartan: la vuelta empezó, y si tomó el lease de la ida ya puso
`migration_in_progress` a false. Si el pendiente repuesto lanza, la salida ya está journaleada y se anota igual.
Descartadas: reponer solo el reconcile cuando el runner cree ser el líder (en un líder antiguo cuya cuenta otro dispositivo
volvió a migrar, `complete` lanza `other_leader` para siempre y bloquea el motor: el callejón que #185 cerró), y drenar el
reconcile antes de la vuelta (mismo callejón).

**D14 · La alerta sale también con «Retomar» y con un re-kick (dos lentes)** → D8 solo miraba el toque. Tras un claim sin
red, «Retomar» —o el re-kick de 30 s con la pantalla delante— recibía el rechazo y la tarjeta de progreso desaparecía sin
aviso. `CloudMigrationController.announceReverseClaimExit` compara la foto de `lastReverseClaimExit` en `startReverse` y en
`resume`. Por qué basta: la alerta vive en `StorageSettingsView` y su `onChange` no dispara al aparecer, así que fuera de esa
pantalla no sale nada y queda la nota.

**D15 · Los textos, en pasado (Jürgen, con la recomendada)** → la lente de pantalla y la de backend cazaron que «Tus datos
siguen en la nube, sin cambios» es falso si la cuenta se borró desde otro dispositivo (`no_profile` con el token aún
vigente), y que las notas en presente envejecen en la tarjeta. Quedan: «…tus datos todavía estaban terminando de pasar a la
nube. Vuelve a intentarlo en un rato.» · «…tu cuenta no lo permitía. Ese intento no cambió nada. Escríbenos a %@…» ·
«…otro de tus dispositivos ya estaba volviendo. Cuando termine, podrás hacerlo en este.»

**Tests que la lente de pantalla demostró ciegos, ya cerrados** → textos cruzados entre dos motivos (ahora cada motivo se
compara con su clave) y un `==` de `ReverseClaimExit` que ignorara la secuencia (ahora se afirma `.sequence` aparte).

**Fuera, con ticket** → el toque perdido en silencio si hay un `resume` en vuelo, preexistente
(`reverse-tap-is-lost-while-a-resume-is-running`), y un `not_complete` que tapa la vuelta en curso de otro dispositivo con
tres dispositivos, del backend (anotado en `reverse-exit-on-a-reverted-account-rejects-the-retry`). No se añadió scan del
`.alert` de la vista: el anchor es preexistente y lo usan otros avisos.

### Segunda pasada (dos lentes sobre los arreglos) y 8 mutantes más

Los 8 mutantes de D13 y D14 cazados (21 en total). Hallazgos, cada uno juzgado contra el código:

**D16 · La salida se anota antes de drenar lo repuesto** → estaba después, así que un kill durante el reconcile repuesto
perdía el canario. Va dentro del mismo paso que journalea la salida, como la espera de #185.

**D17 · Un pendiente repuesto que falla siempre puede dejar el motor sin arrancar esa sesión (residual aceptado)** → solo
con un líder desplazado (su `complete` responde `other_leader` en cada intento) que además relanzó con la vuelta a medias:
el 14.7 arranca el motor con pendientes, el controlador no. Se acepta porque lo repuesto es exactamente lo que el teléfono
tenía antes del toque, y no reponerlo deja `migration_in_progress` colgado para toda la cuenta. Descartada: reponer solo con
`migration_in_progress` (ata el cliente a los motivos del RPC y deja sin reponer un `.adoptBackendAccount`). Ticket
`reverse-claim-exit-with-a-restored-failing-effect-keeps-the-engine-off`.

**Arreglados sin decisión nueva** → los source-scans fijan ahora el cuerpo ENTERO de `startReverse` y `resume` (dos
mutantes dejaban la alerta muda en verde: el aviso dentro de `if clearingError` y el borrado por debajo del aviso); la pata
del kill usa un contexto nuevo; las dos frases en alemán que se leían al revés; el `fatalError` en `reverseClaimLeader`
queda excluido en el docblock (hoy nadie lo emite).

**Anotado en tickets existentes** → «Todo al día» con un pendiente repuesto que falla, en
`reverse-abort-rejected-leaves-a-frozen-cloud-saying-up-to-date`, y el matiz de «Ese intento no cambió nada» en la carrera
del claim perdido, en `reverse-exit-on-a-reverted-account-rejects-the-retry`. El texto aprobado se queda: los datos de la
persona no cambian en ningún caso.
