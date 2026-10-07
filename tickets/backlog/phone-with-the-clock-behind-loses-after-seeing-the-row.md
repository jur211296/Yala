---
id: phone-with-the-clock-behind-loses-after-seeing-the-row
status: backlog
priority: low
area: "modo-nube, sync, groups"
created: 2026-10-07
updated: 2026-10-07
source: "residual de `personal-clock-ahead-wins-every-conflict-until-real-time-catches-up` y `groups-clock-ahead-wins-every-conflict-until-real-time-catches-up` (2026-10-07)"
---

# Un teléfono con la hora ATRASADA pierde sus cambios sobre filas que ya vio, y se queda divergente

## El problema, en lenguaje de usuario

Bruno tiene la hora de su iPhone una hora atrasada. Ve un gasto que editó Ana, lo cambia, y su cambio desaparece del
servidor sin aviso; en el iPhone de Bruno sigue viéndose su versión, y en los demás la de Ana. Dura hasta que alguien
vuelva a editar ese gasto.

## Por qué pasa (inferido del código, 2026-10-07)

Es la mitad que el tope del servidor no cubre. Los tres pulls integran el HLC de cada fila que bajan
(`HLCClock.observePulled`), pero con la guarda de 5 min de `receive`: con el reloj de Bruno una hora atrasado, la fila
de Ana va «una hora por delante» de su hora y no se integra. Su edición sale estampada con su hora, por DEBAJO de la de
Ana, el servidor la descarta (`all_units_stale` / `stale`), Bruno purga su fila del outbox y no vuelve a bajar nada,
porque el servidor no cambió.

Con el tope del servidor el teléfono ADELANTADO quedó acotado a un minuto; el atrasado no tiene tope posible desde el
servidor (su HLC está en el pasado).

## Qué habría que decidir

- ¿Integrar sin guarda lo que baja del servidor? Desde `hlc01` todo lo guardado es `≤ now() + 60 s` del servidor, así
  que integrarlo mueve el reloj de Bruno como mucho a la hora real + 1 min. El riesgo: un servidor SIN la migración
  (legacy) contagiaría un adelanto de meses.
- ¿O que el servidor «toque» la fila tras un `noop` por obsoleto, para que el perdedor la vuelva a bajar? Descartado en
  el Paso 0 de 2026-10-07 porque en Grupos cada re-bajada notifica «gasto modificado» a todos los miembros.

## Criterios de aceptación

- [ ] Decisión escrita.
- [ ] Test: con el reloj una hora atrasado, la edición de una fila ya vista no se pierde en silencio.
