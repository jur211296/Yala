---
id: group-expense-draft-is-deleted-with-its-sheet-open-when-the-expense-is-gone
status: backlog
priority: low
area: "inbox, groups"
created: 2026-10-24
updated: 2026-10-24
source: "review adversarial del lote 12.1 Grupos (card 9o4n)"
---

# Si el gasto de grupo desaparece mientras su borrador está abierto, el borrador se borra con la hoja montada

## Qué pasa

`DraftService.approveGroupExpenseAccountDraft`, cuando no encuentra el `SplitExpense` (un borrado remoto que llegó con
la hoja de la Bandeja abierta), borra y guarda el borrador y lanza `missingAccount`. La hoja
(`GroupExpenseAccountFinalizationSheet` / `…AndSubcategoryFinalizationSheet`) no se cierra: pinta su alerta leyendo el
`InboxDraft` ya borrado, que es el SIGTRAP de SwiftData que `InboxRowPruneCoordinator` documenta (iOS 27). La poda de la
fila protege la lista, no la hoja.

Es una carrera rara de sync. El caso frecuente de la misma familia (el segundo borrador de un gasto ya registrado, card
9o4n) se arregló el 2026-10-24 retirando el borrador al cerrar la hoja (`retireGroupExpenseDraftIfAlreadyRegistered`).

## Por dónde va

El mismo molde: lanzar sin borrar (y con su propio error, `groupExpenseTargetMissing`, que ya existe) y retirar el
borrador al desaparecer la hoja.
