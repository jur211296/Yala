---
name: la-grafica-se-queda-el-gesto
description: Al conducir Estadísticas/Tendencias con axe, un swipe que empieza sobre una gráfica no desplaza (la gráfica lo usa para recorrer puntos); deslizar por el margen x=8. Y un aviso del sistema se captura en ráfaga.
metadata:
  type: feedback
---

Un `axe swipe` que empieza encima de una gráfica de Swift Charts (la curva de saldo de Tendencias, la del Panel)
no mueve el scroll: la gráfica se queda el gesto para recorrer sus puntos y la pantalla no cambia, sin error.
Desliza por el margen izquierdo (`--start-x 8`), fuera de las tarjetas. Para parar en una sección, desliza
despacio (`--duration 1.2+`): con duraciones cortas la inercia se pasa de largo (de y=367 a y=48 en un gesto).

Un aviso local (banner de «Probar recordatorio») dura ~5 s y una captura suelta tras el toque lo pierde:
**ráfaga** de `simctl io screenshot` cada 0,3 s y quedarse con el fotograma bueno; el texto largo se lee
recortando esa franja.

**Why:** lote 11 (2026-10-15) — tres tandas de capturas de variantes salieron idénticas al «antes» hasta ver
que los swipes caían en la gráfica; y dos intentos de capturar la prueba del informe salieron sin banner.

**How to apply:** al conducir a mano cualquier pantalla con gráficas, antes de culpar a la app comprueba con
`axe describe-ui` si la posición cambió. Relacionado: [[el-final-del-scroll-se-mide-hasta-que-para]].
