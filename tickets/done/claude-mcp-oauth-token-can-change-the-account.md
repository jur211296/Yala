---
id: claude-mcp-oauth-token-can-change-the-account
status: done
priority: high
area: cloud
created: 2026-09-26
updated: 2026-09-26
source: encargo 2026-09-26-plugin-claude-mcp-fase0-spike (medido en el e2e de OAuth contra staging)
---

# El permiso que el usuario da a Claude para LEER también le deja cambiar la cuenta

## Resultado (2026-09-26, cerrado el mismo día)

**Claude ya no recibe un token de Supabase: se lo da el Worker del conector, y ese token no sirve en Supabase.**
La promesa de la pantalla («No podrá crear, cambiar ni borrar nada: ni tus finanzas ni los datos de tu cuenta») se
cumple entera. Decisión: ADR «El conector de Claude emite sus propios tokens» (`docs/DECISIONS.md`). Detalle y
medidas: §8 de `docs/exploracion/plugin-claude-mcp.md`.

**De las tres vías del ticket:**

1. **La limpia no existe.** En GoTrue v2.197.0 —la de staging y la última publicada— `requireAuthentication` no mira
   `client_id` ni `scope`, y no hay issue ni PR. El texto del issue está abajo, sin publicar.
2. **La vía 2 queda como capa extra**, no como cierre. La reautenticación solo cuenta si la sesión tiene más de
   24 h, y «contraseña actual» solo si el usuario ya tiene una: a uno de Apple o Google el token le podía poner una.
   Activadas en staging.
3. **Vía 3, hecha.** El Worker es el servidor OAuth de Claude (`@cloudflare/workers-oauth-provider`) y un cliente
   OAuth confidencial de Supabase. Guarda la sesión de Supabase cifrada, con revocación al momento, rotación y
   caducidad de 30 días deslizantes y 90 como máximo. En Supabase, solo su cliente recibe tokens (`mcp0_02`), y el
   DCR está apagado.

**Medido contra staging** (`mcp/test/e2e/oauth.e2e.test.ts`, usuarios A y B):

- **Las 17 escrituras de `/auth/v1/*`** con el token de Claude dan 403 `bad_jwt`, y la cuenta de A queda idéntica.
  Son: `PUT /user` con cuerpo vacío, metadatos, email, contraseña y teléfono; factores; códigos de recuperación;
  `logout` global; `reauthenticate`; identidades; permisos; passkeys; y aprobar autorizaciones.
- **Su refresh** no vale en Supabase, y PostgREST lo rechaza.
- **Las seis herramientas** leen (A: 39 cuentas, −189 PEN). B no ve nada de A.
- **Revocar corta al momento**, desde Claude (RFC 7009) y desde la cuenta de Supabase.
- **Un cliente de la fase 0** que el propio usuario aprueba recibe 403 del hook, sin token.
- **El login normal no cambió:** `authenticated` y sin `client_id`.

**Staging, antes → después, y marcha atrás:** `docs/RUNBOOK-staging-ddl.md`, sección `mcp0_02`.

**La review adversarial (tres lentes) cazó, y se cerró antes del merge:**

- **Escalada por MFA (alta):** GoTrue reemite un token para la misma sesión al verificar un factor MFA, sin
  `client_id`, y salía `authenticated` —escribía toda la base—. Con un Worker comprometido, la cuenta entera. El hook
  pasó a decidir por la SESIÓN (`mcp0_03`) y se apagó MFA. Verificado en SQL.
- **Un parpadeo del JWKS revocaba la conexión (alta):** un fallo pasajero de las claves de Supabase se leía como
  «token inválido» y borraba el grant. Ahora es «no disponible» (503), no revoca, y reintenta.
- **La lista de vueltas era por dominio, no por URL (media):** un open redirect en `claude.ai` habría robado el
  código. Ahora es la URL exacta del callback de Claude, y loopback `/callback`.
- Y varios menores: PKCE obligatorio para todos, `formData` fuera del try daba 500, clasificación de errores de
  GoTrue por lista cerrada, tests que pasaban por la razón equivocada (verificados con mutación).

**Residuales, con ticket propio:**

- `claude-mcp-production-auth-hardening`: llevarlo a producción (con `mcp0_03` y MFA apagado allí también), apagar el
  proveedor de email y poner `sessions_timebox`.
- `claude-mcp-revoke-from-claude-leaves-supabase-session`: la sesión que deja huérfana revocar desde Claude.

### Issue para `supabase/auth` (redactado, NO publicado; lo publica Jürgen si quiere)

> **OAuth 2.1 server: access tokens issued to OAuth clients can modify the user's account — no way to restrict
> account endpoints by client or scope**
>
> **Summary.** Access tokens issued by the OAuth 2.1 server (beta) to third-party clients are accepted by every
> endpoint behind `requireAuthentication`, including account-mutating ones: `PUT /user` (email, password, phone,
> `user_metadata`), `POST /factors` / `DELETE /factors/{id}`, `/user/identities/*`, `DELETE /user/oauth/grants`,
> `POST /logout?scope=global`, `GET /reauthenticate` and `POST /oauth/authorizations/{id}/consent`. Neither the
> `client_id` claim nor the granted `scope` is checked (`internal/api/auth.go`, v2.197.0). A user who grants an app
> (e.g. an MCP connector) read access through the consent screen gives it control of the account.
>
> **Why existing settings don't cover it.**
> - Scopes only shape the ID token and `/oauth/userinfo` (see the "Token security" docs).
> - A custom access token hook can change `role`, so RLS can make data read-only, but GoTrue ignores the role.
> - `security_update_password_require_reauthentication` only applies to sessions older than 24 h
>   (`internal/api/user.go`), so a freshly authorized OAuth session can change the password without a nonce.
> - `security_update_password_require_current_password` only applies when the user already has a password. For
>   social-only users the OAuth token can set a first password and then sign in with email + password: account
>   takeover.
> - Metadata changes, TOTP enrollment and global logout are not covered by any setting.
>
> **Repro (hosted, v2.197.0).** Enable the OAuth server with DCR, register a client, authorize as a user and
> exchange the code. Then `PUT /auth/v1/user` with `Authorization: Bearer <oauth access token>` and
> `{"data":{"x":"1"}}` → `200`, metadata changed.
>
> **Proposal.** By default, do not accept tokens that carry a `client_id` on account-management endpoints (`PUT
> /user`, `/factors`, `/user/identities`, `/user/oauth/grants`, `/logout` with `global`/`others`, `/reauthenticate`,
> `/oauth/authorizations/*`), keeping `GET /user` and `/oauth/userinfo`. Alternatively, gate them behind a scope
> granted at consent, or add a config flag. At minimum, document the behavior in the OAuth server docs.
>
> **Workaround.** Our MCP server became the authorization server for the third party and a confidential OAuth
> client of Supabase, so the third party never holds a Supabase token. A custom access token hook denies tokens to
> any other `client_id`.


## Qué cambia para el usuario

Hoy, en staging, cuando alguien conecta Yala a Claude y pulsa «Permitir», Claude recibe una llave que no puede
tocar sus finanzas —la base lo impide—, pero sí puede cambiar datos de la **cuenta** de inicio de sesión: los
metadatos, y por lo que expone esa API también el email y la contraseña. La pantalla le promete que Claude «no
podrá crear, cambiar ni borrar nada». Esto bloquea la fase 1: no se lanza a producción así.

## Qué se midió (2026-09-26, `mcp/test/e2e/oauth.e2e.test.ts`)

- El token que Supabase emite a Claude sale con `role = yala_mcp_reader` y `client_id`. PostgREST le deniega
  todas las escrituras (403) y las RPC de escritura.
- Con ese mismo token, `PUT /auth/v1/user` de GoTrue responde **200** y aplica el cambio. Lo que se probó fue una
  clave de metadatos, que después se borró por SQL. GoTrue no mira el rol de Postgres ni el `scope` del token
  (`openid email`).
- En staging, `security_update_password_require_reauthentication` está en `false`. Así que, inferido, no medido,
  cambiar la contraseña tampoco pediría nada más.

El e2e lo deja como `it.fails`: el día que se cierre, ese test se pone rojo y avisa de que hay que retirarlo.

## Qué hay que hacer

Hay que decidir el camino, y medirlo con el mismo e2e:

1. Averiguar si Supabase ofrece restringir los endpoints de `/auth/v1/user*` para tokens OAuth, por `scope` o
   por cliente. Es lo limpio. Si no existe, abrir un issue en `supabase/auth`.
2. Mientras tanto, activar `security_update_password_require_reauthentication` y la confirmación de cambio de
   email. Eso cubre la contraseña y el email, pero no los metadatos.
3. Si no hay forma en Supabase, emitir a Claude un token que NO sea de Supabase: un OAuth propio en el Worker
   (por ejemplo, la librería `workers-oauth-provider` de Cloudflare) que guarde la sesión de Supabase cifrada.
   Es lo que el Paso 0 descartó por guardar refresh tokens, y hay que volver a pesarlo con este dato.

## Contexto

El hueco lo anticipó la lente de seguridad de la review adversarial del 2026-09-26, y el e2e lo confirmó.
