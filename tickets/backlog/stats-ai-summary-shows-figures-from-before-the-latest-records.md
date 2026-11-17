---
id: stats-ai-summary-shows-figures-from-before-the-latest-records
status: backlog
area: statistics
priority: medium
created: 2026-11-16
updated: 2026-11-16
source: encargo 2026-11-16-hero-claro-estadisticas-registros-flujo (captura de Jürgen)
---

# El resumen con IA de Estadísticas cita cifras de antes de los últimos registros

## Qué pasa

En la captura de Jürgen del 16-nov, Estadísticas › Resumen decía:

- Hero: «Te queda S/ 18,484», con gastos S/ 12,376.
- Texto de IA, en la misma pantalla: gastos S/ 11,821 y saldo S/ 19,039.

Los ingresos cuadran al céntimo en las dos (18,484 + 12,376 = 19,039 + 11,821 = 30,860). Solo cambian los gastos, en
S/ 555: el texto se escribió antes de uno o dos gastos.

## Por qué pasa (medido en el código, no es un error de cálculo)

`StatsAIAutoRefreshLogic.decide` deja a la vista el texto guardado de la misma ranura (período y filtros) hasta que haya
un «cambio relevante»: ±3 registros (`relevantCountDelta`) o un total que se mueva un 10 % (`relevantTotalFraction`),
o hasta 24 h. S/ 555 sobre S/ 12,376 es un 4,5 %: por debajo del umbral, el texto viejo se queda. Es el diseño del
encargo `estadisticas-ia-automatica` (2026-11-03) para acotar el coste; la regla está en `.claude/rules/ai-gateway.md`.

## Qué decidir (Jürgen)

El texto viejo contradice al hero con números concretos, y eso resta confianza. Opciones:

- **A. Regenerar si cambia cualquier cifra que el texto cita** (ingresos, gastos, saldo del período). Más llamadas: rehacer
  la cuenta de coste de `ai-gateway.md` antes (hoy ≈ 0,005 USD por usuario y día).
- **B. Mantener el umbral, pero marcar el texto viejo**: «Escrito con tus datos de las 18:05 · Actualizar», sin cifras
  nuevas hasta que se regenere.
- **C. Bajar el umbral** (p. ej. ±1 registro o 2 %), con el mismo techo diario de 4 automáticas por página.

Recomendada: **B** (no cambia el coste y la pantalla deja de contradecirse sin aviso).

## Fuera de este encargo

El encargo del hero claro solo tocaba los heros; cambiar la regla de la IA es una decisión de coste y de producto, y
vive en `StatsAIAutoRefreshLogic` / `InsightsViewModel`, fuera de sus archivos.
