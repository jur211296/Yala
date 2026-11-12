---
name: el-gesto-de-cerrar-agarra-la-hoja-de-debajo
description: XCUITest de «cerrar deslizando» con navigationBars.firstMatch arrastra la hoja de DEBAJO; el test sale verde con el bug dentro
metadata:
  type: feedback
---

Un XCUITest que cierra una hoja apilada deslizando desde `app.navigationBars.firstMatch` agarra la barra de la hoja
de DEBAJO (en Ajustes, la de «Perfil», no la de «Detalles personales»). Medido el 2026-10-15 (lote 16): el test del
nombre que se perdía al deslizar salió VERDE con el arreglo quitado. Lo cazó el mutante, no la lectura.

**Why:** el árbol de accesibilidad conserva entera la hoja de fondo, y `firstMatch` devuelve la primera en el orden
del árbol, no la de arriba.

**How to apply:** para cerrar deslizando, arrastra desde una coordenada de la ventana (`app.coordinate(…dy: 0.09)`)
y afirma que un elemento de la hoja de arriba ha DESAPARECIDO antes de mirar el resultado. Y corre el mutante: un
test de gesto sin mutante no prueba nada. Relacionado: [[exists-no-implica-alcanzable]],
[[la-asercion-que-no-puede-fallar]].
