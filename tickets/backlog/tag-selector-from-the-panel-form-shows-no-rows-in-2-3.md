---
id: tag-selector-from-the-panel-form-shows-no-rows-in-2-3
status: backlog
priority: medium
area: "transactions, tags, testing"
created: 2026-11-06
updated: 2026-11-06
source: gate del lote «Bugs UI: widget del mes, mover entre divisas, importe desde Estadísticas» (2026-11-06)
---

# En 2.3, el selector de etiquetas de «Nuevo registro» (desde el Panel) no monta filas

## Medido (2026-11-06, iPhone 17 Pro, iOS 27.2, `Yala Dev`)

- `TransactionsCrudUITests/test_recordSelectorsOpenAtMediumDetent` cae en `:124` con «No se montó el selector de
  new_transaction_tags_chip con filas (tag_selector_row_…)». Cuenta y subcategoría, en el mismo caso, pasan.
- **3 de 3 en rojo aislado** en la rama del lote, centinela «estuviste solo».
- **También rojo en `origin/2.3` limpio** (`b182e5774`, sin los cambios del lote): no lo trae ese lote.
- **Verde en las nocturnas de 2.2** del 3, 4 y 5 de noviembre. Ningún CI de PR contra 2.3 lo ejecuta (no estaba en
  sus áreas), así que el rojo nació en algún commit propio de 2.3 sin que nada cantara.

## Sin medir

Si es la app (el selector abre vacío o no abre) o el test (el seed `minimal` de 2.3 ya no trae etiquetas, o cambió el id
de las filas). Primer paso: lanzar 2.3 con `-uitest -uitest-reset -uitest-skip-onboarding`, Panel › + › Nuevo registro ›
Etiquetas, y mirar la pantalla y el árbol. Después, bisecar `origin/2.2..origin/2.3` con este caso.

## Hecho cuando

El caso vuelve a verde en 2.3 por el arreglo que toque (app o test), con su causa escrita aquí.
