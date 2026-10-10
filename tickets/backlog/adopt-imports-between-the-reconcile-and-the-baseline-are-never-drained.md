---
id: adopt-imports-between-the-reconcile-and-the-baseline-are-never-drained
status: backlog
priority: low
area: "modo-nube, migración"
created: 2026-10-05
updated: 2026-10-08
source: "lectura del código al implementar el canario de `adopt-window-uploads-what-reaches-the-mirror-after-the-icloud-check`, 2026-10-05"
---

# Lo que el espejo importa entre el reconcile del adopt y el paso 3 no lo juzga nadie ni lo traduce el drain

## El problema, en lenguaje de usuario

Activo la nube en un iPhone con una cuenta que ya existe. Mientras el adopt sube lo que le faltaba a la nube, mi iCloud
todavía está bajando algo (un gasto que apuntó el iPad). Ese gasto se queda en este iPhone y no llega a la nube: no lo ven
mis otros dispositivos.

## Lo leído en el código (2026-10-05), sin reproducir

- `MigrationWorkExecutor.runAdoptFlow`: paso 2 `runAdoptOrphanReconcile` → paso 2-bis → paso 3
  `engine.fastForwardHistoryBaseline`.
- Dentro del reconcile, el último inventario (`collectAdoptInventory`, el plan definitivo) se lee ANTES de
  `await uploadAdoptOrphans`, que va a la red.
- `fastForwardHistoryBaseline` ancla el token en la ÚLTIMA transacción del store personal que no escribió el motor. Un
  import que el espejo fusione durante ese `await` queda por debajo del ancla.
- El drain tras relanzar lee solo lo posterior al ancla: esa alta no se traduce. Y la guarda de linaje no la vio.
- Inferido, sin medir: que el espejo importe en ese hueco (el paso 1 exige quiescencia del import, pero no la mantiene) y
  que ninguna otra vía (el Merkle del runtime) acabe subiéndola.

## Por qué low

El hueco dura lo que la subida de huérfanas del adopt (segundos con red), y lo que cae ahí es del mismo iCloud. El dato no
se pierde: sigue en este teléfono.

## Opciones, sin decidir

- Releer el inventario después de la subida y antes del paso 3, y repetir el reconcile si creció.
- Anclar el paso 3 en el token que había cuando se leyó el último inventario, no en el último del historial: lo de después
  lo traduciría el drain (y lo contaría el canario `cloudAdoptLateImportUnproven`).

## Relación

- Sale de `adopt-window-uploads-what-reaches-the-mirror-after-the-icloud-check` (el canario no lo ve).
- Familia: `adopt-window-late-imports-overwrite-newer-cloud-edits`.

## Medido en 2.1 (triage 2026-10-08)

- En `runAdoptOrphanReconcile` el último `collectAdoptInventory()` sigue antes de `await uploadAdoptOrphans(plan, …)` y no hay relectura después.
- `runAdoptFlow` sigue llamando a `engine.fastForwardHistoryBaseline` en el paso 3, después del reconcile, con el ancla en la última transacción del store.

Triage 2026-10-08: abierto · low → low · el orden inventario → subida → baseline sigue igual; el hueco dura segundos y el dato no se pierde, sigue en el teléfono.
