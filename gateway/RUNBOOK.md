# Gateway · runbook de despliegues pendientes

El Worker no se despliega solo: `deploy:staging` y `deploy:production` los corre Jürgen a mano (`README.md`, «Deploy»).
Aquí se apunta lo que está mergeado y espera despliegue, con cómo comprobarlo. Lo desplegado se borra de aquí.

## 2026-10-15 · «Eliminar mi cuenta» olvida el contador de uso de la cuenta

- **Qué cambia:** `/account/delete` pide al Durable Object `RateLimiter` del cubo `sub:<sub>` que borre su estado
  (op `forget`). Ticket `account-deletion-leaves-attest-key-and-usage-counter-in-cloudflare`.
- **Sin migración de D1**: no cambia ninguna tabla. Solo código del Worker.
- **Desplegar:** `cd gateway && npm run deploy:staging`, y después `npm run deploy:production`.
- **Comprobar:** en `npx wrangler tail [--env production]`, un borrado de cuenta no imprime
  `[account-delete] quota cleanup falló`. Hasta desplegar, el contador de la cuenta se sigue quedando en producción
  aunque la política ya diga que se borra.
