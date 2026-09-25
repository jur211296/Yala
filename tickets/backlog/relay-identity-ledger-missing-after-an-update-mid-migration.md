---
id: relay-identity-ledger-missing-after-an-update-mid-migration
status: backlog
priority: low
area: "modo-nube, migración"
created: 2026-09-25
updated: 2026-09-25
source: "review adversarial de `relay-row-rekeyed-then-deleted-tombstones-the-leader-identity` (2026-09-25), lente del ciclo de vida"
---

# Un teléfono que se actualiza a mitad de activar la nube no tiene el registro de identidades

## El problema, en lenguaje de usuario

Si actualizas Yala justo mientras activas la nube y ya habías pasado el paso de preparar tus datos, la protección nueva
contra «un movimiento borrado que reaparece» no se aplica en esa activación. Las siguientes, sí.

## Lo medido y lo inferido (2026-09-25)

- **Medido**: el registro `RelayIdentityLedger` solo lo siembra `assignIdentity`. Con la fase ya pasada, no se repite, y
  el borrado de una fila re-identificada sale como antes del ticket (solo con la identidad preservada).
- **Inferido**: la población es mínima (actualizar en esa ventana, y además el caso raro del líder desplazado).

## Criterios de aceptación

- [ ] Decidido si merece sembrar también en `restoreRelayIdentities` (ya recorre las filas vivas), midiendo el coste de
      escribir el fichero antes de cada página del snapshot.
