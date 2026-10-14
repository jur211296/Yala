---
id: export-filters-say-1-seleccionadas
status: backlog
priority: very-low
area: "copy, l10n, export"
created: 2026-10-14
updated: 2026-10-14
source: "auditoría UX 2.2 · lote 8 (B4), visto fuera del lote"
---

# Exportar dice «1 seleccionadas»

## Qué pasa

`filters.selectedCount` («%d seleccionadas») es una clave plana sin plural, y la usa el paso de filtros de Exportar
(`Yala/App/ViewModels/ExportFiltersStepViewModel.swift`, cuentas y etiquetas). Con una sola cuenta elegida sale
«1 seleccionadas». Es el mismo fallo que el lote 8 arregló en Registros («1 seleccionados», «1 resultados») y no se
tocó por el alcance estricto del lote.

## Qué hacer

Pasar `filters.selectedCount` al `.stringsdict` de los 12 idiomas base (polaco con cuatro formas) y dejarla plana
con la forma `other` en las cuatro variantes, como `records.selectedCount` (PR #499).
