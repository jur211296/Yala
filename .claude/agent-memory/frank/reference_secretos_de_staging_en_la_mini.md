---
name: secretos-de-staging-en-la-mini
description: Desde la Max, los accesos de staging de Yala (Management API de Supabase, wrangler con sesión, usuarios de prueba A/B, cliente OAuth de la web) viven solo en la Mini y se usan por ssh sin copiarlos.
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
Relacionado: [[decisiones-py-no-esta-en-la-max]].
