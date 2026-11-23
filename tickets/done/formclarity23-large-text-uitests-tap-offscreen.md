---
id: formclarity23-large-text-uitests-tap-offscreen
status: done
priority: medium
area: "transactions-core-crud"
created: 2026-11-12
updated: 2026-11-22
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

## Cierre (2026-11-22)

Medido el 2026-11-22 (sesión nocturna «pruebas de interfaz rojas de 2.3», Max): **verde en la nocturna de 2.3 del 22-nov** (run 44991989046, sobre b27dcc084, runner del CI iOS 27.0) y **verde en local** sobre origin/2.3 = ea35c1234 (iPhone 17 Pro, iOS 27.2, `Yala Dev`, cola del simulador; 9 casos de los 8 tickets en una corrida, 9/9).

Mismo caso que `form-clarity-23-large-text-uitests-red-on-2-3`: V3 pasa y M1 ya no existe (hoja B1, 20-21 nov). Sin cambios.
