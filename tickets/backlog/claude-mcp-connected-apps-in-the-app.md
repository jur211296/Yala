---
id: claude-mcp-connected-apps-in-the-app
status: backlog
priority: low
area: cloud, mcp
created: 2026-11-05
updated: 2026-11-05
source: encargo 2026-11-04-login-apple-google-conector-y-lote-p7 (decisión 1A, propuesta de diseño)
---

# «Claude conectado» en la app: una fila por cada app de Claude, con «Desconectar»

## Qué cambia para el usuario

En Ajustes de Yala ve qué apps de Claude leen sus finanzas (Claude Code, claude.ai, Claude Desktop), desde cuándo y
cuándo fue la última lectura, y puede desconectar cada una. Desconectar desde aquí o desde Claude da el mismo
resultado: Claude deja de leer al momento y no queda ninguna sesión abierta en la nube.

## Decidido (2026-11-05, opción 1A)

La lista la da **el conector**, no el permiso «Yala para Claude» de Supabase. El permiso de Supabase es una sola fila
para todas las apps de Claude y no se entera cuando Claude desconecta; los grants del Worker son una fila por app y
ya se cierran bien (`mcp/src/revoke.ts`). Las sesiones que el Worker no puede cerrar las limpia el barrido diario
(`qa/cloud/mcp0_04_sweep_connector_sessions.sql`).

## Propuesta (no implementada)

- **Worker:** `GET /connections` y `DELETE /connections/<id>`, autenticados con el token NORMAL de la app (no con uno
  del conector: el hook marca esos como `yala_mcp_reader` y no deben poder listar ni borrar). Se verifica como hoy
  (`auth.ts`) pero exigiendo `role = authenticated` y sin `client_id`. Por debajo, `listUserGrants(sub)` y
  `revokeGrant(id, sub)` de la librería; el borrado cierra antes la sesión de Supabase, igual que `revoke.ts`.
- **Cada fila:** `client_name` de Claude, fecha de autorización (`authorizedAt`) y, si se guarda, la última lectura.
  Nada de tokens ni ids de sesión hacia la app.
- **La salida a Supabase** que haga falta va a la lista cerrada (`egress.ts`) con una regla propia.
- **App (Swift):** la pantalla en Ajustes, junto a «Dónde viven tus datos»; solo con la nube activada.

## Qué falta decidir

- Si «última lectura» se guarda (es un write al KV por llamada a `/mcp`, o uno por refresh, más barato).
- El copy de la pantalla (BRAND-VOICE).
