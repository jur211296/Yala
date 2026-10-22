---
id: groups-outbox-rows-without-a-provable-owner-never-upload
status: backlog
priority: low
area: "groups, modo-nube"
created: 2026-09-28
updated: 2026-10-08
source: "residual de `groups-outbox-rows-without-a-live-session-have-no-exit` (review adversarial, 2026-09-28)"
---

# Un cambio de grupo cuyo dueño no se puede probar no lo sube nadie

## El problema, en lenguaje de usuario

Actualicé Yala con cambios de grupo pendientes y sin ninguna sesión abierta. Al volver a entrar con mi cuenta, esos cambios
no suben, y al cerrar sesión Yala me dice que son de otra cuenta.

## Lo medido (leído, sin ejecutar, 2026-09-28)

- Desde `groups-outbox-rows-without-a-live-session-have-no-exit` cada fila de `GroupSyncOutbox` lleva su dueño, y
  `pushPending` solo sube las de la sesión. Una fila sin dueño probado no la sube nadie, a propósito: retener gana a
  reatribuir.
- Las filas anteriores a ese build toman el dueño de su entrada del espejo del App Group o, sin ella, del registro de
  sesiones a su hora de encolado (`GroupsSyncClient.adoptOwnersForUnownedRows`). El arranque siembra ese registro con la
  sesión guardada o la cuenta de grupos asociada (`SessionSignInLog.seedIfAbsent`).
- Se quedan sin dueño las filas que ni el espejo ni el registro explican: un teléfono que actualizó sin sesión y sin cuenta
  de grupos asociada, o una transacción más vieja que la entrada más antigua del registro (tope de 64 entradas). También lo
  que se apunte en un teléfono que nunca tuvo sesión.
- No hay pérdida silenciosa: el cierre las cuenta y ofrece perderlas con aviso.

## Lo que se espera

Una prueba más de dueño para esa población, o un gesto explícito «estos cambios son míos» que la persona confirme. Medir
antes cuántos teléfonos caen aquí: hoy no hay canario.

## Medido en 2.1 (triage 2026-10-08)

- `GroupsSyncClient.adoptOwnersForUnownedRows` sigue siendo la única prueba de dueño (espejo o registro de sesiones, con `GroupsOutboxOwnershipLogic.maxEntries = 64`); lo que no explica, no sube, y la retiene `liveRowsHeldForAnotherAccount`.
- Sigue sin canario que mida la población. Sin commits sobre el mecanismo desde `70b8c1e67` (el que lo creó).
- No hay pérdida silenciosa: el cierre de sesión las cuenta y ofrece perderlas con aviso.

Triage 2026-10-08: abierto · low → low · las filas sin dueño probado siguen sin subir por diseño, con aviso al cerrar sesión; población sin medir y probablemente muy pequeña.
