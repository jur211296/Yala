---
id: 2026-11-26-eficiencia-6-memoria-por-vuelta
status: done
priority: medium
area: "performance, memoria, panel, spotlight"
created: 2026-11-26
updated: 2026-11-27
source: "pedido de Jürgen del 26-nov-2026, 10:44 Lima («encola los 6 lotes de mejoras de eficiencia de la sesión del calor»), lote 6 del informe docs/qa/rendimiento-iphone14-2026-11-26/"
---

# La memoria deja de subir ~25 MiB por cada vuelta a Yala

El informe del iPhone 14 midió que la memoria de Yala subía ~25 MiB por cada vuelta a primer plano (238 → 363 MiB en 5
ciclos con 16.004 movimientos, y iOS la cerraba al sexto). Sospecha: las recargas completas del Panel y de Spotlight
dejaban vivas las filas de SwiftData.

## Hecho cuando

- Medido en el iPhone 14, 10 ciclos: memoria estable (± 10 MiB) tras el ciclo 2.
- Comprobado si una recarga completa deja filas vivas, en el Panel y en Spotlight.
- Lo que aparezca, corregido y fijado con un test de memoria por ciclo.
- Pasada final de todo el plan de eficiencia en el iPhone 14 con los guiones del informe.

## Resolución (2026-11-27)

- **No hubo nada que corregir en la app.** Con los lotes 1 a 5 dentro, la memoria al volver queda en 108 → 110 MiB en 10
  ciclos. Forzando la recarga completa del Panel y de Spotlight en cada vuelta (interruptor temporal solo en la copia de
  medición), 105-109 MiB del ciclo 2 al 10: las recargas no dejan filas vivas.
- Inferido, sin aislar en la build vieja: subía porque cada vuelta lanzaba el recálculo y la lectura de Spotlight de una
  vez en el hilo principal, con el ciclo anterior aún en vuelo. Los lotes 1, 3 y 4 quitaron las tres cosas.
- Test: `YalaTests/EficienciaMemoriaPorVuelta/MemoriaPorCicloTests` (Panel, Spotlight y control positivo de la fuga
  sospechada). Verificado con dos mutantes que retienen un contexto por recarga: los dos lo ponen rojo.
- Pasada final (vuelta, reposo, scroll, calor, cierres, energía, memoria) y cifras antes/después en
  `docs/qa/rendimiento-iphone14-2026-11-26/despues-eficiencia-6-memoria-por-vuelta/README.md`.

## Queda fuera

- Tirones de scroll: 1,6-2,0 por segundo en Panel y Registros (objetivo del lote 5: < 0,5). Casi todos son trabajo del
  hilo principal durante el gesto, no del render.
- El Panel sigue con mediana de 31 pasadas fuera de pantalla por fotograma (objetivo < 20).
- La proyección del saldo sigue ocupando el hilo ~0,9 s de una vez en cada recálculo (lote 4, «Lo que quedó fuera»).
