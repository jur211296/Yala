---
id: group-expense-draft-is-deleted-with-its-sheet-open-when-the-expense-is-gone
status: done
priority: low
area: "inbox, groups"
created: 2026-10-24
updated: 2026-10-28
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

## Hecho (2026-10-28, card ouka)

El molde de 9o4n, en los DOS caminos de `approveDraft` que borraban con la hoja montada: el borrador de cuenta con el
gasto ausente (antes lanzaba `missingAccount`) y el borrador-puntero de subcategoría sin ninguna transacción del gasto.
Los dos lanzan `groupExpenseTargetMissing` sin tocar el borrador; las tres hojas (`GroupExpenseAccount…`,
`…AndSubcategory…` y `GroupExpenseDraftFinalizationSheet`) apuntan el motivo (`GroupExpenseDraftRetirement`), el «OK» las
cierra y al desaparecer llaman a `retireGroupExpenseDraftIfTargetGone`, que vuelve a medir con el mismo criterio. El enlace
(«¿Ya lo apuntaste?») con el gasto ausente también lo retira al cerrar. Tests: `GroupExpenseSecondAccountDraftTests`
(gasto borrado con la hoja abierta en los dos caminos, controles y el scan de las tres hojas).

Review adversarial (2026-10-28): aprobar en bloque o deslizando, que no tienen hoja, retiran en el acto el borrador sin
gasto (`retireStaleGroupExpenseDraftWithoutSheet`), como antes.
