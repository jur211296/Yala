---
id: opening-balance-replaced-without-asking-and-its-locked-error-talks-about-deleting
status: done
priority: medium
area: groups, opening-balance
created: 2026-11-10
updated: 2026-11-10
source: revisión por vistas 2.3 de Grupos (zona 37), PR #856 · lote 01 de las mejoras necesarias 2.3
qa-status: passed
qa-date: 2026-11-10
qa-notes: xcuitest GroupOpeningBalanceAdminUITests test_addingASecondOpeningBalanceBetweenTheSamePair_asksBeforeReplacing
---

# Añadir un saldo inicial entre dos personas que ya tienen uno lo reemplazaba sin avisar

La revisión 2.3 de Grupos lo leyó en el código: «Añadir saldo inicial» entre dos personas que ya tienen uno en esa moneda
(en cualquier sentido) edita el que había sin decir nada; y con pagos confirmados, el error de editar o quitar un saldo
inicial hablaba de «borrar el gasto».

## Resuelto (2026-11-10)

- El formulario pregunta antes de reemplazar: «Ya hay un saldo inicial entre Ana y Beto · Ahora dice: Beto le debe a Ana ·
  S/ 75.00» con «Cancelar» y «Reemplazar». Lo que se guarda al confirmar no cambia
  (`GroupExpenseService.openingBalanceThatAddingWouldReplace` sigue el mismo camino que `setOpeningBalance`, guard de
  pagos compartido en `openingBalanceEditIsLocked`). Si un pago confirmado no deja editar el que había, el nuevo va aparte
  y no se pregunta, como antes.
- Con pagos confirmados, editar o quitar un saldo inicial dice «Quienes están en este saldo inicial ya tienen pagos
  confirmados, así que ya no se puede cambiar ni quitar.» (16 idiomas).

Lo fijan `OpeningBalanceReplacePromptTests`, `GroupsNecesarias23Lote01Tests` y el XCUITest de arriba. Evidencia:
`~/Claude/entregas/2026-11-10-lote-2-3-grupos-cifras-planificacion/evidencia/antes-4-saldo-inicial-reemplaza-sin-avisar.png`, `~/Claude/entregas/2026-11-10-lote-2-3-grupos-cifras-planificacion/evidencia/despues-4-saldo-inicial-pregunta.png`.
