---
id: groups-drain-failure-reads-as-nothing-pending
status: backlog
priority: medium
area: "groups, modo-nube"
created: 2026-09-26
source: "review adversarial de `fresh-start-wipe-kills-unsent-group-writes-silently` (2026-09-26)"
---

# Un drain de grupos que falla se lee como «no hay nada pendiente»

## El problema

Antes de dar por vacío el outbox de grupos, el cierre de sesión y «Empezar de cero» drenan el SwiftData History al
outbox (`GroupsSyncClient.drainOnce`) y cuentan las filas vivas. Pero `drainOnce` no devuelve nada: `performDrain` se
traga cualquier error (`fetchHistory`, `buildLookups`, el `save`), y la deriva del reloj HLC corta con `break`. Lo que
no llegó a traducirse vive solo en el History, el recuento da 0 y el borrado sigue. Después ningún drain encuentra una
fila viva que traducir, y ese gasto se pierde en silencio.

Lo encontró la lente de datos de la review de `fresh-start-wipe-kills-unsent-group-writes-silently` (2026-09-26),
leyendo el código sin ejecutarlo. El hueco ya existía en `CloudSessionSignOut.pushAllPendingGroupsForSignOut`; desde
ese día también lo usa `groupsOutboxIsSettledEmpty`.

**Su gemelo, por el espejo:** el drain escribe primero en el espejo del App Group (regla Q3). Un kill o un `save`
fallido deja la fila solo ahí, y la rehidratación solo corre en `startIfEligible`, con el flag compuesto y una sesión.
En un proceso sin esas dos cosas el recuento da 0 y `resetSyncState` purga el espejo.

## Por dónde va

El molde es el del canal personal (`CloudSyncEngine.drainOnce` devuelve si terminó, desde
`drain-duplicates-the-unit-clock-when-its-row-cannot-be-read`). Que `GroupsSyncClient.drainOnce` lo devuelva también,
y que los dos pre-checks bloqueen con `false`. Para el espejo, contar sus entradas en el cinturón del borrado.
