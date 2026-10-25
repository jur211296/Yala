---
id: applied-amount-filter-keeps-filtering-after-its-currency-changes
status: backlog
priority: low
area: "filters"
created: 2026-10-25
updated: 2026-10-25
source: "review adversarial del lote 12.5 (2026-10-25), leído en el código, sin medir en pantalla"
---

# Un monto ya aplicado sigue filtrando cuando cambia la moneda que tenía a la vista

## Qué pasa (leído en `2.2`, sin medir)

El lote 12.5 hizo que la hoja de Filtros no aplique el monto cuando no queda una sola moneda a la vista. Quedan dos
caminos fuera de la hoja:

1. Quitar el chip de una moneda desde la barra de filtros (`FilterControlBar`): el monto sigue aplicado y pasa a
   comparar cada registro en su propia moneda.
2. Crear el primer registro en una moneda nueva: el monto aplicado empieza a filtrarla en su unidad.

Y el chip «>100» no dice en qué moneda compara.

## Qué hacer

Medirlo. Si se confirma: vaciar el monto (o avisarlo) cuando su moneda deja de ser la única a la vista, desde
cualquier escritor del filtro (`session-filters.md`: el filtro tiene varios escritores).
