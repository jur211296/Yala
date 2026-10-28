---
id: groups-next-column-needs-the-capability-level-in-the-drain
status: backlog
priority: medium
area: "groups, cloudsync, gateway"
created: 2026-10-24
updated: 2026-10-24
source: "lote 12.1 Grupos (card k5ve): lo que la versión de columnas de Grupos deja para la primera columna con `since: 3`"
---

# La próxima columna de Grupos necesita cuatro piezas que hoy no hacen falta

Desde la card k5ve el canal de Grupos declara su versión de columnas (`X-Yala-Capability-Set`, `GroupsSyncCapability`,
`group_capability_manifest.json` v2) y el Worker poda pull y Merkle por versión. Hoy el cliente declara siempre 2, que
es todo el manifest, así que cuatro cosas no muerden todavía. Muerden el día que se añada una columna con `since: 3`:

1. **El drain de Grupos llama a `DeltaEmitter.emit` sin `capabilityLevel`** (`GroupsSyncClient`, ~L1393), y ese
   parámetro toma por defecto `SyncCapability.declaredLevel`, el nivel del canal PERSONAL. Si el `since` de la columna
   nueva se pusiera en su emisor, la columna dejaría de subir en todo teléfono cuyo canal personal declara 1 (casi todo
   el que usa Grupos sin la nube personal). Por eso hoy el `since` de Grupos vive en `GroupsSyncCapability.columnSince`
   y un test prohíbe `since` en los emisores de Grupos. Antes de la columna nueva: pasar
   `capabilityLevel: GroupsSyncCapability.declaredLevel` en ese `emit`.
2. **La subida de versión en el cliente** (re-encolar lo que no subió y volver a bajar desde 0, molde
   `applyCapabilityUpgradeIfPending` del canal personal) no existe en Grupos: hoy no puede haber subida.
3. **El guard de despliegue** (`gateway/scripts/check-manifest-not-older.mjs` y `/config`) solo mira el manifest
   personal: no impide desplegar un manifest de Grupos más viejo que el desplegado.

4. **El cliente poda columna a columna y el Worker poda el grupo de coherencia entero** (`droppedGroupsFor`): con la
   primera columna `since: 3` que entre en un grupo de coherencia, el Merkle local y el remoto divergirían. Hoy
   `budget_limit_amount` es `safe` y el nivel es siempre 2 (review adversarial del lote 12.1).

Hecho cuando: las cuatro piezas existen con su test, o la primera columna con `since: 3` las trae en el mismo PR.
