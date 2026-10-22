---
id: chat-creates-only-one-transaction-per-message
status: backlog
priority: low
area: chat
created: 2026-09-09
updated: 2026-10-08
source: idea Jürgen 2026-09-09
---

# El chat debería crear varias transacciones desde un solo mensaje

## La idea

Que un único mensaje al chat pueda producir **varias** transacciones de golpe. El caso que Jürgen
tiene en la cabeza: pedirle a una IA que lea sus correos, arme un solo texto con el detalle y se lo
pegue al chat de Yala para que lo registre todo de una vez.

## Por qué importa

Hoy el camino de «tengo veinte movimientos del mes en el correo» a «están en Yala» es de veinte
idas y vueltas. De uno en uno, la función deja de compensar justo cuando más falta hace.

## Lo medido (2026-09-09) — el transporte ya es plural

El modelo de respuesta del chat **ya lleva un array**, no un borrador suelto:

```swift
case drafts([ChatTransactionDraft])   // Yala/App/Models/ChatAssistantModels.swift:301
```

…con su `encode`/`decode` de la lista completa (`:316-332`). Así que el tope, si existe, **no está
en la estructura de datos**. Antes de diseñar hay que medir dónde está: en el prompt, en
`ChatIntentClassifierService`, en el ViewModel o en la card que los pinta
(`ChatTransactionDraftCard.swift`). Que el transporte lo admita no significa que el camino entero
funcione.

## Estado

Idea capturada, **sin spec**. Y hay una dependencia dura: [[chat-assistant-is-down]] — mientras el
chat esté caído esto no se puede ni probar.

## Relacionados

- [[chat-assistant-is-down]] (**high**) — bloquea la verificación.
- [[chat-draft-sign-can-contradict-its-subcategory]] — con N borradores por mensaje, los defectos
  de contenido de un borrador se multiplican por N. Conviene mirarlos antes de abrir el grifo.

## Medido en 2.1 (triage 2026-10-08)

- **La premisa del título es falsa.** `ChatAssistantService.swift:196` fija `maxDraftsPerMessage = 5`; `:261` recorta con `prefix(5)` y `:266-269` avisa con `chat.draft.overflowFormat` («Detecté %d movimientos. Registro los primeros %d; manda el resto en otro mensaje.»). El parseo es plural (`TranscriptionParserService.parseMultiple`, `:233`). Existe desde 52d2ad6b6 (2026-04-27).
- Lo que queda de la idea: el caso de «veinte movimientos del correo» choca con el tope de 5, no con un tope de 1. Antes de subirlo: coste del parseo, límite diario del chat y cómo se revisan 20 cards.
- La dependencia `chat-assistant-is-down` está en `tickets/discarded/`.

Triage 2026-10-08: abierto · medium → low · premisa falsa: el chat ya crea hasta 5 borradores por mensaje desde 52d2ad6b6 (`ChatAssistantService.maxDraftsPerMessage`); lo que queda es subir ese tope para pegar un mes entero.
