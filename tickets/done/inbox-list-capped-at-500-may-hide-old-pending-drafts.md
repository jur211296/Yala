---
id: inbox-list-capped-at-500-may-hide-old-pending-drafts
status: done
priority: low
area: inbox
created: 2026-11-07
updated: 2026-11-10
source: revisión por vistas 2.3, zona 38, eficiencia (docs/ux/revision-vistas-2.3/38-bandeja-ia/02-revision.html)
---

# La lista de la Bandeja lee 500 borradores, archivados incluidos: un pendiente viejo podría no salir

Hipótesis, sin medir. `InboxViewModel.loadAllDrafts` lee como mucho los 500 borradores más recientes por fecha de creación,
de todos los estados (`InboxViewModel.swift:91-94`), y de ahí salen la lista y los contadores de los filtros. Otra lectura,
la de pendientes, no tiene límite (`:112-115`) y alimenta `hasPendingDrafts` y «Guardar el siguiente». No se encontró
purga de archivados. Con más de 500 borradores en el historial, un pendiente creado antes de los 500 más recientes no
aparecería en la lista mientras la app sigue creyendo que hay pendientes.

## Cómo medirlo

Sembrar 600 borradores archivados más nuevos que un pendiente y abrir la Bandeja: ¿sale el pendiente? Si no sale, que el
límite se aplique por filtro (pendientes sin límite, archivados con el suyo).

## Resuelto (2026-11-10, lote 03 de las necesarias 2.3)

Medido: con 600 archivados más nuevos que un pendiente, el pendiente no salía en la lista ni en su contador. Ahora
`InboxViewModel.loadAllDrafts` lee TODOS los pendientes y aplica el tope de 500 solo a los resueltos
(`InboxViewModel.resolvedDraftsLimit`). Nota: la otra lectura de pendientes no era «sin límite» como decía el ticket,
tiene tope de 200; alimenta «hay pendientes» y «Guardar el siguiente», que miran los más recientes, y no se tocó.

Prueba: `YalaTests/InboxOldPendingDraftTests`. Nada que probar a mano.
