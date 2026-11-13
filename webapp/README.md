# Yala web (`webapp/`)

La app de Yala en el navegador, como un aparato más de la cuenta en la nube. Plan, maqueta y las 13 decisiones
aprobadas: `docs/web-app/index.html`. Ticket del lote en curso: `tickets/*/yala-web-lote-0-cimientos.md`.

**Lote 0 (2.3, solo staging):** entrar con Apple o Google, sesión segura en el servidor, defensa anti-bots y una página
con el nombre de la cuenta y «Salir». Todavía no hay Panel: eso es el lote 1.

Staging: <https://yala-web-staging.misty-surf-6866.workers.dev>

## Cómo funciona

```
Navegador ──cookie HttpOnly──▶ Worker «yala-web-staging» ──▶ Supabase Auth (login social, permiso OAuth)
   (solo pinta)                 · sesión cifrada en KV         ──▶ PostgREST, rol yala_mcp_reader (solo lectura)
                                · lista cerrada de salidas     ──▶ Turnstile (anti-bots)
                                · shared-core (núcleo)
```

1. **Entrar.** La página pide Turnstile y manda un formulario a `/auth/start`. El Worker verifica el desafío y lleva al
   login de Apple o Google **a través de Supabase** (PKCE). Apple y Google solo ven la vuelta de Supabase, y las
   credenciales web que usan ya existían: el Services ID `pe.yala.app.web` y el cliente web «Yala Web (MCP)».
2. **Vuelta** (`/auth/callback`). Con el código, el Worker abre una sesión NORMAL de Supabase y con ella:
   - comprueba que la cuenta usa la nube (`profiles.kind`; «solo Grupos» no entra hasta el lote 3);
   - pide y aprueba **él solo** el permiso de su cliente OAuth (`GET /oauth/authorize` da el `authorization_id` sin
     navegador), así que no pasa por la Site URL de Supabase, que en staging es la del conector de Claude;
   - canjea el código con su secreto y recibe una sesión que el hook marca `role = yala_mcp_reader`;
   - cierra la sesión normal.
3. **Sesión.** Cookie `__Host-yala-web` (`HttpOnly`, `Secure`, `SameSite=Lax`). En el KV, la clave es el SHA-256 de la
   cookie y los tokens van cifrados con AES-GCM con una clave derivada de la propia cookie: leer el KV no revela nada.
   Dura 30 días sin uso (tope 90). Con «equipo compartido», hasta cerrar el navegador o 30 minutos sin uso.
4. **Salir** (`/auth/logout`). Cierra la sesión de Supabase que llevaba dentro, borra la del KV y la cookie.

Defensas: Turnstile al entrar; límites por IP (`/auth/*`) y por sesión (`/api/*`); `Origin` obligatorio en los POST; CSP
cerrada, `no-store` y `no-referrer` en todo (la página incluida: `run_worker_first`); y una lista cerrada de lo que el
Worker puede pedir fuera (`src/worker/egress.ts`). Si la configuración está mal, 503 a todo (`src/worker/config.ts`).

## Núcleo compartido

Los cálculos y el lector de PostgREST viven en `shared-core/` (los usan el conector, el gateway y la web). La web lo
importa por ruta relativa. Ver `shared-core/README.md`.

## Comandos

```bash
npm ci
npm run typecheck
npm test                     # unitarias, sin red
npm run deploy:staging       # build de la página + wrangler deploy
source ~/Secrets/yala-supabase-test/test-users.env && npm run test:e2e   # contra staging
```

La ruta `/auth/password` (contraseña) existe **solo en staging**, para el e2e: la niegan la configuración y la lista
cerrada en cualquier otro entorno.

## Supabase staging (cambios del lote 0, 2026-11-13)

| Qué | Antes | Después | Marcha atrás |
|---|---|---|---|
| Cliente OAuth «Yala web (staging)» | — | `03e0f13b-818f-4a93-8e69-701ea6343fda`, confidencial, vuelta `…/auth/supabase/callback`. Secreto en `~/Secrets/yala-web-staging/supabase-oauth-client.json` | borrarlo en *Authentication → OAuth Server* |
| Hook `yala_mcp_access_token_hook` | md5 `0a03fb943169e9fcee294fca49710398` (mcp0_03) | md5 `120f45468bc1db690a4c5655e7a7d48c` (`supabase/web0_01_hook_web_client.sql`) | `supabase/web0_01_rollback.sql` |
| `uri_allow_list` | `yaladev://auth-callback` | + `https://yala-web-staging.misty-surf-6866.workers.dev/auth/callback` | quitar la segunda entrada |
| Site URL | la del conector | **sin cambios** | — |

Comprobado después de aplicar: el login normal de la app sigue saliendo `authenticated` y sin `client_id`.

**Producción: nada.** Ni Worker, ni cliente OAuth, ni hook, ni `uri_allow_list`.

## Pendiente

- **Turnstile real.** Staging usa las claves de prueba de Cloudflare (siempre pasan). Hace falta crear el widget
  (dashboard de Cloudflare → Turnstile, dominio `yala-web-staging.misty-surf-6866.workers.dev`) y cambiar
  `TURNSTILE_SITE_KEY` y el secreto. `config.ts` rechaza las de prueba en producción.
- **Sesiones huérfanas.** Una sesión web que caduca en el KV deja viva su sesión de Supabase (de solo lectura, sin
  nadie con su refresh). El barrido, como el `mcp0_04` del conector, va con la lista de sesiones del lote 1.
- **Producción y `app.yala-app.pe`**: el dominio pide mover el DNS de `yala-app.pe` a Cloudflare (hoy en RCP).
