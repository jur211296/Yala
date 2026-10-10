---
id: ai-insights-error-card-shows-raw-english-errors
status: done
priority: medium
area: insights, ai, l10n
created: 2026-10-07
updated: 2026-10-09
source: revisión del uso de IA (docs/ai-usage-review-2026-10.md, hallazgo H2)
---

# La tarjeta de error de Insights muestra el error técnico en inglés

> **Grupo: autónomo.** Manejo de errores y copy. No cambia modelo ni proveedor.

## Qué le pasa al usuario

Si el análisis de IA de Insights falla, la tarjeta dice cosas como «Network error: The request timed
out.», «Rate limited — try again shortly» o «Failed to parse AI response», en inglés, sea cual sea el
idioma de la app. Si se agotó la cuota diaria del gateway (429 `yala_quota_daily`), el usuario ve
«Network error: …» en vez de «has llegado al límite de hoy».

## Lo medido (2026-10-07, en este árbol)

- `InsightsViewModel.swift:261`: `aiError = error.localizedDescription`.
- `InsightsLLMService.swift:38-48`: `errorDescription` devuelve literales en inglés sin localizar.
- `AIInsightCardComponents.errorCard` (`Yala/App/Views/Shared/AIInsightCardComponents.swift:33`) pinta
  ese texto tal cual; lo usan `InsightsTabView.swift:311` y `CategoriesTabView.swift:1130`.
- `ProxyErrorMapper.remap` solo existe para `ChatAssistantError`; Insights no lo usa.

## Qué hay que hacer

1. Tipar el error en el ViewModel (no un `String`) y elegir el copy en la vista, con claves de `L10n`.
2. Mapear `yala_quota_daily` / `yala_quota_burst` / `yala_pro_required` del gateway igual que el chat.
3. Revisar Tendencias (`TrendsAIViewModel`) con el mismo criterio.

## Hecho cuando

- Ningún camino de error de Insights pinta `localizedDescription`.
- Test: cada caso de `InsightsLLMError` y cada tipo del gateway produce su copy localizado.
- Paridad de l10n en verde con las claves nuevas en los siete idiomas.

## Hecho (2026-10-09)

- Si el análisis de IA de Resumen, Distribución o Tendencias falla, la tarjeta dice el motivo en el idioma de la app:
  sin conexión, tardó demasiado, cupo de hoy agotado («Agotaste tu cupo de análisis con IA de hoy. Vuelve mañana.»),
  demasiadas peticiones seguidas, no se pudo confirmar Yala Pro, o el genérico «Algo salió mal. Intenta de nuevo.».
- El ViewModel guarda el motivo (`AIInsightFailure`, en `Yala/App/Logic/AIInsightFailureLogic.swift`), no un texto; la
  vista lo traduce en `AIInsightCardComponents.message(for:)`. Se retiró el `errorCard(String)`, así que el compilador ya
  no deja pintar un `localizedDescription`. Los tipos del gateway se leen con `ProxyErrorMapper.gatewayType`, como el chat.
- Sin oferta de Pro: Insights no tiene cupo de prueba y `yala_pro_required` le llega a quien la app ya cree Pro.
- Tendencias, igual: `Phase.failed` lleva el motivo; sin red ahora dice «sin conexión» en vez del genérico.
- 4 claves nuevas `insights.aiError.*` en los 16 `.lproj`; `timeout` y `generic` reusan las del chat.
- Tests: `YalaTests/AIInsightFailureTests` (cada caso de `InsightsLLMError`, cada tipo del gateway, las claves en los
  16 idiomas, Tendencias, y source-scan sin `localizedDescription`). Control rojo: 4 mutantes, los 4 muertos.
- Simulador: antes «Network error: No se ha podido completar la operación. (Error de Yala.AppAttestError 2.)»; después
  «Algo salió mal. Intenta de nuevo.». El cupo agotado no se puede provocar en el simulador sin gastar el cupo real: lo
  fija el test con el sobre exacto del gateway.
- `ai-comments-ignore-the-app-language` se revisó y está entero en su alcance; no se tocó.
