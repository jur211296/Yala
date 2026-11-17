---
id: 2026-11-15-registros-filtros-rapidos
status: done
priority: medium
area: "records, filters, ui"
created: 2026-11-15
updated: 2026-11-16
source: "Jürgen, 15-nov, captura de la pestaña Registros en el iPhone"
---

# Registros: filtros rápidos de Cuenta y Categoría más bonitos, alineados y sin el hueco del hero

Los chips rápidos que se añadieron bajo «Nuevo registro · Voz · Foto · Yala IA» se veían mal: cuatro cápsulas sin
iconos, el período repetido, los botones Lista/Calendario en una fila aparte con un hueco, y en el hero el rótulo «Te
queda» lejos de su cifra.

## Hecho cuando

- Sin chip de período: quedan Cuenta, Categoría y Más filtros, con icono y más aire.
- Cuenta y Categoría eligen varias a la vez con las piezas de la app: la fila de cuenta de Nuevo registro y la rejilla
  de categorías + subcategorías del primer presupuesto del onboarding.
- La fila va en la misma línea que Lista/Calendario y no se corta en el iPhone SE.
- En el hero de Registros el rótulo y la cifra se leen como un bloque.

## Resolución (2026-11-16)

- `RecordsQuickFilterBar`: sin chip de período; chips con icono (tarjeta, etiqueta, filtro) y `trailing` para Lista/
  Calendario. Si la fila no cabe, «Más filtros» queda solo con su icono; si aun así no cabe, los chips bajan a una
  segunda línea y los botones de vista se quedan arriba a la derecha.
- `Records/QuickFilters/`: hoja de cuentas (`AccountSelectorRow`) y hoja de categorías (`TutorialSelectableTile` +
  círculos de subcategoría). Lo marcado lo guarda la barra y se aplica al cerrar la hoja, de una vez.
- `RecordsQuickCategorySelectionLogic`: categorías enteras → `selectedCategories`; alguna a medias → todo en
  `selectedSubcategories`, nunca las dos (el filtro exige las dos).
- Hero de Registros: aire rótulo → cifra `xs` (`SummaryHeaderStack.labelToContentSpacing`).
- Tests: `RecordsQuickFiltersMultiSelectTests`, `RecordsQuickFiltersRowUITests`; `RecordsQuickFilters23UITests` al día.
