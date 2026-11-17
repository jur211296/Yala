---
id: 2026-11-16-web-gasto-de-grupo-en-el-total-del-dia
status: backlog
priority: low
area: web
created: 2026-11-16
updated: 2026-11-16
source: hallazgo del lote 4 de «Yala web como la app»
---
# Yala web: ¿el total de cada día cuenta «mi parte» de un gasto de grupo, como la app?

La cabecera de cada día de Registros en la web suma los gastos con el importe que manda `/api/registros`
(`webapp/src/client/app/registro.ts`, `gastadoDelDia`). La app suma con `DailySpendingCalculator.dayTotals`, que aplica
el ajuste de Grupos (`statsAdjustment`: «mi parte» y las patas que se suprimen). No se midió si el importe que manda el
núcleo para la fila de un gasto de grupo ya es esa parte.

Qué hacer: con un gasto de grupo de prueba (pagado por mí, repartido entre tres), comparar el total del día en la app y
en la web. Si difieren, decidir si el núcleo manda la parte o si la web no suma esas filas.
