---
id: insights-and-trends-payload-labels-mislead-the-model
status: backlog
priority: low
area: insights, trends, ai
created: 2026-10-07
updated: 2026-10-07
source: banco de Insights y Tendencias (sesión 2 del gateway de IA, gateway/bench/results/2026-10-07/REPORT-insights-y-tendencias.md)
---

# Tres etiquetas de los datos que la app manda a la IA llevan a error

## Lo medido (2026-10-07)

1. **`monthsPositive` y `monthsNegative` cuentan el saldo ACUMULADO**, y los modelos lo leen como flujo del mes («flujo
   positivo los 6 meses»). Conviene renombrarlo (`monthsWithPositiveBalance`) o mandar el flujo.
2. **La etiqueta de mes «Sept 26» / «9月 26»** se lee como el día 26. Mejor «sep 2026» o el año con cuatro cifras.
3. **El enfoque de Tendencias menciona «cards» y «hero»**, que no existen en esa pantalla.

## Hecho cuando

- Las tres etiquetas cambiadas y `npm run bench -- --task insights.cards,trends.summary` igual o mejor que el 2026-10-07.
