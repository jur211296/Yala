---
id: an-undecodable-migration-phase-reads-as-never-started
status: backlog
priority: medium
area: "modo-nube, migración"
created: 2026-09-22
updated: 2026-09-22
source: "residual de `an-unreadable-migration-journal-reads-as-never-started` (2026-09-22)"
---

# Si la fase guardada de la migración no se entiende, la app sigue creyendo que nunca empezó

## El problema, en lenguaje de usuario

La app apunta en qué paso va el cambio de tus datos a la nube. Desde el 2026-09-22, si esa anotación **no se deja leer**,
la app lo dice y no hace nada con ella. Pero hay un segundo caso que sigue igual: la anotación **se lee**, pero lo que pone
no se entiende (por ejemplo, la escribió una versión más nueva de Yala y el teléfono volvió a una más vieja). Ahí la app
sigue concluyendo que el cambio **nunca empezó**, con los mismos permisos que antes del arreglo.

## Por qué pasa (medido el 2026-09-22 en la rama del ticket padre)

`MigrationState.readPhase()` devuelve `(.notStarted, decodeFailed: true)` cuando `phaseData` existe y no decodifica. Los dos
lectores —`MigrationPhaseStore.phaseRead(fetch:)` y `MigrationJournalRead.read(fetch:)` del controller— toman esa fase
tal cual. El primero deja un breadcrumb ruidoso (`migrationPhaseDecodeFailed`); el segundo, ni eso.

`notStarted` es fase ESTABLE, así que es el mismo desenlace que el ticket padre cerró para el `fetch` que lanza, por otro
camino.

## Por qué quedó fuera

El ticket padre era el `catch` del `fetch`. Este camino tiene una red que el otro no tenía: `MigrationStateJournalTests`
congela un fixture JSON por cada case del enum (APPEND-ONLY), así que renombrar o borrar un case rompe el test antes de
publicar. Lo que no cubre es el DOWNGRADE: un build con un case nuevo escribe un blob que un build anterior no entiende.

## Qué habría que decidir

1. ¿`decodeFailed` es `.unreadable`? Probablemente sí en los dos lectores, y el tipo ya existe (`JournaledPhaseRead`).
2. El runner también usa `readPhase()`: ver qué hace él con `decodeFailed` antes de cambiar solo los lectores.
3. Efectos pendientes que no decodifican (`readPendingEffects` devuelve `[]`): la misma pregunta, un nivel más abajo.

## Criterios de aceptación

- [ ] Un `phaseData` presente que no decodifica no se presenta como `notStarted` en ninguno de los dos lectores.
- [ ] Test con un blob que no decodifica + control positivo.
