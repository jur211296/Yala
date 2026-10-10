---
id: reverse-leaves-dangling-refs-it-can-no-longer-resolve
status: backlog
priority: low
area: "cloud sync, reverse"
created: 2026-10-08
updated: 2026-10-08
source: investigación de cloud-tx-epoch-orphan-relations (2026-10-08)
---

# Una referencia que queda colgada durante «Volver a iCloud» no se vuelve a resolver nunca

## Qué pasa

Cuando un pull aplica una fila cuya cuenta, subcategoría o categoría aún no existe en el teléfono, el applier deja la
relación en `nil` y apunta un `SyncDanglingRef` (`EntityApplyMap.resolveRef`). Lo resuelve el pase final de cada
`pullAndApplyOnce` (`reresolveDanglingRefs`), y en `.cloud` eso ocurre en cada ciclo.

La reversa hace pulls en sus fases previas al montaje (`reverseDrainOnce`, `verify`). Tras ella el teléfono queda en
`.icloud`, donde el motor no corre y no hay más pulls. Un dangler apuntado en esa ventana se queda en el store
sync-meta para siempre: si el destino llega después (por ejemplo, por el import del espejo al remontar), nadie
re-adjunta la relación, y el movimiento queda fuera de Registros, que agrupa por cuenta.

## Lo medido y lo inferido

- **Medido** (test de `cloud-tx-epoch-orphan-relations`): con la búsqueda de la cuenta forzada a `nil` en el apply, el
  pase final del mismo ciclo la re-adjunta; el daño solo dura si el destino tampoco está en ese pase.
- **Inferido**: que tras la reversa nada más llama a `reresolveDanglingRefs`. No hay ningún llamador fuera del motor.
- No medido en device: cuántos teléfonos terminan la reversa con danglers. No hay canario.

## Qué haría falta decidir

Un pase de `reresolveDanglingRefs` al cerrar la reversa (tras el remontaje y la quiescencia del import), o retirarlos
con rastro. Va con el resultado del device-QA de `cloud-tx-epoch-orphan-relations`: si allí aparece `danglingRef`,
este ticket sube.
