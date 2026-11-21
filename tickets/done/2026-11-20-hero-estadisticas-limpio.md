---
id: 2026-11-20-hero-estadisticas-limpio
status: done
priority: medium
area: "statistics, records"
created: 2026-11-20
updated: 2026-11-20
source: "decisiones de Jürgen del 20-nov-2026 en su chat (encargo «Hero de Estadísticas limpios»)"
---

# Hero de Estadísticas limpio: «Tu dinero hoy» en todas las pestañas, sin «Te queda» ni líneas extra

Cada pestaña de Estadísticas enseñaba otra cifra en el mismo hueco: Distribución el saldo de todas las cuentas («Tu saldo
hoy») y Resumen, Tendencias y Registros ingresos − gastos del período («Te queda»). Jürgen: «te queda es un tercer número
que realmente no existe; confunde al usuario». Además el hero cargaba texto que sobraba («Ingresos» y «Gastos» sobre cada
monto, «X registros · Sigue así», «X categorías», la frase de la variación) y Distribución tenía un hero distinto, sin
flechas.

## Hecho cuando

- Las cuatro pestañas (y Registros) enseñan «Tu dinero hoy», la misma cifra que el Panel; «Tu dinero al cierre» con un
  período cerrado. Los estados de un solo lado no cambian.
- El hero es: la cifra con su rótulo y su «?», e ingresos y gastos con sus flechas. Nada más.
- Un solo hero para las cuatro pestañas, sin saltos de altura al deslizar.
- «Te queda» sale también del Sankey y del resumen en voz alta. La hoja del «?» explica lo que se ve.
- Textos nuevos en `HeroEstadisticas.strings` (16 idiomas); las claves sin uso, retiradas. Tests en
  `YalaTests/HeroEstadisticasLimpio/`.

## Resolución (2026-11-20)

- `StatsHeroView` (nuevo): el hero de las cuatro pestañas, sobre `SummaryHeaderStack`. Calcula «Tu dinero hoy» él mismo
  cuando cambia algo de lo que depende (recargas, cuentas, filtros de cuenta, preferencias), como el Panel.
- `StatsMoneyTodayLogic` (nuevo): la cifra con las piezas del Panel, en su orden (cuentas del saldo grande y, de ellas,
  las que cuentan como dinero). Con un período cerrado, el mismo cálculo con el corte en el último día del período.
- `StatsHeroCaption`: `.netPeriod` y `.accountsBalance` pasan a `.moneyToday`. `HeroClaroLogic` y la hoja del «?» igual.
- Sankey y voz: «Diferencia».
- Fuera: `RecordsMotivationalLogic`, `HeroFlowAmountCaption` y 18 claves de texto en los 16 idiomas. «Te queda» y
  «Te quedó» (`panel.hero.leftNow`/`leftPast`) se quedan: Yala web los enseña y los lee de los textos de la app.
- Distribución pinta sus flechas con el resumen del período de Resumen y Tendencias.

Decisiones menores tomadas sin consultar (en el Paso 0 del encargo): la cifra se ve aunque el período no tenga
movimientos (es un stock, como en el Panel); «Solo gastos» conserva la variación del gasto bajo la cifra; Distribución con
filtro de categoría sigue enseñando la suma de la tarta; el cierre usa el tipo de cambio de hoy.
