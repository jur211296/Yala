---
id: more-forms-read-their-deleted-model-while-closing
status: backlog
priority: medium
area: "accounts, categories, groups, cashflow"
created: 2026-10-31
updated: 2026-10-31
source: "encargo S31 formularios-modelo-borrado (barrido del patrón de forms-read-their-deleted-model-while-closing)"
---

# Siete formularios más (y tres pantallas que los presentan) leen su modelo tras borrarlo

## Qué pasa

Mismo riesgo que `forms-read-their-deleted-model-while-closing` (hecho el 2026-10-31 en el formulario de gasto de
grupo, el editor de registro, el de presupuesto y el de favorito): en iOS 27.x leer una propiedad de un modelo SwiftData
borrado aborta la app, y estos formularios borran su modelo y siguen presentados durante el cierre. El simulador 27.0 no
aborta, así que es un riesgo, no un crash visto. Ninguno se arregló en S31 porque el arreglo no es una copia de una
línea: toca ViewModels, el `init` que el padre vuelve a ejecutar o, en Grupos, un borrado que es sync.

Barrido por lectura del código (coordenadas del árbol del 2026-10-31, re-mídelas antes de tocar):

| Vista | Qué lee tras borrar |
|---|---|
| `AccountFormView` | Título de la alerta (`accountToEdit?.name`) y el ViewModel por `canSave`: `lineRole`, `hasBrokenLink`, `currencyCollidingLine` en `AccountFormViewModel+Lines.swift` |
| `CategoryDetailView` | `isSystemCategory` del VM (lee `category.isSystem/isIncome/name`), la lista de subcategorías filtra por `$0.category == category` incluyendo las borradas, `viewModel.category.iconName` |
| `SubcategoryDetailView` | `isSystemSubcategory` (`subcategoryToEdit?.isAnySystem`), y el padre la vuelve a crear con un `init` que lee `sub.name`, `sub.need`… |
| `SubcategoryTransferSheet` | El texto de la hoja (`subcategoryToDelete.name`) y los destinos; el padre borra en `onComplete` justo tras el `dismiss()` |
| `GroupOpeningBalanceDetailSheet` | `paidByMemberID`, `amount`, `currencyCode`, `date` del saldo inicial que el padre borra (hard delete) antes del `dismiss` |
| `CashFlowLineConfigSheet` | `navigationTitle(line.name)`, `line.subcategory/category`, y el padre la vuelve a crear leyendo `line.method/manualAmount` mientras `selectedLine` siga puesto |
| `GroupSettingsView` (salir del grupo) | Tras el `await` de `leaveGroup` (hard delete del grupo), el `defer { isLeavingGroup = false }` repinta y lee `group.isOwner/name/isArchived/simplifyDebts`; el `onDisappear` llama a `saveIdentity`, que lee `group.name/iconName/colorHex` |

Y en quien presenta esos formularios (review adversarial de S31; tampoco se tocó, es previo):

| Vista | Qué lee tras borrar |
|---|---|
| `BudgetsListView` + `BudgetRowView` | Borrar un presupuesto sube `dataVersion` y la lista repinta, pero recarga 150 ms después (`BudgetsViewModel.scheduleRecalculation`): mientras tanto el `ForEach` lee `summary.budget.currencyCode` y la fila `name`, `limitAmount`, `isFavorite` del presupuesto borrado. Es el molde de la card f8rj en filas de presupuesto; arreglo de `RecordRowView` (mirar `isDeleted` antes de leer). **Lo más probable de la lista.** |
| `GroupDetailView` (hoja `.editExpense`) | Si el `@Observable` del detalle repinta tras `deleteExpense` → `loadData()` con `activeSheet` aún puesto, el contenido de la hoja vuelve a correr y lee `expense.paidByMemberID` (`membersForExpenseForm`) y `expense.id` (`sharesForExpense`). Depende de si `dismiss()` vacía `activeSheet` antes del pase siguiente. |
| `CashFlowCellDetailSheet.activeTransactions` | Lee `tx.date`, `tx.subcategory`, `tx.category` de su `let transactions` sin mirar; el registro editado sale de esa lista. Si la hoja repinta antes de recibir la lista nueva, aborta. |

Dudosos (sin decidir si llegan a leerse tras borrar):

- `TagFormView`: el mensaje de la alerta lee `tagToEdit?.transactions?.count` (relación), y `canSave` lee `tag.id`.
- `CashFlowCellDetailSheet`: `line?.subcategory/category` si la proyección no se ha recalculado aún.
- Lecturas de `id` con `@Attribute(.preserveValueOnDeletion)` (`SplitExpense`, `Tag`, `Budget`, `ScheduledPayment`):
  `GroupSheet.id` en `GroupDetailViewModel` lee `e.id` del gasto borrado mientras la hoja de edición se cierra. No está
  medido si ese getter es seguro en 27.x.

## Qué haría falta

El molde de S31 por formulario: copia previa de lo que se pinta (título de alerta, textos), accesor guardado
`isDeleted || modelContext == nil` para lo que el `body` lea, y que el ViewModel suelte el modelo tras borrarlo. En
`GroupSettingsView`, revisar con review adversarial: es el borrado de un grupo. Red de test: el molde de
`DeletedModelFormGuardWiringTests`.
