# Yala web (`webapp/`)

La app de Yala en el navegador, como un aparato más de la cuenta en la nube. Plan, maqueta y las 13 decisiones
aprobadas: `docs/web-app/index.html`. Tickets: `tickets/*/yala-web-lote-0-cimientos.md` y `tickets/*/yala-web-lote-1-beta.md`.

**Lote 0 (2.3, solo staging):** entrar con Apple o Google, sesión segura en el servidor y defensa anti-bots.

**Lote 1 (2.3, la beta, solo staging):** Panel, Registros y Bandeja en lectura; «Apuntar», que deja el gasto en la
Bandeja del iPhone; Configurar (cuenta, sesiones web, ocultar montos, idioma, salir); español e inglés; y, en el iPhone
(Yala Dev), Ajustes › Tu cuenta de Yala › «Navegadores conectados» para ver y cerrar las sesiones web.

Staging: <https://yala-web-staging.misty-surf-6866.workers.dev>

## Cómo funciona

```
Navegador ──cookie HttpOnly──▶ Worker «yala-web-staging» ──▶ Supabase Auth (login social, permiso OAuth)
   (solo pinta)                 · sesión cifrada en KV         ──▶ PostgREST, rol yala_mcp_reader (solo lectura)
                                · lista de sesiones (DO)       ──▶ Turnstile (anti-bots)
iPhone ──Bearer (su sesión)──▶  · shared-core (núcleo)         ──▶ D1 del gateway: cola de borradores (mail_drafts)
                                · lista cerrada de salidas
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
cerrada, `no-store` y `Referrer-Policy: same-origin` en todo (la página incluida: `run_worker_first`); y una lista cerrada de lo que el
Worker puede pedir fuera (`src/worker/egress.ts`). Si la configuración está mal, 503 a todo (`src/worker/config.ts`).

## Lote 1: mirar, apuntar y sesiones

- **Mirar.** `/api/panel`, `/api/registros` y `/api/categorias` llaman a los cálculos del núcleo compartido tal cual
  (`listar_cuentas`, `resumen_periodo`, `buscar_movimientos`, `listar_categorias`): mismas cifras que el conector y que
  la app. `/api/bandeja` lee `inbox_drafts` pendientes (SELECT dado por `supabase/web1_01`). Cada petición comprueba antes
  que la sesión de Supabase sigue viva (`GET /user`): así una sesión cerrada desde el iPhone deja de leer al momento.
- **Apuntar.** `POST /api/borradores` deja la fila en la cola COMÚN de borradores (decisión D9): `mail_drafts` del D1 del
  gateway de staging, con la forma del correo del banco más `source: "web"`, `account_ref` y `subcategory_ref`. El iPhone
  la recoge por `GET /mail/drafts` (también cuando hay sesiones web, no solo con el correo preparado) y la pasa a su
  Bandeja con origen «Automatización» y evidencia «Yala web». Tope: 30 al día por cuenta. El gateway no cambió.
- **Sesiones.** Un Durable Object por cuenta (`SessionIndex`) guarda la lista: navegador, sistema, ciudad aproximada,
  fechas y equipo compartido. No va en el KV porque su `list` es eventual (una sesión recién abierta tardaba hasta un
  minuto en verse). «Cerrar» borra la sesión del KV, su entrada y su sesión de Supabase (`yala_web_close_session`). La
  página pregunta `/api/me` cada 30 s y al volver a la pestaña: una sesión cerrada vuelve a la pantalla de entrar.
- **El iPhone** entra por `/api/dispositivo/*` con el token de su sesión de la nube (`role = authenticated`, sin
  `client_id`). Sin App Attest: solo ve y cierra las sesiones web propias (decisión P9 del ticket).

## Núcleo compartido

Los cálculos y el lector de PostgREST viven en `shared-core/` (los usan el conector, el gateway y la web). La web lo
importa por ruta relativa. Ver `shared-core/README.md`.

## Comandos

```bash
npm ci
npm run typecheck
npm test                     # unitarias, sin red
npm run deploy:staging       # build de la página + wrangler deploy
set -a; source ~/Secrets/yala-supabase-test/test-users.env; set +a; npm run test:e2e   # contra staging
```

El e2e del lote 1 apunta borradores de verdad en la cola de staging, con la descripción `e2e-lote1-<marca>`. Después,
se retiran para que no le lleguen al iPhone del usuario de prueba A:

```bash
npx wrangler d1 execute yala-gateway-staging --remote \
  --command "DELETE FROM mail_drafts WHERE json_extract(payload, '$.merchant') LIKE 'e2e-lote1-%'"
```

La ruta `/auth/password` (contraseña) existe **solo en staging**, para el e2e: la niegan la configuración y la lista
cerrada en cualquier otro entorno.

## Supabase staging (cambios del lote 1, 2026-11-14)

`supabase/web1_01_bandeja_y_sesiones.sql`, aplicado el 14-nov (marcha atrás: `supabase/web1_01_rollback.sql`):

| Qué | Antes | Después |
|---|---|---|
| `inbox_drafts` para `yala_mcp_reader` | sin acceso | SELECT con política de filas propias (como sus otras 9 tablas) |
| `yala_web_close_session(uuid)` | — | `security definer`; solo sesiones del cliente web y de `auth.uid()`; EXECUTE para `authenticated` y `yala_mcp_reader` |
| Barrido diario | — | `yala_web_sweep_sessions()` + cron `yala-web-sweep-sessions` (04:27 UTC): sesiones web sin uso en 31 días o con más de 91 |

**Producción: nada.**

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
- **Origen «Yala web» en la Bandeja del iPhone.** Hoy entra como «Automatización» con la evidencia «Yala web»: un origen
  propio pide un caso nuevo en `DraftSourceType`.
- **Cerrar sesión en el iPhone** no cierra las sesiones web (borrar la cuenta sí).
- **La política de privacidad** tiene que nombrar lo que guarda la web: la sesión, el navegador y la ciudad aproximada.
- **Producción y `app.yala-app.pe`**: el dominio pide mover el DNS de `yala-app.pe` a Cloudflare (hoy en RCP).
