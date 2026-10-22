---
id: chat-draft-sign-can-contradict-its-subcategory
status: done
priority: medium
area: "chat"
created: 2026-09-08
source: review adversarial de chat-draft-drops-the-expense-sign (2026-09-08)
updated: 2026-09-23
qa-status: not-replicable
qa-date: 2026-09-23
qa-notes: barrido 2026-09-23 sin device-QA - pide aprobar cinco ingresos con la misma nota antes de dictar; 13 tests y 4 mutantes en DraftBuilderTests
---

# Un borrador del chat puede nacer marcado «gasto» con una subcategoría de ingreso

## Qué le pasa al usuario

Dicta algo ambiguo, el chat le propone un borrador marcado **Gasto** pero con una subcategoría de
**ingreso** —porque la eligió por el comercio, no por el tipo—, y lo guarda. La transacción entra
como un «ingreso negativo»: **resta** del total de ingresos en Registros, Estadísticas y flujo de
caja, mientras el widget de la pantalla de inicio la suma. **La app y el widget dicen cosas distintas
de la misma fila.**

## Por qué aparece ahora (medido el 2026-09-08, en este árbol)

Este estado ya se podía alcanzar antes, pero era **inofensivo**: hasta el fix de
`chat-draft-drops-the-expense-sign` el chat guardaba todo en positivo, así que un borrador marcado
gasto con categoría de ingreso acababa como un ingreso normal y coherente. Al firmar el monto, ese
mismo desajuste pasa a producir la combinación «signo contrario a su categoría», que
`TransactionClassificationLogic` trata **a propósito** como un reembolso:

> «un monto de signo contrario a su categoría se trata como reembolso/corrección y REDUCE el bucket,
> no como magnitud absoluta»

El fix no crea el desajuste; le quita el disfraz.

## Dónde se origina

`DraftBuilder` tiene dos vías para elegir subcategoría y solo una respeta el tipo:

- **La vía con hint** (`matchSubcategoryByHint(hint:isExpense:)`) **sí** filtra por naturaleza.
- **El fallback por comercio** no:

```swift
static func suggestSubcategory(merchant: String, context: ModelContext) -> Subcategory? {
    …
    switch service.suggest(for: trimmed) {
    case .suggest(let sub), .autoAssign(let sub):
        return sub          // ← sin contrastar con parsed.isExpense
```

Y nada lo detiene después: la validación de naturaleza de `ChatAssistantViewModel.updateDraft` solo
corre si el usuario **cambia** la subcategoría a mano, y el filtro del card limita el **menú**, no lo
que ya viene puesto. Como el prompt del parser dice «por defecto asume gasto», el texto ambiguo
aterriza en `isExpense: true` con la subcategoría que dictó la memoria de comercios.

## Lo que NO se midió

Con qué frecuencia pasa de verdad. Requiere una memoria de comercios que apunte a una subcategoría de
ingreso y un texto cuyo hint no case — estrecho, pero alcanzable, y el daño es silencioso.

## La decisión: manda el tipo del borrador (`isExpense`)

Cuando el tipo y la subcategoría discrepan, **gana el tipo y la subcategoría se descarta**. No es una
preferencia nueva: es lo que ya hacían los otros cuatro puntos del borrador del chat, medidos el
2026-09-08 en este árbol —

- el menú del card filtra por `draft.isExpense` (`ChatTransactionDraftCard.filteredSubcategories`) y
  **ni siquiera ofrece cambiar el tipo**: `updateDraft` no acepta `isExpense`;
- `ChatAssistantViewModel.updateDraft` rechaza contra él la subcategoría que el usuario elige a mano;
- `DraftBuilder.matchSubcategoryByHint` filtra por él;
- `ChatAssistantViewModel.saveDraft` firma el monto con él.

El único punto que no lo respetaba era el fallback por comercio — y su sugerencia es lo **menos**
parecido a una intención del usuario: no sale de lo que acaba de dictar, sino del recuerdo
estadístico de otros dictados sobre ese mismo comercio. Alinear el quinto con los otros cuatro.

**Qué cambia para el usuario:** cuando la memoria del comercio contradice el tipo, el borrador nace
sin subcategoría y el card la pide (Guardar sigue bloqueado hasta que la elija). Es exactamente el
mismo estado que cuando no hay memoria de ese comercio, que es el caso común.

## Lo que se arregló

`DraftBuilder.suggestSubcategory` recibe ahora el tipo y descarta lo que lo contradiga, con el
criterio en un solo sitio (`DraftBuilder.matchesNature`, que `matchSubcategoryByHint` reusa). Eso
cubre a sus **tres** llamadores, no solo al chat:

1. **Chat** (`DraftBuilder.build`) — el del ticket.
2. **Siri** (`SiriDraftService.buildDraft`) — mismo daño, y con un agravante medido aquí: el
   `expensesOnlyMode` forzaba el gasto **después** de resolver la subcategoría, así que con el modo
   activo y un dictado que el LLM leyó como ingreso el desajuste se producía **incluso por la vía del
   hint**, sin necesidad de memoria de comercios. La línea sube antes de resolverla.
3. **Visión** (`VisionDraftFactory.createDraft`) — no tenía ningún `isExpense` que consultar: el
   prompt de visión pide el monto ya firmado («expenses are NEGATIVE»), así que el tipo se deriva del
   signo. Sin monto se asume gasto, el mismo default que aplica `InboxDraftEditSheet.prefillFromDraft`
   (`:828`), que es donde acaba ese borrador.

## Lo que este ticket NO arregla, y tiene ticket propio

Otras **tres** superficies llaman a `MerchantMemoryService.suggest(for:)` sin pasar por
`DraftBuilder`, y tienen el mismo cruce: Apple Pay (`ApplePayDraftService.swift:102`, con el monto
siempre negativo), la voz (`VoiceRecordingView.swift:935`) y el prefill de la hoja de la Bandeja
(`InboxDraftEditSheet.swift:840`, que ni consulta el `isExpense` que resolvió doce líneas antes).
→ `merchant-memory-suggests-across-natures-in-three-more-places`.

**No se añadió red en `saveDraft`**, y el AC lo permitía («o»). El copy de error que existe
(`chat.draft.saveFailedSubcategory`) dice que la subcategoría «ya no existe», que sería mentira aquí,
y uno nuevo son 16 locales. Residual aceptado y medido: un borrador cruzado que ya esté serializado
en la sesión del día sobrevive a una actualización de la app y se puede guardar. Vida máxima: la
sesión de ese día.

## Criterio de hecho (AC)

- [x] `suggestSubcategory` no devuelve una subcategoría cuya naturaleza contradiga `isExpense`.
- [x] Decidido quién manda cuando discrepan: **el tipo del borrador** (arriba), documentado en el
      docblock de `DraftBuilder.matchesNature` para que viaje con el código.
- [x] Test con la combinación cruzada, con control positivo y verificado por mutación: 13 tests
      nuevos en `DraftBuilderTests`, `SiriDraftServiceTests` y `VisionDraftFactoryTests`. Cuatro
      mutantes compilados (quitar el filtro, invertir el criterio, devolver el orden viejo de
      `expensesOnlyMode`, fijar el tipo en visión) ponen en rojo exactamente los tests que deben.

## Pendiente

- **Device-QA.** Es simulable: sembrar una memoria de comercio sobre una subcategoría de ingreso
  (aprobar 5 veces un ingreso con esa nota desde la Bandeja), dictar al chat un gasto con esa misma
  nota y comprobar que el borrador pide subcategoría en vez de nacer con la de ingreso.

## Barrido de `qa` · 2026-09-23 · cerrado sin device-QA

Sale de la cola de device-QA por el barrido que pidió Jürgen el 2026-09-23 (encargo `2026-09-23-barrido-qa-in-qa-pre-device`). Para verlo hay que aprobar antes cinco ingresos con la misma nota, y es raro. Lo cubren 13 tests y 4 mutantes en `DraftBuilderTests`.
