---
id: projected-flow-with-plan-counts-a-future-dated-row-twice-in-a-future-month
status: backlog
priority: medium
area: estadisticas
created: 2026-11-10
updated: 2026-11-10
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
