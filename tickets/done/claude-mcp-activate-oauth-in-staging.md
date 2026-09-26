---
id: claude-mcp-activate-oauth-in-staging
status: done
priority: medium
area: cloud
created: 2026-09-26
updated: 2026-09-26
source: encargo 2026-09-26-plugin-claude-mcp-fase0-spike (residual)
---

# Conectar Claude a Yala en staging: falta encender el inicio de sesión con OAuth

## Resultado (2026-09-26, hecho en la misma sesión)

A media sesión Jürgen dio un token de gestión de la cuenta dueña de Yala, que solo ve el proyecto de staging. Con
él se aplicaron los tres pasos de abajo por la Management API, en ese orden. Después se verificó:

- **`oauth.e2e.test.ts` 10/10** contra el Worker desplegado.
  - El token de Claude sale con `role = yala_mcp_reader` y `client_id`, también al refrescarlo.
  - PostgREST le deniega las escrituras (403) y B no ve nada de A.
  - Revocar el permiso corta el refresh; el access token vivo sirve hasta que caduca (1 h).
  - Discovery en 312-524 ms y token en ~225 ms.
- **El login normal no cambió**: tras encender el hook, A entra con `role = authenticated` y sin `client_id`.
- **Claude Code conectado de verdad**: `/mcp` → *Authenticate*. Hizo DCR, PKCE S256 y mandó `resource`. Tras el
  «Permitir» en la pantalla del Worker, respondió con los datos de A (39 cuentas, −189 PEN).
- **Hallazgo que bloquea la fase 1**: con ese token, GoTrue deja cambiar la cuenta (`PUT /auth/v1/user` → 200).
  Ticket `claude-mcp-oauth-token-can-change-the-account`.

**Configuración de Auth de staging, antes → después** (para revertir, el mismo `PATCH` con los valores de antes):

| Campo | Antes | Después |
|---|---|---|
| `hook_custom_access_token_enabled` | `false` | `true` |
| `hook_custom_access_token_uri` | `null` | `pg-functions://postgres/public/yala_mcp_access_token_hook` |
| `site_url` | `http://localhost:3000` | `https://yala-mcp-staging.misty-surf-6866.workers.dev` |
| `oauth_server_enabled` | `false` | `true` |
| `oauth_server_allow_dynamic_registration` | `false` | `true` |
| `oauth_server_authorization_path` | `null` | `/oauth/consent` |

Todo queda encendido para que Jürgen pueda probar Claude Desktop contra staging. El token de gestión ya no hace
falta y se puede revocar.

## Qué cambia para el usuario

En Claude se puede añadir Yala (staging) como conector, iniciar sesión con un usuario de prueba, pulsar
«Permitir» y preguntar por las propias finanzas.

## Pasos (dashboard de Supabase, proyecto de STAGING `fostjbbwstyuunmmefuk`)

**El orden importa** (review adversarial del 2026-09-26): el hook va ANTES que el servidor OAuth. Con OAuth
encendido y el hook apagado, Supabase emite a Claude —o a cualquier cliente registrado por DCR— un token
`authenticated` que escribe directamente en PostgREST. El MCP lo rechaza, pero el token ya está en manos del
cliente.

1. **Authentication → Hooks → Customize Access Token (JWT) Claims:** activarlo, tipo *Postgres*, schema `public`,
   función `yala_mcp_access_token_hook`. Comprobar que la app y los goldens siguen entrando.
2. **Authentication → URL Configuration → Site URL:** `https://yala-mcp-staging.misty-surf-6866.workers.dev`.
   Hoy nada de la app depende de la Site URL de staging (medido: ninguna referencia en el repo).
3. **Authentication → OAuth Server:** activarlo. Marcar *Allow dynamic client registration*. En
   *Authorization path*, `/oauth/consent`.
4. Correr `npm run test:e2e` en `mcp/` (el baile OAuth entero con A y B) y conectar Claude Code.

Con un token de gestión de la cuenta dueña de Yala en `~/Secrets/yala-supabase-mgmt/pat`, los pasos 1-3 son un
`PATCH` a `/v1/projects/fostjbbwstyuunmmefuk/config/auth` (`hook_custom_access_token_enabled`,
`hook_custom_access_token_uri = pg-functions://postgres/public/yala_mcp_access_token_hook`, `site_url`,
`oauth_server_enabled`, `oauth_server_allow_dynamic_registration`, `oauth_server_authorization_path`).

**Riesgo del paso 1:** el hook corre en TODO inicio de sesión de staging. Si la función fallara, fallaría el login
de la app y de los goldens. La función es de una sola rama, sin lecturas, y se probó en SQL con los tres casos.
Para apagarlo, el mismo interruptor.

## Cómo se sabe que está bien

- `mcp/test/e2e/oauth.e2e.test.ts` en verde: descubrimiento, DCR, PKCE, consentimiento, token con
  `role = yala_mcp_reader` y `client_id`, las seis herramientas, B sin ver nada de A, escrituras denegadas con el
  token de Claude, refresh que conserva el rol y revocación que corta el refresh.
- Claude Code conectado: `claude mcp add --transport http yala-staging https://yala-mcp-staging.misty-surf-6866.workers.dev/mcp`,
  `/mcp` → *Authenticate*, y una pregunta respondida con datos de A.
- Actualizar §7 de `docs/exploracion/plugin-claude-mcp.md` con lo medido: los NO VERIFICADO que cierra el e2e.
