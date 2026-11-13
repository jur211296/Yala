---
name: sentry-breadcrumbs-fechan-el-pull
description: En un App Hang de Sentry, los breadcrumbs http (ruta del gateway y hora) fechan página a página el pull de la nube y atan issues distintos a la misma apertura
metadata:
  type: reference
---

Medido el 2026-11-13 con YALA-IOS-J/K/A (2.2 (9)). El evento completo (`…/issues/<id>/events/?full=true`) trae
`contexts.app.app_start_time` y breadcrumbs `http` con la URL del gateway: los `GET /sync/pull` cada 3-4 s fueron cada
uno una página aplicada en el hilo principal, y el `POST /account/claim` de antes dijo que era la primera bajada tras
«Activar la nube». Dos issues con el mismo `app_start_time` son la misma apertura: así se vio que A (stack sin código
propio, «regresión» de la foto de perfil) era la misma carga que J. Antes de culpar al stack, mira la línea de tiempo.

Relacionado: [[reference-sentry-tokens-y-api]], [[sentry-vacio-no-descarta-un-crash]].
