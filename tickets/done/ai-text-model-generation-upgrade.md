---
id: ai-text-model-generation-upgrade
status: done
priority: medium
area: ai, cost
created: 2026-10-07
updated: 2026-10-07
source: revisión del uso de IA (docs/ai-usage-review-2026-10.md, hallazgo H16)
---

# ¿Seguir con `gpt-4.1-mini` o pasar a la generación nueva?

> **Grupo: para Jürgen.** Cambio de modelo con impacto en coste y en calidad. El caso urgente de
> `gpt-4.1-nano` va aparte: `gpt-4-1-nano-shuts-down-on-october-23`.

## Qué pasa

Ocho llamadas usan `gpt-4.1-mini`: el chat, el parser de voz/chat/Siri, los cuatro de Insights,
Tendencias y el reescritor de sugerencias. `gpt-4.1-mini` **no tiene fecha de apagado**, pero su ficha
recomienda «starting with GPT-5 Mini for more complex tasks»
(https://developers.openai.com/api/docs/models/gpt-4.1-mini, consultada 2026-10-07).

## Precios confirmados (USD por 1M tokens, https://developers.openai.com/api/docs/pricing, 2026-10-07)

| Modelo | Entrada | Entrada en caché | Salida | Estado |
|---|---|---|---|---|
| `gpt-4.1-mini` (hoy) | 0,40 | 0,10 | 1,60 | vigente |
| `gpt-6-luna` | 0,10 | 0,01 | 0,50 | vigente; «most efficient model for focused, high-volume tasks» |
| `gpt-5.6-luna` | 0,20 | 0,02 | 1,20 | vigente; equivale al nivel *nano* |
| `gpt-5.6-terra` | 2,00 | 0,20 | 12,00 | vigente; equivale al nivel *mini* |
| `gpt-5.4-mini` | 0,75 | 0,075 | 4,50 | vigente |
| Claude Haiku 4.5 (Anthropic) | 1,00 | — | 5,00 | https://platform.claude.com/docs/en/about-claude/pricing |
| Gemini 3.1 Flash-Lite (Google) | 0,25 | — | 1,50 | https://ai.google.dev/gemini-api/docs/pricing |

En la generación 5.6 y posteriores, **escribir** en la caché de prompts cuesta 1,25× la entrada, algo que
`gpt-4.1` no cobra (https://developers.openai.com/api/docs/guides/prompt-caching). Los modelos «luna» y
«terra» razonan por defecto (`medium`); para estas tareas habría que fijar `reasoning_effort: "none"` o
«low». Si aceptan `temperature` **no consta** en sus fichas.

## Coste estimado de hoy (cálculo propio, tokens **no medidos**)

Una pregunta del chat con ≈6 500 tokens de entrada (≈1 500 fijos + ≈5 000 de datos, supuesto) y ≈150 de
salida: ≈$0,003 con `gpt-4.1-mini`. Un usuario Pro en el tope de 75 preguntas al día: ≈$0,22/día. Con
`gpt-6-luna` la misma pregunta saldría ≈$0,0007 (−75 %). Estas cifras son orientativas hasta tener
`gateway-does-not-record-ai-token-usage`.

## Opciones

| | Qué se hace | A favor | En contra |
|---|---|---|---|
| **A** | Seguir con `gpt-4.1-mini` | Cero trabajo, comportamiento conocido, sin fecha de apagado | Pagar ≈4× por token frente a `gpt-6-luna`; quedarse en una generación que OpenAI ya no recomienda |
| **B** | Pasar a **`gpt-6-luna`** (`reasoning_effort: none`) las tareas acotadas: parser, Insights, Tendencias, reescritor. El chat, tras una evaluación propia | El más barato de la lista y el más nuevo. Soporta `json_schema` estricto | Modelo nuevo: hay que comparar calidad en un juego de pruebas propio (preguntas reales del chat, frases dictadas en seis idiomas). Su multiplicador de imagen no está publicado |
| **C** | Pasar a `gpt-5.6-luna` | Sustituto oficial de nano; precio intermedio | Más caro que B sin ventaja clara documentada |

Otros proveedores (Haiku, Gemini Flash-Lite) **no** salen más baratos que B y añaden un segundo
proveedor (claves, cuotas, privacidad, revisión del texto de consentimiento). No se recomiendan ahora.

## Recomendación

**B, en dos pasos y con datos.** Primero medir (`gateway-does-not-record-ai-token-usage`) y montar el
juego de pruebas; después mover las tareas acotadas; el chat, el último. Si el gateway elige el modelo
(`ai-model-choice-lives-in-the-app-binary`), B se puede probar con un % de usuarios sin release.

## 2026-10-07: el banco ya existe

`gateway/bench/` mide cualquier modelo de cualquier proveedor con las peticiones reales de la app. Las tres tareas de
`gpt-4.1-nano` ya están elegidas (`docs/ai-model-bench-2026-10.md`); las 8 de `gpt-4.1-mini` son el paso 3 de
`ai-every-call-sends-its-task-and-passes-the-bench`.

## Hecho cuando

- Decisión anotada aquí.
- Si B: juego de pruebas en el repo, resultado de la comparación y cambio desplegado por tarea.

## Cierre

Resuelto en la sesión 2 (2026-10-07): las siete llamadas de `gpt-4.1-mini` pasaron por el banco. Chat, reescritura, lectura de la nota e Insights a `gpt-6-luna`; Tendencias a `gpt-6.1-sol`. Tablas en `docs/ai-model-bench-2026-10.md` (sección «Sesión 2»).
