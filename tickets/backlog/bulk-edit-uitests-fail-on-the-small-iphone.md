---
id: bulk-edit-uitests-fail-on-the-small-iphone
status: backlog
priority: low
area: "testing, records, bulk-edit, adaptativo"
created: 2026-10-01
source: "gate de iphone-landscape-headers-fill-the-short-screen (carril adaptativo), 2026-10-01"
---

# Los dos casos de `BulkEditUITests` caen en el iPhone SE

**Medido el 2026-10-01** en `YalaLane-Adapt-iPhone-SE` (`C248A9E8…`), por UDID, corrida aislada y vigilada
(`sim-libre --vigilar` = 0): `test_opensBulkEditSheet` y `test_bulkEditNoteCompletes` fallan los dos con «No se montó
BulkEditSheet (bulk_edit_option_note)» (`BulkEditUITests.swift:60` y `:85`). **Igual en `2.1` limpio
(`a6b957630`, worktree aparte) que con el PR de `iphone-landscape-headers-fill-the-short-screen`**: no lo trae ese
cambio. El gate de siempre los corre en el `iPhone 17 Pro`, así que el SE no se había mirado.

## Hipótesis (sin medir)

El test toca las dos primeras filas de Estadísticas › Registros y espera la hoja de edición masiva. Con UNA sola fila
seleccionada el botón abre el editor individual, no el masivo. En el SE vertical la segunda fila puede quedar bajo la
barra de pestañas y el toque perderse, con lo que se abre el editor individual. Se confirma con `snapshot_ui` tras los
dos toques, o mirando el `record_row` 1 contra el marco de la barra.

## Qué hacer

Si la hipótesis se confirma, el test debe asegurarse de que la segunda fila es tocable (desplazar antes, o elegir
filas visibles) — es del test, no del producto: con el dedo la fila se alcanza deslizando.
