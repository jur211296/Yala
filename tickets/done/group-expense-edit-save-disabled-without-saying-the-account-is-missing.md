---
id: group-expense-edit-save-disabled-without-saying-the-account-is-missing
status: done
updated: 2026-10-04
priority: medium
area: "groups"
created: 2026-10-04
source: recorrido de group-expense-views-redesign (2026-10-04)
qa-status: absorbed
qa-date: 2026-10-04
qa-notes: barrido 2026-10-04 - su comprobacion es el paso 5 de group-expense-views-redesign (R11 del guion), que sigue en qa
---

# Al editar un gasto de grupo, «Guardar» queda apagado sin decir que falta la cuenta

## El problema, en lenguaje de usuario

Abres un gasto que pagaste tú, tocas Editar y el botón Guardar sale gris aunque no hayas cambiado
nada. No hay ningún aviso: el único indicio es un chip «Cuenta» abajo, igual que el de
«Subcategoría», que no parece obligatorio.

Visto en el simulador (seed `grupos`, «Viaje a Lima» › «Hotel Miraflores»):
`~/Claude/worktrees/_capturas/2026-10-04-mejorar-vistas-del-registro-en-grupos/antes-6-editar-dos-personas.png`.

## Por qué pasa (medido en el código)

`GroupExpenseViewModel.canSave` exige cuenta cuando pagaste tú y el puente con tus finanzas está
activo (`isAccountRequired`). Al editar, `resolveSelectedAccountForCaseA` busca la cuenta en el
movimiento personal enlazado; si ese movimiento todavía no existe (no llegó por sync, o el gasto se
creó antes de activar el puente), la cuenta queda vacía y Guardar se apaga. Es intencionado; lo que
falta es decirlo.

Inferido, no medido en un dispositivo: en el seed el caso sale porque el gasto no tiene movimiento
personal enlazado.

## Qué haría falta

Que el formulario diga qué falta (el chip Cuenta marcado como pendiente, o un aviso al tocar Guardar
como ya hace el monto con `amountRequiredTitle`). Si se elige la propuesta B de
`group-expense-views-redesign`, cabe en el mismo trabajo.

## Resuelto en `group-expense-views-redesign` (2026-10-04)

La cuenta pasó a la tarjeta «Pagado por · Reparto» del formulario, siempre visible cuando pagaste tú, y sin
cuenta dice «Selecciona una cuenta» con el icono de aviso. Pin: `GroupsSmokeUITests#test_groupExpenseAccountRowFollowsThePayer`.
QA en el iPhone: paso 5 del guion de `group-expense-views-redesign`.

## Barrido de `qa` · 2026-10-04 · absorbido

Sale de la cola de device-QA por el barrido antes del QA del lunes (encargo `2026-10-04-barrido-qa-antes-del-qa-del-lunes`). Se arregló dentro de `group-expense-views-redesign`, y su comprobación entera —un gasto que pagaste tú sin cuenta enlazada dice «Selecciona una cuenta» con aviso y Guardar apagado— es el paso 5 de ese ticket, que sigue en `qa` como R11 del guion.
