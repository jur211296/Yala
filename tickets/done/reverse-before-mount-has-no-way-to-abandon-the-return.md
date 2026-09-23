---
id: reverse-before-mount-has-no-way-to-abandon-the-return
status: done
updated: 2026-09-23
qa-status: not-replicable
implementation_date: 2026-09-21
priority: medium
area: "modo-nube, migración"
created: 2026-09-17
source: "review adversarial de `reverse-before-mount-stays-stuck-with-an-expired-session` (2026-09-17), lente de la máquina — hallazgos 1 y 2"
qa-date: 2026-09-23
qa-notes: barrido 2026-09-23 sin device-QA - el boton de cancelar hermano se prueba en snapshot-upload-has-no-ceiling-and-no-way-out; pide SQL; MigrationStateMachineTests
---

# Las cuatro fases previas al montaje de «Volver a iCloud» no tienen forma de abandonar

## El problema, en lenguaje de usuario

Empecé a volver a iCloud y algo no deja terminar: el servidor dice que otro de mis dispositivos ya la lleva, mi cuenta
está suspendida, o perdí el acceso a la cuenta con la que la empecé. La barra se queda donde está y no hay ningún botón
para dejarlo: ni «Cancelar y seguir en la nube», ni «Reintentar». Y mientras tanto **mis movimientos no suben a ningún
sitio**, porque con esa fase journaleada el motor de la nube no arranca.

## Por qué pasa (medido el 2026-09-17)

Las cuatro fases previas al montaje del espejo salen **solo por éxito**:

| Fase | Única salida | Qué pasa con lo demás |
|---|---|---|
| `reverseClaimLeader` | `.reverseLeaderClaimed` | tiene salida al origen para el rechazo (ticket hermano, cerrado) |
| `reverseDrainAll` | `.reverseDrainCompleted` | todo lo demás corta sin evento |
| `reverseVerify` | `.reverseVerifyOutcome` | degradaba a `reverseFailedRollback` al agotar el presupuesto de RED |
| `reverseFreezeBackend` | `.reverseBackendFrozen` | `otherLeader` y `rejected` cortan sin evento |

Y la tarjeta de progreso **no ofrece cancelar en ninguna**: `cancelReverseButton` está gateado por
`isWaitingReverseUpload`, que es `journaledPhase == .reverseUpload`.

**Lo que cambió el 2026-09-17, y hay que decirlo entero:** `reverse-before-mount-stays-stuck-with-an-expired-session`
quitó la única degradación automática que quedaba —la de `reverseVerify` por sesión caducada— porque su criterio 3 lo
pedía: ese terminal llegaba con `.reverseRollback` pendiente, un efecto que con la sesión caducada **lanza en cada
resume**, así que ni el terminal ni su «Reintentar» funcionaban. O sea: **no es una regresión de desenlace** (el
terminal ya estaba roto), pero sí cierra la última puerta sin abrir otra.

Los tres motivos que llegan aquí y que esperar NO arregla:

- **`otherLeader` / `rejected` en el freeze.** El lease de la vuelta dura 60 minutos y **ninguna de las cuatro fases
  paradas late** (`sendLeaseHeartbeatIfDue` tiene tres call-sites y ninguno cubre una fase parada). Quien vuelve dos
  horas después puede encontrarse con que otro dispositivo suyo hizo takeover.
- **`.accountUnavailable` (403, cuenta suspendida)** en el drain y en el verify: se lee como red a propósito —no es una
  sesión que renovar— y ahí se queda.
- **Una cuenta a la que ya no se puede entrar** (borrada, acceso perdido): la tarjeta pide volver a entrar y no se puede.

## Qué habría que decidir

1. **Qué ofrece la salida.** Volver al origen en modo nube, como hace la salida de la espera de `reverseUpload`, con
   `[.rearmMirrorOff, .reverseRollback]`. Pero `reverse_abort` necesita sesión: sin ella el efecto queda pendiente y
   lanza en cada resume — el bug-class que este ticket describe, con otro nombre.
2. **Si la salida es automática (un techo, como el de `reverseUpload`) o un botón**, o las dos. Un techo protege a
   quien no está delante; un botón, a quien sí.
3. **Qué se le dice**, con el molde de `ReverseAbortReason` y `L10n.Storage.ReverseAbort.note(for:)`, que ya tiene tres
   motivos y su sitio en la tarjeta.

## Criterios de aceptación

- [x] Decidido 1, 2 y 3 antes de tocar código.
- [x] Ninguna de las cuatro fases puede quedarse sin salida indefinidamente con el motor de la nube parado.
- [x] Un `reverse_abort` que no puede salir (sin sesión) NO deja un efecto pendiente que lance en cada resume.
- [x] Tests por motivo, con mutante.

## Relacionado

- `reverse-claim-rejection-has-no-way-out-in-the-client` — el molde: la salida al origen sin efectos.
- `reverse-upload-has-no-ceiling-and-no-exit` — el molde del techo y del botón de cancelar, post-montaje.
- `reverse-before-mount-stays-stuck-with-an-expired-session` — el que cerró el caso de la sesión caducada y midió esto.

## Decisión Jürgen (2026-09-21)

**Salida completa:** techo automático **y** botón de cancelar.

- **Qué hace la salida:** rollback al origen en modo nube, molde de la salida de espera de `reverseUpload` / rechazo de claim — sin dejar `reverse_abort` pendiente que dispare en cada resume si no hay sesión.
- **Copy:** molde `ReverseAbortReason` + `L10n.Storage.ReverseAbort.note(for:)`.
- Listo para implementar cuando la cola A lo tome (serie; no adelantar a `force-fetch` en curso).


## Paso 0 — el árbol de decisiones (2026-09-21)

Jürgen decidió el QUÉ (techo + botón + rollback al origen + copy con el molde de `ReverseAbortReason`).
Esto es el CÓMO, resuelto contra el árbol y no contra la documentación. **Cinco cifras del propio ticket y
de las reglas de área no se sostenían al medirlas**, y están al final.

### D1 · Qué fases cubre

Las cuatro previas al montaje: `reverseClaimLeader` (15 %), `reverseDrainAll` (30 %), `reverseVerify` (50 %)
y `reverseFreezeBackend` (62 %). Las cuatro son INESTABLES (`MigrationRuntimeGate.isDomainStablePhase`
devuelve `false` para todas), así que con cualquiera journaleada el motor de la nube no arranca: el daño de
que no salgan no es una barra parada, es un teléfono que deja de sincronizar.

### D2 · El reloj: tiempo journaleado SIN AVANZAR, y «avanzar» es cambiar de fase

Molde de `reverseUploadProgressAt`, con dos campos nuevos en el journal (`MigrationState`, schema 6 → 7):
`reversePreMountProgressAt` (instante del último avance, con el `now` inyectado) y
`reversePreMountPhaseRaw` (en qué fase se selló). Avanzar es que la fase pre-montaje journaleada sea
distinta de la sellada; entonces se re-sella y el reloj vuelve a cero.

**Por qué el cambio de fase y no un contador de progreso:** aquí no hay cifra que baje. El drain sube un
outbox cuyo tamaño no es observable como «lo más bajo visto» (lo escrito durante la espera lo sube), el
verify es un veredicto y el freeze es una sola llamada.

**Por qué no se puede burlar con un rebote:** el único bucle pre-montaje es `reverseVerify ⇄ reverseDrainAll`
por mismatch, y lo acota `MigrationPolicy.maxMismatchRetries = 3`. Un sello en el FUTURO (reloj puesto
atrás durante la espera) se re-sella en vez de esperar, igual que el techo de la espera de subida.

### D3 · Los presupuestos: los mismos dos del molde, con nombre propio

`reversePreMountDefinitiveBudgetSeconds = 900` (15 min) y `reversePreMountUnknownBudgetSeconds = 259_200`
(72 h). Son los números que Jürgen ya ratificó el 2026-09-16 para la espera de `reverseUpload` y para el
paso 4 de la ida; reusarlos es lo conservador, y no hay medición que justifique otros.

### D4 · Qué es `definitive` — y por qué hay que SEPARAR tres outcomes que hoy se colapsan

El techo corto solo vale si la app sabe que el servidor ya dijo que no. Hoy no lo sabe: los tres motivos
que el ticket nombra llegan al runner disfrazados de red.

| Dónde | Qué dice el servidor | Cómo llega HOY | Cómo llegará |
|---|---|---|---|
| `freezeBackendForReverse` | `other_leader` | `.transient` (`MigrationWorkExecutor:1007-1009`) | `.blocked(.otherLeader)` |
| `freezeBackendForReverse` | `rejected(reason)` | `.transient` (`:1010-1012`) | `.blocked(.refused)` |
| `reverseDrainOnce` | 403 `accountUnavailable` (push y pull) | `.transient` (`:968`, `:978`) | `.blocked(.accountUnavailable)` |
| `verify` (la vuelta) | 403 `accountUnavailable` (push y pull) | `.networkTimeout` (`:518`, `:531`) | `.blocked(.accountUnavailable)` |

`ReverseStepOutcome` y `VerifyProbe` ganan un caso `.blocked(ReversePreMountBlocker)`. **La IDA no cambia:**
`verify()` la comparten las dos direcciones, y `driveVerify` mapea `.blocked` al mismo trato que
`.networkTimeout`, igual que ya hace con `.sessionExpired`.

Todo lo demás —red de verdad, sesión caducada— es `unknown`, el presupuesto largo.

### D5 · La sesión caducada también tiene techo, y es el largo

Cubre el tercer motivo del ticket, «una cuenta a la que ya no se puede entrar»: el aviso «vuelve a entrar»
sigue saliendo primero y el botón sigue ahí, pero a las 72 h sin que nadie entre la vuelta sale sola. Sin
esto, ese motivo se queda exactamente como está hoy.

### D6 · Qué hace la salida: al origen SIN efectos, y el `reverse_abort` después, best-effort

Evento `reversePreMountStalled(stalledSeconds:cause:returnTo:)` y su gemelo de la persona,
`reversePreMountCancelled(returnTo:)`. Los dos van de cualquiera de las cuatro fases a
`reverseOriginPhase(origin)` **sin efectos de máquina**, y el runner llama a `reverse_abort` DESPUÉS de
journalear la salida, una vez, tragándose el fallo con un breadcrumb.

**Por qué sin `.rearmMirrorOff`:** pre-montaje el local está intacto; el espejo nunca se re-encendió (lo
enciende `mountMirrorAndRelaunch`, en la arista `reverseFreezeBackend → reverseMountMirror`). El propio
docblock del efecto lo dice: «Pre-montaje, el local sigue intacto».

**Por qué el abort NO va como efecto journaleado**, que es lo que pide el criterio 3 del ticket: hoy
`execute(.reverseRollback)` LANZA con el token ausente, con la sesión caducada y con cualquier
`.transient` —y el 403 cae ahí, porque `CloudAccountClient` manda todo status ≠ 200/401 a `.transient`—.
Un efecto que lanza no se consume, y `MigrationBootDecision.decide` devuelve `.resume` mientras haya
pendientes: el abort volvería a lanzar en cada arranque y en cada vuelta a la app, que es el bug-class
que esta salida existe para cerrar.

**Por qué journalear PRIMERO y abortar después, y no al revés:** si el proceso muere entre las dos cosas,
el estado malo es el mejor de los dos. Journaleando primero queda «en el origen, con la reserva puesta»,
que se cura solo; al revés quedaría «en una fase pre-montaje, con la reserva quitada», que reintenta un
paso cuya reserva ya no existe.

**Y el coste de un abort que no sale es bajo, medido:** el re-claim del MISMO dispositivo es
idempotente-ok y NO mira la edad del lease (golden 14 de `gateway/test/account.goldens.test.ts`), así que
este teléfono puede volver a intentarlo cuando quiera. Para los demás dispositivos de la cuenta el lease
caduca a los 60 min. Y sin el freeze estampado el backend no responde 409, así que el motor de la nube
arranca igual al volver al origen.

### D7 · El botón: el mismo, con el cuerpo de la confirmación cambiado

«Cancelar y seguir en la nube» (`storage.progress.cancelReverse`) pasa a pintarse también en las cuatro
fases. El título y los dos botones del diálogo se reusan; **el cuerpo NO**: el de hoy dice «Yala te pedirá
cerrarla y volver a abrirla», y pre-montaje eso es falso —no hay espejo montado que apagar, así que no
hay relanzamiento que pedir—. Clave nueva `storage.confirm.cancelReverseBeforeMountBody`.

### D8 · El copy: dos motivos nuevos, dos reusados

`ReverseAbortReason` (rawValue WIRE-ESTABLE, append-only) suma:

- **`preMountRefused`** — el servidor no dejó continuar y esperar no lo cambia (`rejected` del freeze, 403
  de cuenta no disponible). Lleva el correo de soporte, como `claimRefused`, porque reintentar no lo
  arregla. Texto propio y no el de `claimRefused`: aquí la vuelta SÍ había empezado, así que «ese intento
  no cambió nada» sería falso.
- **`preMountStalled`** — el techo largo venció sin que el servidor dijera por qué (red que no vuelve,
  sesión que nadie renovó). No lleva correo: reintentar sí puede funcionar.
- **`otherDeviceReverting`**, ya existente, para el `other_leader` del freeze.
- **`cancelled`**, ya existente, para el botón: `ReverseUploadWaitingCopyLogic.abortNote` lo filtra y no
  deja nota, que es lo correcto — lo decidió la persona.

### D9 · El canario

`cloudReversePreMountAborted`, `detail` = `<fase>|<motivo>`, los dos literales del propio build (no vienen
de la red, así que no necesitan el acotado de `reverseClaimRejectedDetail`). Por observación y no
`canaryOnce`: una salida ocurre una vez por intento, no en cada re-kick. Y un abort que no sale deja
breadcrumb `reverseAbortBestEffortFailed`, sin canario propio: es el residual conocido, no una serie.

### D10 · Lo que NO se toca, a propósito

- **El presupuesto S9 del verify** (`maxNetworkRetries = 8`) y su degradación a `reverseFailedRollback` con
  `.reverseRollback` pendiente: es preexistente, es de la ida tanto como de la vuelta, y tocarlo aquí
  arrastraría un hermano. Por eso el techo NO se observa en el `.networkTimeout` del verify, que ya tiene
  su propio contador; se observa en los cortes que hoy no tienen ninguno.
- **`execute(.reverseRollback)`**: lo comparten la ida, el techo de la espera de subida y
  `reverseFailedRollback`. Se reusa tal cual, envuelto en el `do/catch` del runner.
- **El `default: .transient` de `CloudAccountClient.migrationProgress`**, donde cae el 403 del claim y del
  freeze. Separarlo tocaría la ida entera; el 403 de esas dos llamadas se queda en el presupuesto largo.

### Lo que la medición corrigió del propio ticket y de las reglas

1. **«`reverseVerify` degradaba a `reverseFailedRollback` al agotar el presupuesto de RED»** — sigue siendo
   verdad para el `.networkTimeout`; lo que el 2026-09-17 quitó fue solo el camino de la sesión caducada.
2. **«`otherLeader` y `rejected` cortan sin evento» en el freeze** — cortan, sí, pero NO como ellos mismos:
   el executor los colapsa en `.transient` antes de que el runner los vea. Sin separarlos no hay techo
   corto posible.
3. **El schema de `MigrationState` es 6, no 5.** Lo dice v5 el ticket hermano
   (`tickets/qa/reverse-claim-rejection-has-no-way-out-in-the-client.md`); el 6 lo añadió
   `forwardClaimIntentRaw`. **La regla de área no dice nada del schema del journal** —cero menciones, medido—, y
   esta frase decía que sí: lo corrigió una lente, y es justo lo que el `CLAUDE.md` pide no hacer (distinguir lo
   medido de lo inferido). Este ticket lo sube a 7.
4. **El 403 no existe como outcome del claim ni del freeze.** `/account/migration` no lleva App Attest y el
   gateway solo devuelve 400/401/502; un 403 solo puede venir de la capa de abajo y el cliente lo lee como
   red. Donde el 403 SÍ llega tipado es en el drain y en el verify, por `SyncPushClient`/`SyncPullClient`.
5. **«El lease de la vuelta dura 60 minutos»** es cierto para OTROS dispositivos, no para este: el re-claim
   del mismo líder es idempotente y no mira la edad del lease. Eso rebaja el residual de un abort perdido.

## Hecho el 2026-09-21

### Qué cambia para la persona

- **«Volver a iCloud» ya se puede abandonar desde el primer momento.** El botón «Cancelar y seguir en la nube», que
  hasta hoy solo salía al 95 %, aparece también al 15, al 30, al 50 y al 62 %. Antes, en esas cuatro la tarjeta
  ofrecía «Retomar» y nada más, y «Retomar» recibía lo mismo una y otra vez.
- **Y si no hay nadie delante, la app sale sola.** Cuando el servidor ya dijo que no —la cuenta en la nube no está
  disponible, otro dispositivo tomó el relevo, el paso de congelar salió rechazado— espera 15 minutos y vuelve a la
  nube; cuando no se sabe por qué no avanza —sin cobertura, o una sesión que nadie renueva— espera 72 horas. Eso
  último es lo que cubre el caso peor: una cuenta a la que ya no se puede entrar. Antes, cualquiera de esos tres
  dejaba el teléfono **sin sincronizar** hasta que alguien se diera cuenta, que es bastante más que una barra parada.
- **Al volver, le decimos qué pasó**, en la tarjeta de «Volver a iCloud» y con su frase:
  - «No pudimos terminar de volver a iCloud: tu cuenta en la nube no lo permitió. Tus datos siguen en la nube de
    Yala. Escríbenos a admin@yala-app.pe y lo revisamos contigo.»
  - «No pudimos terminar de volver a iCloud: otro de tus dispositivos tomó el relevo. Cuando termine, podrás hacerlo
    en este.»
  - «No pudimos terminar de volver a iCloud: la vuelta no avanzó. Tus datos siguen en la nube de Yala y puedes volver
    a intentarlo cuando quieras.»
- **Si cancela ella, no hay nota** —lo decidió ella— y **tampoco se le pide cerrar y reabrir Yala**: antes del montaje
  del espejo no hay nada que relanzar, así que el diálogo dice otra cosa que en la espera de la subida.
- **Sus datos siguen donde estaban.** La vuelta no había llegado a tocar nada local: el teléfono se queda en la nube,
  sincronizando, y puede volver a intentarlo cuando quiera.
- **Y si firma para continuar, continúa.** Un «Cancelar» que se quedó esperando a que iCloud terminara de importar ya
  no se ejecuta cuando la persona toca «Iniciar sesión» para rescatar esa misma vuelta.

### Qué se tocó

- `MigrationStateMachine`: eventos `reversePreMountStalled(stalledSeconds:cause:returnTo:)` y
  `reversePreMountCancelled(returnTo:)`, válidos desde las cuatro fases, con hold en la propia fase bajo presupuesto
  y salida al origen **sin efectos**; presupuestos `reversePreMount*BudgetSeconds` (900 / 259 200).
- `MigrationState` (schema 6 → 7): `reversePreMountProgressAt` y `reversePreMountPhaseRaw`, los dos aditivos.
- `ICloudCutoverGateLogic`: `ReversePreMountBlocker` (el 403, el relevo y el rechazo) y tres motivos nuevos de
  `ReverseAbortReason` (`preMountRefused`, `preMountStalled`, `preMountOtherDevice`).
- `MigrationWorkExecutor`: el 403 del push y del pull sale tipado en `reverseDrainOnce` y en `verify`; el
  `other_leader` y el `rejected` del congelado dejan de colapsar en `.transient`.
- `MigrationRunner`: `ReverseStepOutcome.blocked` y `VerifyProbe.blocked` (la IDA no cambia: `driveVerify` los agrupa
  con la red); `observeReversePreMountStall` + `leaveReversePreMount` + `abortReverseServerBestEffort`;
  `cancelReverseUpload` pasa a `cancelReverse` y sirve a las cinco fases; `ReverseSessionExpiryPhase` pasa a
  `ReversePreMountPhase` (mismos `rawValue`: el canario no cambia de serie) y gana `init?(phase:)`.
- `CloudMigrationController`: `canCancelReverse` e `isBeforeReverseMount`; el «sí» se apunta antes del spin y se
  retira al firmar para continuar.
- `StorageSettingsView`: el gate del botón, el cuerpo y el «no» del diálogo por fase.
- `MetricsService`: `cloudReversePreMountWaiting` (por observación) y `cloudReversePreMountAborted`; tres breadcrumbs.
- `L10n` + 16 idiomas: cuatro claves. Regla nueva en `.claude/rules/swiftdata-cloudkit.md`, una corrección en
  `.claude/rules/testing.md` y cinco áreas de `qa/coverage-index.json`.

### Cómo se verificó

- **Build ×2** en verde y **368 casos en 10 suites**, leídos de `Test run with`.
- **13 mutantes, los 13 cazados.** Nueve de la implementación (el colapso del executor, los presupuestos
  intercambiados, el reloj heredado de un intento anterior, el cambio de fase que deja de contar como avance, la
  causa siempre corta, el abort que desaparece, el gate viejo del botón, el verify gastando red, el abort
  journaleado como efecto) y cuatro de los arreglos de la review.
- **Review adversarial con cuatro lentes** (máquina y journal · runner y concurrencia · pantalla, copy y tests · las
  reglas de área leídas CONTRA el diff). **Tumbó nueve cosas mías, y tres eran de publicación:**
  1. **El hold nuevo BORRABA los pendientes del origen.** `reverseClaimLeader` nunca había tenido una arista que la
     dejara en sí misma, y el brazo que descarta lo guardado («la vuelta empezó de verdad») cazaba ese hold: un
     corte de red durante el claim perdía el `runLeaderReconcileFromFrozenCloudKit` del líder —lo único que manda
     `complete`— y el rechazo posterior reponía una lista vacía. El bug que cerró el ticket hermano, reabierto por
     la puerta de al lado.
  2. **El reloj no se re-sellaba al VOLVER a una fase ya visitada.** `verify` vuelve a `drain` por mismatch, y la
     segunda visita heredaba el sello de la primera: el techo saltaba con cero segundos de parada real. Mi test solo
     cubría el avance a una fase nueva.
  3. **Firmar para continuar ejecutaba un «Cancelar» apuntado.** Los dos botones nunca habían podido coexistir; con
     el nuevo en esas cuatro fases, la persona que rescataba la vuelta se la encontraba abandonada sin nota.
  4. **`CloudSyncSchemaParityTests` en rojo**: no había pedido esa suite.
  5. El abort best-effort **no se intentaba nunca** si un pendiente repuesto lanzaba.
  6. **El ternario del cuerpo del diálogo fallaba ABIERTO** («¿no es la espera?» en vez de «¿es previa al montaje?»).
  7. **Violé una regla mía**: `.claude/rules/swiftdata-cloudkit.md` dice «un escritor y UN borrador» del testigo de
     la sesión caducada, y añadí un segundo borrador inobservable — la línea exacta que esa regla describe como
     mutante superviviente. Dos lentes discreparon sobre si era necesaria; lo zanjó medir quién lee el testigo.
  8. **Cinco aserciones que no podían fallar** en mis tests, incluida la del cuerpo del diálogo, que no comprobaba lo
     que su nombre promete; y el `%@` del correo de soporte **no lo protegía nada** (el parser de placeholders no ve
     un `%@` aislado, así que la paridad comparaba `0 == 0` en 15 idiomas).
  9. **El copy del relevo decía «no pudimos EMPEZAR»** reusando el texto del claim, cuando desde el congelado la
     vuelta sí había empezado — el mismo argumento por el que este ticket no reusa `claimRefused`, aplicado a una
     sola de las dos mitades.

### Residuales, con ticket

- `reverse-pre-mount-ceiling-has-no-alert-and-leaves-network-verify-out` — el techo no avisa en el momento (la nota
  está, la alerta no), y `reverseVerify` + red pura sigue saliendo por el terminal viejo. Los dos, decisiones.
- `reverse-abort-rejected-leaves-a-frozen-cloud-saying-up-to-date` — ya existía, y esta salida le añade un camino:
  desde `reverseFreezeBackend` el congelado puede haberse estampado con la respuesta perdida, y ahí un abort que no
  sale deja el motor contra un backend que responde 409.
- **Aceptado sin ticket:** el `reverse_abort` best-effort corre dentro del guard del runner con el tope de 60 s de
  `URLSession`, así que el motor arranca hasta un minuto más tarde de lo que podría. Ocurre una vez, después de una
  espera de 15 min o 72 h. Y un toque de «Cancelar» que llegue cuando el pase en vuelo ya cruzó hasta el montaje es
  no-op silencioso: ahí la salida previa ya no existe.

## QA en iPhone

**Por qué en iPhone:** llegar a estas fases exige una cuenta en la nube de verdad, y el simulador no las crea sin el
secreto de attest (`.claude/rules/gateway-attest.md`). **Los techos por tiempo no se recorren a mano** —15 min o
72 h—: los fijan los unit tests con reloj inyectado. Aquí se ve el botón, el copy y que la vuelta al origen deja el
teléfono sincronizando.

**Montaje:** un iPhone de pruebas con un build que incluya este cambio (`Yala Dev` desde Xcode, contra staging), con
una cuenta en la nube y algunos movimientos. El id de esa cuenta, en el SQL Editor de Supabase (staging):
`select id from auth.users where email = '<correo>';`, y apunta el estado de partida:
`select kind, reverted_at, migration_in_progress, reverse_in_progress, leader_device_id, reverse_frozen_at from public.profiles where id = '<id>';`

**Caso A · el botón, en la fase del congelado.** Monta el relevo de otro dispositivo:
`update public.profiles set leader_device_id = 'qa-otro-dispositivo', migration_updated_at = now() where id = '<id>';`

1. **Ajustes → «Dónde viven tus datos» → «Volver a iCloud»**, pasa las dos confirmaciones. La barra avanza y se para
   en el 62 % («Volviendo a iCloud…»). Captura.
2. **El botón está ahí.** Debajo de «Retomar» tiene que salir «Cancelar y seguir en la nube». Antes de este cambio
   no salía: si no lo ves, el build no lleva el cambio.
3. Tócalo. El diálogo dice «¿Cancelar la vuelta a iCloud?» con el cuerpo **«Tus datos siguen en la nube de Yala y en
   este dispositivo. Puedes volver a intentarlo cuando quieras.»** — **sin** la frase de cerrar y volver a abrir
   Yala, que es la del 95 %. Los botones son «Sí, seguir en la nube» y **«Seguir volviendo a iCloud»**. Captura.
4. Toca «Seguir volviendo a iCloud»: el diálogo se cierra y la barra sigue en el 62 %.
5. Vuelve a tocar el botón y ahora sí «Sí, seguir en la nube». La pantalla vuelve a «Tu cuenta en la nube»,
   **sin pedir relanzar**, y la tarjeta «Volver a iCloud» queda sin nota (lo cancelaste tú). Captura.
6. **La nube sigue viva:** anota un gasto y comprueba que sube (panel DEBUG → «Modo Nube · Auth»: el outbox baja a 0
   sin error). Un 409 `yala_account_reverting` aquí significa que el `reverse_abort` no llegó.
7. Deshaz: `update public.profiles set leader_device_id = '<el que apuntaste>', reverse_in_progress = false where id = '<id>';`

**Caso B · el copy del relevo, por el techo.** Con el mismo montaje del caso A, toca «Volver a iCloud», deja la
barra en el 62 % y **espera 15 minutos con la app abierta** (la pantalla re-consulta cada 30 s).

8. A los 15 min la vuelta sale sola: la pantalla cambia a «Tu cuenta en la nube» y la tarjeta «Volver a iCloud» lleva
   un triángulo naranja con **«No pudimos terminar de volver a iCloud: otro de tus dispositivos tomó el relevo.
   Cuando termine, podrás hacerlo en este.»** Captura.
9. **Cierra Yala del todo y ábrela.** La nota sigue ahí: la persona puede leerla al día siguiente.
10. Toca «Volver a iCloud» otra vez: la nota desaparece al empezar el intento nuevo.

**Caso C · el camino feliz no cambia.** Con todo deshecho (paso 7), toca «Volver a iCloud» y deja que avance. Tiene
que pasar del 62 %, pedir cerrar y reabrir Yala, y terminar en modo privado.

### Criterios de aceptación de QA

- [ ] El botón «Cancelar y seguir en la nube» sale en una fase previa al montaje, y no salía antes.
- [ ] Su diálogo NO promete cerrar y volver a abrir Yala, y su «no» dice «Seguir volviendo a iCloud».
- [ ] Cancelar devuelve a «Tu cuenta en la nube» sin pedir relanzar, y lo que se anota después sube.
- [ ] A los 15 minutos la vuelta sale sola con su frase, y la frase sobrevive a cerrar y abrir Yala.
- [ ] El camino feliz sigue terminando en modo privado.

## Barrido de `qa` · 2026-09-23 · cerrado sin device-QA

Sale de la cola de device-QA por el barrido que pidió Jürgen el 2026-09-23 (encargo `2026-09-23-barrido-qa-in-qa-pre-device`). Montarlo pide un UPDATE en staging. El botón hermano («Cancelar la activación», en la ida) se prueba en `snapshot-upload-has-no-ceiling-and-no-way-out`, que sigue en `qa`. Lo cubre `MigrationStateMachineTests`.
