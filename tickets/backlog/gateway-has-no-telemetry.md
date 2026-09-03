---
id: gateway-has-no-telemetry
status: backlog
priority: medium
area: cloud, qa
created: 2026-09-03
updated: 2026-09-03
source: medido por el panel de diseño de notificaciones (2026-09-03)
---

# El gateway no escribe un solo punto de telemetría: si el push deja de llegar, nadie se entera

## Qué pasa

El gateway **no llama a `writeDataPoint` ni una vez**. Sus canarios —incluido
`[canary] groupApnsSendFailed` del fan-out— son `console.log`, que **sólo existen mientras alguien
tenga `wrangler tail` abierto**. En cuanto se cierra la terminal, no queda rastro.

Consecuencia práctica: si los avisos de Grupos dejan de entregarse, la única forma de enterarse es que
un usuario se queje. Y hay precedente — `notifications-not-delivered-testflight` acabó siendo el
permiso de notificaciones apagado, un caso en el que **APNs responde 200** y todo parece correcto.

## Por qué importa más desde hoy

El 2026-09-03 el fan-out pasó de silent push a **alerta**, y las RPC de membresía empezaron a emitir.
Es más superficie y más visible para el usuario, con la misma observabilidad que antes: ninguna.

## Lo MEDIDO

- `gateway/src/metrics.ts` existe y tiene el molde (`writeDataPoint`), pero **ningún camino del
  gateway lo usa**.
- El binding de Analytics Engine está declarado en `wrangler.toml`
  (`[[analytics_engine_datasets]]` y su gemelo en `[[env.production.analytics_engine_datasets]]`),
  así que la infraestructura está puesta y pagada.
- El canario del fan-out vive en `gateway/src/groups/routes.ts`, en la rama de envío fallido.

## Qué habría que hacer

Emitir datapoints en los puntos que hoy sólo loguean: envío de push fallido, token podado,
short-circuit por secret ausente, y RPC de tokens que responde no-2xx. Con eso el dashboard de
Analytics Engine puede responder «¿están llegando los avisos?» sin abrir una terminal.

**Y el canario de permiso apagado no lo cubre esto**: APNs devuelve 200 con el permiso en OFF, así
que eso sólo se ve guardando `authorization_status` al registrar el token. Va en el mismo trabajo.
