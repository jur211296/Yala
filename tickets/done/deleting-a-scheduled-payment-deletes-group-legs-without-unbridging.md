---
id: deleting-a-scheduled-payment-deletes-group-legs-without-unbridging
status: done
priority: medium
area: "grupos, pagos planificados"
created: 2026-11-09
updated: 2026-11-22
source: "review adversarial de `convert-personal-expense-to-group-from-the-editor` (2026-11-09), lente de invariantes del puente"
---

# Borrar un pago planificado se lleva la pata real de un gasto de grupo y deja el préstamo solo

## El problema, en lenguaje de usuario

Si un registro de un pago planificado de este mes es la pata real de un gasto de grupo, y luego se borra el pago
planificado, el registro desaparece pero el gasto del grupo y su «Préstamo a grupos» se quedan. El saldo personal sube
por lo que te deben, sin el gasto que lo compensa, y en la siguiente pasada del puente sale un borrador «Elige cuenta» en
la Bandeja.

## Por qué pasa (leído el 2026-11-09; no ejecutado)

`EntityDeletionService` (paso 3 del borrado de un pago planificado) hace `context.delete(tx)` a los registros con
`scheduledPaymentID` del mes en curso o posteriores, sin mirar `splitExpenseID` ni pasar por el puente.

## Desde cuándo

Ya pasaba con las patas de los gastos de grupo recurrentes (`ScheduledPaymentDraftService`). Desde 2.3, «Convertir a gasto
compartido» lo hace alcanzable con cualquier pago planificado personal.

## Qué haría falta

Al borrar, soltar el enlace de grupo del registro (o no borrar los registros que son pata real de un gasto vivo) y
decidir con Jürgen qué esperar del gasto del grupo.

## Resolución

Hecho el 2026-11-22 (encargo «Grupos: un guardado que falla no duplica gastos…»). Medido antes en `origin/2.3`:
seguía pasando. Decidido sin consultar (el encargo ya fijaba el resultado): al borrar el pago planificado, un registro
que es pata de Grupos (`splitExpenseID` o `splitSettlementID`) se DESVINCULA del pago, en cualquier mes, en vez de
borrarse; el gasto del grupo no se toca. Descartado: borrar el registro y desmontar el puente (el gasto del grupo se
quedaría sin el dinero que pagaste) y borrar el gasto del grupo (afecta a los demás miembros). Lo fija
`deletingAScheduledPayment_keepsTheGroupLeg` en `YalaTests/GruposGuardadoFallido/GruposGuardadoFallidoTests`.
