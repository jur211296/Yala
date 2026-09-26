---
id: fresh-start-drops-mirror-entries-of-another-identity-without-counting-them
status: backlog
priority: low
area: "groups, modo-nube"
created: 2026-09-26
source: "review adversarial de `fresh-start-has-no-way-out-when-group-writes-can-never-upload` (2026-09-26, lente de datos)"
---

# «Empezar de cero» se lleva entradas del espejo de otra cuenta sin contarlas

## El síntoma

En un teléfono con la sesión de grupos de una persona, el espejo del App Group guarda cambios de grupos de OTRA cuenta
que nunca llegaron a su fila. «Empezar de cero» los borra y ni el aviso ni la cifra de «perderlos» los cuentan.

## Lo medido (2026-09-26, leído en el código, sin ejecutar)

- El recuento y lo aceptado de «Empezar de cero» miran el espejo con
  `GroupsSyncClient.MirrorPendingScope.sessionOwnerOrEveryoneWhenSignedOut`: con sesión, solo las entradas de su dueño.
- El borrado purga el espejo ENTERO (`DataWipeService.wipeLocalGroupsDomain` → `GroupsOutboxMirror()?.purgeAll()`).
- Es la decisión B2 de siempre (el cierre y el desasociar purgan igual) y no la introdujo la salida «perderlos». Lo que
  cambia es que ahora el docblock de `FreshStartGroupsBlock.pendingCount` dice «lo que el borrado se llevaría», y con
  sesión y entradas ajenas no es exacto.

## Por dónde va

O el recuento de «Empezar de cero» cuenta todas las entradas cuando va a purgar todas (y entonces esa sesión no puede
subirlas: bloquearía con `.sessionExpired`, que ofrece perderlas), o se acota el docblock y se deja escrito que las ajenas
se van por la decisión B2. Lo primero puede bloquear a quien tiene restos de otra cuenta, así que es decisión de producto.
