---
id: convert-to-group-fails-generically-with-an-income-homonym-category
status: backlog
priority: very-low
area: "grupos, registros"
created: 2026-11-09
updated: 2026-11-09
source: "review adversarial de `convert-personal-expense-to-group-from-the-editor` (2026-11-09), lente de UI"
---

# Convertir a gasto compartido falla con «Algo salió mal» si la categoría tiene una homónima de ingreso visible

## El problema, en lenguaje de usuario

Si el registro está en una subcategoría de gasto OCULTA y existe otra de ingreso VISIBLE con el mismo nombre, el puente
leería el gasto como una venta (Grupos B · card 8) y borraría el registro. La conversión lo impide, pero solo dice «Algo
salió mal», sin decir que hay que elegir otra categoría.

## Por qué pasa (leído el 2026-11-09)

Del gasto viaja solo el nombre de la categoría; `GroupSubcategoryMatchLogic` prefiere la visible antes que la de gasto.

## Qué haría falta

Un texto propio que pida cambiar la categoría en la revisión, o que la conversión elija una homónima de gasto.
