---
id: trends-prompt-asks-the-language-by-bare-code
status: backlog
priority: very-low
area: insights, ai, l10n
created: 2026-10-07
updated: 2026-10-08
source: sesión de idioma de Insights (gateway/bench/results/2026-10-07-idioma/REPORT-idioma.md)
---

# El resumen de Tendencias pide el idioma solo con el código y cita «gasto» entre comillas

## Qué le pasa al usuario

Hoy nada visible: el banco del 2026-10-07 le da 100 % de idioma a la fila activa (`gpt-6.1-sol`). Pero su prompt tiene las
dos formas que en Insights sacaban respuestas en el idioma equivocado con modelos más pequeños: «Responde SIEMPRE en
\(input.locale)» con el código solo (en Insights, «en it» salió en español) y la regla `Usa "gasto" o "ingreso"`, que los
modelos copiaban tal cual («Dein Gasto», «gasto oscylował» en la sesión 2). Si la fila baja a un modelo más barato, vuelve.

## Qué hacer

En `TrendsAIService.systemPrompt`, usar `InsightsLLMService.languageInstruction` (o `AIPromptLanguage.label`) y la regla de
vocabulario sin comillas, como Insights (`.claude/rules/ai-gateway.md`, «El idioma de la respuesta»). Cambiar el marcador del
banco (`trendsSystemPrompt` en `gateway/bench/lib/insightsRequests.ts`) y volver a correr `trends.summary`.

## Hecho cuando

- `trends.summary` sigue al 100 % con la fila activa y sube con `gpt-6-luna` none (68,8 % en la sesión 2).

## Medido en 2.1 (triage 2026-10-08)

- `TrendsAIService.systemPrompt` sigue con «Responde SIEMPRE en \(input.locale)» (`:285`) y «Usa "gasto" o "ingreso"» (`:291`); no usa `InsightsLLMService.languageInstruction` ni `AIPromptLanguage`.

Triage 2026-10-08: abierto · low → very-low · el prompt sigue igual, pero hoy no se ve nada (100 % de idioma con el modelo activo) y solo mordería si se baja de modelo.

## Medido con Claude (banco del 2026-10-08)

Con Claude sí muerde, y es lo que deja fuera a Anthropic en Tendencias (`docs/ai-model-bench-2026-10-claude.md`):
Sonnet 5.5 contesta entero en español a `t05-en-GB-week` y `t08-fr-previous-zero`, y escribe «Dein Gasto», «Ingreso» o
«aucun gasto» en otros casos. Acierto 84,4 %; sin contar el idioma, 96,9 %. Haiku 5.5 falla el idioma en 7 a 9 de 32.
`gpt-6.1-sol` y Gemini 3.8 Flash, con el mismo prompt, no tropiezan. Si algún día se quiere a Anthropic de relevo en
Tendencias, este ticket va primero.

## Visto también (2026-10-09)

- El mismo prompt fija el trato en español: «Tutea al usuario» (`TrendsAIService.swift:288`). Insights, el flujo de caja y
  las desviaciones ya piden el trato de cada idioma con `AIPromptLanguage.informalRegister` (ticket
  `ai-comments-ignore-the-app-language`). Al arreglar este ticket, que Tendencias use lo mismo.
