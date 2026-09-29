---
id: inbox-header-leaves-no-room-for-drafts-at-large-text
status: backlog
priority: medium
area: "inbox, a11y, iphone, adaptativo"
created: 2026-09-28
source: "iphone-small-screens-and-safe-areas-audit (carril adaptativo, paso 3), capturas del 2026-09-28"
---

# Con el texto muy grande en un iPhone SE, la Bandeja no deja sitio a los borradores

**Sale del paso 3 del carril adaptativo** ([[iphone-small-screens-and-safe-areas-audit]]).

## Qué le pasa al usuario

En un iPhone SE con el texto en el tamaño máximo (AX5), la Bandeja enseña su cabecera y el rótulo de la fecha
(«28 de septiembre»), y ningún borrador. Deslizar sobre la pantalla no mueve nada. Los borradores están, pero en
una franja de scroll de unos pocos puntos bajo la fecha: en la práctica no se pueden abrir ni aprobar. **Visto** en
`YalaLane-Adapt-iPhone-SE` (iOS 27.0) el 2026-09-28. En el ProMax a AX5 se ve el primer borrador y se llega al resto.

## Por qué pasa

`InboxView.body` apila en un `VStack` una cabecera **fija** —resumen de pendientes, filtros Pendientes /
Archivados, el aviso de acciones masivas y la guía contextual— y debajo la `List` de borradores, que se queda con
el alto que sobre. A AX5 en el SE la cabecera ocupa casi toda la pantalla.

## Qué hacer

Que la cabecera se desplace con la lista, al menos a tamaños de accesibilidad: moverla dentro de la `List` como
primera sección, o envolver el conjunto en un solo scroll. Cambia cómo se comporta la pantalla (hoy la cabecera no
se va al bajar), por eso no entró en la auditoría. Verificar con capturas antes/después en los dos iPhone del
carril, a tamaño normal y a AX5, con el guion descrito en `qa/evidencia-adaptativo-20260928/
iphone-small-screens-and-safe-areas-audit/README.md`. A tamaño normal no debería cambiar nada visible.

## Relacionados

- [[large-text-leftovers-outside-the-main-iphone-screens]] — punto 4, los filtros de la Bandeja partidos en
  sílabas a AX5. Se puede arreglar a la vez.
