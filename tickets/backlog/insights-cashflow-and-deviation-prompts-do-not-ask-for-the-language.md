---
id: insights-cashflow-and-deviation-prompts-do-not-ask-for-the-language
status: backlog
priority: high
area: insights, ai, l10n
created: 2026-10-07
updated: 2026-10-07
source: banco de Insights (sesión 2 del gateway de IA, gateway/bench/results/2026-10-07/REPORT-insights-y-tendencias.md)
---

# Los comentarios del flujo de caja y de las desviaciones salen en español a quien no habla español

## Qué le pasa al usuario

Con Yala en inglés, alemán, japonés o cualquier idioma que no sea español, el comentario de la IA bajo el flujo de caja
y el de las desviaciones del plan sale casi siempre en español.

## Lo medido (2026-10-07)

- Los prompts de `InsightsLLMService.generateCashFlowInsight` y `generateDeviationInsight` no dicen en qué idioma
  contestar. Con todos los modelos del banco, el acierto con el idioma se queda entre el 21 y el 57 %; sin contar el
  idioma, todos aciertan el 100 %. Le pasa también a `gpt-4.1-mini`, el modelo de hasta hoy.
- El vocabulario del prompt español se cuela en otros idiomas en las tarjetas y Tendencias: «Dein Gasto», «gasto
  oscylował», «ingressos».

## Qué hacer

Añadir a los dos prompts `IDIOMA: Responde SIEMPRE en \(locale)` (con `AppLocale.current.identifier`, como el resto) y
volver a correr `npm run bench -- --task insights.cashflow,insights.deviation`: el banco lee el prompt del Swift solo.

## Hecho cuando

- Los dos comentarios salen en el idioma de la app en los 14 locales del banco, sin bajar del 100 % sin idioma.
