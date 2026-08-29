---
id: zone-decisions-still-per-row
status: backlog
area: groups
priority: medium
created: 2026-08-29
updated: 2026-08-29
source: docs/aprendizajes-tecnicos.md
---

# Tres sitios siguen decidiendo por FILA sobre una zona

## Qué pasa

La familia del «duplicado mixto» se arregló moviendo las decisiones de FILA a ZONA con todas
sus filas (molde `GroupZoneCacheGate.belongsToBackendChannel`, ANY-row). Quedaron tres sitios
sin migrar, verificados vivos el 2026-08-29:

1. **`GroupService.batchClassifyAllGroups`** deriva `isOwner` **por fila**, y
   **`GroupBatchLeaveStore.replaceAll`** deduplica por zona quedándose con la **última** ⇒ la
   `plannedAction` CONGELADA que el resume re-ejecuta puede venir de la fila equivocada.
2. **`SplitGroupDeduplicationService.computeDedupPlan`** elige keeper por `createdAt` y es
   **ciego al canal**.

## Por qué van juntos

Son la misma clase y el mismo molde de fix. Separarlos en tres tickets multiplica el trabajo de
lectura sin cambiar nada de la solución.

## Contexto que ahorra tiempo

El **productor** de los duplicados (`$0.id == modelID` en `SplitSyncManager.applyGroupMeta`)
**ya no existe**: murió con el transporte CloudKit en la Fase 3, verificado el 2026-08-29 con
cero líneas de código. Esto es endurecimiento contra duplicados LEGACY que ya estén en disco,
no contra un productor activo — eso cambia la prioridad, no la corrección.

## De dónde sale

Residuales (b) y (c) de [docs/aprendizajes-tecnicos.md#un-gate-por-zona-calculado-sobre-filas-vivas-es-la-herramienta-equivocada-para-un-tombstone-por](../../docs/aprendizajes-tecnicos.md#un-gate-por-zona-calculado-sobre-filas-vivas-es-la-herramienta-equivocada-para-un-tombstone-por).
