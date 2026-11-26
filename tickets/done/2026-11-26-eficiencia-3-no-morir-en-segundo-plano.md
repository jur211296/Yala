---
id: 2026-11-26-eficiencia-3-no-morir-en-segundo-plano
status: done
priority: high
area: "performance, panel, widgets, spotlight"
created: 2026-11-26
updated: 2026-11-26
source: "pedido de Jürgen del 26-nov-2026, 10:44 Lima («encola los 6 lotes de mejoras de eficiencia de la sesión del calor»), lote 3 del informe docs/qa/rendimiento-iphone14-2026-11-26/"
---

# Yala no muere en segundo plano

Quien abría Yala y se iba a otra app a los pocos segundos la encontraba cerrada al volver: iOS la mataba en segundo
plano (`0x8BADF00D`) porque el hilo principal seguía ocupado con el cálculo del Panel y, detrás, con la foto de los
widgets. Con 16 k movimientos en el iPhone 14, abrir en frío y salir a los 3 s la cerraba 4 de cada 5 veces.

## Hecho cuando

- Al pasar a segundo plano, el cálculo del Panel en vuelo se corta y la reconciliación de Spotlight también.
- La foto de los widgets al irse no ocupa el hilo de una vez.
- Spotlight lee por tramos, fuera del contexto de la app.
- Tirar para actualizar no recalcula si nada cambió.
- Medido antes y después en el iPhone 14 con el almacén de 16 k: cero cierres del vigilante.

## Resolución (2026-11-26)

- `PanelViewModel.performCalculationInStages`: cinco etapas con pausa de 1 ms; entre una y otra mira cancelación, freno,
  primer plano y almacén. Lo cortado queda en `hasInterruptedWork`; lo pedido a medias corre detrás.
  `refreshIfStale()` para tirar para actualizar.
- `WidgetDataCache.flushPendingUpdate`: al irse, la foto sigue por etapas con `beginBackgroundTask`.
- `SpotlightIndexService`: lectura por tramos de 1.000 en contextos propios, entradas y plan fuera del hilo principal,
  corte al pasar a segundo plano (`ReconcileSuspension`).
- Pruebas: `YalaTests/EficienciaSegundoPlano/` (con mutantes comprobados).
- Medición: `docs/qa/rendimiento-iphone14-2026-11-26/despues-eficiencia-3-no-morir-en-segundo-plano/`. Antes 4 de 5
  cierres en frío con salida rápida; después 0 de 5, y 0 en 10 ciclos en caliente. Tirar para actualizar sin cambios:
  de 5 recálculos completos a 0.

## Pendiente (de otros lotes)

- Arranque en frío hasta el Panel listo: sigue en ~11 s con 16 k (el objetivo de < 3 s es del lote 4).
- Spotlight entero fuera del hilo principal exige quitar el aislamiento al main actor de los modelos.
