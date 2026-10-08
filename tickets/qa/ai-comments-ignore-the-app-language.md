---
id: ai-comments-ignore-the-app-language
status: qa
priority: medium
area: insights, ai
created: 2026-10-07
updated: 2026-10-07
qa-status: needs-testing
source: revisión del uso de IA (docs/ai-usage-review-2026-10.md, hallazgo H1)
---

# Los comentarios de IA de Insights y del flujo de caja no siguen el idioma de la app

> **Grupo: autónomo.** Bug de prompt y de payload. No cambia modelo ni proveedor.

## Qué le pasa al usuario

Un usuario con la app en inglés y la región del iPhone en Perú recibe el análisis de Insights en
español. Y los comentarios de una frase del flujo de caja (proyección y desviaciones) no llevan ninguna
instrucción de idioma: el prompt está escrito en español, así que lo esperable es que contesten en
español aunque la app esté en alemán. Esto último es **inferido**, no medido: no se llamó a la API.

## Lo medido (2026-10-07, en este árbol)

- `Yala/App/ViewModels/InsightsViewModel.swift:286` manda
  `"locale": Locale.current.language.languageCode`. Es la región de formato, no el idioma de la
  interfaz. El chat (`ChatAssistantService.swift:147-153`), las sugerencias
  (`ChatSuggestionsLLMService.swift:55-59`) y Tendencias (`TrendsTabView.swift:961`) ya usan
  `AppLocale`, y el chat deja escrito por qué `Locale.current` es un error.
- `InsightsLLMService.generateCashFlowInsight` (prompt en ≈596-609) y `generateDeviationInsight`
  (≈741-752) no reciben ni mencionan el idioma.
- Las tres instrucciones de «Tutea ("tú")» están fijas en español en los prompts de Insights; el chat sí
  adapta el registro por idioma (`du`, `tu`, `você`).

## Qué hay que hacer

1. Insights: pasar `AppLocale.current.identifier` (BCP-47) en lugar de `Locale.current…`.
2. Flujo de caja y desviaciones: recibir el idioma y añadir `IDIOMA: <idioma>` al prompt.
3. Registro de trato: reutilizar el switch por idioma del chat (`ChatAssistantService`, «Registro»).

## Hecho cuando

- Un test de payload fija que `InsightsViewModel` manda el idioma de `AppLocale`, no el de la región.
- Los prompts de flujo de caja y desviación contienen el idioma recibido (test de prompt puro).
- Device-QA: app en inglés con región Perú → Insights, flujo de caja y desviación salen en inglés.

## Hecho (2026-10-07)

- Insights, el flujo de caja y las desviaciones piden el idioma de la app (`AIPromptLanguage.current`, que sale de
  `AppLocale`), con nombre y código («italiano (it)») y el trato de ese idioma (`du`, `tu`, `você`). El código solo era
  ambiguo dentro de una frase en español: «Responde en it» sacó un caso en español en el banco.
- Las reglas ya no citan entre comillas «gasto» e «ingreso»: el modelo las copiaba tal cual («Coffee gasto was…»).
- Los nombres de mes del flujo de caja van en el idioma de la app, y las tres cachés llevan el idioma.
- Banco (`gateway/bench/results/2026-10-07-idioma/REPORT-idioma.md`, fila activa `gpt-6-luna`, 14 locales, 2 repeticiones):
  flujo de caja 25 → 100 %, desviaciones 21 → 100 %, tarjetas 91 → 100 %; 0 respuestas en otro idioma.
- Tests: `YalaTests/InsightsResponseLanguageTests` (la petición que sale de verdad, con el idioma de la app distinto del
  de la región; rojo con el código viejo).

## Guion de device-QA (Jürgen)

Hace falta Pro, el consentimiento de IA aceptado y red. Con un iPhone real, build de TestFlight.

1. Ajustes del iPhone → General → Idioma y región: deja la región en **Perú** e idioma del iPhone **Español**.
2. En Yala: Perfil → Ajustes → Idioma → **English**.
3. Estadísticas → pestaña **Insights**: el análisis de la IA (frase grande y tarjetas) tiene que salir en **inglés**.
4. Informes → **Flujo de caja** (con un plan creado) → abre las gráficas: el comentario de la IA bajo la proyección sale en
   **inglés**, y si te pasaste en alguna línea del plan, el comentario de desviaciones también.
5. Cambia el idioma de Yala a **Deutsch** y vuelve a abrir las dos pantallas: los comentarios salen en **alemán**, sin
   palabras sueltas en español («gasto», «presupuesto»). Antes de este arreglo, la caché devolvía el comentario viejo hasta
   24 h.
6. Devuelve Yala a «Idioma del sistema».
