---
id: groups-clock-ahead-wins-every-conflict-until-real-time-catches-up
status: backlog
priority: low
area: "groups, sync"
created: 2026-09-26
updated: 2026-09-26
source: "review adversarial de `groups-clock-rollback-wedges-the-drain-forever` (2026-09-26), lentes HLC y regresión"
---

# Un teléfono que tuvo la hora adelantada gana todos los conflictos de sus grupos hasta que la hora real lo alcanza

## El problema, en lenguaje de usuario

Ana adelanta la hora de su iPhone una semana, apunta un gasto de grupo y la devuelve. Durante esa semana, lo que Ana
cambie en un gasto del grupo gana siempre: si Bruno edita o borra ese mismo gasto después, su cambio desaparece en el
siguiente refresco, sin aviso. Con la hora puesta años adelante, dura años.

## Por qué pasa (leído el 2026-09-26; inferido, no ejecutado)

- Desde `groups-clock-rollback-wedges-the-drain-forever` el drain de Grupos estampa con `HLCClock.sendLocal`, que sigue
  el reloj lógico del teléfono aunque vaya por delante de la hora real: es lo que conserva el orden de sus propios
  cambios (sin eso, su edición de después perdería contra la suya de antes). Antes ese teléfono dejaba de subir nada;
  ahora sube, con HLC del futuro.
- El servidor (`apply_group_delta`) compara el HLC como texto y no pone tope a uno futuro. El cambio de otro miembro sale
  `all_units_stale`, `stale_tombstone` o `stale_over_tombstone`; el cliente lo trata como aplicado y lo borra del outbox
  (`GroupsSyncClient`, rama `noop` de `applyResults`), y el pull le devuelve la versión del teléfono adelantado.
- El orden propio tampoco es completo: vive en `GroupSyncCursor.clockLatestHLC`, que el cierre de sesión borra. Tras
  volver a entrar el reloj arranca en la hora real, y una edición de una fila que el teléfono selló adelantada sale
  `all_units_stale`. En el sentido contrario, sin relanzar, el reloj en memoria sobrevive al cierre y la cuenta siguiente
  hereda el adelanto.

## Qué habría que decidir

- ¿Tope en el servidor (rechazar o recortar un HLC más de X por delante de `now()`)? Recortar rompe el orden propio del
  teléfono adelantado; rechazar lo vuelve a dejar sin subir, ahora con dead-letters.
- ¿Que el pull de Grupos haga avanzar el reloj con los HLC que baja (un `receive` sin la guarda de deriva), para que el
  orden propio sobreviva al cierre de sesión?
- ¿Avisar a quien pierde un conflicto por `noop`?

## Criterios de aceptación

- [ ] Decisión escrita sobre el tope del servidor.
- [ ] Test: con el reloj persistido borrado tras un cierre de sesión, una edición de una fila sellada adelantada no se
  pierde en silencio.
