---
id: forward-migration-steps-have-no-ceiling-and-no-exit
status: backlog
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

- [ ] Cada uno de los tres pasos tiene techo y salida journaleada.
- [ ] Un fallo persistente no deja la barra parada indefinidamente.
- [ ] Test por paso con el fallo persistente, midiendo que la fase CAMBIA.

## Relacionado

- `snapshot-upload-has-no-ceiling-and-no-way-out` — el mismo bug-class, cerrado para la subida.
- `reverse-before-mount-has-no-way-to-abandon-the-return` — el mismo bug-class, cerrado en la vuelta.
- `forward-verify-reads-an-expired-session-as-network` — la verificación de la ida, que sí tiene salida por contador.
