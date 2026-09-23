---
id: identity-uuid-repair-can-commit-half-done-after-a-read-failure
status: backlog
priority: medium
area: "sync, dedup, etiquetas"
created: 2026-09-23
updated: 2026-09-23
source: "review adversarial de `drain-duplicates-the-unit-clock-when-its-row-cannot-be-read` (2026-09-23), lente de gemelos"
---

# Si al reparar etiquetas o cuentas duplicadas falla una lectura, la reparación puede quedar a medias

## El problema, en lenguaje de usuario

Cuando la app arregla etiquetas, cuentas o subcategorías que comparten el mismo identificador interno, les da uno
nuevo y actualiza todo lo que apunta a ellas. Si a mitad de camino no consigue leer algo, puede guardar el cambio
de identificador sin haber actualizado todas las referencias: una etiqueta puede quedar huérfana en tus movimientos
para siempre, o el cambio no llegar a la nube.

## Por qué pasa (leído el 2026-09-23; inferido, no ejecutado)

Tres sitios de `CategoryDeduplicationService.repairCollapsedIdentityUUIDs` (`Yala/App/Services/`):

- `rebuildTagCSVMirrors` se traga el `fetch` que falla: «nada que reconstruir», y el remap y el save siguen. Queda
  el CSV stale-pero-presente que la regla `899c1c25` describe como huérfano permanente.
- Los ids se regeneran antes de leer `Budget` y antes del `save()`. Si cualquiera de los dos lanza, el `catch`
  EXTERNO solo hace `return 0`: los ids nuevos quedan sucios en el `mainContext`, sin remap, y el próximo save
  ajeno los guarda. Solo el `catch` interno del remap hace `rollback()`.
- `SyncIdentityService.rekeyIdentity` devuelve `false` si su fetch falla, y el llamador lo descarta: el testigo
  sigue con el id viejo mientras se guarda el `tombstone(oldID)`.

## Criterios de aceptación

- [ ] Toda lectura que falle durante la reparación deshace la pasada entera (rollback) y la aplaza.
- [ ] Tests con cada lectura lanzando + control positivo.
