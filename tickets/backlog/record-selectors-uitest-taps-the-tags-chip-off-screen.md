---
id: record-selectors-uitest-taps-the-tags-chip-off-screen
status: backlog
priority: low
area: testing
created: 2026-10-07
updated: 2026-10-28
source: rojo del gate de advisory-ui-tests-fail-every-retry, bisecado contra la base
---

# `test_recordSelectorsOpenAtMediumDetent` toca el chip de etiquetas cuando está fuera de pantalla

## Qué se midió el 2026-10-07

`TransactionsCrudUITests.test_recordSelectorsOpenAtMediumDetent` falla así en iPhone 17 Pro, iOS 27.0, Xcode 27.0:

```
Failed to compute hit point for Button, {{417.0, 716.0}, {115.3, 34.0}},
identifier: 'new_transaction_tags_chip', label: 'Etiquetas'
```

El chip empieza en x=417 y la pantalla mide 402 de ancho: está en la fila horizontal de chips, a la derecha del de
subcategoría, sin desplazar. El test lo recorre en su tabla de selectores (`TransactionsCrudUITests.swift`,
entrada `("new_transaction_tags_chip", "tag_selector_row_", false)`) y lo toca sin hacerlo visible antes.

**Es preexistente, medido, no supuesto:** con el producto de `2.1` @ `5d72ab97d` (los cuatro ficheros de app de la
rama devueltos a `HEAD`, binario recompilado), falla 2 de 2 con el mismo mensaje. En el gate de la rama falló
igual (1 de 49 casos).

El test nació el 2026-10-04 en `67edfa1e2` (los selectores a media altura). En la QA programada del CI no se ve
porque esa suite cae entre las que no llegan a correr antes del tope de 110 min
([[nightly-ui-suite-hits-its-110-minute-cap-every-night]]).

## Qué haría falta

Hacer visible el chip antes de tocarlo (desplazar la fila de chips) o elegirlo por una vía que no dependa de
dónde cae en la fila. Mirar antes si en un iPhone de 402 pt la fila enseña algún indicio de que hay un chip más a
la derecha: si no lo enseña, es también de producto.

## Medido en 2.1 (triage 2026-10-08)

- `YalaUITests/Flows/TransactionsCrudUITests.swift` `test_recordSelectorsOpenAtMediumDetent`: la tabla sigue con `("new_transaction_tags_chip", "tag_selector_row_", false)` y el bucle hace `chip.tap()` tras `waitForExistence`, sin hacerlo visible. Sin commits en el fichero desde el 2026-10-07.
- Sigue sin mirarse la pregunta de producto (si la fila enseña que hay un chip más a la derecha en 402 pt).

Triage 2026-10-08: abierto · low → low · rojo determinista de un test, no de la app; ensucia los gates que corren esa suite, pero no los deja ciegos.

## 2026-10-09 · sigue en el gate, bisecado contra `4c973dd8a`

Gate de `after-session-redesign-review-widgets-siri-applepay-and-web-copy`, `iPhone 17 Pro` iOS 27.0 `46287CFE`: falla
en lote (centinela en 0) con `Failed to compute hit point for Button … new_transaction_tags_chip` en `{444, 716}`. **Un
build de `2.1` sin el cambio (`4c973dd8a`) falla igual, aislado.**

## 2026-10-09 · el rojo del test, resuelto; la pregunta de producto, abierta

El test pasa por el helper `openSelectorFirstRow` (ticket `new-transaction-account-picker-uitests-fail-on-the-ios-27-lane-pro-max`),
que, si el chip queda fuera de la ventana, arrastra la fila de chips en horizontal a su altura antes de tocarlo. Se mira
el marco del chip y no `isHittable`: con el chip entero fuera de pantalla, `isHittable` **lanza** («Activation point
invalid») en vez de devolver `false` (medido en el primer lote). Verde en lote dos rondas en el `iPhone 17 Pro` iOS
27.0, centinela en 0.

Queda la mitad de producto: si en un iPhone de 402 pt la fila enseña algún indicio de que hay un chip más a la derecha.
Por eso el ticket sigue abierto, ahora solo por eso.

## 2026-10-27 · el test vuelve a estar rojo, con otro mensaje

Ahora falla en la línea 124 con «No se montó el selector de `new_transaction_tags_chip` con filas (`tag_selector_row_…`)»:
el chip se alcanza, pero el selector de etiquetas no enseña filas. Medido en `iPhone 17 Pro` iOS 27.0 con el simulador
recién borrado: **rojo con la base `origin/2.2` @ `12601e455`** y rojo igual con el cambio del encargo
`yala-ia-detalles-selector` (que cambia cómo se pinta el fondo de estos selectores). Es preexistente; no se persiguió
en ese encargo. Hipótesis sin medir: con la semilla de los tests no hay etiquetas, y el selector vacío no tiene filas
`tag_selector_row_` que esperar.

**Confirmado de nuevo el 2026-10-27** en el gate de `nuevo-registro-inactivo-post-onboarding` (card omw5): mismo
mensaje, rojo con la base `d89a68061` recompilada (1 de 1, centinela en 0) y con la rama (en lote y aislado).

**Y el 2026-10-28** en el gate de `grupos-bugs-columna-reintento-borrador` (Frank): mismo mensaje en la línea 124, en lote
(1 de 157) y aislado con la rama, y **rojo con la base `d071f1657` extraída con `git archive` y compilada aparte** (1 de
1, centinela en 0 en las tres corridas). Esa rama no toca etiquetas ni «Nuevo registro».
