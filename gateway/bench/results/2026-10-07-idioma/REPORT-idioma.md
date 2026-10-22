# Insights, flujo de caja y desviaciones en el idioma de la app — banco del 2026-10-07

Vuelve a medir las tres tareas de Insights después de que sus prompts pidan el idioma de la app. Tickets
`insights-cashflow-and-deviation-prompts-do-not-ask-for-the-language` y `ai-comments-ignore-the-app-language`. Informe
anterior: `../2026-10-07/REPORT-insights-y-tendencias.md`. Gasto: 0,018 USD.

## Resultado

Solo la fila activa de cada tarea (`gateway/src/ai/routes.ts`), los mismos casos de la sesión 2 (14 locales) y 2
repeticiones.

| Tarea | Fila | Acierto antes → ahora | Sin idioma antes → ahora | Idioma mal | JSON |
|---|---|---|---|---|---|
| `insights.cashflow` | `gpt-6-luna` none | 25,0 % → **100 %** | 100 % → 100 % | 0 de 28 | 100 % |
| `insights.deviation` | `gpt-6-luna` none | 21,4 % → **100 %** | ~100 % → 100 % | 0 de 28 | 100 % |
| `insights.cards` | `gpt-6-luna` low | 90,6 % → **100 %** | 96,9 % → 100 % | 0 de 32 | 100 % |

- El acierto de las tarjetas es con la revisión manual de cifras (`insights.flagged-review.json`): el verificador marcó
  4 y las 4 son derivadas (una resta y tres sumas de porcentajes del payload, el mismo caso que en la sesión 2). Ninguna
  inventada.
- La latencia de esta pasada no vale: corrió en paralelo. Una muestra en serie de 3 tarjetas dio p50 7,2 s, la misma de
  la sesión 2 (7,2 s).

## Qué cambió en los prompts

1. **La línea de idioma**, compartida por los tres (`InsightsLLMService.languageInstruction`): pide el idioma de la app
   (`AIPromptLanguage.current`, de `AppLocale`) aunque las instrucciones estén en español, y que no copie palabras de
   ellas.
2. **El idioma con nombre y código** («italiano (it)», `AIPromptLanguage.label`). Con el código solo, «Responde SIEMPRE
   en it» sacó un caso en español: dentro de una frase en español «it» y «de» se leen como palabras.
3. **Las reglas ya no citan «gasto» e «ingreso» entre comillas.** Con la cita, el modelo las copiaba en otros idiomas:
   «Coffee gasto was **$ 4** over plan», «dein gasto € 270». Ahora dicen «Habla de gastos e ingresos, nunca de
   transacciones».
4. **El trato por idioma** (`AIPromptLanguage.informalRegister`, la tabla del chat): «du», «tu», «você» en vez de
   «Tutea ("tú")».

Las dos primeras versiones del arreglo se midieron y se descartaron por los puntos 2 y 3 (85,7 % y 96,4 % en
desviaciones); no se guardan.

## Ejemplos (repetición 0)

- en: «Your cash flow stays positive for all **6 months**, with a projected balance of $ 3,950 in Jan 2027.»
- de: «Restaurants lagen **€ 270** über deinem Plan; auch Kleidung überschritt ihn um € 140 – prüfe, ob du dort künftig
  etwas reduzieren möchtest.»
- it: «Bar e Benzina superano il piano di **€ 95** in totale: puoi rivedere queste due spese.»
- ja: «12か月すべて収支はプラスで、2027年9月末の残高は**¥ 2,386,000**の見込みです。»

## Lo que no se midió

Los otros candidatos (la fila no cambia y su elección no dependía del idioma); Tendencias (ya daba 100 % y su prompt no
se tocó); el juez; los nombres de mes de iOS (el banco usa `Intl`).
