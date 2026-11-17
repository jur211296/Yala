---
name: web-con-sesion-de-noche-en-la-max
description: De noche en la Max, la prueba con sesión de Yala web en producción y el artifact público pueden no tener vía (iPhone 14 reflejado por otra app, Chrome sin extensión); staging con Playwright en la Mini sí funciona.
metadata:
  type: reference
---

Medido el 2026-11-16 (lote 5 de Yala web, sesión nocturna en la Max, ~21:45 Lima):

- **iPhone 14 «blocked: Another app (such as Xcode's Device Hub) is mirroring»** en `list_devices`. No se le quitó:
  puede ser Jürgen o la sesión de la Mini. Sin él no hay sesión de Google para producción.
- **Chrome corriendo pero `list_connected_browsers` vacío**: sin extensión no hay vía para pasar un artifact a público
  (ADR-112) ni para mirar producción con sesión. No se busca otra; el cierre lo reporta como ERROR.
- **Lo que sí funcionó para probar con sesión**: Playwright en `~/tmp/yala-web-lote2-shots` de la Mini contra STAGING
  con `USER_A/B` de `test-users.env` (entrada por `/auth/password`). En «Depa Miraflores» A no puede invitar
  (`puedeInvitar` falso) y B sí. Lo escrito se borra al final con el token de la app por `/groups/push` (tombstone) y la
  invitación con `/groups/rpc/revoke_invite`.

**How to apply:** en un lote de Yala web, deja la prueba con sesión de staging hecha en la Mini antes de producción, y
si el iPhone y Chrome no están, producción se verifica sin sesión (rutas 200, `/api/me` 401, que el bundle servido
traiga el código nuevo) y lo demás va a «Necesita de ti». Relacionado: [[secretos-de-staging-en-la-mini]],
[[playwright-en-la-mini]], [[el-iphone-14-lo-ve-tambien-la-otra-maquina]].
