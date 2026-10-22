---
id: groups-drain-has-no-rollback-and-keeps-the-mirror-of-a-failed-save
status: backlog
priority: low
area: "grupos, sync"
created: 2026-09-23
updated: 2026-10-08
source: "review adversarial de `drain-duplicates-the-unit-clock-when-its-row-cannot-be-read` (2026-09-23), lente de gemelos"
---

# El drain de Grupos no deshace un guardado que falla

## El problema, en lenguaje de usuario

Casi nunca se nota. Si al capturar tus cambios de grupos falla el guardado, las filas se quedan a medio escribir y
su copia de seguridad ya escrita no se retira. Normalmente se arregla sola en la vuelta siguiente; si el fallo lo
causan esas mismas filas, la app podría no conseguir guardar nada más hasta relanzar.

## Por qué pasa (leído el 2026-09-23; inferido, no ejecutado)

`GroupsSyncClient.performDrain` escribe el espejo antes del save (igual que el personal) y su `catch` no hace
`rollback()` ni retira el espejo. Es el gemelo de lo que el drain personal cerró el 2026-09-23. Lo atenúa que el
dedup ve las filas pendientes del contexto y los HLC son deterministas (`clock.sendLocal(eventTime: tx.timestamp)` desde
el 2026-09-26; antes `clock.send(now: tx.timestamp)`).

## Criterios de aceptación

- [ ] Medir primero si un save del outbox de Grupos puede fallar por sus propias filas.
- [ ] Si sí: rollback acotado a lo que escribió el drain + retirada del espejo, con el molde del personal.

## Medido en 2.1 (triage 2026-10-08)

- `GroupsSyncClient.performDrain` sigue escribiendo el espejo (`writeMirror(rows:)`) antes de `saveWithAuthor`, y su `catch` solo registra en DEBUG y devuelve `false`: ni `rollback()` ni retirada del espejo.
- Los commits posteriores sobre el fichero (`8d7b44ba4`, `d9462c742`) tocan el reloj y los importes no finitos, no este `catch`.

Triage 2026-10-08: abierto · low → low · el catch del drain de Grupos sigue sin rollback ni retirada del espejo; inferido y no reproducido, lo atenúan el dedup y los HLC deterministas.
