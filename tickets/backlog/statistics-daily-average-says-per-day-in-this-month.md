---
id: statistics-daily-average-says-per-day-in-this-month
status: backlog
priority: low
area: statistics, l10n
created: 2026-11-10
updated: 2026-11-10
source: lote 07 de mejoras necesarias 2.3 (Estadísticas, textos), encontrado al buscar todas las frases con el nombre del período
---

# Resumen dice «· por día en Este mes» bajo el promedio diario

El lote 07 sacó el nombre del período de tres frases donde se rompía («Probaste X este Este mes», «Tu período Este
mes…», «Este es tu primer Este mes con Yala»). Queda una de la misma familia, medida en código el 2026-11-10 en
`origin/2.3`:

- `InsightsTabView.swift:679`: `"· " + L10n.Stats.Insights.dailyAvgIn(trendsViewModel.detailPeriod.displayName)`, con
  `stats.insights.dailyAvgIn %@` = «por día en %@». Sale junto al chip de variación del promedio diario: «+5 % · por día en
  Este mes», «por día en Últimos 30 días». Los nombres de período son rótulos con mayúscula, no sustantivos.

No se tocó en el lote porque la frase no se rompe igual que las otras y cambiarla obliga a decidir qué dice el chip (la
variación del promedio diario frente al período anterior): es texto y significado a la vez.

Dos restos más, sin efecto en pantalla hoy (medido con `grep` en `Yala/App`):

- `stats.trends.insightTitleFree %@` y `stats.distribution.insightTitleFree %@` («Tu %@ en pocas palabras», «Tu %@ de un
  vistazo») tienen la misma forma y ninguna vista los usa. Si alguien los recupera, saldrían «Tu Este mes…».
- `insights.offlineCached` e `insights.offlineNoCache` no se pintan en ninguna pantalla. El lote 07 les quitó «insights»
  igual, en los 12 idiomas que la usaban.

## Qué haría falta

Reescribir «por día en %@» sin el período (la tarjeta ya está dentro del período elegido) en los 16 idiomas, con un test
como `PeriodNameStaysOutOfInsightSentencesTests`, y decidir si los dos títulos sin uso se retiran.
