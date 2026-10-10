---
id: groups-convergence-retries-every-launch-without-a-ceiling
status: backlog
priority: very-low
area: "groups"
created: 2026-09-27
updated: 2026-10-08
source: "review adversarial de `activation-start-fresh-drops-group-settlement-legs` (2026-09-27, lente de momento y kill-safety); inferido por lectura, NO reproducido"
---

# La convergencia del bridge de grupos reintenta en cada arranque, sin tope, si el store falla

## El síntoma, en lenguaje de usuario

Ninguno visible mientras el store funcione. Si una lectura o un guardado del store personal falla siempre (un store
dañado), cada arranque vuelve a re-puentear todos los gastos de grupo y las liquidaciones sin patas, y a trabajar para
nada.

## Lo medido (2026-09-27, leyendo código)

- `GroupsBridgeRestoreConvergence.convergeIfPending` hace todo dentro de un solo `do`: gastos, liquidaciones
  (`reBridgeSettlementLegs`, desde este ticket), la entrega a `GroupsPendingBridgeIntent` y `dedupeSettlementVirtualLegs`.
  Si algo lanza, el `catch` deja la intención puesta y el arranque siguiente repite todo.
- No hay contador: al revés que `GroupsPendingBridgeIntent`, que corta a los 3 intentos por ID.
- Preexistía para los gastos. Desde el 2026-09-27 un fallo al re-puentear las liquidaciones también deja sin cerrar la
  convergencia de gastos; antes, en el aviso tardío, las liquidaciones iban por la intención durable, con su tope.
- Solo lanzan los fetch y los `save()`: los fallos por gasto o liquidación los traga el bridge.

## Criterios de aceptación

- [ ] Un fallo persistente del store no hace trabajo en cada arranque para siempre.
- [ ] Un fallo al re-puentear liquidaciones no deja sin cerrar la convergencia de gastos, ni al revés.

## Relacionados

- [[activation-start-fresh-drops-group-settlement-legs]]

## Medido en 2.1 (triage 2026-10-08)

- `GroupsBridgeRestoreConvergence.convergeIfPending` sigue con gastos, liquidaciones, la entrega a `GroupsPendingBridgeIntent` y `dedupeSettlementVirtualLegs` dentro de un solo `do`; el `catch` deja la intención puesta y no hay contador de intentos.
- Los cinco commits posteriores sobre el fichero (`e7bfa659f` … `ae204458d`) cambiaron qué se converge, no el tope.
- Solo muerde con un store que falla siempre, y entonces el síntoma es trabajo de más en cada arranque, no un dato perdido.

Triage 2026-10-08: abierto · low → very-low · sigue sin tope, pero solo con un store dañado de forma persistente y sin síntoma visible.
