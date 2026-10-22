---
id: groups-purge-save-crosses-two-stores-without-atomicity
status: done
priority: medium
area: "modo-nube, groups, swiftdata"
created: 2026-09-11
updated: 2026-10-01
source: "review adversarial de `detach-failure-looks-like-success` (lente de datos y sync)"
---

# El borrado del dominio Grupos promete «todo o nada» y su `save()` cruza dos archivos distintos

## El problema, en lenguaje de usuario

Suelto mi cuenta de grupos, o dejo el teléfono en blanco para otra persona. Si el borrado falla a
mitad, la app promete que no queda nada a medias. Puede no ser verdad: lo que se borra vive en **dos
archivos** y el teléfono podría terminar con los grupos todavía puestos pero su marcador de
sincronización borrado — el par que la regla de área marca como el peligroso.

## Lo medido (2026-09-11)

`DataWipeService.deleteLocalGroupsRows` hace un solo `context.save()` que abarca:

- las cinco entidades `Split*`, del `groupsSchema` (archivo `groups.sqlite`), y
- lo que el llamador mete en `alsoDeleting`: `GroupSyncOutbox` y `GroupSyncCursor`, del
  `syncMetaSchema` (archivo `syncmeta.sqlite`).

Su docblock y el de `CloudSessionSignOut.purgeGroupsDomainForDetach` afirman que el borrado es **UNA
transacción**, y de ahí cuelga el argumento de la regla `L211` de `.claude/rules/swiftdata-cloudkit.md`:
«el par coherente en una frontera de CUENTA es *filas borradas + cursor borrado*, atómico». Un
`ModelContext` de SwiftData con varias `ModelConfiguration` reparte el save entre los stores; **no está
comprobado** que un fallo del segundo deshaga lo comiteado en el primero, y `context.rollback()` solo
repone lo que sigue en memoria.

El par malo —«cursor borrado + filas VIVAS»— es el que la misma regla describe como el que re-emite
upserts con HLC nuevos al re-asociar.

## Cómo se prueba

Con el andamio de `GroupsDetachPurgeFailureTests`: tres stores on-disk y el **`syncmeta` en solo
lectura** (`allowsSave: false`), el de grupos escribible. Correr `purgeGroupsDomainForDetach` y contar
después las filas de `SplitGroup` y de `GroupSyncCursor`. Si `SplitGroup` sale en 0 con el cursor vivo
(o al revés), la atomicidad prometida no existe y hay que escribirla: dos `save()` con un orden que
haga inocuo morir entre ellos, o un sello que deje el par reparable en el arranque.

Los tests de hoy inyectan el fallo en `alsoDeleting`, o sea **antes** del `save()`: miden el rollback en
memoria, no la atomicidad del save.

## Por qué no se arregló en su ticket

`detach-failure-looks-like-success` cierra que el fallo se vea; la atomicidad cross-store es anterior a
él (viene de `detach-history-replay-can-tombstone-groups-on-next-launch`) y afecta también al «Empiezo
de cero», así que es su propio objeto.

## Resuelto (2026-10-01)

**Medido antes de arreglar**, con tres stores on-disk y el borrado del desasociar tal como estaba (un solo
`save()`): con el sync-meta en solo lectura quedaba `SplitGroup = 0, GroupSyncCursor = 1`; con el store de Grupos
en solo lectura, `SplitGroup = 1, GroupSyncCursor = 0` — el par peligroso. La atomicidad prometida no existía:
el `save()` comitea store a store. Un lock exclusivo de SQLite desde otra conexión no sirve para inyectar el
fallo: Core Data espera sin tope.

**Arreglo** (en `DataWipeService.deleteLocalGroupsRows`, el escritor de los tres caminos): primero todas las
lecturas —un `fetch` que falla no escribe nada— y después un `save()` por tramo en este orden: outbox →
`GroupBridgePreference` → filas de Grupos → cursor. El cursor no puede irse antes que las filas; las filas son el
testigo con el que los reintentos de «Empiezo de cero» saben que falta borrar (`checkHasExistingData` cuenta
`SplitGroup`), así que van lo más tarde posible; y el outbox va primero porque el Merkle de Grupos salta los grupos
con dead-letters. `alsoDeleting` devuelve las filas en vez de borrarlas. Sin sello de arranque nuevo (Paso 0 del
encargo, D1). La primera versión (Grupos → outbox/cursor → preferencias) la tumbó la review adversarial por las dos
últimas razones.

**Lo fija** `YalaTests/CloudSync/GroupsPurgeCrossStoreOrderTests` (8 casos; cada store cerrado por turno con
`allowsSave: false`, 12 contenedores por caso porque el orden de commit de Core Data cambia entre contenedores,
oráculo leído de un contenedor nuevo). Mutantes, todos muertos (exit 65): `save()` único (6 rojos; el par peligroso
salía en 6 de 20 contenedores), cursor antes que las filas (2), preferencias detrás de las filas (2), la lectura de
`alsoDeleting` detrás del primer `save()` (7), outbox detrás de las filas (5). Regla:
`.claude/rules/swiftdata-cloudkit.md`, bullet «ARCHIVOS, nunca FILAS…».

**Residuales**: la curación por Merkle del par reparable al volver a entrar está inferida, no medida. Un kill
justo entre el `save()` de las filas y el del cursor deja ese par sin la marca de reintento (se arma en el `catch`).
Si el contexto llega con cambios ajenos sin guardar, el primer `save()` vuelve a cruzar stores (ningún llamador
llega así hoy). Y dos textos que no son verdad en el corte a medias, con ticket:
`detach-purge-failed-copy-says-groups-remain-after-a-cursor-only-failure` y
`welcome-fresh-start-failed-copy-says-data-is-still-here-after-partial-wipe` (este, anterior al cambio).
