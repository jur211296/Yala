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
   # repetir con --env production donde aplique (sin DEV_SHARED_SECRET en prod)
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

Privacidad: el Worker **no loguea bodies** (contexto financiero/audio/imagen); solo metadata operativa.
