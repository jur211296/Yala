---
id: ai-responses-use-json-object-not-a-strict-schema
status: backlog
priority: low
area: ai, chat, insights, image
created: 2026-10-07
updated: 2026-10-08
source: revisión del uso de IA (docs/ai-usage-review-2026-10.md, hallazgo H6)
---

# Las respuestas de IA piden «un JSON», no «este JSON»

> **Grupo: autónomo.** Estructura de respuesta. No cambia modelo ni proveedor.

## Qué pasa

Seis llamadas usan `responseFormat: .jsonObject`: el clasificador de intención, la imagen, Insights (4
variantes), Tendencias, las sugerencias del chat y su reescritor. Con `json_object` el modelo garantiza
JSON válido, pero **no la forma**: un campo que falta o un tipo distinto se descubren al parsear, y el
código lo compensa con valores por defecto silenciosos (p. ej. `confidence` ausente → 0 en
`ChatIntentClassifierService.parseClassificationJSON`; `icon` ausente → `"sparkles"` en Insights).

El caso de mayor riesgo, el parser de voz sin modo JSON, tiene su propio ticket:
`voice-parser-sends-no-json-mode`.

## Lo medido (2026-10-07, en este árbol)

`grep -rn "responseFormat: .jsonObject" Yala` → ChatIntentClassifierService.swift:90,
ImageVisionService.swift:170, InsightsLLMService.swift:230/529/615/759, TrendsAIService.swift:124,
ChatSuggestionsLLMService.swift:150, SuggestionsRewriterService.swift:222. El SDK 0.4.7 soporta
`.jsonSchema` con `strict`.

## Qué hay que hacer

1. Un esquema estricto por respuesta, con `enum` donde el dominio es cerrado: `intent`
   (`ask|register|ambiguous`), `imageType` (`single|list|receipt|unknown`), `sentiment`
   (`positive|neutral|attention`), `chart` de Tendencias.
2. El icono de Insights: elegirlo de una lista cerrada en el esquema, porque un SF Symbol inventado se
   pinta vacío (`InsightCard.swift:27` lo usa tal cual con `Image(systemName:)`).
3. Decodificar con `Codable` en vez de `JSONSerialization` + casts donde el esquema ya lo garantiza.

## Hecho cuando

- Cada `ChatQuery` de la lista lleva su `json_schema` estricto (test por servicio).
- Ningún icono de Insights sale de fuera de la lista cerrada.

## Medido en 2.1 (triage 2026-10-08)

- Siguen 8 `responseFormat: .jsonObject` y ningún `jsonSchema` en `Yala/`: `ChatIntentClassifierService.swift:90`, `ImageVisionService.swift:216`, `InsightsLLMService.swift:235/510/669` (tres, no cuatro), `TrendsAIService.swift:124`, `ChatSuggestionsLLMService.swift:150`, `SuggestionsRewriterService.swift:222`.

Triage 2026-10-08: abierto · low → low · ninguna llamada ha pasado a esquema estricto; robustez, sin datos en riesgo.
