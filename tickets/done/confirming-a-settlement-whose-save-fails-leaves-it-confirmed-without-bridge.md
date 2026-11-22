---
id: confirming-a-settlement-whose-save-fails-leaves-it-confirmed-without-bridge
status: done
priority: medium
area: groups, settlements, bridge
created: 2026-11-10
updated: 2026-11-22
source: lote 01 de las mejoras necesarias 2.3 (Grupos)
---

# Confirmar un pago cuyo guardado falla lo deja confirmado en memoria y sin su movimiento personal

Lo encontró la review adversarial del lote 01 de las mejoras necesarias 2.3 (2026-11-10), **no reproducido**:
`GroupExpenseService.confirmSettlement` pone `isConfirmed = true` y, si `context.save()` falla, lanza sin deshacerlo. El
siguiente guardado de cualquier otra cosa escribe el pago confirmado en disco sin haber pasado por el puente, así que no
crea el movimiento personal. Si la persona reintenta confirmar se arregla; si no, el pago queda confirmado sin movimiento.
Lo usa el detalle del grupo al confirmar un pago que apuntó otro (`GroupDetailViewModel.confirmSettlement`).

Cómo verificarlo: test de servicio con un seam que haga fallar ese guardado y un guardado posterior ajeno; mirar
`isConfirmed` en disco y el movimiento del puente. Criterio: un fallo al confirmar no deja el pago confirmado a medias.

## Resolución

Hecho el 2026-11-22 (encargo «Grupos: un guardado que falla no duplica gastos…»). Medido antes en `origin/2.3`:
seguía pasando. `GroupExpenseService.confirmSettlement` devuelve `isConfirmed` a su valor anterior si el guardado falla,
así que un guardado ajeno posterior ya no escribe el pago confirmado sin puente. Seam `_testFailNextConfirmSave`. Lo
fijan `confirmFailedSave_doesNotLeaveTheSettlementConfirmed` (rojo sin el arreglo) y `confirmRetryAfterAFailedSave_confirms`
en `YalaTests/GruposGuardadoFallido/GruposGuardadoFallidoTests`.
