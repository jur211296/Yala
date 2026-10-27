---
id: groups-fab-group-with-only-pending-groups-says-nothing
status: done
area: groups
priority: medium
created: 2026-10-21
updated: 2026-10-27
source: auditoría UX 2.2 · L13-8 (lo que la decisión B no cubre)
---

# «Grupo» del botón + con grupos solo pendientes de aprobación no abre nada ni avisa

## Qué pasa

L13-8 B (implementada el 2026-10-21) cubre a quien no tiene **ningún** grupo: una hoja dice «Para dividir un gasto,
primero crea un grupo». Quien tiene grupos pero todos esperando aprobación (o archivados) sigue como antes: el
toque lleva a la pestaña Grupos, `pendingNewGroupExpense` queda puesto sin consumirse
(`GroupsContainerView.openExpenseComposerIfRequested` exige un grupo elegible) y no se dice nada. El gasto
salta solo cuando el grupo se aprueba, aunque sea horas después.

## Qué haría falta decidir

Qué ve esa persona: el aviso de «esperando aprobación» que ya existe en la pestaña
(`showPendingApprovalNotice`), una variante de la hoja nueva, u otra cosa. Es UI: va a Jürgen con opciones.

## Contexto

- Condición de la hoja nueva: `FABStackView.hasNoActiveGroups()` (sin archivados ni borrados para todos).
- Eligibilidad del gasto: `GroupsViewModel.eligibleGroupsForExpense()`.

## Cierre (2026-10-27, PR #654)

Decisión de Jürgen (2026-10-26): reutilizar el aviso de la pestaña. Sin grupo donde apuntar y con alguno pendiente de
aprobación, «Grupo» del + enseña «Esperando aprobación» y retira la petición (recarga una vez antes de decidir). Solo
archivados, sin pendientes: sigue la hoja de L13-8. Red:
`GroupPendingMemberDoorUITests#test_panelGroupWithOnlyPendingGroup_explainsInsteadOfWaiting` (rojo sobre la base);
control: `GroupsSmokeUITests#test_groupExpenseFromPanelFAB`.
