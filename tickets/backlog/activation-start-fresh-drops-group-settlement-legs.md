---
id: activation-start-fresh-drops-group-settlement-legs
status: backlog
priority: medium
area: "groups, onboarding"
created: 2026-09-27
source: "review adversarial de `activation-private-gate-leaves-a-late-notice-that-purges-groups` (2026-09-27, lente «después del borrado»); inferido por lectura, NO reproducido"
---

# «Activar Yala completo → Restaurar → Empezar desde cero» pierde las liquidaciones de grupo en lo personal

## El síntoma, en lenguaje de usuario

Activo Yala completo, entro en Restaurar y elijo «Empezar desde cero». Mis grupos y sus saldos siguen bien, pero en mis
cuentas personales los cobros y pagos de grupo que ya había liquidado desaparecen: la cuenta de grupos cuenta lo que
presté sin descontar lo que ya me devolvieron.

## Lo medido (2026-09-27, leyendo código)

- El borrado es `.importedRows`: `DataWipeService.wipeAllUserData` borra toda `TransactionItem`, también las patas de
  liquidación (`splitSettlementID`).
- Después solo se pide `GroupsBridgeRestoreConvergenceStore.markPending()` (`ContentView`,
  `performICloudZoneAndImportedRowsWipe`), y esa convergencia re-puentea solo GASTOS
  (`GroupsBridgeRestoreConvergence.convergeIfPending`, `settlementIDs: []`). Las patas de liquidación solo vuelven si un
  sync cambia esa liquidación.
- El aviso tardío de quien activó tiene el mismo borrado y ya las re-arma (`armSettlementLegsAfterLateWipe`, ticket
  `activation-private-gate-leaves-a-late-notice-that-purges-groups`). Aquí no se copió porque la sesión todavía es
  solo-grupos: re-puentear una liquidación en esa sesión puede crear la forma de solo-grupos, que la convergencia de
  después no sabe fundir. Hay que decidir cuándo pedirlo (¿tras `completeFullActivation`?).

## Criterios de aceptación

- [ ] Tras «Empezar desde cero» dentro de la activación, las liquidaciones confirmadas vuelven a lo personal.
- [ ] Ninguna liquidación sale dos veces.

## Relacionados

- [[activation-private-gate-leaves-a-late-notice-that-purges-groups]]
