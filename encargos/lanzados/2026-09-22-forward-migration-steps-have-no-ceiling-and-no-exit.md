# Al activar la nube, tres pasos más (22 % / 35 % / 80 %) pueden quedarse parados para siempre — mismo techo+salida que la subida

## Contexto
Cola A serial tras merge #213 (proceso autónomo) y #212 (techo de la subida al 55 %). Ticket `forward-migration-steps-have-no-ceiling-and-no-exit` (very-high). Ya en `tickets/in-progress/` e índice `docs/TICKETS.md` al día.

Hermano cerrado: `snapshot-upload-has-no-ceiling-and-no-way-out` (#212). Piezas a reusar: `CauseStallClock`, presupuestos de `MigrationPolicy`, salida a `failedRollback` con `[.rollback]` (antes del cutover el teléfono está intacto), y texto por motivo vía `StorageFailureCopyLogic`.

Los tres agujeros medidos (nombres de función; las líneas se mueven):
- `claimingMigration` (22 %) — `MigrationRunner.driveClaim`: `.transient` / `.sessionExpired` / `.accountUnavailable` devuelven `false` sin evento
- `assigningIdentity` (35 %) — `catch` de `executor.assignIdentity()` hace `return` sin evento
- `cutover(.pending)` (80 %) — `confirmCutoverServer() == false` sin evento

**`cutover(.serverConfirmed)` NO entra** (backend ya estampó `migrated_at`; otro diseño).

ESTADO 22-sep: el destino del gate por nombre no resuelve en esta Mac (iOS 27.0). Corre el gate con `-destination 'platform=iOS Simulator,id=9D0F6D32-1F49-46AD-8070-603D42B5220F'` (iPhone 17 Pro 26.5).

## Que se pide
1. Techo + salida journaleada en cada uno de esos tres pasos, reusando el patrón de la subida (reloj por causa; no un techo «genérico» que trate un 401 renovable como definitivo).
2. Que un fallo persistente no deje la barra parada indefinidamente; al rendirse: tarjeta de fallo con texto por motivo + camino de salida (Cancelar/abandonar coherente con #212).
3. Test por paso con fallo persistente midiendo que la **fase CAMBIA**.
4. Board del repo al cerrar: ticket a `qa` (con guion device-QA si aplica) o `done`; `docs/TICKETS.md` al día. Residuales → ticket propio antes de cerrar.

## Decisiones de producto (día 6:00–21:00 Lima)
Puedes usar AskUserQuestion para lo que necesites de Jürgen. Si preguntas, ofrece opciones y recomienda la robusta (norma: nunca la más básica):
1. ¿Un techo por etapa (cambio de fase = avance) o uno por fase? Recomendación: reloj por causa alineado con #212 / vuelta pre-mount; no un techo flojo que no dispare.
2. ¿«Cancelar» también aquí (como en la subida)? Recomendación: sí, con confirmación, mientras el teléfono sigue intacto.
3. En `cutover(.pending)`: no pisar la salida ya existente del canal iCloud; rollback limpio porque aún no hay `migrated_at`.

Si Jürgen no contesta a tiempo y el riesgo es reversible: elige la opción recomendada y anótala. Si es irreversible / datos en riesgo: aparca en ticket propio, no inventes.

## MODO AUTÓNOMO HASTA TERMINAR
Gate, commit, docs/board del repo, `docs/TICKETS.md`, PR, CI, merge a `2.1` y `/cerrar-total` sin preguntar si corres el gate o el commit. Device-QA de iPhone deja el ticket en `qa` con guion y **no** frena el merge.

**Override del gate «>3 ficheros / ¿Sigo?»:** en esta cola autónoma NO te pares a pedir OK tras el plan ni tras implementar, aunque toques muchos ficheros. Sigue hasta el cierre. (Quedó escrito en CLAUDE.md con #213; si algo del agent memory contradice, gana este override.)

## Que NO hay que tocar
- `marketing/`, Web/
- `cutover(.serverConfirmed)` / diseño post-`migrated_at`
- No reabrir la subida del 55 % (#212) salvo bug real de integración
- No inventar prioridades ni cerrar sin evidencia

## Como se sabe que esta bien
- Los tres pasos tienen techo y salida; un fallo persistente no deja la barra quieta para siempre
- Tests por paso demuestran cambio de fase
- Gate verde (destino por `id=` si hace falta)
- PR mergeado a `2.1`, board/`TICKETS.md` al día, `/cerrar-total`

## Paso 0 (2026-09-22, sesión de día — decisiones de Jürgen por AskUserQuestion)

### Lo medido antes de decidir

- **Los tres cortes, confirmados en este árbol.** `driveClaim` devuelve `false` sin evento en sus tres no-éxitos; el `catch`
  de `assignIdentity()` hace `return`; `confirmCutoverServer()` es un `Bool` y su `false` corta sin evento. Los tres se
  retoman por el boot, cada foreground y el re-kick de 30 s (`MigrationBootDecision.decide` → `.resume`).
- **Qué causas llegan a cada paso.** Claim (`/account/claim`, `requireUser`, sin attest): sin JWT o 401 (`.sessionExpired`),
  403 defensivo (`.accountUnavailable`, hoy no se emite) y red/5xx (`.transient`). Identidad: solo el `context.save()`
  puede lanzar ⇒ fallo LOCAL. Cutover `.pending` (`migration_progress('cutover')`): sin JWT o 401, `other_leader` (otro
  dispositivo tomó el relevo del lease), `rejected` (`not_in_progress`, `no_profile`, `bad_action`) y red.
- **El 401 no es uno.** En los dos pasos de red, «sin JWT» incluye el token que no se renueva sin red con la sesión
  guardada. Regla de la familia: definitivo solo con la sesión BORRADA por el SDK (`canRenewSession == false`, leído
  después de la llamada); con la sesión guardada va al plazo largo.
- **Rollback limpio en los tres.** Antes del cutover el teléfono sigue en `.icloud`, sin marcador ni mirror apagado.
  En `cutover(.pending)` una respuesta perdida puede dejar `migrated_at` estampado: medido que el cliente no lo lee y que
  el reintento del mismo líder converge (claim → `created`, `cutover` idempotente, goldens 6 y 4).
- **La trampa del claim perdido (nueva alcanzabilidad, no preexistente en la práctica).** Un claim que llega al servidor
  con la respuesta perdida deja la cuenta `complete` sin el sello `.proceedMigration`. Hoy no se ve porque el paso no sale
  nunca; con techo o «Cancelar», el reintento se para en la puerta de identidad con `accountHasPersonalData` (falso) y ya
  no deja migrar a esa cuenta.
- **La salida del canal iCloud en `cutover(.pending)`** (`abortCutoverEntryIfChannelBroken`) corre antes de
  `confirmCutoverServer` en cada pasada: el techo nuevo solo observa cuando esa puerta ya dejó pasar. No se pisan.
- **El «sí» de Cancelar en vuelo**: `drive()` hoy lo tira en cuanto la fase no es la subida; con el claim en vuelo y la
  red de vuelta, un «sí» dado al 22 % se perdería y la pasada seguiría hasta el cutover.

### Decisiones de Jürgen (las cuatro, la recomendada)

1. **Techo 15 min / 72 h por paso**, molde de la vuelta previa al montaje: pasar de paso cuenta como avance; 15 min
   ACUMULADOS bajo un motivo que esperar no arregla; 72 h con cualquier causa.
2. **«Cancelar la activación» también en los tres**, con el mismo botón y la misma confirmación que al 55 %.
3. **Texto por motivo** en la tarjeta de fallo: se reusan los dos del 55 % que siguen siendo verdad (cuenta, dispositivo)
   y tres nuevos en los 16 idiomas (días sin avanzar, sesión caducada, otro dispositivo tomó el relevo).
4. **La trampa del claim perdido se cierra en este PR**: marca local «este teléfono ya pidió esta cuenta para migrar»,
   escrita antes del POST, que deja pasar el reintento; el claim sigue decidiendo.

### Lo técnico, decidido por mí con lo medido

- **Un solo mecanismo para los tres**, con la familia `forwardStepStall*` (cuatro campos, reloj de avance + tres del
  reloj de causa vía `CauseStallClock`) y `forwardStepExitReasonRaw` aparte. Sin campo de fase: `handle` los limpia en
  cada cambio de `ForwardStepPhase`, como la subida al entrar y salir. `MigrationState` schema 9 → 10.
- **Motivos definitivos**: `sessionExpired` (sesión borrada), `accountUnavailable` (403 del claim), `refused`
  (`rejected` del cutover), `otherDevice` (`other_leader`), `localFailure` (identidad). La red y el 401 con sesión
  guardada van al largo. El motivo journaleado lo elige el techo que VENCIÓ.
- **Salida** a `failedRollback` con `[.rollback]`; **Cancelar** a `notStarted` sin efectos. Eventos nuevos
  `forwardStepStalled` / `forwardStepCancelled`, legales solo desde los tres; `snapshotUploadCancelled` no se toca.
- **`confirmCutoverServer` pasa a devolver un outcome tipado** (el ejecutor clasifica); el claim sigue con
  `ClaimOutcome` y el runner pregunta `canRenewSession()` al ejecutor tras un `.sessionExpired`.
- **El «sí» de Cancelar vale para la pasada**: se honra en la próxima fase cancelable y se tira en la primera que no lo
  es (verificación, cutover confirmado). Mantiene el caso de #212 (pedido en `verifying` no cancela la vuelta a la subida).
- **Nombres generalizados** (`canCancelMigration`, `cancelMigration()`, `requestMigrationCancel()`): el mismo botón sirve
  a cuatro fases y un nombre de «subida» mentiría.
- **La marca del claim**: `CloudClaimActionStore`, clave propia, escrita en `performClaim` tras tener JWT y antes del
  POST, borrada con cualquier `.success`. La puerta la suma a `claimedForMigrationHere`. Hueco aceptado, de la misma
  clase que ya existe: un takeover de una migración abandonada de otro dispositivo de la misma cuenta.
- **Canarios**: `cloudForwardStepWaiting` por observación (`<paso>|<tramo avance>|<tramo causa>|<causa>`, `canaryOnce`) y
  `cloudForwardStepAborted` en la salida y en la cancelación.

### Lo que cambió la review adversarial (tres lentes)

- **El claim, solo con «Migrar»**: con la intención de adoptar, la salida era un callejón. El techo y «Cancelar» del
  claim quedan acotados a `migrateOnly` (`ForwardCancelScope.offersCancel(_:claimIntent:)`, `driveClaim`); el adopt, con
  ticket propio (`adopt-claim-stays-parked-with-no-ceiling`).
- **La marca del claim**: solo la escribe un claim de «Migrar» (`performClaim(marksMigrationAttempt:)`), y la puerta la
  recibe APARTE del sello (`hasUnansweredMigrationClaim`) y sin saltarse la red de «Empezar desde cero».
- El detalle entero, con lo aceptado y lo que tiene ticket, en el ticket (`tickets/qa/forward-migration-steps-have-no-ceiling-and-no-exit.md`, «Review adversarial»).
