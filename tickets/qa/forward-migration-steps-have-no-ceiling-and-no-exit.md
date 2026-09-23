---
id: forward-migration-steps-have-no-ceiling-and-no-exit
status: qa
priority: very-high
area: "modo-nube, migración"
created: 2026-09-22
updated: 2026-09-22
source: "Paso 0 de `snapshot-upload-has-no-ceiling-and-no-way-out` (2026-09-22): barrido del mismo patrón en la ida"
---

# Al activar la nube, tres pasos más pueden quedarse parados para siempre, sin aviso y sin botón

## El problema, en lenguaje de usuario

Al pasar tus datos a la nube la barra avanza por varios pasos. Si en tres de ellos algo falla de forma
persistente, la barra se queda quieta —al **22 %**, al **35 %** o al **80 %**— y ahí se queda: cerrar la app no
cambia nada, «Retomar» repite el mismo fallo y no hay forma de cancelar. Tu iCloud sigue funcionando, pero el
refresco de widgets en segundo plano se para mientras dure.

`snapshot-upload-has-no-ceiling-and-no-way-out` cerró el mismo agujero en el paso del **55 %** (la subida). Estos
tres quedaron fuera a propósito (decisión de Jürgen del 2026-09-22: «solo la subida + ticket»).

## Por qué pasa (medido el 2026-09-22, por nombre de función; las líneas se mueven)

| Paso (barra) | Dónde corta | Qué lo deja parado |
|---|---|---|
| `claimingMigration` (22 %) | `MigrationRunner.driveClaim` | `.transient`, `.sessionExpired` y `.accountUnavailable` devuelven `false` sin evento. Deja rastro en `lastClaimBlocker`, pero la fase no sale nunca |
| `assigningIdentity` (35 %) | `MigrationRunner.drive`, `case .assigningIdentity` | el `catch` de `executor.assignIdentity()` hace `return` sin evento |
| `cutover(.pending)` (80 %) | `MigrationRunner.driveCutover`, `.pending` | `confirmCutoverServer() == false` devuelve `false` sin evento |

Las tres son fases **transitorias** (`BGTaskMigrationGate`): con ellas journaleadas el widget no refresca en
segundo plano y los BGTasks de informes se difieren sin quiescencia.

**`cutover(.serverConfirmed)` NO entra en este ticket, y es a propósito.** Allí `persistLocalMode() == false`
también corta sin evento, pero el backend ya estampó `migrated_at` y «el cutover jamás hace rollback» manda: la
salida de ese paso no puede ser un `failedRollback`. Es otro problema, con otro diseño.

## Qué hay ya hecho que se puede reusar

- El mecanismo de dos relojes (`CauseStallClock`, `MigrationPolicy.snapshot*BudgetSeconds`) y la salida a
  `failedRollback` con `[.rollback]` del ticket hermano. Antes del cutover el teléfono está intacto, así que esa
  salida vale para los tres.
- El texto por motivo de la tarjeta de fallo (`StorageFailureCopyLogic`).

## Qué habría que decidir

1. **¿Un solo techo para la etapa** (como las cuatro fases previas al montaje de la vuelta), con el cambio de fase
   como avance, o uno por fase? En `claimingMigration` y `assigningIdentity` no hay una cifra que baje.
2. **¿«Cancelar» también aquí?** Hoy solo lo ofrece la subida.
3. **`cutover(.pending)`**: aún no hay `migrated_at`, así que el rollback es limpio; pero su precondición de canal
   iCloud ya tiene su propia salida. Hay que mirar que no se pisen.

## Criterios de aceptación

- [x] Cada uno de los tres pasos tiene techo y salida journaleada. (El claim, con «Migrar»; el del adopt tiene ticket
      propio: `adopt-claim-stays-parked-with-no-ceiling`.)
- [x] Un fallo persistente no deja la barra parada indefinidamente.
- [x] Test por paso con el fallo persistente, midiendo que la fase CAMBIA (`MigrationRunnerTests` §15; 22 mutantes
      medidos, los 22 muertos).

## Relacionado

- `snapshot-upload-has-no-ceiling-and-no-way-out` — el mismo bug-class, cerrado para la subida.
- `reverse-before-mount-has-no-way-to-abandon-the-return` — el mismo bug-class, cerrado en la vuelta.
- `forward-verify-reads-an-expired-session-as-network` — la verificación de la ida, que sí tiene salida por contador.

## Paso 0 (2026-09-22, sesión de día — decisiones de Jürgen por AskUserQuestion)

El árbol entero, con lo medido, está en el encargo (`encargos/lanzados/2026-09-22-forward-migration-steps-have-no-ceiling-and-no-exit.md`,
«## Paso 0»). Aquí, lo que manda:

1. **Techo 15 min / 72 h por paso**, molde de la vuelta previa al montaje: pasar de paso cuenta como avance.
2. **«Cancelar la activación» también en los tres**, mismo botón y misma confirmación que al 55 %.
3. **Texto por motivo**: se reusan las dos frases de la subida que siguen siendo verdad (la cuenta, el dispositivo) y hay
   tres nuevas en los 16 idiomas (la activación lleva días sin avanzar, la sesión caducó antes de terminar, otro
   dispositivo con tu cuenta tomó el relevo).
4. **La trampa del claim sin respuesta se cierra aquí**, con una marca local que deja llegar el reintento al claim.

## Lo que se hizo

- `claimingMigration`, `assigningIdentity` y `cutover(.pending)` observan el techo en cada corte (`forwardStepStalled`) y
  salen a `failedRollback` con `[.rollback]`; «Cancelar» (`forwardStepCancelled`) va a `notStarted` sin efectos.
  `MigrationState` schema 10 (cuatro `forwardStepStall*` + `forwardStepExitReasonRaw`).
- Motivos definitivos: la sesión BORRADA por el SDK (claim y cutover), el 403 del claim, el `rejected` y el
  `other_leader` del cutover (`confirmCutoverServer` pasa de `Bool` a `CutoverServerOutcome`) y el `save()` de la
  identidad. La red y el 401 con la sesión guardada esperan 72 h.
- En el claim, techo y «Cancelar» **solo con «Migrar a la nube»**: el adopt conserva su espera (ver la review).
- El «sí» de «Cancelar» vale para la pasada (se honra en la próxima fase que lo ofrece) y un solo sitio decide dónde se
  ofrece (`ForwardCancelScope`).
- La marca del claim de «Migrar» sin respuesta (`CloudClaimActionStore`), que la puerta de identidad trata aparte del
  sello y sin saltarse la red de «Empezar desde cero».
- Canarios `cloudForwardStepWaiting` (por observación) y `cloudForwardStepAborted` (salida y cancelación).

## Review adversarial (2026-09-22, tres lentes independientes + refutación por hallazgo)

**Arreglado:**

1. **(lente de consumidores) El techo y «Cancelar» del claim alcanzaban también al ADOPT**, y ahí la salida era un
   callejón: quien quería entrar en su cuenta acababa en un teléfono vacío, con «Migrar» bloqueado por la puerta y un
   «tus datos siguen en este dispositivo» falso. Ahora el claim solo tiene techo y botón con «Migrar»; el adopt se lleva
   ticket propio.
2. **(dos lentes) La marca del claim la escribía cualquier claim** —adopt y seguidor incluidos— y **se saltaba la red de
   «Empezar desde cero»**: con la sesión de la persona anterior, el reclaim del mismo líder habría subido las finanzas de
   la nueva a su cuenta. Ahora solo marca «Migrar», y la puerta la recibe aparte (`hasUnansweredMigrationClaim`) y no la
   cuenta con esa sesión.
3. **(lente de la marca) Dos mutantes que la suite no mataba**: escribir la marca después del POST (ahora el stub la mira
   en el instante de la petición) y leer `canRenewSession` antes de pedir el token en el cutover (ahora un doble de sesión
   la borra dentro de la renovación). Y la marca con `claiming_in_progress`, que el test no probaba.
4. **(lente de consumidores) Rastros de producción que mentían**: «stop sin evento» en el claim y «converge a follower» en
   el `other_leader`, que nunca convergía.
5. Docblocks de la puerta y de `CloudClaimActionStore` que decían que el sello era la única excepción.

**Aceptado, con su porqué:**

- **Un «sí» dado sobre una fase puede acabar cancelando en otra posterior** que también lo ofrece (p. ej. confirmar sobre
  el 55 % con la pasada ya en la verificación y cancelar al aparcarse en el 80 %). Es lo que la persona pidió y la fase
  sigue dejando el teléfono intacto; el comportamiento viene de #212.
- **Un «sí» con el cutover confirmándose en el servidor no deshace un cutover que ya pasó**: desde `.serverConfirmed`
  manda «el cutover jamás hace rollback». Test propio.
- **Cancelar o rendirse al 80 % con `migrated_at` estampado** (respuesta perdida) deja la cuenta con `mip=true` y este
  teléfono de líder; si la persona reintenta, converge. Si no, a los 60 min otro dispositivo toma el relevo: la misma
  clase que la cancelación al 55 %.
- **La marca deja pasar un poco más que el sello**: un `claiming_in_progress` perdido seguido del abandono de otro
  dispositivo acaba en un relevo, la clase de hueco que ya tiene cualquier «Migrar». Y no se retira cuando otro
  dispositivo termina: el claim para el intento con el aviso bueno, después del consentimiento.

**Con ticket propio:**

- `adopt-claim-stays-parked-with-no-ceiling` — el claim del adopt sin techo, que necesita otra salida.
- `a-failed-snapshot-enqueue-save-leaves-the-journal-unsaved` (ampliado) — **inferido por una lente**: si el `save()` de
  la identidad falla por sus propias filas, el contexto compartido queda sucio y la salida del 35 % no llega a disco. Es
  la misma clase que ese ticket, con la misma decisión pendiente (el alcance de un `rollback()` sobre el `mainContext`).

## QA en dispositivo (lo que un teléfono SÍ puede comprobar)

Los techos (15 min de un motivo definitivo, 72 h en el mismo paso), los seis motivos y sus textos no se pueden montar a
mano: exigen una cuenta rechazada, otro dispositivo que tome el relevo, un `save()` local que falle o tres días de espera.
Los fijan los tests unitarios (`MigrationRunnerTests` §15, `MigrationStateMachineTests`, `ForwardStepCeilingLogicTests`,
`MigrationWorkExecutorTests`). Aparcar el claim (22 %) a mano tampoco es posible: la puerta de identidad pregunta al
backend justo antes, así que sin red se para ahí, y la ventana entre las dos llamadas es de milisegundos. Lo que sí se
comprueba en el teléfono es que nada se rompe y, con suerte, el 80 %:

**Montaje**
1. Build de **Yala Dev** (va a staging) en un iPhone con un corpus mediano (unos cientos de movimientos). Tu cuenta de
   staging, sin migrar.
2. Ajustes → Almacenamiento → «Migrar a la nube» → consentimiento → iniciar sesión.

**Guion**
3. Deja que la migración termine sin tocar nada.
   Esperado: la barra pasa por 22 %, 35 %, 55 %, 75 % y 80 % sin pararse, y termina en «cierra y vuelve a abrir Yala»
   como siempre. Cierra y abre: modo nube activo.
4. (Regresión de #212) Vuelve a iCloud, repite el montaje y, en cuanto la barra llegue a **55 %**, activa el **modo avión**.
   Esperado: aparece «Cancelar la activación» debajo de «Retomar»; «Sí, cancelar» vuelve a «Migrar a la nube» sin alerta.
5. (Opcional, depende del momento) Repite el montaje y activa el **modo avión** justo cuando la barra pase de **75 %**.
   Si se queda en **80 %**: aparece «Cancelar la activación»; «Seguir activando la nube» no cambia nada; quita el modo
   avión y toca «Retomar» → la migración termina normal. Si la barra se queda en 75 %, el corte llegó antes (verificación):
   no es este paso y no cuenta como fallo.
