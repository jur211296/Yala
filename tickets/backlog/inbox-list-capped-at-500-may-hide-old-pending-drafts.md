---
id: inbox-list-capped-at-500-may-hide-old-pending-drafts
status: backlog
priority: low
area: inbox
created: 2026-11-07
updated: 2026-11-07
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
