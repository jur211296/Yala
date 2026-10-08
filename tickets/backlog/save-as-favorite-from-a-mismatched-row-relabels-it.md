---
id: save-as-favorite-from-a-mismatched-row-relabels-it
status: backlog
priority: low
area: "transactions, favorites, scheduled, currency"
created: 2026-10-08
updated: 2026-10-08
source: review adversarial de account-currency-change-leaves-scheduled-and-favorites-stale (2026-10-08, tres lentes)
---

# «Guardar como favorito» y «Hacer recurrente» desde una fila desemparejada la reetiquetan

## Qué le pasa al usuario

Abre un movimiento de 50 USD que vive en una cuenta en soles. Desde
`saving-a-mismatched-transaction-relabels-it-without-converting` el formulario enseña «$ 50» y lo guarda en dólares.
Pero si toca «Guardar como favorito» o «Hacer recurrente», la hoja enseña «S/ 50» y crea un favorito o un pago
programado de 50 **soles**. El dato es el mismo que antes del arreglo; lo nuevo es que contradice lo que la pantalla
acaba de enseñar. Duplicar el movimiento también vuelve a la divisa de la cuenta (el símbolo pasa de $ a S/).

## Lo medido (2026-10-08, en código)

- `Yala/App/Views/Transactions/NewTransactionView.swift` — `favoriteSheetContent` y `recurringSheetContent` pasan
  `viewModel.effectiveCurrencyCode` (la divisa de la cuenta), no `amountCurrencyCode`.
- `SaveAsFavoriteSheet` y `ScheduledPaymentEditorView` (`:1483`) estampan la divisa de la cuenta.
- La precarga de un favorito (`prefillFromFavorite`) usa la divisa de la cuenta, así que pasarle la de la fila tampoco
  basta: el favorito se reetiquetaría al usarse.

## Qué hay que decidir

Convertir el importe a la divisa de la cuenta al crear el favorito/programado (tasa de hoy), o avisar. Se dejó fuera
del PR del 2026-10-08 para no tocar lo adyacente.
