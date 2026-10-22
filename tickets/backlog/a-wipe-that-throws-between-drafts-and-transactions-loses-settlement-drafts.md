---
id: a-wipe-that-throws-between-drafts-and-transactions-loses-settlement-drafts
status: backlog
priority: low
area: "groups, settings"
created: 2026-09-27
source: "review adversarial de `wipe-data-keeps-groups-but-drops-their-bridged-rows` (2026-09-27, lente de dinero); inferido por lectura, NO reproducido"
updated: 2026-10-08
---

# Un «Vaciar datos» que falla entre los borradores y las transacciones pierde los borradores de las liquidaciones

## El síntoma, en lenguaje de usuario

«Vaciar datos» falla con un error. Mis movimientos siguen, pero el borrador que me preguntaba a qué cuenta llegó un cobro
de grupo ha desaparecido, y no vuelve.

## Lo medido (2026-09-27, leyendo código)

- `wipeAllUserData` guarda por pasos: los borradores en el paso 1.1b y las transacciones en el 1.2.
- Si falla entre los dos, las transacciones siguen y los borradores no. La convergencia (que desde el ticket padre se
  pide ANTES de borrar) salta las liquidaciones con alguna pata, así que su borrador no vuelve.
- Los gastos sí vuelven: su re-puenteo rehace el borrador.

## Qué hay que decidir

¿Se reordena el borrado (transacciones antes que borradores) o la convergencia re-crea el borrador de una liquidación
con pata virtual y sin borrador?

## Relacionados

- [[wipe-data-keeps-groups-but-drops-their-bridged-rows]]

## Medido en 2.1 (triage 2026-10-08)

- `DataWipeService.wipeAllUserData` sigue guardando los borradores (paso 1.1b) antes que las transacciones (1.2), cada uno con su `save()`.
- `GroupsBridgeRestoreConvergence.settlementsToReBridge` sigue excluyendo toda liquidación con alguna pata (`legSettlementIDs`), así que la que conserva su pata virtual sin borrador no se re-puentea.

Triage 2026-10-08: abierto · low → low · el orden borradores→transacciones y el filtro de `settlementsToReBridge` siguen igual; requiere un wipe que lance a mitad, raro.
