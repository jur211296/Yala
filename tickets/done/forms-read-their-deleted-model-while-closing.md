---
id: forms-read-their-deleted-model-while-closing
status: done
priority: medium
area: "groups, records"
created: 2026-10-29
updated: 2026-10-31
source: "encargo 2026-10-29-bandeja-crash-borrar-dos-seguidos (repaso del mismo patrón en otras listas)"
---

# Dos formularios se leen a sí mismos tras borrar su modelo, mientras se cierran

## Qué pasa

Hallado al buscar el patrón del crash de la Bandeja (`inbox-deleting-two-drafts-in-a-row-crashes`): en iOS 27.x leer
una propiedad de un modelo SwiftData borrado aborta la app. Las listas ya no lo hacen; dos formularios borran su propio
modelo y siguen presentados durante la animación de cierre:

- `GroupExpenseFormView`: «Eliminar» llama a `onDelete` (borra y guarda el gasto) y luego `dismiss()`. El título del
  `confirmationDialog` lee `expenseToEdit?.expenseDescription`, y el cuerpo se vuelve a evaluar al cerrarse el diálogo.
- `NewTransactionView.deleteTransaction()`: borra y guarda `transactionToEdit` y luego `dismiss()`.

No está medido que el cuerpo se vuelva a pintar en esa ventana (el simulador 27.0 no aborta al leer un modelo borrado),
así que es un riesgo, no un crash visto.

## Qué haría falta

Que esos formularios no lean el modelo tras borrarlo: copiar lo que pintan (título, importe) antes de borrar, o guardar
con `isDeleted || modelContext == nil` las lecturas de su `body`, como `BudgetDetailView.isBudgetValid`.

## Hecho (2026-10-31, encargo S31 `formularios-modelo-borrado`)

- **Formulario de gasto de grupo:** el título del diálogo de borrado sale de una copia del nombre hecha al tocar la
  papelera. Era la única lectura del gasto en el `body`.
- **Editor de registro:** el `body` lee el registro solo por `readableTransactionToEdit` (nil si está borrado), la alerta
  de borrado pinta una copia hecha al abrirla, y tras borrar y guardar el ViewModel suelta el registro conservando la
  divisa que se enseñaba (`releaseDeletedRecord`). El ViewModel también lo leía: `amountCurrencyCode`, que pinta el
  importe.
- Para quien use la app no cambia nada visible: el riesgo era un cierre de la app en iOS 27.x que el simulador 27.0 no
  reproduce.
- Red: `DeletedRecordFormReleaseTests`, `DeletedModelFormGuardWiringTests` y
  `RecordsDetailSheetUITests#test_deleteFromEditor_confirm_closesAndRemovesTheRecord`.
