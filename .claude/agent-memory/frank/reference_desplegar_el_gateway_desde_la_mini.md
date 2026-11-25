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

- **Repetido el 2026-11-20 (g32_01, manifest v7)**: los dos Workers corrían `e4d8752701` y `2.3` traía `shared-core` sin
  desplegar. `git archive e4d8752701 gateway mcp shared-core <manifests>` en el scratchpad + `npm ci` en `gateway/` y
  `shared-core/` + copiar SOLO el manifest nuevo: diff del bundle 8 líneas. Ahí el `npx wrangler` del `npm ci` sí arrancó
  con Node 26. **`wrangler` sin variables usa `~/.wrangler/config` (la cuenta personal) y da «Authentication error
  10000»**: delante, `CLOUDFLARE_API_TOKEN` (renovado desde `~/Library/Preferences/.wrangler/config/default.toml`, receta en
  [[secretos-de-staging-en-la-mini]]) y `CLOUDFLARE_ACCOUNT_ID=86c270…`. El token caduca en una hora: renuévalo antes de
  cada paso largo y bórralo al acabar.

- **Repetido el 2026-11-20 (cuenta sola al leer, staging)**: base `e4d8752701` + `capability_manifest.json` de 2.3 dio 0
  líneas de diff. Para sacar `worker.js` del multipart, **parte por el boundary de la primera línea**: una regex que corte
  en `\n--` se para en el `-----END CERTIFICATE-----` que lleva el bundle (sale 1,2 MB de 1,6 y miles de líneas de diff
  falsas). Saber qué base corre: `GET …/workers/scripts/<worker>/deployments` ordenado por `created_on` (no viene
  ordenado) y su `workers/message`, si quien desplegó lo anotó: anótalo tú con `--message`.

- **Repetido el 2026-11-21 (reglas de captura): staging y producción pueden necesitar bases distintas.** Staging recibió
  manifest v9 (con su columna ya en Supabase staging) y producción solo los cambios de `src/ai/` sobre su manifest v8: un
  Worker v9 sin la columna en la base de producción rompe la subida de cuentas. Cada uno con su base verificada (0
  líneas) y diff final solo de lo mío. La renovación del token por `refresh_token` (script en Python, token a un fichero
  0600 del scratchpad) funcionó sin pedir nada.

Relacionado: [[feedback-verificar-prod-del-gateway-con-token-acunado]].

- **Repetido el 2026-11-24 (lote 5 del conector): staging corría el trabajo SIN MERGEAR de otra sesión** (Gmail sin
  código, «sobre 400978c4d sin 436e7f9c8 routes ni apariencia de shared-core + solo src/mail»). Desplegar la rama a
  pelo se lo habría quitado. La base se reconstruye leyendo su `--message`: `git archive 400978c4d` + `src/mail` de su
  rama + `git show <commit>^:<fichero>` de lo que dice que quitó → 0 líneas. **El `export {}` del final del bundle dice
  qué entrypoints viven**: ese staging no publicaba `ConnectorDrafts` (el conector no podía apuntar) aunque 2.3 sí.
  Con el symlink a `node_modules` las rutas del bundle cambian: normaliza con `sed` antes del `diff`. Nombres nuevos
  (`str`, `tokens`) renombran variables ajenas en el bundle: son ruido, no cambios.
- **El D1 de staging no lleva `d1_migrations` al día** (le faltaban 0004 y 0005): `migrations apply` reaplicaría todo.
  Se aplica solo el fichero propio con `d1 execute --file` (que sea `IF NOT EXISTS`) y se anota a mano su fila.

- **2026-11-25 (D1 saturada): parche de BUNDLE sobre el bundle vivo, sin reconstruir la base.** Staging corría un montaje
  de tres sesiones (manifest v9, por detrás de 2.3 con v11). En vez de reconstruirlo: `dry-run` de 2.3 y de mi commit, `diff
  -u` entre los dos bundles (100 líneas, solo lo mío), `patch` sobre el `worker.js` bajado de `content/v2`, y comprobar que
  las funciones que nombra el parche existen en el vivo (`withScope2`, etc.). Desplegar con una COPIA del toml con
  `main = "<parcheado>"` y `no_bundle = true` (`wrangler deploy <fichero> --no-bundle` ignora el toml: «provide a name»);
  `dry-run --outdir` + `cmp` confirma que sube exactamente ese fichero. Antes, `/settings` del script contra `[vars]` del
  toml: un deploy reescribe las variables.
- **Diagnosticar D1 desde la Mini, solo lectura**: GraphQL `d1AnalyticsAdaptiveGroups` (por `databaseId`, por minuto) y
  `workersInvocationsAdaptive` (por `scriptName`). Un minuto sin consultas registradas con el error en Sentry = la cola de
  Cloudflare, no carga nuestra.
