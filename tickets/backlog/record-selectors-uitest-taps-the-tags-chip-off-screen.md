---
id: record-selectors-uitest-taps-the-tags-chip-off-screen
status: backlog
priority: low
area: testing
created: 2026-10-07
updated: 2026-10-07
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
