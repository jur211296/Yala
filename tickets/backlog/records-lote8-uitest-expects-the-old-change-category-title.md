---
id: records-lote8-uitest-expects-the-old-change-category-title
status: backlog
priority: medium
area: "testing, records"
created: 2026-10-24
updated: 2026-10-24
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
