---
id: push-token-does-not-record-the-notification-permission
status: backlog
priority: low
area: grupos, notifications, cloud
created: 2026-10-25
updated: 2026-10-25
source: lote 12.7, card 9f9u (`gateway-has-no-telemetry`)
---

# Con el permiso de avisos apagado, el aviso de Grupos cuenta como entregado

## Qué pasa

Desde el 2026-10-25 el gateway cuenta cuántos avisos de Grupos entrega (`groupFanoutDelivered`, `qa/cloud/README.md`
§ «Canarios del propio gateway»). Pero con el permiso de notificaciones apagado en el iPhone, APNs responde 200 igual: el
aviso cuenta como entregado y la persona no ve nada. Pasó ya una vez (`notifications-not-delivered-testflight`).

## Qué haría falta

Guardar `authorization_status` al registrar el token (`POST /push/register`): la app lo manda, el gateway lo escribe en
`push_tokens` y el fan-out lo separa en su canario. Pide una columna nueva en Supabase (DDL en staging y producción, con
su runbook) y un cambio de app, así que no entró en el lote 12.7.
