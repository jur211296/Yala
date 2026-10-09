---
id: chat-compares-with-the-month-in-progress
status: done
priority: medium
area: chat, ai, statistics
created: 2026-10-07
updated: 2026-10-09
source: banco de chat.answer (sesión 2 del gateway de IA, gateway/bench/results/2026-10-07/REPORT-chat-y-nota.md)
---

# Yala IA compara el mes en curso con el mes pasado entero

## Qué le pasa al usuario

Pregunta a mitad de mes «¿gasto más que el mes pasado?» y le responde que gasta menos, porque compara lo que lleva del
mes con el mes pasado completo.

## Lo medido (2026-10-07)

- El contexto de `FullFinancialContextBuilder` no trae «el mes pasado hasta el mismo día». Es la mayor fuente de
  respuestas equivocadas del banco (las cinco malas de la muestra a mano, «Yes… less»).
- La app ya resuelve esa comparación en Tendencias (MTD contra MTD).

## Hecho cuando

- El contexto lleva el mes pasado hasta el día equivalente y el prompt dice cuándo usarlo.
- Caso del banco a mitad de mes que hoy falla y pasa.

## Hecho (2026-10-09, encargo `chat-context-archived-accounts-and-mtd`)

- El contexto lleva `periods.last_month_to_date` (el mes pasado hasta el final del día equivalente a hoy) y cada
  categoría, subcategoría y comercio su `total_last_month_to_date`. La variación precalculada se compara con ese total y
  se renombró `variation_percent_vs_last_month_to_date`: hasta hoy comparaba con el mes entero y el modelo la citaba tal
  cual. `last_month` y `total_last_month` siguen siendo el mes entero.
- La alineación es la del hero de Tendencias (`DateAlignmentHelper.alignedPreviousInterval`) con el `-1 s` en el
  extremo (`FullFinancialContextBuilder.lastMonthToDateInterval`). El helper cuenta la medianoche del día siguiente en
  los heros: `aligned-previous-interval-counts-the-next-midnight`.
- El prompt vive en la app (`ChatAssistantService.buildSystemPromptStatic`): regla `7b` y el ejemplo de Bus, que
  enseñaba a comparar con el mes entero. No se renumeró la 16/17: el banco las busca literalmente.
- Tests: `ChatContextPanelParityAndMonthToDateTests` (día 15, día 1 a medianoche y a media mañana, 31 frente a 30,
  29-31 de marzo frente a febrero, febrero bisiesto, medianoche del día siguiente, variaciones, y que la regla del
  prompt nombre las claves que serializa el contexto). Controles rojos: sin el `-1 s`, variación contra el mes entero
  y sin el tramo (ver el PR).
- **Banco: no se corrió (sin presupuesto de API).** La réplica TS (`gateway/bench/lib/chatContext.ts`) ya trae los
  campos, `npm test` del gateway pasa en local, y los casos de comparación esperan ahora la cifra hasta el mismo día:
  `us-01-month-vs-last` y `pl-01-month-vs-last` (`periods.last_month_to_date.expense`), `fr-02-sub-vs-last` y
  `es-01-sub-vs-last` (`total_last_month_to_date`). Medido en la réplica: en `us` (18-oct) lo que va de octubre es 1993,
  septiembre hasta el 18 es 1993 y septiembre entero 2070; la respuesta buena es «igual», no «menos».
- **Cuando haya presupuesto:** `cd gateway && npm run bench -- --task chat.answer --cases
  us-01-month-vs-last,pl-01-month-vs-last,fr-02-sub-vs-last,es-01-sub-vs-last,de-02-month-vs-last,ar-03-followup,us-03-followup`
  (con `--only` el modelo de la fila `chat.answer` de `gateway/src/ai/routes.ts`, para no pagar todos los candidatos).
  Los cuatro primeros comparan el mes en curso y deben citar la cifra hasta el mismo día; los tres últimos preguntan
  por el mes pasado en sí y tienen que seguir citando el mes entero.
- Sin device-QA: el cambio no se ve en pantalla.
