---
id: displaced-leader-after-the-cutover-restores-its-own-identity-over-the-relays
status: discarded
priority: medium
area: "modo-nube, migración"
created: 2026-09-25
updated: 2026-09-25
source: "review adversarial de `relay-row-rekeyed-then-deleted-tombstones-the-leader-identity` (2026-09-25), lente de pérdida de datos"
---

# El líder desplazado tras el cutover puede devolverse SU identidad sobre la del relevo y duplicar

## El problema, en lenguaje de usuario

El primer teléfono activa la nube, llega al último paso y se queda sin red. El segundo toma el relevo y termina. Cuando
el primero vuelve, entra en la cuenta como uno más. Si en ese rato iCloud le había traído las identidades del segundo,
el primero podría volver a poner las suyas y subir algunos movimientos como si fueran nuevos: duplicados.

## Lo medido y lo inferido (2026-09-25)

- **Medido en código**: `restoreRelayIdentities` (#243) corre en CUALQUIER teléfono que lidere la ida, también en el
  reconcile de `done` del líder desplazado, delante de `resolvePostCutoverLease`. Allí devuelve a las filas vivas la
  identidad que ESE teléfono acuñó (la del registro de testigos con coordenadas). Las salidas `finishedHere` /
  `finishedElsewhere` se unen a la cuenta sin el linaje del adopt, así que nada las re-identifica después.
- **Inferido**: si el espejo del líder desplazado importó las identidades del relevo antes del remonte, la restauración las
  cambia por las suyas, que el backend no conoce, y el sync normal las subiría como filas nuevas.
- **Ya cubierto**: los BORRADOS de esas filas salen con las dos identidades desde
  `relay-row-rekeyed-then-deleted-tombstones-the-leader-identity`, así que no resucitan.
- **Sin medir**: qué valor gana CloudKit (dos teléfonos); el canario `cloudRelayIdentityRestored` lo contaría en la flota.

## Criterios de aceptación

- [x] Decidido si la restauración debe correr solo en quien conserva el lease (o solo antes de perderlo), medido contra
      el caso del relevo legítimo, que es el que la necesita. **Ninguna de las dos: corre antes de preguntar y con
      cualquier respuesta, como ya hacía.** Ver abajo.

## Cierre (2026-09-25): descartado, la premisa no se sostiene

**Lo que pasa para el usuario:** nada que arreglar. El teléfono que vuelve se devuelve una identidad que la nube ya tiene,
así que no sube nada como nuevo. Cambiar el código abría en cambio un duplicado real en el caso normal del relevo.

**Medido en código:**

- **El backend tiene la identidad que se restaura.** Al reconcile de `done` solo llega quien pasó SU cutover
  (`.runLeaderReconcileFromFrozenCloudKit` se journalea solo en `(.cutover(.mirrorOff), .mirrorRelaunchCompleted)`), al
  cutover solo se entra desde la verificación en `.match` (`MigrationStateMachine.verifyTransition`), y la hoja del Merkle
  lleva el `sync_id` (`SyncMerkle.swift`, cabecera). O sea que el backend tiene cada fila viva con la identidad que llevaba
  aquí en ese momento, y la restauración vuelve exactamente a esa. La que trajo el espejo solo la tiene si quien la acuñó
  la llegó a subir. El «inferido» de arriba («la suya, que el backend no conoce») era falso.
- **Moverla detrás del lease rompía el relevo legítimo.** El runtime arranca con el reconcile pendiente
  (`CloudSyncRuntime.canRunDomain` no mira los pendientes, `done` es estable y el sello sigue en `.proceedMigration`). Con la
  restauración detrás de la petición de red, el pull del runtime traía la copia del backend de la fila re-identificada,
  creaba un born-remote, y la restauración ya no la tocaba (su identidad quedaba viva en otra fila). Se implementó, se
  probó (sus tests mataron los 6 mutantes que se corrieron) y se retiró tras la review adversarial.
- **Desde g16_04 el caso ni siquiera llega** salvo con la cuenta volviendo a iCloud: quien hizo el cutover no pierde el
  lease ante otra ida.

**Qué quedó:** el código igual, con el porqué escrito en el efecto y en el docblock de `restoreRelayIdentities`; un test
que fija que el reconcile restaura antes de su primera petición de red en las cinco respuestas del lease; la regla
corregida (punto (4) de «Y lo que el líder desplazado exporta TARDE…» y dos frases que decían que el runtime se queda
parado con un pendiente en `done`, medido que no); y el hallazgo del runtime, anotado en
`cloud-engine-can-start-with-a-reverse-abort-pending`.
