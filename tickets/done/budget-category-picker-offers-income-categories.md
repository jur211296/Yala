---
id: budget-category-picker-offers-income-categories
status: qa
priority: medium
area: budgets
created: 2026-11-06
updated: 2026-11-07
source: "revisión del usuario nuevo (6-nov, captura 23 del PR 837); card tablero-al-elegir-categorias-de-un-presupuesto-d-dkq6"
---

# Al elegir categorías de un presupuesto de gasto aparece «Ingresos»

## Qué pasaba

Nuevo presupuesto › Elegir categorías listaba los 11 grupos por nombre, incluido «Ingresos». Un presupuesto solo suma
gastos (`BudgetsViewModel.calculateSpending`), así que una categoría de ingreso elegida no sumaba nunca. Y «Seleccionar
todo» marcaba también las subcategorías de ingreso.

## Hecho (2026-11-07, lote 2.3)

El selector del editor de presupuesto ofrece solo categorías de gasto y sus subcategorías
(`BudgetEditorViewModel.budgetCategoryChoices`). Una categoría de ingreso sigue a la vista solo si el presupuesto ya
guarda alguna de sus subcategorías, para poder quitarla. Filtros de Registros y Exportar no cambian.

Tests: `BudgetEditorExpenseCategoriesTests` (sin nada elegido no sale «Ingresos» ni sus subcategorías; una guardada sigue
a la vista; cableado del editor).

## Guion de QA (simulador o iPhone, Yala Dev)

1. Planificación › Presupuestos › «+».
2. En «Qué cuenta», toca «Elegir categorías».
3. La lista no tiene «Ingresos» (ni ninguna categoría de ingreso propia).
4. Toca «Seleccionar todo», vuelve: el resumen nombra solo categorías de gasto.
