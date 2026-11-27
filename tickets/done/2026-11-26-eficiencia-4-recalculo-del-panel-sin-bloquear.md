---
id: 2026-11-26-eficiencia-4-recalculo-del-panel-sin-bloquear
status: done
priority: high
area: "performance, panel, presupuestos, salud financiera"
created: 2026-11-26
updated: 2026-11-26
source: "pedido de Jürgen del 26-nov-2026, 10:44 Lima («encola los 6 lotes de mejoras de eficiencia de la sesión del calor»), lote 4 del informe docs/qa/rendimiento-iphone14-2026-11-26/"
---

# El recálculo del Panel deja de bloquear

Cada recálculo del Panel (al arrancar, con datos nuevos, al cambiar un filtro) ocupaba el hilo principal de 7 a 9 s con
16 k movimientos en el iPhone 14, en bloques de hasta 3,7 s en los que la app no respondía. Lo caro eran recorridos
repetidos del historial entero: cada presupuesto (dos veces), cada ciclo de presupuesto de la nota de salud, sus alertas
y los filtros de la tendencia.

## Hecho cuando

- El cálculo cede el hilo dentro de cada etapa, no solo entre etapas, y se abandona si la app se va.
- Presupuestos, nota de salud y gastos por cuenta no recorren el historial entero por cada presupuesto o ciclo.
- El ritmo de la nota no ordena todos los movimientos.
- Las cifras del Panel, presupuestos, salud financiera y gastos por cuenta quedan idénticas (pruebas viejo contra nuevo).
- Medido antes y después en el iPhone 14 con el almacén de 16 k.

## Resolución (2026-11-26)

- `Logic/RecalculoPanel/`: `IndiceFechasMovimientos` (índice por fecha armado una vez por recálculo; devuelve los
  movimientos de un intervalo en el orden original), `CesionDelHilo` (cede cada ~25 ms y corta si el cálculo ya no
  sigue) y `MarcasRecalculoPanel` (`os_signpost` «Panel.performCalculation» y por etapa; `PERF panel-calculo` en DEBUG).
- `PanelViewModel.performCalculationInStages`: etapa del índice; tendencia con sus cuatro recorridos del historial por
  trozos y cesión entre widgets; presupuestos por el índice; nota de salud por partes (`FinancialScoreCalculator.plan`);
  gastos por cuenta por el índice. Un guardado que deja borrados movimientos del cálculo lo corta y pide la recarga.
- `FinancialScoreCalculator` y `FinancialScoreAlertsLogic`: índice opcional; ritmo desde los días con registro.
- Medido (`docs/qa/rendimiento-iphone14-2026-11-26/despues-eficiencia-4-recalculo-del-panel-sin-bloquear/`): bloqueos del
  Panel en el arranque de 16,7 s (máx. 3,7 s) a 5,3 s (máx. 0,95 s); recálculo en caliente de ~7,7 s a ~4,5 s.
- Pruebas: `YalaTests/EficienciaRecalculoPanel/` (paridad viejo/nuevo con 6.000 movimientos en cinco períodos, índice,
  cesión, cableado, corte por borrado). Mutante del extremo del intervalo cazado.

## Pendiente

- La proyección del saldo sigue siendo un bloque de ~0,9 s (`ProjectedFlowBuilder` → `FlujoMotorMesEntrada.movimientos`).
- El Panel termina ~4 s más tarde en el arranque en frío porque ya no bloquea al resto (widgets, Spotlight).
