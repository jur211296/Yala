---
id: chat-context-encoding-failure-is-silent
status: backlog
priority: low
area: chat, ai
created: 2026-10-07
updated: 2026-10-08
source: revisión del uso de IA (docs/ai-usage-review-2026-10.md, hallazgo H11)
---

# Si el contexto del chat no se puede codificar, el chat dice que no hay datos

> **Grupo: autónomo.** Manejo de errores. No cambia modelo ni proveedor.

## Qué le pasa al usuario

Si el JSON con sus finanzas falla al codificarse (p. ej. un `Double` no finito que se cuele en el
contexto), el modelo recibe `{}` y contesta con seguridad que no tiene datos de ese gasto. El usuario no
tiene forma de saber que fue un error.

## Lo medido (2026-10-07, en este árbol)

`Yala/Services/Chat/FullFinancialContext.swift:43`: `guard let data = try? encoder.encode(self) …
else { return "{}" }`. Es un `try?` que silencia, prohibido por las reglas del repo, y además se manda
la pregunta igual, pagando la llamada.

## Qué hay que hacer

`toJSONString()` lanza; `ChatAssistantService.runAskFlow` convierte el fallo en un error tipado del chat
y **no** llama al modelo.

## Hecho cuando

- Test: un contexto que no se puede codificar produce error tipado y cero llamadas al cliente.

## Medido en 2.1 (triage 2026-10-08)

- `FullFinancialContext.toJSONString()` (`Yala/Services/Chat/FullFinancialContext.swift:43`) sigue con `guard let data = try? encoder.encode(self) … else { return "{}" }`.

Triage 2026-10-08: abierto · low → low · el `try?` que devuelve `{}` sigue; hace falta un valor no codificable en el contexto, raro desde que el sync rechaza NaN.
