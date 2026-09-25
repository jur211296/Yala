---
id: displaced-leader-after-the-cutover-restores-its-own-identity-over-the-relays
status: backlog
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

- [ ] Decidido si la restauración debe correr solo en quien conserva el lease (o solo antes de perderlo), medido contra
      el caso del relevo legítimo, que es el que la necesita.
