---
id: gateway-proxies-any-model-and-any-length
status: done
priority: low
area: gateway, ai, security
created: 2026-10-07
updated: 2026-10-07
source: revisión del uso de IA (docs/ai-usage-review-2026-10.md, hallazgo H12)
---

# El gateway reenvía a OpenAI cualquier modelo y cualquier longitud

> **Grupo: autónomo.** Endurecimiento. Fija en el servidor los modelos que la app **ya** usa; no cambia
> ninguno. Si Jürgen decide mover la elección de modelo al gateway (`ai-model-choice-lives-in-the-app-binary`),
> este ticket se absorbe ahí.

## Qué pasa

`gateway/src/proxy/openai.ts` reenvía el cuerpo de la petición sin mirarlo. Un cliente atestado puede
pedir cualquier modelo (incluido el más caro de la cuenta) y cualquier `max_completion_tokens`, y la
categoría de cuota la elige el propio cliente con `X-Yala-Category`: una petición de chat marcada como
`vision` cae en el cubo de visión. Para un free, eso es chat sin Pro dentro de la cuota de 5 fotos.

El riesgo real es bajo —hace falta pasar App Attest, o sea la app genuina, y la app genuina no hace
esto— pero el coste del peor caso no está acotado en ningún sitio del servidor.

## Lo medido (2026-10-07, en este árbol)

- `proxy()` pasa `c.req.raw.body` como stream sin leerlo.
- `categoryFrom` acepta `chat|vision|insights|suggestions` desde la cabecera.
- `policy.ts`: free tiene `vision` 5/día y no tiene `chat`.

## Qué hay que hacer

1. Leer el cuerpo JSON de `/v1/chat/completions` (es pequeño salvo la imagen) y rechazar con 400 los
   modelos fuera de una lista por categoría (hoy: `gpt-4.1-mini`, `gpt-4.1-nano`).
2. Imponer un tope de `max_completion_tokens` por categoría.
3. `vision` solo si el mensaje lleva una imagen.

## Avance del 2026-10-07

- **Modelo: cerrado.** El gateway resuelve cada petición a una tarea (`gateway/src/ai/`) y rechaza con 400
  `yala_model_not_allowed` un modelo que no está en la tabla ni se deduce, sin gastar cuota.
- **Categoría:** con la cabecera `X-Yala-Task`, una tarea de otro cubo que el declarado → 400. Falta que el cubo salga
  de la tarea (sesión 2: `ai-every-call-sends-its-task-and-passes-the-bench`, paso 1).
- **Longitud:** sigue abierta (tope de cuerpo y de `max_completion_tokens` por tarea).

## Hecho cuando

- Tests del gateway: modelo fuera de lista → 400; `vision` sin imagen → 400; tope aplicado.
- La app actual pasa sin cambios (test con los cuerpos que manda hoy cada servicio).

## Cierre

Resuelto en la sesión 2 (2026-10-07): con cabecera el cubo sale de la tarea; las filas managed fijan el tope de salida; cada tarea tiene tope de cuerpo (413 `yala_too_large`) y la foto exige imagen. Tests: `gateway/test/ai.session2.test.ts`.
