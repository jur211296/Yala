---
name: plegar-la-lista-de-un-split-en-el-ipad
description: XCUITest en el iPad vertical — el botón que pliega la lista de un ListDetailSplit no es `ToggleSideBar` (ese abre la barra de páginas); va por la etiqueta «Ocultar barra lateral»
metadata:
  type: reference
---

En el iPad Pro 13 vertical hay DOS botones de barra lateral, y el que trae id no es el que pliega la lista:

- `ToggleSideBar` («Mostrar u ocultar barra lateral»), en las pestañas de arriba: abre la barra lateral de PÁGINAS por
  encima. Elegirlo por altura o por x no sirve: hay dos con ese id a la misma altura y los dos la abren.
- El de la cabecera de la columna de lista, sin identificador: etiqueta «Ocultar barra lateral» («Hide Sidebar» en
  inglés). Ese pliega la lista y el detalle pasa a ocupar la ventana (la fila del grupo midió 1.000 pt).

En horizontal no hay ningún `ToggleSideBar`. Medido el 2026-11-10 con `axe describe-ui` tras tres vueltas de test
rojo por el botón equivocado. Molde: `ReadableWidthIPadUITests.test_groupDetail_keepsItsExpensesAtTheReadableWidth_withTheListFolded`.

**Cómo aplicar:** antes de escribir un toque a un botón del sistema en el iPad, lee el árbol con `axe describe-ui`
(con la app lanzada a mano con los mismos args) en vez de adivinar el id. Relacionado: [[conducir-simulador-con-axe]].
