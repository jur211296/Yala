---
id: gateway-deploys-from-2-1-are-not-guarded-against-a-manifest-downgrade
status: backlog
priority: high
area: "gateway, cloud-sync, deploy"
created: 2026-10-18
updated: 2026-10-18
source: review adversarial de multi-currency-accounts-1-model-and-sync (lente de servidor, 2026-10-18)
---

# Un despliegue del Worker desde 2.1 puede bajar el manifest y dejar rechazadas las cuentas de los teléfonos 2.2

## Qué le pasa al usuario

Si el Worker de producción se despliega desde una rama con el `capability_manifest.json` viejo (`manifest_version: 1`)
cuando ya hay teléfonos 2.2 hablando `v2`, cada alta de cuenta de esos teléfonos lleva `parent_account_id` (a NULL) y
el Worker la rechaza entera (`unknown_column`). El teléfono la aparta para siempre: esa cuenta no llega a sus otros
dispositivos, y con un rechazo pendiente el Merkle se salta (`SyncMerkle`, dead-letters). También lo que estuviera en
cola sin red en el momento del despliegue.

## Lo medido (2026-10-18)

- Los últimos cambios de `gateway/src` entraron por 2.1, que sigue siendo la rama de trabajo.
- Desde la rama de la entrega 1 (base 2.2) el `predeploy` lo impide: `gateway/scripts/check-manifest-not-older.mjs`
  lee `sync.manifestVersion` del `/config` desplegado y para si el árbol trae uno más viejo. **2.1 no trae ese guard**
  hasta que se mezcle 2.2 en 2.1.
- El cliente no recupera una fila apartada por `unknown_column`: aunque baje a `v1` en el pull siguiente, la fila
  muerta no se reintenta sin la columna.

## Qué hacer

1. Llevar el guard (`gateway/scripts/check-manifest-not-older.mjs` + los dos `predeploy:*` de `gateway/package.json`)
   a 2.1, o mezclar 2.2 en 2.1 antes del primer despliegue de producción de 2.1 posterior a la entrega 1.
2. Decidir si el cliente debe reintentar sin las columnas posteriores una fila rechazada por `unknown_column` de una
   columna con `since` mayor que la versión que anuncia el Worker (hoy la aparta para siempre).

## Relacionados

- [`multi-currency-accounts-1-model-and-sync`](../done/multi-currency-accounts-1-model-and-sync.md)
- `gateway/RUNBOOK.md`, entrada «manifest_version: 2».
