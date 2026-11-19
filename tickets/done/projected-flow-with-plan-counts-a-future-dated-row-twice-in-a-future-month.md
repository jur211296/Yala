---
id: projected-flow-with-plan-counts-a-future-dated-row-twice-in-a-future-month
status: done
priority: medium
area: estadisticas
created: 2026-11-10
updated: 2026-11-18
source: review adversarial del lote 02 de mejoras necesarias de 2.3 (PR del lote)
---
# Con plan, un gasto ya fechado en un mes futuro se proyecta dos veces

**Qué ve la persona.** Con plan de flujo de caja, «Ver proyectado» (Tendencias, Panel, widgets) con un horizonte que
llega a un mes que aún no empezó —«Este año»— cuenta dos veces un movimiento ya fechado en ese mes si una línea del plan
lo cubre. Ejemplo inferido: línea «Comida» de 900 y un gasto de 100 fechado el 10-dic ⇒ diciembre proyecta 1.000 en vez
de 900.

**Por qué (leído en el código, no medido con un test).** `ProjectedFlowBuilder.planRemaining` resta de cada línea su
`realAmount`, y `CashFlowProjectionCalculator` solo lo calcula en meses pasados o en curso
(`if isPast || isCurrent`, ~línea 323). En un mes futuro la línea aporta lo planeado entero, y además
`ProjectedFlowBuilder.futureDatedFlows` pinta ese movimiento en su día.

**Contexto.** El lote 02 hizo que el lado del ritmo (sin plan, y lo que el plan no cubre) descuente «lo que el mes ya
tiene», también lo fechado por delante. Con esto, los dos caminos discrepan en este caso.

**Para cerrarlo.** Un test con plan, horizonte a diciembre y un gasto cubierto fechado en diciembre, que fije 900; luego
descontar lo ya fechado del mes futuro en `planRemaining` (o que el calculador del plan lo cuente como real en meses
futuros, mirando antes qué más lee `realAmount`).

## Cerrado (2026-11-18, S1 del replanteo del flujo de caja)

El motor del mes (`FlujoMotorMes`) calcula lo que falta de cada línea como límite − real − fechado − pendiente, en el
mes en curso y en los que vienen, y `ProjectedFlowBuilder.planRemaining` lo pide a ese motor: lo fechado entra una vez,
dentro de su línea. Lo fija `FlujoMotorMesTests.loFechadoEnUnMesQueVieneEntraUnaVezDentroDeSuLinea` (ocio de diciembre:
300, no 300 + 150).

**S6 (2026-11-18):** sin plan, o con filtros, el mismo motor sin líneas: lo fechado de un mes que viene descuenta de lo
que le falta a «otros» y se pinta una vez, en su día. Lo fija `FlujoConsumidoresParidadTests.sinPlan_loFechadoEntraUnaVez`.
