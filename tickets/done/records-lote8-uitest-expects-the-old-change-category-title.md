---
id: records-lote8-uitest-expects-the-old-change-category-title
status: done
priority: medium
area: "testing, records"
created: 2026-10-24
updated: 2026-10-26
source: "gate de la sesión «Duo cerrado · opción 2» (2026-10-24)"
---

# El XCUITest de cambiar la categoría de un registro espera el título viejo

`RecordsLote8UITests#test_changeSubcategory_marksTheCurrent_andUndoesFromTheNotice` cae siempre en la línea 134:
busca la barra «Cambiar subcategoría», y la hoja se titula **«Cambiar categoría»** desde el commit `77f62f037`
(lote decidido 2.2 · 02, sesión B), que cambió `records.l8.changeSubcategoryTitle` y no el test.

**Medido el 2026-10-24** en el iPhone 17 Pro (iOS 27.0): rojo 3 de 3 con la rama de la sesión y **1 de 1 con la base
`2.2` (`c62c00c8e`) sin cambios**. No lo trae el Duo.

## Hecho cuando

- El test lee el título por la clave de localización (o el literal nuevo) y vuelve a verde.
- Se comprueba que el resto del caso (marca la actual, deshacer desde el aviso) sigue cubriendo lo que cubría.

**Medido otra vez el 2026-10-25** (lote 12.3, iPhone 17 Pro, iOS 27.0): ahora cae ANTES, en la línea 130 («El menú no
ofrece cambiar la categoría»): tras la pulsación larga, `app.buttons["Cambiar categoría"]` no aparece. Rojo 2 de 2 con la
rama del lote y 1 de 1 con la base `2.2` (`fc58604a0`) sin cambios, así que no lo trae el lote. El arreglo del título de
la hoja no basta: hay que mirar primero cómo sale hoy el menú contextual de la fila.

## Cerrado (2026-10-26, sesión «tests rojos 2.2»)

- **El menú contextual no estaba roto.** Medido hoy en el iPhone 17 Pro (iOS 27.0) sobre `origin/2.2` (`be99a2256`): tras
  la pulsación larga, «Cambiar categoría» sale y el caso pasa la línea 130; cae en la 134, el título de la hoja. El
  rojo de la 130 del 2026-10-25 no se repitió en ninguna de las 4 corridas de hoy.
- **Arreglo, solo en el test:** la hoja se busca por «Cambiar categoría» (el título de `records.l8.changeSubcategoryTitle`
  desde `77f62f037`) y el cierre de la hoja se espera por esa misma barra. El producto no cambia.
- El resto del caso sigue cubriendo lo mismo: la opción actual sale marcada (`selected == true`), elegir otra saca el
  aviso con «Deshacer», la hoja se cierra y «Deshacer» retira el aviso.
- Verde 3 de 3 junto al resto de `RecordsLote8UITests` (7 casos × 3, todos verdes).
