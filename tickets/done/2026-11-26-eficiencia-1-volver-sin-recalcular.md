---
id: 2026-11-26-eficiencia-1-volver-sin-recalcular
status: done
priority: high
area: "performance, panel, statistics, records, groups, reports, spotlight"
created: 2026-11-26
updated: 2026-11-26
source: "pedido de Jürgen del 26-nov-2026, 10:44 Lima («encola los 6 lotes de mejoras de eficiencia de la sesión del calor»), lote 1 del informe docs/qa/rendimiento-iphone14-2026-11-26/"
---

# Volver a Yala no recalcula lo que no cambió

Al ir a otra app y volver, Yala recargaba y recalculaba el Panel, Estadísticas, Registros, Grupos, el detalle de grupo e
Informes, aunque nada hubiera cambiado y aunque la pantalla estuviera oculta detrás de otra pestaña, y reindexaba
Spotlight en cada vuelta. Con 16 k movimientos, el teléfono se calentaba y el scroll se congelaba 9-25 s tras volver.

## Hecho cuando

- Al volver, cada pantalla a la vista solo recalcula si cambió su firma (un guardado, `dataVersion`, el día, trabajo que
  el freno cortó con la app fuera); oculta, no calcula y lo hace al aparecer.
- Spotlight solo se reconcilia al volver si cambió algo desde la última reconciliación.
- Un test de cableado prohíbe recargar a pelo dentro de un `onChange(of: scenePhase)`.
- Medido antes y después en el iPhone 14 con el almacén de 16 k.

## Resolución (2026-11-26)

- `Yala/App/Logic/FrescuraAlVolver/`: `VueltaAPrimerPlano` (suelta el freno y, con la página a la vista, comprueba la
  firma una vuelta del main actor después), `FrescuraAlVolver` (firma al irse para Registros, Grupos y el detalle de
  grupo) y `SpotlightAlVolver`.
- Panel: `reloadOnAppearIfStale()` en vez de `reloadAndRecalculate()`; el freno apunta en `hasInterruptedWork` lo que
  descarta o corta con la app fuera. Estadísticas: `requestCalculationOnEntry()`. Informes: la frescura de la
  Comparativa. Grupos y detalle: `RecalculationDebouncer.hasUnfinishedWork`.
- Pruebas: `YalaTests/EficienciaVolverSinRecalcular/` (lógica, Panel con almacén y cableado; mutantes comprobados).
- Medición en el iPhone 14: `docs/qa/rendimiento-iphone14-2026-11-26/despues-eficiencia-1-volver-sin-recalcular/`.
  Tras cada vuelta (ciclos 2-10): bloque con el hilo ≥ 90 % de 9 s a 0 s, CPU en 20 s de 11,5 s a 2,9 s (mediana),
  cuelgues con Yala delante de uno de ~7,5 s por vuelta a ninguno, 0 recálculos del Panel al volver.

## Fuera de este lote

- «Tirar para actualizar» sigue costando un recálculo completo del Panel (~7,5 s): lote 4.
- La foto de los widgets al irse (~280 ms por salida) y los dos cálculos del arranque en frío: no son de este lote.
