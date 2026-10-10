---
id: merchant-memory-suggests-across-natures-in-three-more-places
status: backlog
priority: medium
area: "inbox"
created: 2026-09-08
updated: 2026-10-08
source: barrido del patrón en chat-draft-sign-can-contradict-its-subcategory (2026-09-08)
---

# La memoria de comercios también cruza gastos e ingresos en Apple Pay, la voz y la Bandeja

## Qué le pasa al usuario

Lo mismo que en el chat, en tres sitios más: un comercio que su memoria aprendió sobre **ingresos**
le rellena la subcategoría de un **gasto** (o al revés), y esa fila entra con el signo contrario a su
categoría. Registros y Estadísticas la leen como un reembolso —**resta** del bucket— mientras el
widget de la pantalla de inicio, que solo mira el signo, la suma. La app y el widget dicen cosas
distintas de la misma fila.

## Por qué queda fuera del arreglo del chat

`chat-draft-sign-can-contradict-its-subcategory` cerró el patrón en `DraftBuilder.suggestSubcategory`,
que ahora recibe el tipo del borrador y descarta lo que lo contradiga
(`DraftBuilder.matchesNature`). Eso cubre a sus tres llamadores: el chat, Siri y visión.

**Estas tres superficies no pasan por ese helper**: llaman a `MerchantMemoryService.suggest(for:)`
directamente, y ese servicio no sabe nada de naturaleza —guarda `merchant → subcategoría` y punto—.

## Lo medido (2026-09-08, en este árbol)

| Dónde | La sugerencia | El signo |
|---|---|---|
| `ApplePayDraftService.swift:102` | `suggest(for: merchant)` sin filtro | `amount: -abs(parsed.amount)` (`:124`) — **siempre gasto** |
| `VoiceRecordingView.swift:762` | `suggest(for: parsed.note)` sin filtro; el hint de arriba **sí** filtra (`findSubcategory(matching:isExpense:)`) | `parsed.isExpense ? -abs(value) : abs(value)` (`:738`) |
| `InboxDraftEditSheet.swift:840` | `suggest(for: note)` sin filtro | `isExpense` ya está resuelto **doce líneas antes** (`:825`, `:828`) y no se consulta |

Apple Pay es el más expuesto de los tres: el monto es negativo **siempre**, así que basta con que la
memoria del comercio apunte a una subcategoría de ingreso. Y el borrador se marca con
`confidenceSubcategory: 0.95` cuando viene de `.autoAssign`, o sea que la app se muestra segura de
una combinación que no puede ser.

La hoja de la Bandeja tiene una atenuante y una agravante. Atenuante: su selector manual **sí** filtra
por tipo (`SubcategorySelectorSheet(transactionType:)`) y tocar el selector de tipo limpia la
subcategoría. Agravante: nada reconcilia el par que llega **prefilado**, y desde la Bandeja se puede
aprobar con un swipe sin abrir la hoja (`DraftService.approveDraft` no mira naturaleza; tampoco
`bulkApprove`, ni `InboxDraft.isReadyToApprove`).

## Lo que NO se midió

Con qué frecuencia pasa. Igual que en el ticket del chat: requiere una memoria de comercio que apunte
a la naturaleza contraria, y eso no se ha contado en datos reales.

## Criterio de hecho (AC)

- [ ] Las tres superficies descartan la sugerencia que contradiga el tipo del borrador, con el mismo
      criterio que ya existe (`DraftBuilder.matchesNature`) y la misma decisión: **manda el tipo**.
- [ ] Decidido si el filtro sube a `MerchantMemoryService.suggest(for:isExpense:)` —un solo sitio,
      seis llamadores— o se queda en cada superficie. Subirlo es más limpio pero cambia un servicio
      con usos de UI; quedarse deja el criterio repetido en cuatro sitios.
- [ ] Test de la combinación cruzada en cada una, con su control positivo.

## Medido en 2.1 (triage 2026-10-08)

Las tres llamadas siguen sin filtro de naturaleza: `ApplePayDraftService.swift:102`, `VoiceRecordingView.swift:776` (antes `:762`) e `InboxDraftEditSheet.swift:839`. `MerchantMemoryService.suggest(for:)` (`:51`) sigue sin parámetro de tipo.

Triage 2026-10-08: abierto · medium → medium · las tres superficies siguen llamando a `suggest(for:)` sin `matchesNature` (`ApplePayDraftService.swift:102`, `VoiceRecordingView.swift:776`, `InboxDraftEditSheet.swift:839`).
