# Gateway · runbook de despliegues pendientes

El Worker no se despliega solo: `deploy:staging` y `deploy:production` los corre Jürgen a mano (`README.md`, «Deploy»).
Aquí se apunta lo que está mergeado y espera despliegue, con cómo comprobarlo. Lo desplegado se borra de aquí.

## 2026-10-18 · `manifest_version: 2` y `accounts.parent_account_id` (tarjeta con varias divisas)

- **Qué cambia:** el manifest gana la primera columna con `since: 2`. `X-Yala-Capability-Set: v1` deja de ser el set
  completo y proyecta sin las columnas posteriores; `/sync/pull` y `/sync/merkle` anuncian `manifest_version`. Ticket
  `multi-currency-accounts-1-model-and-sync`.
- **Requisito:** el DDL `qa/cloud/g18_01_account_parent_account_id.sql` aplicado ANTES en la misma base. Sin él, el select
  del Merkle pide una columna que no existe y cada verificación da 502.
- **Staging: desplegado el 2026-10-18** (`914f5402` → `0207e3eb` → `af424141`, con este cambio y con el de abajo), DDL
  aplicado y sonda `qa/cloud/g18_01-staging-probe.sh` 10/10. **Producción: pendiente**, con los pasos de
  `docs/RUNBOOK-staging-ddl.md` (entrada g18_01).
- **Guard nuevo en `predeploy:*`** (`scripts/check-manifest-not-older.mjs`): lee `sync.manifestVersion` del `/config` del
  Worker desplegado y para el despliegue si este árbol trae un manifest más viejo. Sin él, desplegar desde 2.1 (o un
  `wrangler rollback`) con teléfonos 2.2 en `v2` dejaría sus altas de cuenta rechazadas para siempre. **2.1 no lo trae
  hasta que se mezcle 2.2**: mientras, no se despliega producción desde 2.1. Forzar: `ALLOW_MANIFEST_DOWNGRADE=1`.

## 2026-10-15 · «Eliminar mi cuenta» olvida el contador de uso de la cuenta

- **Staging: desplegado el 2026-10-18** junto con el de arriba. Producción: pendiente.

- **Qué cambia:** `/account/delete` pide al Durable Object `RateLimiter` del cubo `sub:<sub>` que borre su estado
  (op `forget`). Ticket `account-deletion-leaves-attest-key-and-usage-counter-in-cloudflare`.
- **Sin migración de D1**: no cambia ninguna tabla. Solo código del Worker.
- **Desplegar:** `cd gateway && npm run deploy:staging`, y después `npm run deploy:production`.
- **Comprobar:** en `npx wrangler tail [--env production]`, un borrado de cuenta no imprime
  `[account-delete] quota cleanup falló`. Hasta desplegar, el contador de la cuenta se sigue quedando en producción
  aunque la política ya diga que se borra.
