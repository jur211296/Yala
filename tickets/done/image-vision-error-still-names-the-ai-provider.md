---
id: image-vision-error-still-names-the-ai-provider
status: done
priority: low
area: ai
created: 2026-10-21
updated: 2026-10-25
source: review del lote decidido 2.2 · 11 (fuera del lote)
---

# Un error de la foto todavía nombra al proveedor de IA

`ImageVisionService` (≈ línea 82) devuelve «OpenAI API key not configured» como `errorDescription`, en inglés. Si algún
camino enseña `localizedDescription` al usuario, la app nombra al proveedor, cuando la norma es decir «un servicio de IA»
(el único sitio que lo nombra es la política de privacidad). Solo pasa sin clave configurada (build mal firmado o de
desarrollo), así que es baja. No se midió si llega a pantalla.

## Resuelto (lote 12.4, 2026-10-25)

Medido: ninguna pantalla enseña `localizedDescription` de estos errores (`ImageEntryFlowLogic` y `VoiceEntryFlowLogic` los traducen a su propio copy), pero el texto va a logs y a cualquier camino futuro. No era uno: eran cuatro (`VisionError`, `InsightsLLMError`, `ParserError`, `TranscriptionError`) con el mismo «OpenAI API key not configured». Ahora «AI service not configured».
- Lo fija `AIErrorsDoNotNameTheProviderTests` (las 21 descripciones, sin «OpenAI» ni «GPT»).
