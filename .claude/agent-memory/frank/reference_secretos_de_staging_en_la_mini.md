---
name: secretos-de-staging-en-la-mini
description: Desde la Max, los accesos de staging (y la Management API de producción) de Yala (Management API de Supabase, wrangler con sesión, usuarios de prueba A/B, cliente OAuth de la web) viven solo en la Mini y se usan por ssh sin copiarlos.
metadata:
  type: reference
---

Medido el 2026-11-14 (sesión de la beta de Yala web, en la Max): `~/Secrets` de la Max solo trae `yala-ai-bench`,
`yala-google` y `yala-siwa`, y no hay `wrangler` con sesión. En la Mini (`ssh mini`, sin contraseña) están
`yala-supabase-mgmt/pat`, `yala-supabase-test/test-users.env`, `yala-web-staging/`, `yala-cloudflare/` y wrangler
con OAuth de la cuenta de Cloudflare.

**How to apply:** no copies secretos entre máquinas; corre el comando allí:
- SQL en Supabase staging: `python3 -c json… | ssh mini 'curl … api.supabase.com/v1/projects/fostjbbwstyuunmmefuk/database/query -H "Authorization: Bearer $(cat ~/Secrets/yala-supabase-mgmt/pat)" --data-binary @-'`.
- Desplegar un Worker: `rsync` del directorio (y `shared-core/` si lo importa) a `mini:tmp/…`, `npm ci` y `npm run deploy:staging` allí.
- e2e con usuarios A/B: `set -a; source ~/Secrets/yala-supabase-test/test-users.env; set +a` dentro del mismo `ssh`.
- **El mismo PAT alcanza producción** (`kefvaiymtgytemwbltlz`), medido el 2026-11-15. Mídela en solo lectura
  (`read_only: true` en el cuerpo); con DDL ese flag da 500/401 engañosos. Para PROBAR DDL sin dejar huella, una sola
  consulta que acabe en RAISE: la API la corre en una transacción y el RAISE la deshace (`webapp/supabase/ciclo_staging.py`).
- **El OAuth de wrangler en la Mini caduca** («Invalid access token» de la API de Cloudflare): `cd /tmp/x && npx -y
  wrangler@4.141.0 whoami` lo refresca; luego el token de `~/Library/Preferences/.wrangler/config/default.toml` sirve para
  la API (zonas, dominios de Workers, D1). No lee registros DNS (falta el permiso).
- **Desde el 2026-11-16 hay DOS sesiones de wrangler en la Mini.** `~/.wrangler/config` (la que wrangler lee primero)
  es la cuenta PERSONAL de Jürgen; la de Yala (86c270…) sigue en `~/Library/Preferences/.wrangler/config/default.toml`
  y su token caduca cada hora. Renovarla: POST `https://dash.cloudflare.com/oauth2/token` con su `refresh_token`, el
  `client_id` de wrangler y **`User-Agent: wrangler/…`** (sin él, 403 `error code: 1010`). Usarla sin pisar la otra:
  `CLOUDFLARE_API_TOKEN=<ese token> CLOUDFLARE_ACCOUNT_ID=86c270…` delante de wrangler. **Ese OAuth no trae Turnstile**
  (`challenge-widgets`): un widget lo crea Dan en el panel.
- **Desplegar Yala web a producción desde la Max** (medido el 16-nov, lote 1 de la base visual): `git clone --depth 1
  --branch <rama>` en un `mktemp -d` de la Mini, `npm ci` + `npx vite build`, y `wrangler deploy --env production` con el
  token de Yala delante (renovado con un script que reescribe `oauth_token`, `refresh_token` y `expiration_time` en el
  toml y deja el token en un fichero 0600 dentro del temporal, nunca en pantalla). Antes, `wrangler deployments list
  --env production` para anotar la versión de vuelta atrás; al acabar, borrar el temporal con el token.
Relacionado: [[decisiones-py-no-esta-en-la-max]].
