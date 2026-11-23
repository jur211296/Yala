---
id: formclarity23-large-text-uitests-tap-offscreen
status: backlog
priority: medium
area: "transactions-core-crud"
created: 2026-11-12
updated: 2026-11-12
source: gate del lote 2.3 de favoritos al registrar (rojo previo, medido con control)
---

# Dos casos de texto grande de `FormClarity23UITests` caen en `origin/2.3`

## Qué pasa

En el simulador iPhone 17 Pro (iOS 27.2), con `UICTContentSizeCategoryAccessibilityXXXL` y seed `minimal`:

- `test_m1_largeText_theNoticeIsShown` cae en la línea 51 (`typeAmount`): «Neither element nor any descendant has
  keyboard focus». El campo `new_transaction_amount` está en y = 822–953 en una pantalla de 874 pt: el toque cae fuera.
  El helper de esta suite no desplaza el formulario; el de `KeyboardSaveBar23UITests.typeAmount` sí, y esa suite pasa.
- `test_v3_largeText_manualEntryIsReachable` cae en la línea 180: «Failed to scroll to visible» sobre
  `fab_new_transaction`.

## Cómo se midió

El 2026-11-12, en el gate del lote de favoritos: rojos en la corrida con el arreglo y **rojos también con
`NewTransactionView`, `TransferAmountInputView` y `FavoriteChipsRow` devueltos a `origin/2.3`** (control). Con el seed
`minimal` no hay favoritos, así que ese lote no mueve nada en esa pantalla. La nocturna corre sobre 2.2, donde esta suite
no existe: no hay fecha de cuándo empezó. Sospecha sin medir: los lotes de 2.3 que añadieron filas encima del monto
(barra sobre el teclado, categorías) lo bajaron por debajo del borde a ese tamaño.

## Qué hacer

`typeAmount` de `FormClarity23UITests` con el desplazamiento de `KeyboardSaveBar23UITests`, y entrar al «+» de V3 con
`revealPanelFAB` o por deeplink. Antes, mirar si a texto máximo la pantalla real deja el monto alcanzable (es la promesa
de Z1/Z2).
