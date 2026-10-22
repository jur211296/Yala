---
id: groups-merkle-reads-an-unreadable-table-as-an-empty-one
status: done
priority: high
area: "grupos, modo-nube"
created: 2026-09-22
updated: 2026-09-23
source: "barrido del patrón durante `verify-reads-a-failed-local-fetch-as-an-empty-outbox` (2026-09-22)"
---

# Si una tabla de un grupo no se deja leer, la app se cree que el grupo está mal y se lo baja entero otra vez

## El problema, en lenguaje de usuario

La app comprueba de vez en cuando que lo que tiene de un grupo coincide con lo que hay en el servidor. Si en
ese momento la base de datos del teléfono no se deja leer, la app no dice «no he podido comprobarlo»: da por
hecho que **el grupo está vacío**, concluye que no coincide con el servidor y **se vuelve a bajar el grupo
entero**. Sobre una avería del teléfono, y sin que nadie se entere.

## Por qué pasa (medido el 2026-09-22 en este árbol)

Es el mismo patrón que cerró `verify-reads-a-failed-local-fetch-as-an-empty-outbox` en el canal PERSONAL, en el
canal de GRUPOS, que ese ticket dejó fuera a propósito por ser otro canal con otra cadena de consumidores.

1. `GroupMerkleProjection.collectLeaves` (`:193-200`) devuelve `[]` en el `catch` de su `fetch`. Ese `[]` se
   ensambla con `SyncMerkle.entityDigest([])` = `sha256("")` — **byte a byte el mismo hash que una tabla sin
   filas**.
2. `collectMemberLeaves` (`:220-229`) hace lo mismo para `group_members`.
3. Los cinco fetch de `computeLocalMerkle` (`:150-167`) van sobre el MISMO `ModelContext`, así que una avería
   del store los tira los cinco a la vez.
4. `GroupsSyncClient.verifyGroupIntegrity` (`:3321`) recibe ese árbol. Su guard R4 de remoto-vacío exige
   `!localEmpty` (`:3335-3339`) ⇒ **con el local en cero no salta**, y con el remoto poblado las cinco tablas
   divergen → `.diverged(entities:)`.
5. `runGroupMerkleVerification` (`:3266-3268`) responde a eso con `resetGroupCursors(divergentGroups)` +
   `pullUntilExhausted`: **cursor a 0 y el grupo entero de vuelta**.

Y con el remoto también vacío, **converge en falso**.

El contraste está dentro del propio fichero: la FILA que no se puede canonicalizar deja rastro
(`CloudSyncBreadcrumb.encodeRejected`, `:211` y `:240`); la TABLA ENTERA que no se pudo leer no deja nada — solo
un `print` bajo `#if DEBUG`, mudo en producción.

## Qué habría que decidir antes de hacerlo

1. **El veredicto de Grupos necesita su propio motivo.** `MerkleVerdict` es compartido, pero `verifyGroupIntegrity`
   escribe sus `reason` con literales crudos (`"outbox-fetch-failed"` en `:3282`, `"dead-letter-fetch-failed"` en
   `:3290`) en vez de por `MerkleSkipReason`. ¿Se unifican de paso o se deja la asimetría?
2. **Qué hace el caller con un skip nuevo.** Hoy `runGroupMerkleVerification` solo distingue `diverged` del resto;
   un `skipped` nuevo cae en «no hacer nada», que es lo correcto, pero conviene comprobarlo antes de asumirlo.
3. El canal de Grupos no pasa por `VerifyProbeMapping` ni por los techos de la vuelta a iCloud, así que esto **no
   hereda** el `.blocked(.localFailure)` del canal personal.

## Criterios de aceptación

- [x] Un `fetch` que lanza en el cómputo del árbol local de un grupo NO se hashea como tabla vacía.
- [x] `verifyGroupIntegrity` no devuelve `.diverged` por una lectura local que falló, y por tanto no resetea
      cursores ni re-baja el grupo.
- [x] Hay rastro en producción de esa avería (hoy no lo hay).
- [x] Test con el fetch lanzando + control en la dirección contraria (una divergencia REAL se sigue detectando).

## Resuelto (2026-09-23)

- **El árbol local lanza.** `GroupMerkleProjection.computeLocalMerkle`, `collectLeaves` y `collectMemberLeaves` son
  `throws` (`GroupMerkleLocalReadError.leafFetchFailed(table:)`); la fila que no canonicaliza se sigue saltando.
- **Veredicto propio.** `verifyGroupIntegrity` devuelve `.skipped(GroupMerkleSkipReason.localMerkleFetchFailed)`. Todos
  sus motivos salen ahora de `GroupMerkleSkipReason` (mismos valores); **no** de `MerkleSkipReason`, cuyo `all` es el
  canario del canal personal.
- **Caller sin cambios, ahora fijado**: un skip no cuenta, no remedia, no gasta la remediación de la sesión y re-arma la
  cadencia (vuelve a intentarlo como mucho cada 30 min).
- **Rastro en producción**: `GroupsSyncBreadcrumb.groupsMerkleLocalReadFailed(table:)` + `groupsMerkleSkipped`. Este
  criterio se verificó LEYENDO el código: el `Logger` no tiene sink que un test pueda leer.
- A `done` sin device-QA: una base local ilegible no se provoca en un iPhone.
- Tests: bloque (8) de `GroupMerkleTests` (las 5 tablas una a una con control positivo, falso converge contra remoto
  vacío, caller, unicidad de motivos). 9 mutantes, todos muertos (dos de ellos los propuso la review: el seam ahora
  lanza un `CocoaError` para que solo pase si el `catch` real lo convierte). Regla: `.claude/rules/swiftdata-cloudkit.md`,
  «Y el Merkle tampoco».
- Review de tres lentes: ningún defecto de comportamiento en el fix. Ticket nuevo:
  `groups-cursor-map-reads-an-undecodable-json-as-no-cursors`. Descartado sin ticket: un remoto con `entities: {}`
  contaría como «remoto vacío» — inferido, y el servidor emite siempre las cinco tablas del manifest.

## Relacionado

- `verify-reads-a-failed-local-fetch-as-an-empty-outbox` — el mismo patrón en el canal personal, ya cerrado.
