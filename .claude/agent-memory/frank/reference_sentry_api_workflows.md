---
name: reference-sentry-api-workflows
description: Cómo tocar alertas y agrupado de Sentry de Yala por API — /rules/ da 404, las alertas son /workflows/; token del Llavero tiene escritura
metadata:
  type: reference
---

Medido el 2026-11-21 (encargo de afinar Sentry).

- Token: Llavero, servicio `sentry-yala`, cuenta `jur`; host `us.sentry.io`. Tiene `alerts:write` y `project:write`.
- `/projects/yala-is/yala-ios/rules/` da **404**: las alertas viven en `/organizations/yala-is/workflows/` (detector
  «Issue Stream» de yala-ios = `10760395`; el `10760397` es del gateway, no tocar). Condiciones válidas:
  `/organizations/yala-is/data-conditions/?group=workflow_trigger|action_filter`.
- Un entorno nuevo (p. ej. `testflight`) no existe hasta su primer evento: un workflow con `environment` lo rechaza;
  se filtra con `event_attribute environment eq`.
- Reglas de huella: `PUT /projects/yala-is/yala-ios/` con `fingerprintingRules`; `…/events/<id>/grouping-info/` dice
  qué regla casó. Sentry Cocoa 9 no simboliza en el teléfono: huella por función solo en el servidor.
- Para probar una huella con Yala Dev en simulador: `dsymutil` del `Yala.debug.dylib` + `scripts/sentry-subir-dsym.sh`.
- Las sesiones de Sentry en Chrome no están iniciadas: no hay capturas de su web, solo API.
