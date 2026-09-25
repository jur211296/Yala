---
id: row-deleted-during-the-relief-wait-comes-back-after-the-relief
status: backlog
priority: low
area: "modo-nube, migración"
created: 2026-09-24
updated: 2026-09-24
source: "ticket `lineage-coverage-blocks-forever-after-a-row-deleted-during-the-wait` (2026-09-24), decisión D4 del Paso 0"
---

# Un movimiento borrado en el segundo teléfono durante la espera vuelve tras el relevo

## El problema, en lenguaje de usuario

El primer teléfono subió parte de tus datos y se quedó callado. En el segundo borras un movimiento que el primero ya
había subido. El segundo toma el relevo y termina de activar la nube: el movimiento borrado vuelve a aparecer.

## Lo medido y lo inferido (2026-09-24)

- **Medido**: desde `lineage-coverage-blocks-forever-after-a-row-deleted-during-the-wait`, esa fila ya no bloquea el
  relevo ni el adopt. Sigue viva en el backend: el relevo solo sube el corpus del teléfono, nunca un borrado de algo que
  no tiene, y el `verify`/pull la baja. Antes de #241 pasaba lo mismo.
- **Medido**: en las tablas de identidad propia el borrado deja testigo en el historial de SwiftData
  (`MigrationWorkExecutor.lineageDeletedHere`), así que ahí se podría tombstonear en el backend con prueba.
- **Inferido**: en las tablas de identidad sintética un borrado hecho ANTES de que llegara su identidad deja un tombstone
  con `syncID` nulo. Ahí no se distingue «se borró aquí» de «no llegó nunca», y tombstonear podría borrar una fila real.

## Criterios de aceptación

- [ ] Decidido si merece la pena: el daño es un borrado que hay que repetir, no un dato perdido.
- [ ] Si se hace: solo se tombstonea lo que tiene testigo positivo del borrado.
