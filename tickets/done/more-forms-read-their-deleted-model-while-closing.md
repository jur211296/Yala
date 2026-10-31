---
id: more-forms-read-their-deleted-model-while-closing
status: done
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

## Hecho (2026-10-31, encargo S34b `formularios-modelo-borrado-b`, card gxa9)

Para quien usa la app no cambia nada: el riesgo era un cierre de Yala en iOS 27.x al borrar desde estos formularios, que
el simulador 27.0 no reproduce. Lo que cambió, caso por caso:

- **Cuenta:** la alerta corta pinta el nombre copiado al pedir eliminar; tras eliminar (alerta u hoja de mover o borrar),
  el ViewModel suelta la cuenta y sus filas (`releaseDeletedAccount`) y sigue siendo una edición, sin poder guardar otra.
  El `init` del formulario no toma una cuenta ya borrada. La lista de Ajustes › Cuentas, que lo presenta, no lee la
  cuenta borrada al rehacer la hoja ni recorre registros borrados para los saldos.
- **Categoría:** el ViewModel ofrece la categoría por `readableCategory` y la suelta al eliminarla, descartarla o mover sus
  registros (`releaseDeletedCategory`); la lista de subcategorías salta las borradas; la vista no la lee al crear el
  ViewModel si ya está borrada (`readsCategory:`). La lista de Categorías filtra las borradas.
- **Subcategoría y traspaso:** el `init` mira antes de leer la subcategoría y la categoría padre; el traspaso pinta el
  nombre copiado y no calcula destinos con la subcategoría borrada.
- **Saldo inicial de grupo:** la hoja pinta el saldo vivo y, borrado, la copia tomada al abrir.
- **Línea del flujo de caja:** título y categoría vivos o copiados al abrir; el resto (ajustes, previsiones, histórico)
  pasa por `readableLine`. La celda del mes copia el icono y salta los registros borrados.
- **Ajustes del grupo al salir:** con el grupo borrado la lista no pinta filas mientras la hoja baja, no guarda la
  identidad, no recalcula, y los textos de salir no leen miembros. Es el único cambio que puede verse, solo en los
  fotogramas de cierre (molde de `BudgetDetailView.isBudgetValid`).
- **Lista de presupuestos:** la fila y la lista saltan el presupuesto borrado durante los 150 ms antes de recalcular, y el
  conteo del límite de Free tampoco lo cuenta.
- **Detalle de grupo (hojas de editar gasto y de saldo inicial):** repartos y miembros con el gasto borrado no lo leen;
  `GroupSheet.id` usa `persistentModelID` en vez de `id`.
- **Etiqueta (dudoso):** recuento de la alerta copiado; tras eliminar, el ViewModel suelta la lista que recorría la
  unicidad del nombre (`releaseDeletedTag`); la lista de Etiquetas filtra las borradas.

Red: `DeletedModelMoreFormsReleaseTests` (mecanismos de ViewModel y listas) y `DeletedModelMoreFormsGuardWiringTests`
(cableado de las vistas), con mutantes medidos.

Queda fuera, con ticket: `group-detail-reads-the-group-after-leaving-it` (el `body` del detalle de grupo tras salir).
Dudosos sin tocar: `Tag.id` en el `sheet(item:)` de Etiquetas y `expense.id` en las hojas de detalle de gasto y de
editar saldo inicial, solo alcanzables con un borrado por sync; y `readableCategory` mira `isDeleted` pero no
`modelContext == nil` (los tests de ViewModel construyen modelos sin contexto), así que un borrado de categoría por sync
con el detalle abierto sigue sin cubrir.

