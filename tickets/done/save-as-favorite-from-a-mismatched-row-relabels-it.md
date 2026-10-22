---
id: save-as-favorite-from-a-mismatched-row-relabels-it
status: done
priority: medium
area: "transactions, favorites, scheduled, currency"
created: 2026-10-08
updated: 2026-10-22
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

## Medido en 2.1 (triage 2026-10-08)

- `NewTransactionView.favoriteSheetContent` y `recurringSheetContent` siguen pasando `viewModel.effectiveCurrencyCode`; el formulario usa `amountCurrencyCode` a unas líneas. Ningún commit posterior al 4ec6f0c5e los toca.
- Hermanos: `saving-a-mismatched-transaction-relabels-it-without-converting` (qa, medium) y `cloudsync-account-currency-orphans-receiver-history` (medium), que es una de las fuentes de filas desemparejadas.
- Decisión pendiente. A) convertir el importe a la divisa de la cuenta con la tasa de hoy al crear el favorito o el programado. B) crearlo en la divisa de la fila, que obliga a tocar `prefillFromFavorite`. C) avisar y no crear. Recomendada: A, que es lo que hace el arreglo de la divisa de la cuenta.

Triage 2026-10-08: abierto · low → medium · sigue pasando (favoriteSheetContent/recurringSheetContent con effectiveCurrencyCode) y crea un favorito o un programado con un importe en otra divisa justo después de que la pantalla enseñara la buena; es la misma clase que su hermano medium.

## Implementación (2026-10-22, lote decidido 2.2 · 02, sesión A, card 4k2q)

- El favorito y el pago planificado guardan la divisa del IMPORTE (`viewModel.amountCurrencyCode`), sin convertir:
  `favoriteSheetContent`, `recurringSheetContent` y la hoja corta «Hacer recurrente» (`createRecurringPayment`). El editor
  completo de pagos guarda la divisa del prefill mientras la cuenta sea la del registro.
- Al usar un favorito, la precarga enruta por divisa (tarjeta con varias divisas) y, si la cuenta no tiene esa divisa, el
  importe la conserva (`NewTransactionViewModel.keepAmountCurrency`). Lo mismo al duplicar un movimiento.
- Tests: `UXAudit22Decidido02FormTests` (favorito y pago de 50 USD desde un gasto en cuenta en soles; usar un favorito en
  dólares en cuenta en soles guarda USD) y los scans de `UXAudit22Decidido02WiringTests`.
