# Conector de Claude — salida a producción

**Estado (2026-11-04): listo para desplegar, NO desplegado.** El código, `[env.production]`, el script de despliegue
y los tests están en el repo. Falta lo que solo se puede hacer con acceso a producción, y eso es este documento.
Lo despliega Jürgen; nadie más.

Contexto: `README.md` (cómo funciona), el ADR «El conector de Claude emite sus propios tokens» (`docs/DECISIONS.md`),
`docs/exploracion/plugin-claude-mcp.md` §7–§8 y el ticket `claude-mcp-production-auth-hardening`.

## Antes de empezar: lo que tiene que ser verdad

1. **El login con Apple y Google ya está en el conector y probado en staging** (`claude-mcp-consent-with-apple-and-google`).
   Sin él nadie puede entrar en producción: el login con contraseña existe **solo** en staging, y el Worker lo niega
   dos veces fuera de ahí (`authorize.ts` y la lista de salidas de `egress.ts`).
2. **La nube está estable** — confirmado por Jürgen el 2026-11-04.
3. **Una ventana sin migraciones de la cola A** para el paso 5.
4. **La política de privacidad nombra a Anthropic** antes de anunciar el conector (requisito del directorio, §7).

## Lo que falta crear (la lista exacta)

| Qué | Dónde queda | Paso |
|---|---|---|
| KV `yala-mcp-production-oauth` | su id en `wrangler.toml`, `[[env.production.kv_namespaces]]` | 2 |
| Cliente OAuth **confidencial** del Worker en Supabase producción | su id en `wrangler.toml` (`SUPABASE_OAUTH_CLIENT_ID`) y en el hook (SQL del paso 5) | 3 |
| Secreto `SUPABASE_OAUTH_CLIENT_SECRET` | `~/Secrets/yala-mcp-production/supabase-oauth-client.json` **y** `wrangler secret --env production`, en el mismo gesto | 4 |
| Rol `yala_mcp_reader` + hook `yala_mcp_access_token_hook` | Supabase producción (`kefvaiymtgytemwbltlz`), SQL generado | 5 |
| Configuración de Auth de producción | Management API, `PATCH /v1/projects/kefvaiymtgytemwbltlz/config/auth` | 6 y 8 |
| Cuenta de prueba de producción para el e2e (y para los revisores del directorio) | `~/Secrets/yala-mcp-production/test-users.env` | 9 |

Nada más. Los tres límites de peticiones no se crean: los declara `wrangler.toml` y aparecen al desplegar.

## Coste en Cloudflare (estimación)

La cuenta ya está en **Workers Paid** (5 USD/mes, la paga el gateway). El conector **no sube ese tope**: todo lo que
gasta cabe en lo incluido. Precios de la página oficial, leída el 2026-11-04:

| Recurso | Incluido en Paid, al mes | Lo que gasta el conector | Si se pasara |
|---|---|---|---|
| Peticiones | 10 millones | 1 por herramienta, más descubrimiento y refresh. 100 usuarios × 30 llamadas/día ≈ 90 000/mes | 0,30 USD por millón |
| CPU | 30 millones de ms | unos pocos ms por llamada (la espera a Supabase no cuenta) | 0,02 USD por millón de ms |
| KV, lecturas | 10 millones | 1–2 por llamada (validar el token) | 0,50 USD por millón |
| KV, escrituras | 1 millón | registro, autorización y cada refresh (unas pocas por usuario y hora de uso) | 5 USD por millón |
| KV, almacenamiento | 1 GB | kilobytes (clientes y grants) | 0,50 USD por GB-mes |
| Límites de peticiones (`[[ratelimits]]`) | — | 3 cubos | la documentación no les pone precio |

**Tope que se propone:** 0 USD de más al mes en uso normal. Para pasar de lo incluido haría falta más de 10 millones
de llamadas al mes; un abuso lo frenan los límites (120 llamadas/min por usuario, 600/min por IP en registro y token,
30/min por IP en las páginas). Sugerencia: una alerta de facturación en Cloudflare a partir de 10 USD.

Supabase: el proyecto de producción ya es Pro. Cada llamada a `/mcp` hace un `GET /auth/v1/user` y lecturas de
PostgREST; no cambia de plan.

## Los pasos

Todo desde `mcp/`, salvo donde se diga. Antes de cada paso de Supabase, guardar el estado actual: es la marcha atrás.

1. **Medir la configuración de Auth de producción y guardarla.**
   ```bash
   mkdir -p ~/Secrets/yala-mcp-production
   curl -s -H "Authorization: Bearer $(cat ~/Secrets/yala-supabase-mgmt/pat)" \
     https://api.supabase.com/v1/projects/kefvaiymtgytemwbltlz/config/auth > ~/Secrets/yala-mcp-production/auth-config-antes.json
   ```
   Mirar en ese fichero `site_url`, `external_email_enabled`, `hook_custom_access_token_*`, `oauth_server_*`,
   `mfa_totp_*`, `security_update_password_*`, `mailer_notifications_*` y `sessions_inactivity_timeout`.
   **Ojo con `site_url`:** el paso 6 lo cambia a la URL del Worker (Supabase arma la pantalla de login con él). Antes,
   comprobar que ningún flujo de la app depende del valor actual (el login de la app es nativo, con `id_token`, y no
   debería; medirlo, no suponerlo).

2. **El KV.**
   ```bash
   npx wrangler kv namespace create yala-mcp-production-oauth
   ```
   Su `id` sustituye a `PENDIENTE-crear-kv-yala-mcp-production-oauth` en `wrangler.toml`.

3. **El cliente del Worker en Supabase producción.** Dashboard del proyecto → *Authentication → OAuth Server*:
   activarlo con el registro dinámico **apagado**, y registrar un cliente:
   - nombre «Yala para Claude», tipo **confidencial** (`client_secret_basic`);
   - una sola vuelta: `https://yala-mcp-production.misty-surf-6866.workers.dev/oauth/supabase/callback`.

   **Todavía no** poner la ruta de autorización ni encender nada más: el hook va antes (paso 5), o habría una ventana
   en la que Supabase emite tokens que escriben. Su `client_id` sustituye a
   `PENDIENTE-registrar-cliente-oauth-en-supabase-produccion` en `wrangler.toml`. El secreto, al paso 4 sin pasar por
   pantalla.

   > Si el dashboard no deja registrar el cliente con el servidor OAuth apagado, encenderlo aquí es seguro solo
   > porque el DCR está apagado y no hay más clientes: nadie puede pedir un token hasta el paso 6.

4. **El secreto, en el mismo gesto.** Guardar el JSON del cliente en
   `~/Secrets/yala-mcp-production/supabase-oauth-client.json` (`{"client_id": …, "client_secret": …}`) y subirlo:
   ```bash
   python3 -c "import json,os;print(json.load(open(os.path.expanduser('~/Secrets/yala-mcp-production/supabase-oauth-client.json')))['client_secret'],end='')" \
     | npx wrangler secret put SUPABASE_OAUTH_CLIENT_SECRET --env production
   ```
   Si el Worker aún no existe, wrangler pregunta si lo crea para guardar el secreto: sí. Comprobar con
   `npx wrangler secret list --env production`.

5. **El rol y el hook (DDL), en la ventana sin cola A.** Los SQL de staging llevan el id del cliente de staging y
   guardas por md5, así que se GENERAN para producción (cambia el id y recalcula las guardas):
   ```bash
   python3 scripts/sql-produccion.py --verificar          # los de staging siguen dando los md5 medidos
   python3 scripts/sql-produccion.py <client_id> ~/Secrets/yala-mcp-production/sql
   ```
   Aplicar, en este orden y uno a uno, `mcp0_01_readonly_role.sql`, `mcp0_02_oauth_client_allowlist.sql` y
   `mcp0_03_hook_keys_on_session.sql` de esa carpeta (SQL editor del proyecto o `psql "$PROD_DB_URL" -f …`). Al
   terminar, el md5 del hook tiene que ser el que imprimió el script:
   ```sql
   select md5(p.prosrc) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'yala_mcp_access_token_hook';
   ```
   Apuntar el antes → después en `docs/RUNBOOK-staging-ddl.md` (la sección de producción de cada `mcp0_0*`).

6. **Encender, en este orden** (`PATCH /v1/projects/kefvaiymtgytemwbltlz/config/auth`, el mismo token del paso 1):
   1. `hook_custom_access_token_enabled = true`, `hook_custom_access_token_uri = pg-functions://postgres/public/yala_mcp_access_token_hook`.
      Comprobar que el login normal de la app sigue funcionando (sale `authenticated`, sin `client_id`).
   2. **Después**, `site_url = https://yala-mcp-production.misty-surf-6866.workers.dev`,
      `oauth_server_enabled = true`, `oauth_server_allow_dynamic_registration = false`,
      `oauth_server_authorization_path = /oauth/consent`.
   3. **El login con Apple y Google de la pantalla de permiso** (las credenciales web ya existen: Llavero
      `yala-siwa-web` y `yala-google-oauth-web`, y sus Return URLs ya incluyen el callback de Supabase producción):
      - `external_apple_client_id = pe.yala.app.web,com.jurgenschmidt.yala,com.jurgenschmidt.yala.dev` y
        `external_apple_secret` = el JWT web. **El Services ID va PRIMERO**: Supabase usa el primero de la lista para el
        login web, y con el bundle de la app primero Apple responde «Invalid client id or web redirect url» (medido en
        staging el 2026-11-04). La app nativa acepta cualquiera de la lista: no cambia.
      - `external_google_client_id` con el cliente web «Yala Web (MCP)» **primero** y los dos de iOS detrás, y
        `external_google_secret` = su secreto.
      - Nada en `uri_allow_list`: la vuelta del login (`/oauth/consent/social`) es del mismo host que `site_url`.
      Comprobación: `curl -s -o /dev/null -w "%{redirect_url}" "https://kefvaiymtgytemwbltlz.supabase.co/auth/v1/authorize?provider=apple&redirect_to=https://yala-mcp-production.misty-surf-6866.workers.dev/oauth/consent/social&code_challenge=E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM&code_challenge_method=s256"`
      → tiene que llevar `client_id=pe.yala.app.web`; con `provider=google`, el id del cliente web.

7. **Desplegar el Worker.**
   ```bash
   npm ci
   npm run deploy:production
   ```
   `deploy:production` corre antes el preflight (`scripts/preflight-production.mjs`): se niega si queda algo
   PENDIENTE en `[env.production]`, si el id del cliente no es un uuid, si el KV no es un id real, si falta un límite
   o el secreto, o si fallan el typecheck o los tests. Además, una vez desplegado, si la configuración está mal
   (Supabase de staging, anon key de otro proyecto…) el Worker responde **503 a todo** y lo anota en el log
   (`evento: config_invalida`): mirarlo con `npx wrangler tail --env production`.

   Comprobación rápida: `curl https://yala-mcp-production.misty-surf-6866.workers.dev/` → «Yala MCP: conector de
   solo lectura…» (sin «staging»).

8. **Cerrar la cuenta frente a un Worker comprometido** (lo que la review de staging cerró, más lo que falta), con el
   mismo `PATCH`:
   - `security_update_password_require_reauthentication = true` y `security_update_password_require_current_password = true`;
   - `mfa_totp_enroll_enabled = false` y `mfa_totp_verify_enabled = false` (la app no usa MFA);
   - `mailer_notifications_*` de cambio de contraseña, de email y de factores, encendidas;
   - `sessions_inactivity_timeout` distinto de 0 (en staging es 0: una sesión huérfana no caduca nunca);
   - **`external_email_enabled = false`**, solo después de medir que ningún flujo de producción entra con email. Es lo
     que hace inútil una contraseña puesta a una cuenta de Apple o Google.

   Comprobar con el ticket: `POST /auth/v1/token?grant_type=password` da error aunque la contraseña exista.

9. **El e2e contra producción**, con la cuenta de prueba de producción:
   ```bash
   set -a; . ~/Secrets/yala-mcp-production/test-users.env; set +a
   MCP_URL=https://yala-mcp-production.misty-surf-6866.workers.dev npm run test:e2e
   ```
   > Hoy el e2e entra con email y contraseña y tiene fijada la URL de Supabase de staging: hasta que el login con
   > Apple y Google traiga su propio e2e, en producción se valida a mano conectando Claude (abajo) y repitiendo las
   > sondas de escritura con el token que recibe Claude: todas tienen que dar `403 bad_jwt`.

10. **Conectar Claude a producción** y preguntar algo («¿cuánto gasté este mes?»): Claude Code con
    `claude mcp add --transport http yala https://yala-mcp-production.misty-surf-6866.workers.dev/mcp`, o claude.ai →
    Ajustes → Conectores → *Añadir conector personalizado*.

## Marcha atrás

Siempre al revés que la subida, para no abrir nunca una ventana con tokens que escriben:

1. **El Worker:** `npx wrangler rollback --env production` (a la versión anterior), o `npx wrangler delete --env production`
   si era el primer despliegue. Sin Worker, Claude no tiene a quién pedir nada.
2. **El servidor OAuth de Supabase:** `oauth_server_enabled = false` y `site_url` al valor guardado en el paso 1.
3. **El hook:** `hook_custom_access_token_enabled = false`. Luego, si hace falta quitar la función y el rol, los
   `mcp0_0*_rollback.sql` generados, del 03 al 01 (el de `mcp0_01` solo con el hook ya apagado: si no, falla todo login).
4. **El resto de Auth** (paso 8): el `PATCH` con los valores del fichero del paso 1. Apagar el proveedor de email solo
   se revierte si algo dependía de él.
5. **KV, cliente y secreto** pueden quedarse: sin Worker no los usa nadie.

## Dominio propio

Hoy la URL es `*.workers.dev`, como el gateway de producción. Un dominio propio (`mcp.yala-app.pe`) exige que el DNS
de `yala-app.pe` esté en Cloudflare; hoy está en RCP (`ns.rcp.net.pe`, medido el 2026-11-04). Si se cambia **antes**
del primer despliegue basta con: `routes = [{ pattern = "mcp.yala-app.pe", custom_domain = true }]` en
`[env.production]`, `PUBLIC_URL` a la nueva URL, y la vuelta del cliente de Supabase y el `site_url` a juego. Después
del despliegue, además, los usuarios tendrían que volver a conectar Claude: el emisor OAuth cambia.

## Límites de peticiones

| Cubo | Clave | Rutas | Límite |
|---|---|---|---|
| `RL_BROWSER` | IP | `/authorize`, `/oauth/consent`, `/oauth/supabase/callback` | 30 por minuto |
| `RL_OAUTH` | IP | `/oauth/register`, `/oauth/token` | 600 por minuto (claude.ai llama desde pocas IPs de Anthropic) |
| `RL_MCP` | usuario | `/mcp` | 120 por minuto |

Se ajustan en `wrangler.toml` sin tocar código. El contador es aproximado y por ubicación de Cloudflare. Un 429 se
anota en el log como `evento: mcp_limite`.
