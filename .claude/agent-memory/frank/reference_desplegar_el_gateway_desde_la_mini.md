---
name: reference-desplegar-el-gateway-desde-la-mini
description: Cómo desplegar el gateway sin subir de rebote lo que no toca: wrangler limpio en /tmp de la Mini, base = lo que ya corre (verificado byte a byte) + solo tu parche
metadata:
  type: reference
---

Medido el 2026-11-14 (lote 1 de bugs de entrada, gateway en paralelo).

- **En la Max no hay credenciales de Cloudflare** (`wrangler whoami` → sin sesión); en la Mini sí, en
  `~/Library/Preferences/.wrangler/config/default.toml`. El wrangler de `~/Yala/gateway` de la Mini no arranca (miniflare
  con Node 26.3); uno limpio sí: `mkdir /tmp/wr-x && cd /tmp/wr-x && npm i wrangler@4.100.0`.
- **Producción NO corre la cabeza de 2.3**: ese día corría `3b8529af1` (sin el cupo de recibos de Grupos ni Yala web lote 3)
  y staging la cabeza. Desplegar desde tu rama habría subido todo eso a producción.
- **Cómo saber qué corre**: `GET /accounts/86c270a7776be98639700bd5959b303b/workers/scripts/<worker>/content/v2` con el
  `oauth_token` del toml (el `/content` a secas da `method_not_allowed`). Es un multipart: el módulo se llama `index.js` en
  producción y `worker.js` en staging. Compáralo con `wrangler deploy --dry-run --outdir` de un `git archive <commit>
  gateway mcp shared-core capability_manifest.json group_capability_manifest.json` (+ `npm ci` + `npm run sync:manifest`):
  con el commit bueno, 0 líneas de diff.
- Luego `patch -p1` con solo tu diff, `npm run deploy:staging` / `deploy:production`, humo (`/config` 200, rutas sin JWT →
  401 `yala_attest_required`) y vuelve a bajar el script para comprobar que es el verificado.

Relacionado: [[feedback-verificar-prod-del-gateway-con-token-acunado]].
