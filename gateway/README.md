# Yala Gateway

Proxy seguro de Yala a **OpenAI** y al proveedor de **tasas de cambio**. Las API keys reales viven **solo aquí** (Cloudflare Worker secrets), nunca en el binario del cliente iOS. Valida cada request con **App Attest**, verifica el **entitlement Pro** (firma de StoreKit) y aplica **rate-limit server-side**. Diseño completo: `../DESIGN-secure-proxy-gateway.md`. Plan: `~/.claude/plans/dame-el-plan-oficial-groovy-flute.md`.

> Estado: **scaffold** (task #1). Router + `/healthz` + envelopes de error listos y compilando. La lógica de attest/JWS/rate-limit/proxy llega en tasks #2-#5.

## Arquitectura (resumen)

- **Cloudflare Workers Paid** — runtime + secrets.
- **D1** — registro de keys App Attest + cache de entitlement (`migrations/0001_init.sql`).
- **Durable Objects** (`RateLimiter`) — contadores de cuota por device.
- **KV** — nonces de challenge (TTL nativo) + denylist.
- **Cache API** — caché de tasas (no son por-usuario → se sirven a todos desde el edge).
- Entornos: `staging` (acepta App Attest *development* + `DEV_SHARED_SECRET`) y `production` (solo *production*).

## ⚠️ Provisión del owner (task #7) — desbloquea deploy/validación

1. **Cuenta Cloudflare** con **Workers Paid** activado.
2. Crear recursos y pegar los IDs en `wrangler.toml` (reemplazar los `<PLACEHOLDER>`):
   ```sh
   npx wrangler d1 create yala-gateway-staging        # → database_id (staging)
   npx wrangler d1 create yala-gateway-production      # → database_id (prod)
   npx wrangler kv namespace create KV                 # → id (staging)
   npx wrangler kv namespace create KV --env production # → id (prod)
   ```
   Y `account_id` + `APPLE_TEAM_ID` (Apple Developer → Membership).
3. **Secrets** (NO van al repo; uno por entorno):
   ```sh
   npx wrangler secret put OPENAI_API_KEY              # la key NUEVA del 2.0
   npx wrangler secret put EXCHANGE_RATE_API_KEY
   npx wrangler secret put JWT_SIGNING_SECRET          # aleatorio fuerte
   npx wrangler secret put DEV_SHARED_SECRET           # solo staging
   npx wrangler secret put APP_STORE_API_KEY
   npx wrangler secret put GROUPS_ENC_KEY              # G7: cifrado at-rest de columnas † de grupos (pgcrypto)
   # PUSH_ROLE_JWT (G8-3): credencial de máquina `yala_push` del fan-out de silent push. NO se teclea a mano:
   node scripts/mint-push-role-jwt.mjs <path-al-legacy-jwt-secret> | npx wrangler secret put PUSH_ROLE_JWT
   # repetir con --env production donde aplique (sin DEV_SHARED_SECRET en prod)
   # GROUPS_ENC_KEY: staging y PROD llevan llaves DISTINTAS. Sin ella, /groups/pull responde 503 (jamás
   # sirve ciphertext). La de prod la genera el owner; el gateway de prod devuelve 503 en pull de grupos
   # hasta configurarla (irrelevante hoy — flag de grupos→backend OFF).
   # PUSH_ROLE_JWT: JWT HS256 firmado con el legacy secret del proyecto (claim role=yala_push) → SET ROLE
   # yala_push, el único rol con EXECUTE sobre get_group_push_tokens/prune_push_token (revocados de
   # authenticated en g8_02). exp 10 años. Ausente → fan-out no-op silencioso. mint-push-role-jwt.mjs lee el
   # legacy secret de un path (NUNCA a stdout) e imprime SOLO el JWT para el pipe. Rotación: re-acuñar + re-put.
   # ⚠️ si el owner revoca el legacy secret, el fan-out muere en silencio (401) — canario: log "upstream 401".
   ```
4. **Device físico** para QA de App Attest (no corre en simulador).

## Desarrollo local

```sh
npm install
npm run typecheck      # tsc --noEmit
npm run dev            # wrangler dev (local). Secrets locales → archivo .dev.vars (gitignored)
curl localhost:8787/healthz
```

`.dev.vars` (NO commitear):
```
OPENAI_API_KEY=sk-...
EXCHANGE_RATE_API_KEY=...
JWT_SIGNING_SECRET=...
DEV_SHARED_SECRET=...
GROUPS_ENC_KEY=...   # G7: llave del cifrado at-rest de columnas † de grupos (staging). NUNCA commitear.
```

## Migraciones D1

```sh
npx wrangler d1 migrations apply yala-gateway-staging
npx wrangler d1 migrations apply yala-gateway-production --env production
```

## Deploy

```sh
npm run deploy:staging       # wrangler deploy
npm run deploy:production    # wrangler deploy --env production
```

## Endpoints

| Método | Ruta | Estado |
|---|---|---|
| `GET` | `/healthz` | ✅ |
| `POST` | `/v1/attest/{challenge,register,assert}` | task #2 |
| `POST` | `/v1/chat/completions` · `/v1/audio/transcriptions` | task #5 |
| `GET` | `/rates/{live,timeframe}` | task #5 |
| `POST` | `/webhooks/appstore` | task #5 |
| `POST` | `/sync/push` · `GET` `/sync/pull` · `GET` `/sync/merkle` | I6 (Modo Nube) |
| `POST` | `/attest/bind` | I6 (Modo Nube) |
| `POST` | `/prefs/push` · `GET` `/prefs/pull` | I6 (Modo Nube) |
| `POST` | `/v1/debug/push` | spike G0 (staging-only, ver abajo) |
| `POST` | `/metrics` | ✅ telemetría propia (2026-07-17) |

Privacidad: el Worker **no loguea bodies** (contexto financiero/audio/imagen); solo metadata operativa.

### `POST /metrics` — telemetría propia mínima (sustituye TelemetryDeck)

Ingestión PÚBLICA (molde `/config`: sin auth/attest) de 3 eventos: `ping` (activos/día), `register`
(altas/día, `n`=local|cloud) y `canary` (diagnósticos del gate de Modo Nube). Escribe a **Workers
Analytics Engine** (binding `METRICS`; datasets `yala_metrics_staging` / `yala_metrics`, retención 90
días). Validación estricta (whitelist + regex + caps) como único anti-abuso; binding ausente → 200 y
descarte logueado (el cliente no reintenta por config server-side). Queries de referencia y contrato
del wire: `qa/cloud/README.md` § "Telemetría propia POST /metrics". Tests: `test/metrics.test.ts`.

## APNs (spike G0 — Grupos→backend)

`POST /v1/debug/push` envía un push silencioso de prueba vía APNs (`gateway/src/push/apns.ts`).
Gateado como `/v1/attest/dev`: **404 en producción** (`allowsDevBypass`) + header `X-Yala-Dev-Secret`.
Sin secrets configurados responde **503** (estado deployable pre-.p8). Configuración:

```sh
# APNS_KEY_ID (10 chars, no secreto) va en wrangler.toml [vars].
# La .p8 se sube como secret — stdin preserva los saltos del PEM; SIN --env (staging es el default):
npx wrangler secret put APNS_AUTH_KEY < AuthKey_<KEYID>.p8
```

Body: `{"deviceToken": "<hex64>", "sandbox": true}`. La respuesta 200 es el diagnóstico completo
(`delivered/status/apnsId/body/transportError`) — `transportError` = el fetch no negoció el
transporte con APNs (la incógnita HTTP/2 que este spike decide). JAMÁS commitear la .p8.

## Sync API (Modo Nube) — I6

Superficie de sincronización del backend Supabase (`../MODO-NUBE-ARQUITECTURA.md` §d/§e). El contrato del
envelope vive en `src/sync/types.ts` (semilla del contrato multi-cliente); la lógica en `src/sync/`.

**Auth de cada ruta (`requireUserAndAttest`):**
- `Authorization: Bearer <JWT de Supabase>` — el JWT del USUARIO. Se verifica con **`jose` + JWKS remoto**
  (`/auth/v1/.well-known/jwks.json`). El proyecto firma con **claves asimétricas ES256** (verificado
  2026-07-07) → el árbol es verificación real, NO la rama "decodificar-sin-verificar" de HS256 legacy.
  El MISMO JWT se reenvía a PostgREST; **RLS es el árbitro final** (nunca `service_role`). El `sub` es el
  `user_id`; **jamás se confía en un `user_id` del body** (se descarta y se loguea).
- `X-Yala-Attest-Session: Bearer <token de App Attest>` — token de sesión de App Attest en header
  SEPARADO (Authorization ya lo ocupa el JWT de Supabase). En `ENFORCE=observe` (staging) NO bloquea; en
  `enforce` es obligatorio. El rate-limit reusa el `RateLimiter` existente (categoría `sync`).

**`POST /sync/push`** — `{ deltas: [...] }`. Por delta: descarta columnas server-only del payload;
valida forma contra `capability_manifest.json`; **guard del invariante de emisión** (un delta que trae
PARTE de un grupo de coherencia → rechazado con marca `422` + canario `cloudSyncCoherenceGroupPartial`);
**gate `min_writable_version` POR-COLUMNA** (§d.2, lista curada HOY VACÍA en `schemaGate.ts`); re-agrupa
`fields` por unidad y llama al RPC `apply_delta` (PATCH column-by-column POR UNIDAD, §d.4bis). Respuesta
por-delta: `applied` / `noop` / `rejected` + `reason`. Re-enviar un batch = NO-OP idempotente (por HLC).

**`GET /sync/pull?since=&limit=`** — fan-out por tabla (RLS filtra al usuario), mezcla y ordena por
`server_seq` global, aplica el límite y **PODA** cada fila al capability-set del cliente
(`X-Yala-Capability-Set`; v1 iOS = set completo → sin poda; grupo-entero-o-nada). `{ deltas, max_server_seq }`.

**`GET /sync/merkle`** — **501** `{available:false, reason:"merkle_requires_c1_codec"}`. Frontera I6/I8:
la computación llega con el codec canon c1 en I8.

**`POST /attest/bind`** — vincula `keyId ↔ user_id` en `attest_keys` (Postgres, RLS-normal §e.5). El
`user_id` es el `sub`; `UNIQUE(attestation_type, key_id)` rechaza robar un keyId de otra cuenta (409).

**`POST /prefs/push` · `GET /prefs/pull`** — `user_preferences` (§e.6), LWW por key con HLC vía el RPC
`apply_pref` (sin `field_hlcs`).

### Migración Supabase (staging)

- `apply_delta(p_entity, p_sync_id, p_op, p_fields, p_field_hlcs, p_row_hlc, p_schema_version) → jsonb`
  y `apply_pref(p_key, p_value, p_hlc) → jsonb` — desplegadas a staging vía MCP
  (`i6_01_apply_delta` + `i6_02_apply_delta_found_fix`). `SECURITY INVOKER` (RLS activa vía el JWT del
  caller), **no aceptan `user_id`** (`auth.uid()` adentro). `apply_delta` es genérica sobre las 16 tablas
  de dominio (whitelist + `format(%I)`); las UNIDADES no se hardcodean en SQL — el Worker las resuelve del
  manifest y pasa `p_fields` **anidado por unit-key** (`{unit:{col:val}}`) + `p_field_hlcs` (`{unit:hlc}`);
  el tipado jsonb→columna es genérico vía `jsonb_populate_record(null::<tabla>, …)`. El tombstone y el
  guard delete-vs-upsert quedan **ROW-LEVEL** (congelado §d.4bis) con piso por-unidad al resucitar.

## ⚠️ Pendiente del owner (deploy)

- **`wrangler deploy` no está autenticado en este entorno** → el deploy a staging del Worker es del owner
  (`npm run deploy:staging`; el `predeploy` copia el manifest). Las migraciones Supabase YA están en staging.
- **`SUPABASE_URL`/`SUPABASE_ANON_KEY` de PRODUCTION** en `wrangler.toml` son un placeholder (hoy apuntan a
  staging para no romper el typecheck); cambiarlos al crear el proyecto Supabase de producción.
- **Migración a signing keys asimétricas: NO necesaria** — el proyecto YA firma con ES256 asimétrico (JWKS),
  el árbol de diseño. (Si un proyecto futuro estuviera en HS256 legacy, el Worker decodificaría el `sub` sin
  verificar y dejaría la validación a RLS; no es el caso aquí.)
