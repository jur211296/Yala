---
id: 2026-11-26-eficiencia-2-animaciones-solo-visibles
status: done
priority: high
area: "rendimiento, panel, animaciones"
created: 2026-11-26
updated: 2026-11-26
source: "plan de eficiencia del análisis de calentamiento en el iPhone 14 (docs/qa/rendimiento-iphone14-2026-11-26/README.md, lote 2)"
---

# Sin animaciones infinitas fuera de la vista

Con Yala abierta y quieta, el iPhone 14 gastaba el 35-38 % de un núcleo en todas las pantallas. El pulso del punto
«Hoy» de la gráfica de tendencia latía sin fin, también con el Panel oculto detrás de otra pestaña, y obligaba a
repintar la app en cada fotograma.

## Hecho cuando

- El pulso da dos latidos y se queda quieto, y solo con la gráfica a la vista.
- Ninguna animación sin fin corre con su pestaña oculta o la app inactiva, y un test lo prohíbe.
- Lo que VoiceOver dice de la gráfica sale fuera del `body`.
- Reposo medido en el iPhone 14 por debajo del 2 %.

## Resolución (2026-11-26)

- `animaSoloVisible(_:si:)` (`Yala/App/Logic/AnimacionesVisibles/`): enciende la animación solo con la vista montada,
  `\.isRootPageShown` y la escena activa; apagar no se anima. Lo usan la tendencia, el esqueleto, el menú del botón
  flotante, la chispa de Pro, la foto leyéndose de Grupos y el orbe de voz.
- El pulso pasa a `repeatCount(2)`; vuelve a latir dos veces al reaparecer la página.
- `SpokenTrend` precalcula el resumen y los puntos para VoiceOver cuando cambian los datos.
- Pin: `YalaTests/EficienciaAnimacionesVisibles/` (barrido de `repeatForever`, con dos mutantes que lo ponen en rojo).
- Medido en el iPhone 14, mismo almacén de 16.004 movimientos: reposo de 35-38 % a 0,0-0,4 % del hilo principal en
  Panel, Registros y Más; impacto de CPU en reposo de 1,87 a 0,03 (Power Profiler). Datos en
  `docs/qa/rendimiento-iphone14-2026-11-26/despues-eficiencia-2-animaciones-solo-visibles/`.
- Fuera: la foto leyéndose de la entrada por imagen y la escucha de voz del registro (fuera del `toca:` del lote; en
  hojas, sin coste en reposo) quedan como excepciones con motivo en el barrido.
