---
id: voice-parser-sends-no-json-mode
status: qa
priority: medium
area: voice, chat, ai
created: 2026-10-07
updated: 2026-10-09
source: revisión del uso de IA (docs/ai-usage-review-2026-10.md, hallazgo H5)
---

# El parser de voz y chat pide JSON solo por texto, y su prompt se contradice

> **Grupo: autónomo.** Estructura de respuesta y prompt. No cambia modelo ni proveedor.

## Qué le pasa al usuario

Cuando el modelo devuelve algo que no es JSON limpio, el registro por voz, por Siri o desde el chat
falla con un error genérico y el usuario tiene que repetir la frase. Hoy no se sabe con qué frecuencia
pasa: el gateway no registra nada (ver `gateway-does-not-record-ai-token-usage`).

## Lo medido (2026-10-07, en este árbol)

- `TranscriptionParserService.parseMultiple` (≈262-269) construye la `ChatQuery` **sin
  `responseFormat`**: ni `json_object` ni `json_schema`. Es el único servicio de IA de la app sin modo
  JSON. Lo usan la hoja de voz, el chat (rama «registrar») y el atajo de Siri (`QuickExpenseIntent`).
- `parseMultipleResponse` quita a mano vallas de markdown antes de decodificar.
- El prompt se contradice en tres sitios:
  - El esquema dice `"date": "YYYY-MM-DD"` y la regla «Sin mención de fecha → hoy»
    (`DateContextProvider.swift:54`), pero el tercer ejemplo devuelve `"date": null`.
  - El primer ejemplo pone la fecha de hoy y a la vez `"confidence": {"date": 0.0}`.
  - El tercer ejemplo propone `subcategoryHint: "Transporte"`, que no tiene por qué existir en la lista
    del usuario, contra la regla de elegir «ÚNICAMENTE de las subcategorías disponibles».
- El SDK del proyecto (MacPaw/OpenAI 0.4.7) ya soporta `responseFormat: .jsonSchema(...)` con `strict`
  (comprobado en `Sources/OpenAI/Public/Models/ChatQuery.swift` del tag 0.4.7).

## Qué hay que hacer

1. Pasar a `json_schema` con `strict: true`. En modo estricto todos los campos son obligatorios, así que
   los opcionales se declaran como `["string","null"]`.
2. Resolver las tres contradicciones: una sola regla de fecha, ejemplos coherentes con ella y ejemplos
   que no inventen subcategorías.
3. Mantener el limpiador de vallas mientras haya builds antiguas, o retirarlo si el modo estricto lo
   hace inalcanzable (decidirlo midiendo, no suponiendo).

## Hecho cuando

- Test: la `ChatQuery` del parser lleva `json_schema` estricto con todos los campos del DTO.
- Test de prompt: ningún ejemplo contradice la regla de fecha ni usa una subcategoría fuera de la lista.
- Los tests existentes de `parseMultipleResponse` siguen en verde.

## Hecho (2026-10-09)

- **Medido antes de tocar:** el `responseFormat` de la app no llega al modelo. La fila `text.parse` del gateway es
  `managed` y aplica su propio formato (era `"text"`). Por decisión de Jürgen (pregunta del 2026-10-09), el JSON estricto
  va en la fila: `responseFormat: "json_object"` + `jsonSchema: TEXT_PARSE_SCHEMA` + `strictSchema: true`, mismo modelo y
  esfuerzo. Alcanza también a las versiones instaladas, sin release. Desplegado a staging y producción (ver el PR).
- **La app manda igualmente `json_schema` estricto** (`TextParseResponseSchema`, todos los campos obligatorios, los
  opcionales como `[tipo, "null"]`), atado al del gateway por `schemaMatchesTheGateway`.
- **Prompt sin contradicciones:** una sola regla de fecha (siempre `YYYY-MM-DD`, hoy si no la dijo;
  `confidence.date` 1,0 si la dijo y 0,5 si no) y ejemplos coherentes con ella; las pistas de subcategoría de los
  ejemplos salen de la lista del usuario por palabras clave o son `null`.
- **Limpiador de vallas: se mantiene, decidido midiendo.** 5 de 528 respuestas históricas del banco traían vallas; con
  la fila estricta son 0 de 102 y son inalcanzables para todas las versiones, pero la fila se cambia sin release y con un
  formato de texto volverían. Queda escrito en el docblock de `parseMultipleResponse`.
- Banco: 100 % (102/102), cero respuestas que la app no lea. Tests: `TranscriptionParserCurrencyTests` (esquema, fila,
  fecha, subcategorías, los ejemplos se decodifican con el parser de la app) y los de `parseMultipleResponse`, verdes.

## Device-QA (Jürgen)

Lo cubre el guion de `voice-note-parser-prompt-knows-six-currencies`: si los cuatro pasos registran sin «no pude
entenderlo», el modo estricto funciona en producción.
