---
id: relay-identity-ledger-missing-after-an-update-mid-migration
status: discarded
priority: low
area: "modo-nube, migración"
created: 2026-09-25
updated: 2026-10-08
source: "review adversarial de `relay-row-rekeyed-then-deleted-tombstones-the-leader-identity` (2026-09-25), lente del ciclo de vida"
---

Why: Discarded 2026-10-08. El hueco solo existe para quien pasó la fase de identidad con un build SIN el registro (anterior a 624ce61df, 2026-09-25) y actualizó a mitad de la activación. Producción no tiene activación de la nube: el último release etiquetado, v2.0.4, no trae `MigrationWorkExecutor` ni `CloudBackendConfig`, y la activación se estrena en 2.1 (`docs/modo-nube/MODO-NUBE-DECISION-RELEASE-2.1.md`), que ya siembra el registro en `assignIdentity` y en el adopt (`MigrationWorkExecutor.seedRelayIdentityLedger`). Ningún usuario de 2.1 puede estar en esa ventana; solo un tester de TestFlight de antes del 25-sep.

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

## Medido en 2.1 (triage 2026-10-08)

- `RelayIdentityLedger` nace en 624ce61df (2026-09-25). `MigrationWorkExecutor.seedRelayIdentityLedger` lo siembran `assignIdentity` y el adopt; `restoreRelayIdentities` sigue sin sembrar, como dice el ticket.
- `git ls-tree v2.0.4` no contiene `MigrationWorkExecutor.swift` ni `CloudBackendConfig.swift`: ninguna instalación de producción puede tener una activación a medias de antes del registro.

Triage 2026-10-08: descartado · low → — · la ventana solo existe entre un build de TestFlight anterior al 25-sep y uno posterior; producción no tiene activación de la nube y 2.1 sale con el registro.
