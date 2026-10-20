---
name: grabar-yala-en-el-simulador
description: Material de marketing desde el simulador: Yala IA real con Yala Dev + secreto de staging, teclado latino para tildes, permiso de notificaciones bajo -uitest y Apple Pay desde Atajos
metadata:
  type: reference
---

Lo que costó medir el 2026-10-19/20 (encargo de marketing del lanzamiento 2.1). Los guiones quedaron en
`~/Claude/propuestas/marketing-lanzamiento/_fuente/grabaciones/`.

- **Yala IA contesta de verdad en el simulador** solo con la build **Yala Dev** (`-configuration Debug-Dev`; `Debug` a
  secas va al gateway de producción) y `SIMCTL_CHILD_YALA_DEV_SHARED_SECRET` leído de
  `~/Secrets/yala-gateway/staging-dev-shared-secret`. La respuesta tardó de 5 a 14 s según la tanda: reintentar la toma.
- **El teclado físico del simulador es latinoamericano**: `axe type` no escribe tildes ni `¿?/`. `¿` = `axe key 46`,
  tilde muerta = `key 47` + letra por `key` (a=4, e=8), `?` = shift+45, `/` = shift+36. `simctl pbcopy` + ⌘V no pegó.
  `axe batch --file` hace la escritura y los toques en una sola sesión, con pausas fiables.
- **Bajo `-uitest` la app no pide permiso de notificaciones** (`NotificationsSettingsView`). Lo pide el aviso que sale
  tras guardar un registro con `-transactionsSavedCount 5 -hasSeenNotificationPrimer NO`.
- **Apple Pay sin Wallet**: Atajos existe en el simulador; la acción «Registrar pago de Apple Pay» de Yala Dev con
  cantidad «S/ 18.50» manda la notificación real y deja el borrador en la Bandeja. La pantalla bloqueada
  (`axe button lock`) enseña la hora real, no la de `status_bar`.
- **La semilla `ficha`/`realista` trae nombres reales** («Maia 🐶», presupuesto de mascota) y gastos de viaje: para
  material público, cambiarlos en local antes de sembrar.
- El primer toque tras `uitest_ready` se pierde: un toque inocuo antes de grabar. Un toque de 0,18 s con `axe touch`
  abre el menú contextual de la tarjeta de grupo: ahí, `axe tap --tap-style physical`.

Relacionado: [[conducir-simulador-con-axe]], [[molde-ficha-app-store]], [[verificar-prod-del-gateway-con-token-acunado]].
