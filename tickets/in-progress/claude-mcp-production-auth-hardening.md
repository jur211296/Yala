---
id: claude-mcp-production-auth-hardening
status: in-progress
priority: medium
area: cloud
created: 2026-09-26
updated: 2026-11-05
source: encargo 2026-09-26-claude-mcp-oauth-token-can-change-the-account (residual, fase 1)
---

# Llevar a producción el OAuth del conector de Claude, con la cuenta cerrada también si el Worker cae

## Qué cambia para el usuario

Nada visible. Cuando el conector de Claude salga a producción, el permiso que el usuario da a Claude sigue sin
poder tocar su cuenta. Además, si alguien comprometiera el servidor del conector, no podría quedarse con la cuenta.

## Contexto

En staging, Claude ya no recibe un token de Supabase: se lo da el Worker del conector. Así lo decidió el ADR «El
conector de Claude emite sus propios tokens» (`docs/DECISIONS.md`); las medidas están en la §8 de
`docs/exploracion/plugin-claude-mcp.md`.

El Worker guarda sesiones de Supabase de solo lectura en la base. Si alguien lo comprometiera (ejecutara código y
saltara la lista de salidas), en GoTrue quedaría a su alcance lo que el rol de Postgres no cubre:

- cambiar los metadatos;
- y, para un usuario sin contraseña (todos los de Apple o Google), **ponerle una y entrar con ella** — eso da una
  sesión `authenticated` que escribe todo.

**Lo que la review de staging YA cerró, y hay que replicar en producción:** GoTrue reemite un token para la misma
sesión al verificar un factor MFA, sin el claim `client_id`, y salía `authenticated`. El hook pasó a decidir por
`auth.sessions.oauth_client_id` (`mcp0_03`), así que ese token también es de solo lectura, y además se apagó MFA. En
producción hay que hacer las dos cosas.

## Qué hay que hacer (producción, `kefvaiymtgytemwbltlz`, solo con el sign-in real ya verificado)

1. Registrar el cliente CONFIDENCIAL del Worker de producción. Su secreto va a `~/Secrets/` y a `wrangler secret`,
   en el mismo gesto.
2. Escribir y aplicar `mcp0_01`, `mcp0_02` y `mcp0_03` (con ese id) por el runbook, en una ventana sin migraciones de
   la cola A. Después, encender el hook y, DESPUÉS, el servidor OAuth. El DCR de Supabase queda apagado desde el
   principio. El hook de `mcp0_03` decide por `auth.sessions.oauth_client_id`.
3. Activar `security_update_password_require_reauthentication` y `security_update_password_require_current_password`,
   y confirmar el cambio de email por las dos direcciones. Apagar MFA (`mfa_totp_enroll_enabled`,
   `mfa_totp_verify_enabled`): la app no la usa.
4. **Apagar el proveedor de email** (`external_email_enabled = false`): la app solo entra con Apple y Google. Así,
   una contraseña que alguien ponga no sirve para entrar. Antes, medir que ningún flujo de producción use email.
5. Encender los avisos por email de cambio de contraseña, de email y de factores (`mailer_notifications_*`), para
   que el usuario se entere si algo cambia.
6. Poner un `sessions_inactivity_timeout`: en staging es 0, así que una sesión huérfana no caduca nunca.
7. Un `[env.production]` en `mcp/wrangler.toml` con su KV, su `PUBLIC_URL` (dominio propio) y su cliente.
8. **(2026-11-05)** Aplicar `qa/cloud/mcp0_04_sweep_connector_sessions.sql` con el id del cliente de producción
   (cambiar `worker_client`; no lleva guarda por md5). Es el barrido diario de las sesiones que el Worker ya no puede
   cerrar al reconectar o caducar; en staging está aplicado y medido (`docs/RUNBOOK-staging-ddl.md`).

## Cómo se sabe que está bien

- `mcp/test/e2e/oauth.e2e.test.ts` en verde contra producción, con una cuenta de prueba de producción.
- Con el proveedor de email apagado, `POST /auth/v1/token?grant_type=password` da error aunque la contraseña exista.

## Hecho en el repo (2026-11-04) — espera a Jürgen para producción

Lo que se podía hacer sin acceso a producción está hecho y probado; el resto es el runbook
`mcp/RUNBOOK-produccion.md`, que lo despliega Jürgen tras el login con Apple y Google.

- **El punto 7 está hecho:** `[env.production]` en `mcp/wrangler.toml` (Worker `yala-mcp-production`, Supabase
  `kefvaiymtgytemwbltlz`, su KV y sus límites). Quedan dos valores PENDIENTE: el id del KV y el del cliente.
- **`npm run deploy:production`** corre antes un preflight (`mcp/scripts/preflight-production.mjs`) que se niega
  mientras quede algo PENDIENTE, falte el secreto o fallen typecheck o tests.
- **La configuración falla cerrado** (`mcp/src/config.ts`): producción contra el Supabase de staging, la anon key de
  otro proyecto, un id PENDIENTE o sin límites de peticiones → 503 a todo y un log `config_invalida`.
- **Límites de peticiones** (`mcp/src/ratelimit.ts`, pendiente de §7): por IP en las páginas y en registro/token, por
  usuario en `/mcp`.
- **El login con contraseña solo sale en staging**, ahora también en la lista de salidas (`egress.ts`).
- **Los SQL del hook para producción** se generan con `mcp/scripts/sql-produccion.py <client_id>`: cambia el id y
  recalcula las guardas por md5 (con el id cambiado a mano, `mcp0_03` abortaba). Verificado contra los md5 medidos en
  staging.
- Tests: `mcp/test/hardening.test.ts` y `mcp/test/production-config.test.ts`; 11 mutantes del endurecimiento, todos
  cazados.

**Lo que sigue (Jürgen):** los pasos 1–10 del runbook. Los puntos 1–6 de arriba son sus pasos 3, 5, 6 y 8.
