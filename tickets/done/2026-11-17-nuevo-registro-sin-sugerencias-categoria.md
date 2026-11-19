---
id: 2026-11-17-nuevo-registro-sin-sugerencias-categoria
status: done
priority: medium
area: "transactions, nuevo-registro"
created: 2026-11-17
updated: 2026-11-18
source: "Jürgen, 17-nov 18:04 Lima, con captura de su iPhone: las categorías sugeridas bajo el monto ocupan demasiado y se ven mal"
---

# Nuevo registro: sin categorías sugeridas debajo del monto

## Qué pidió Jürgen

Quitar las tres píldoras de categoría sugerida y el «Más…» que salían debajo del monto en Nuevo registro
(«Supermercados y bodegas», «Suscripciones de utilidad», «Comisiones y cargos», «Más…»). Ocupaban demasiado y se veían
mal.

## Qué cambió para quien usa la app

- Debajo del monto ya no hay fila de categorías sugeridas: el formulario sube y queda más limpio.
- La categoría se elige como siempre, con el chip «Categoría» (en el formulario o en la barra encima del teclado), que
  abre la hoja con todas las categorías y su buscador («café» sigue encontrando Restaurantes).

## Qué se tocó

- `NewTransactionView.swift`: fuera el bloque de la fila (`CategoryQuickPickRow`) y su condición `showsQuickCategoryRow`.
- `CategoryQuickPickRow`, `NewTransactionViewModel.quickPickSubcategories` y `CategoryQuickPickLogic` quedan sin uso,
  sin borrar (fuera del alcance de la sesión). Limpieza aparte si se quiere.
- `YalaUITests/Flows/CategoryQuickPick23UITests.swift` se borra: sus dos casos probaban la fila. El caso del buscador
  pasa a `YalaUITests/NuevoRegistroSinSugerencias/NuevoRegistroSinSugerenciasUITests.swift`, entrando por el chip.

## Cómo se probó

- `NuevoRegistroSinSugerenciasUITests`: sin ningún `new_transaction_quick_category_*` en pantalla, a tamaño normal y con
  texto grande (AX3); el chip abre la hoja y «café» → Restaurantes queda puesto. Rojo sobre la base (la fila existía),
  verde con el cambio.
- Capturas antes y después en iPhone 17 Pro y iPhone SE (3.ª gen.), normal y AX3.
