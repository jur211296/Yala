---
id: wipe-data-keeps-groups-but-drops-their-bridged-rows
status: backlog
priority: medium
area: "groups, settings"
created: 2026-09-27
source: "review adversarial de `activation-start-fresh-drops-group-settlement-legs` (2026-09-27, lente de reglas); inferido por lectura, NO reproducido"
---

# «Vaciar datos» conserva los grupos pero se lleva sus gastos y liquidaciones de lo personal

## El síntoma, en lenguaje de usuario

En Ajustes vacío mis datos. Mis grupos y sus saldos siguen ahí, pero cuando vuelvo a empezar mis cuentas personales, los
gastos y las liquidaciones de grupo ya no aparecen en Registros, en el Panel ni en el Inbox. Solo vuelven los que alguien
edite después.

## Lo medido (2026-09-27, leyendo código)

- `UserDataResetView.handleWipeAllData` llama a `DataWipeService.wipeAllUserData`, que borra `TransactionItem` sin
  predicado: también las filas puenteadas (`splitExpenseID`, `splitSettlementID`). El dominio de Grupos se conserva por
  diseño.
- Después solo aplica el aterrizaje (`applyWipeLanding`). No pide `GroupsBridgeRestoreConvergenceStore.markPending()`
  ni `markSettlementLegsPending()`, que es lo que piden desde el 2026-09-27 los dos borrados de iCloud que conservan
  grupos (ticket `activation-start-fresh-drops-group-settlement-legs`).

## Qué hay que decidir

Si «Vaciar datos» es «borrar mi vida personal y volver a empezarla» (los gastos de grupo vuelven a lo personal, con la
misma receta) o si debe dejar lo personal sin rastro de los grupos. El copy de la pantalla decide cuál es la promesa.

## Criterios de aceptación

- [ ] Tras «Vaciar datos» con grupos conservados, lo personal refleja los gastos y liquidaciones de grupo según la
      decisión de arriba, sin duplicados.

## Relacionados

- [[activation-start-fresh-drops-group-settlement-legs]]
