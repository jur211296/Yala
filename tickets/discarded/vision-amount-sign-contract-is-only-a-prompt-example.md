---
id: vision-amount-sign-contract-is-only-a-prompt-example
status: discarded
priority: low
area: "inbox, image"
created: 2026-09-08
source: hallazgo de camino en chat-draft-drops-the-expense-sign (2026-09-08)
updated: 2026-10-08
---

Why: Discarded 2026-10-08. La premisa era falsa ya el día que se escribió. `ImageVisionService.systemPrompt` enuncia la regla en «Rules»: «Amounts: No currency symbol, expenses are NEGATIVE, income is POSITIVE» (hoy `:131`; en el árbol del 2026-09-08, `:98`), desde `d9cfe973d` (2026-01-25), y no solo en el JSON de ejemplo. Eso es exactamente el arreglo «barato y suficiente» que pedía el primer criterio. El segundo ya lo cubre `VisionDraftFactoryTests`, que fija las dos polaridades del signo (`createDraft_rememberedIncomeSubcategory_expenseAmount_leavesItEmpty` y su control con el importe positivo). El DTO con `isExpense` explícito era la opción opcional, sin ningún fallo medido que la pida.

# El signo del monto de una foto depende de un ejemplo del prompt, y no hay red debajo

## Qué le pasa al usuario

Fotografía el recibo de una compra y el Inbox se lo propone como **ingreso** — el selector aparece en
«Ingreso» en vez de «Gasto». Si lo aprueba sin mirar el selector, el gasto entra sumando.

**No está roto hoy**, y esa distinción importa: hoy el modelo devuelve el signo correcto. Lo que no
hay es nada que lo garantice.

## Lo medido (2026-09-08, en este árbol)

`VisionDraftFactory` pasa el monto del modelo **tal cual**, sin firmar y sin `abs()`:

```swift
amount: transaction.amount,
```

Un grep de `isExpense`, `abs(`, `-amount` e `isNegative` sobre el fichero entero devuelve **cero**.
Eso, por sí solo, parece el mismo descuido que `chat-draft-drops-the-expense-sign`. **No lo es**, y
conviene dejarlo escrito para que nadie lo «arregle» al revés: aquí el contrato es que el signo lo
pone el modelo, y el fichero es coherente con él.

El problema es de dónde sale ese contrato. En `ImageVisionService`, el prompt **no enuncia ninguna
regla de signo**; lo único que lo insinúa es el JSON de ejemplo de la respuesta:

```
"transactions": [{"amount": -45.50, "date": "2026-01-25", "merchant": "Starbucks", …}]
```

Un ejemplo no es una regla. Y la fila de abajo tampoco protege: `InboxDraftEditSheet` deduce el tipo
del signo que le llegue (`isExpense = amt < 0`), así que un `45.50` positivo se presenta como ingreso
sin que nada avise. La única red es el modo solo-gastos, que fuerza `isExpense = true` — y solo está
activo si el usuario lo encendió.

## Contraste con las otras rutas del mismo tipo

Las tres rutas hermanas que reciben monto de un parser **no** confían en el signo de entrada: lo
recalculan de una intención explícita. `SiriDraftService` es el molde:

```swift
let isExpense = expensesOnlyMode ? true : parsed.isExpense
let absValue = abs(NSDecimalNumber(decimal: amount).doubleValue)
let signedAmount = isExpense ? -absValue : absValue
```

y `ApplePayDraftService` lo fuerza en la línea (`amount: -abs(parsed.amount)`). La visión es la única
que se queda con lo que le den.

## Qué haría falta

Lo barato y suficiente: **enunciar la regla en el prompt** («los gastos son negativos, los ingresos
positivos»), que hoy solo está insinuada por un ejemplo. Lo robusto: que el DTO de visión traiga un
`isExpense` explícito y el factory firme con él, como Siri.

## Criterio de hecho (AC)

- [ ] La regla de signo está enunciada en el prompt de `ImageVisionService`, no solo en el ejemplo.
- [ ] Test que fije el comportamiento cuando el modelo devuelve un positivo para un gasto.

Triage 2026-10-08: descartado · low → — · la regla de signo que pedía ya está en el prompt desde enero (ImageVisionService.swift:131) y los tests fijan las dos polaridades.
