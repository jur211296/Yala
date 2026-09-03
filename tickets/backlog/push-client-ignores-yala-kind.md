---
id: push-client-ignores-yala-kind
status: backlog
priority: medium
area: grupos, notifications
created: 2026-09-03
updated: 2026-09-03
source: medido al cablear el push de membresía (g8_03, 2026-09-03)
---

# El cliente no distingue tipos de push, y el banner no lleva a ningún sitio

## Qué pasa

Desde el 2026-09-03 el gateway manda **alertas** con un `loc-key` distinto por evento (actividad en
grupos, solicitud de entrada, respuesta a tu solicitud). El sistema pinta el banner correctamente.
Pero al **tocarlo**, la app no lleva al grupo: aterrizas donde estuvieras.

Y la app tampoco sabe de qué push se trata: cualquiera dispara lo mismo.

## Lo MEDIDO

`Yala/App/YalaAppDelegate.swift:54-84` es quien recibe el push remoto:

- `:67` lee `userInfo["yala"]` y saca `kind`… **sólo para un breadcrumb**
  (`PushBreadcrumb.received`). No hay `switch` por `kind`.
- `:76` dispara `GroupsSyncClient.shared.syncNowFromPush(...)` **incondicionalmente**, para cualquier
  payload que traiga la clave `yala`.
- El enrutado por `deepLink` sí existe y funciona —`NotificationService.swift:45-79`,
  `parseDestination` ya entiende `"groups/{UUID}"` → `.groupDetail`— pero **el gateway no emite esa
  clave**, así que nunca se usa desde un push remoto.

Kinds que existen hoy en el emisor: `"groups-sync"` (el fan-out) y `"g0-spike"` (ruta de debug).
Ninguno está declarado como constante compartida: es un string libre en TypeScript y un `String?` en
Swift, que es justo como divergen.

## Qué habría que hacer

1. **`switch` por `yala.kind`** en `YalaAppDelegate`, y decidir por tipo qué hacer además de
   sincronizar. Hoy un aviso de membresía dispara un ciclo de sync de Grupos que no necesita.
2. **Propagar `deepLink`** desde el gateway (`userInfo["deepLink"] = "groups/<uuid>"`) para que tocar
   el banner abra el grupo. **Ojo al formato**: el `group_id` del servidor es `SplitGroup-<uuid>` y
   `parseDestination` espera el uuid pelado.
3. Considerar una constante compartida de kinds, o al menos un test que pinnee los que el emisor
   produce contra los que el cliente entiende.

## Lo que NO bloquea

El banner **ya suena** sin esto: el push es `alert` y lo pinta iOS. Esto mejora qué pasa al tocarlo y
evita trabajo inútil, pero el problema de fondo —que el aviso dependiera de que la app corriese— ya
está resuelto.
