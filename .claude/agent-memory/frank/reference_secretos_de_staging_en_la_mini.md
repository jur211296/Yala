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
Relacionado: [[decisiones-py-no-esta-en-la-max]].
