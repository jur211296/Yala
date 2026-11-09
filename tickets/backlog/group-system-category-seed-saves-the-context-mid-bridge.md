---
id: group-system-category-seed-saves-the-context-mid-bridge
status: backlog
priority: low
area: "grupos, puente"
created: 2026-11-09
updated: 2026-11-09
source: "medido el 2026-11-09 con el seam `GroupExpenseService._testFailConversionSave` en `PersonalToGroupConversionTests`"
---

# La siembra de las categorías de sistema de Grupos guarda el contexto a mitad del puente

## El problema

La primera vez que un teléfono necesita «Préstamo a grupos» u otra categoría de sistema de Grupos, el puente la siembra
desde `GroupBridgeSystemEntities.systemSubcategory` → `seedSystemGroupCategoriesIfNeeded`, que hace `context.save()` del
contexto ENTERO. Cualquier llamador que pase `shouldSave: false` para guardar todo junto (o deshacer si falla) queda con
la mitad de su gesto ya en disco.

## Medido

En la conversión de un registro a gasto de grupo, con el guardado final forzado a fallar, el gasto, sus repartos y el
enlace del registro quedaban en el almacén. La conversión lo evita sembrando antes de escribir (desde 2.3). Siguen
expuestos: `DraftService.linkGroupExpenseDraft` (L13-15, su «deshacer solo lo propio» no puede deshacer lo guardado) y la
primera pasada del puente en un teléfono sin la siembra.

## Qué haría falta

Que la siembra no guarde dentro del puente (lo guarda quien llama) o sembrar en el arranque de forma garantizada.
