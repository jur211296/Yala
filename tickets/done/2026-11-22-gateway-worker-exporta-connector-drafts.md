---
id: 2026-11-22-gateway-worker-exporta-connector-drafts
status: done
priority: high
area: "gateway, conector-mcp"
created: 2026-11-22
updated: 2026-11-22
source: "despliegue de Dan del gateway de producción, 22-nov"
---

# El gateway no publicaba ConnectorDrafts y «apunta un gasto» del conector fallaba siempre

`gateway/src/worker.ts` (el `main` de wrangler desde el 14-nov) reexportaba `default`, `RateLimiter`, `WebGroupsReader` y `WebGroupsWriter`, pero no `ConnectorDrafts`, que `index.ts` sí exporta. El service binding `CONNECTOR_DRAFTS` de `mcp/wrangler.toml` no encontraba la entrada, en staging y en producción.

## Arreglo
- `worker.ts` reexporta `ConnectorDrafts` desde `./connector/entrypoint`. Era la única clase de `index.ts` que faltaba.
- `gateway/test/worker-exports.test.ts` lee `gateway/`, `mcp/` y `webapp/wrangler.toml` y exige que cada `class_name` y cada `entrypoint` hacia `yala-gateway*` salga de `worker.ts`, y que todo export de `index.ts` también. Falla sin el arreglo (medido).
- `wrangler deploy --dry-run` empaqueta `ConnectorDrafts` en el bundle. No se desplegó: lo hace Dan.
