---
id: dangling-ref-pass-overwrites-a-pending-local-edit
status: backlog
priority: low
area: "modo-nube, sync"
created: 2026-09-23
updated: 2026-09-23
source: "review adversarial de `dangling-ref-repair-is-lost-when-its-row-cannot-be-read` (2026-09-23), lente de corrección — hallazgo 4"
---

# Si cambias la categoría de un movimiento que esperaba la suya de la nube, la app puede ponerle la vieja

## El problema, en lenguaje de usuario

Un movimiento baja de la nube antes que su categoría y se queda esperándola. Si mientras tanto le pones otra
categoría a mano, cuando la de la nube llega la app te la cambia por la de la nube. Casi siempre vuelve a tu
elección en la siguiente sincronización; en una ventana estrecha, tu cambio se pierde.

## Por qué pasa (leído el 2026-09-23; no ejecutado)

- `SyncApplyEngine.reresolveDanglingRefs` aplica la ref del dangler SIN consultar el guard D-1 (`buildPendingGuards`)
  y ningún camino de edición local borra el `SyncDanglingRef` de esa (fila, columna). Sus únicos escritores son
  `EntityApplyMap.resolveRef`, `clearDangler`/`registerDangler` y el propio pase.
- Caso normal: la edición local ya está en el outbox con su valor (`fieldsJSON`), sube y vuelve a bajar ⇒ parpadeo.
- Ventana de pérdida (inferida): el pase corre tras la última página del ciclo y, si esa página vino vacía, **sin**
  `drainOnce` delante. Una edición que aterriza durante el `await` de ese último pull todavía no está en el outbox;
  el pase la pisa bajo `outboxSaveAuthor` y el próximo drain relee el modelo vivo ⇒ sube el valor remoto con HLC
  fresco (el laundering de D-2). Exige además que el destino llegue o se vuelva legible justo en ese ciclo.

## Qué habría que decidir

- Un `drainOnce` síncrono antes del pase y el guard D-1 por unidad al aplicar el dangler, o que una edición local de
  la columna borre su dangler (el valor local gana y la ref del wire deja de estar pendiente).

## Criterios de aceptación

- [ ] Una edición local de una columna con dangler pendiente no la pisa el pase final.
