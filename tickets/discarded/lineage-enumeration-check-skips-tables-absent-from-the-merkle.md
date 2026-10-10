---
id: lineage-enumeration-check-skips-tables-absent-from-the-merkle
status: discarded
priority: medium
area: "modo-nube, migración"
created: 2026-09-24
updated: 2026-10-08
source: "ticket `lineage-coverage-blocks-forever-after-a-row-deleted-during-the-wait` (2026-09-24), hallazgo menor medido en su ficha original"
---

Why: Discarded 2026-10-08. Premisa falsa: /sync/merkle emite las 16 tablas del manifest, también las vacías con count 0, o falla con 502

# La comprobación de la enumeración solo mira las tablas que trae el Merkle

## El problema, en lenguaje de usuario

Antes de decidir si el segundo teléfono puede subir sus datos, Yala lista lo que la cuenta ya tiene en el servidor y
comprueba que la lista está completa. Esa comprobación solo mira las listas que el servidor le dice que existen. Si una
lista no aparece en ese resumen y la lectura se quedó a medias, Yala la da por completa, y podría subir filas que el
servidor ya tenía.

## Lo medido (2026-09-24)

- `MigrationWorkExecutor.verifyEnumerationComplete` recorre `merkle.entities` y compara, tabla a tabla, el conteo de
  vivas del Merkle con lo enumerado. Una tabla con filas en la enumeración y ausente de `merkle.entities` no se compara.
- La usan el adopt (`runAdoptOrphanReconcile`), la ida (`checkForwardLineage`) y el dry-run. No depende del arreglo de
  `lineage-coverage-blocks-forever-after-a-row-deleted-during-the-wait`: ya estaba así.

## Sin medir

- Si el Merkle del servidor devuelve todas las tablas del canal, con `count: 0` las vacías, o solo las que tienen filas.
  Si las devuelve todas, el hueco es teórico. Es lo primero que hay que medir (cuerpo de `/sync/merkle` en `gateway/`).

## Criterios de aceptación

- [ ] Medido qué tablas devuelve `/sync/merkle`.
- [ ] Si alguna puede faltar: una tabla enumerada o del inventario local ausente del Merkle no da la enumeración por
      completa (o se justifica por qué no hace falta).

## Medido en 2.1 (triage 2026-10-08)

`handleSyncMerkle` (`gateway/src/sync/routes.ts:361-396`) recorre **todas** las `SYNCABLE_ENTITIES` del manifest (`gateway/src/sync/manifest.ts:38`). Escribe `entities[entity] = { count, hash }` para cada una, también con `count: 0`, y si una tabla falla devuelve 502. Así que ninguna tabla del canal puede faltar en `merkle.entities`: el hueco es teórico, como el propio ticket preveía.

Triage 2026-10-08: descartado · medium → — · premisa falsa: `/sync/merkle` emite las 16 tablas del manifest, también las vacías con `count: 0`, o falla con 502 (`gateway/src/sync/routes.ts:361-396`).
