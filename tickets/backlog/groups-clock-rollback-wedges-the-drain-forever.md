---
id: groups-clock-rollback-wedges-the-drain-forever
status: backlog
priority: medium
area: "groups, sync"
created: 2026-09-26
updated: 2026-09-26
source: "review adversarial de `groups-drain-failure-reads-as-nothing-pending` (2026-09-26), lente de regresión"
---

# Si la hora del iPhone retrocede, tus cambios de grupos dejan de subir para siempre

## El problema, en lenguaje de usuario

Si alguien adelanta la hora del iPhone a mano, apunta un gasto de grupo y luego la devuelve (o el teléfono corrige la
hora sola), los gastos de grupo que apunte después de más de 5 minutos de diferencia dejan de subir. No se curan
esperando. Y desde el 2026-09-26 tampoco se puede cerrar sesión, desasociar la cuenta de grupos ni «Empezar de cero»:
las tres salidas se niegan a borrar lo que no subió y dicen «inténtalo en un rato», que en este caso no es verdad.

## Por qué pasa (leído el 2026-09-26; inferido, no ejecutado)

- El drain estampa cada cambio con la fecha de su transacción: `clock.send(now: tx.timestamp)`
  (`GroupsSyncClient.translate…`, `HLC.swift`). Si el reloj lógico persistido (`GroupSyncCursor.clockLatestHLC`) va más
  de `HLCClock.maxDriftMillis` (5 min) por delante de esa fecha, `send` lanza y la vuelta corta en esa transacción.
- El cursor se queda antes de ella, así que cada drain posterior corta en el mismo sitio. La fecha de la transacción no
  cambia, y el reloj lógico tampoco baja: no se cura con el tiempo.
- Nada de lo que se apunte después sale del teléfono: el drain nunca pasa de esa transacción.
- Desde `groups-drain-failure-reads-as-nothing-pending` esa vuelta cortada devuelve `false` y las salidas que borran se
  bloquean. Es a propósito —borrar perdería esos cambios, que ya no suben—, pero el aviso dice `.uploadRetryLater`.

Es el mismo mecanismo que describe `clock-drift-aborted-drain-lets-the-pull-overwrite-untranslated-edits` en el canal
personal, que da por hecho que «se corrige» al arreglar el reloj: con el sello por fecha de transacción, no se corrige.

## Por dónde va (a decidir; toca el núcleo del sync)

- Estampar con `max(tx.timestamp, ahora)` rompe el determinismo del HLC, del que depende el dedup de un re-drain tras un
  fallo (`seen` por `(syncID, hlc, op)`). Hay que medir qué duplicaría.
- O tolerar la deriva en `send` para eventos LOCALES antiguos (la deriva protege de relojes ADELANTADOS, no de
  transacciones viejas).
- Y, mientras tanto, decidir si esas salidas deben ofrecer algo distinto de «inténtalo en un rato».

## Criterios de aceptación

- [ ] Con el reloj retrocedido más de 5 min entre dos cambios de grupo, el segundo sube en cuanto hay red.
- [ ] Un test que avanza la hora real SIN tocar `clockLatestHLC` y comprueba que el drain termina.
