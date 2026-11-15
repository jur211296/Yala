---
id: balance-chip-compares-against-the-day-after-in-the-previous-month
status: backlog
priority: low
area: "panel, statistics"
created: 2026-11-11
updated: 2026-11-11
source: "lote 2.3 · Panel día 1 y gráfica de saldo (decisión 11), 2026-11-11; encontrado al nombrar la fecha del chip"
---

# El chip de la gráfica de saldo compara con el día siguiente del mes anterior

Medido el 2026-11-11 en el simulador (iPhone 17 Pro, iOS 27.2, semilla `ficha`, reloj falso en el 20-nov-2026,
período «Este mes»): el chip dice «+3.6 % vs 21 oct». Desde la decisión 11 el chip nombra su fecha, y la fecha es la
del punto que ya usaba el porcentaje: `DateAlignmentHelper.alignedPreviousTotal` recorta la curva anterior al dominio
de la actual **con un día de margen a cada lado** (`currentDataDomain`, ±1 día), así que el 20 de noviembre compara
con el 21 de octubre, no con el 20.

No es nuevo: el % era el mismo antes; ahora se ve. El margen sirve a la curva superpuesta de la Comparativa
(`PeriodComparisonChartView`) y el total lo comparte a propósito (p20-15: «el KPI es el último punto visible de la
curva»), así que cambiarlo toca las dos y los tests de `DateAlignmentHelperTests`.

Hecho cuando el chip del 20 compare con el 20 del mes anterior (o se decida que el día de margen se queda y el texto lo
asume).
