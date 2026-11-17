---
id: ia-guided-payment-as-a-group-expense
status: backlog
priority: low
area: ai
created: 2026-11-16
updated: 2026-11-16
source: encargo 2026-11-16-guiados-mejoras (opciones avanzadas del guiado de pago)
---
# El guiado de pago de Yala IA no pregunta «¿es un gasto de grupo?»

Jürgen pidió (16-nov) que las opciones avanzadas del guiado de pago planificado incluyan, entre otras, si es un gasto
compartido o de grupo. El editor de pagos lo tiene (`ScheduledPaymentEditorView`, `isGroupExpense`): elegir el grupo,
la moneda del grupo, el reparto entre miembros (`GroupExpenseViewModel`, partes que tienen que cuadrar) y guardar tu
parte como monto con el total aparte (`splitTotalAmount`, `groupZoneID`, `splitType`, `splitParticipantIDs`,
`splitValues`), sin cuenta ni categoría propias.

Se dejó fuera del lote porque toca el puente de Grupos (SplitExpense ↔ TransactionItem), donde un error sale caro y el
reparto no cabe en una pregunta de chips: el guiado tendría que preguntar grupo, reparto y moneda, y validar que las
partes cuadren igual que el editor.

## Qué haría falta

- Una pregunta «¿Lo pagan entre varios en un grupo?» con los grupos visibles; con uno elegido, reparto en partes
  iguales entre todos los miembros como propuesta y «Cambiar reparto» que abra el editor del reparto que ya existe.
- Guardar por `ScheduledPaymentEditorViewModel.savePayment` con los mismos campos que el editor.
- Review adversarial (puente de Grupos) y XCUITest con el seed de grupos.
