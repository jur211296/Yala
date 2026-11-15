---
name: reference-leer-telemetria-de-staging
description: Cómo ver en staging los eventos que manda una instalación del simulador (AE SQL con el token de wrangler) y cómo recorrer el alta conversacional sin -uitest
metadata:
  type: reference
---

Medido el 2026-11-13 (card del usuario nuevo después del alta).

- **Telemetría real en el simulador = `Yala Dev` instalada limpia y lanzada SIN `-uitest`** (bajo `-uitest`
  `MetricsService` no arranca). Va al gateway de staging → dataset `yala_metrics_staging`.
- **Leer AE**: `POST https://api.cloudflare.com/client/v4/accounts/86c270a7776be98639700bd5959b303b/analytics_engine/sql`
  con `Authorization: Bearer <oauth_token>` de `~/Library/Preferences/.wrangler/config/default.toml`. Filtra por
  `blob5 LIKE '<install>%'` (el install sale en la primera consulta). AE tarda segundos, no minutos.
- **El token caduca a la hora.** El `wrangler` de `~/Yala/gateway` NO arranca (workerd sin binario, Node 26 y 22);
  el de `panel/node_modules` de un worktree con `npm ci` sí: `node node_modules/wrangler/bin/wrangler.js whoami`
  renueva el token.
- **Alta conversacional de 2.3 en el simulador**: XcodeBuildMCP `type_text` y `axe type` no escriben en
  `welcome_chat_name_field` (el toque llega, el texto no); **Device MCP `fill` con `device=<udid>` sí**. Tras conducir
  a mano, `HardwareKeyboardLastSeen` queda en 1: `simctl spawn <udid> defaults write com.apple.keyboard.preferences
  HardwareKeyboardLastSeen -bool NO` lo devuelve sin borrar el simulador.
- Sin cuenta de iCloud el simulador no pide «Reabre Yala»: `alta.reabrir.*` no se puede ver ahí.

Relacionado: [[feedback-el-silencio-de-la-telemetria-tambien-mide]].
