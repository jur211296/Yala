---
id: lineage-enumeration-check-skips-tables-absent-from-the-merkle
status: backlog
priority: medium
area: "modo-nube, migración"
created: 2026-09-24
updated: 2026-09-24
source: "ticket `lineage-coverage-blocks-forever-after-a-row-deleted-during-the-wait` (2026-09-24), hallazgo menor medido en su ficha original"
---

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
