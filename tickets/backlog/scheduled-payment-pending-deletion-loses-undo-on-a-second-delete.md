---
id: scheduled-payment-pending-deletion-loses-undo-on-a-second-delete
status: backlog
priority: low
area: "planning, deletion"
created: 2026-10-25
updated: 2026-10-25
source: "cola 2.2 · lote 12.5, al cerrar record-pending-deletion-still-counts-outside-records"
---

# Un pago planificado que espera su borrado pierde su «Deshacer» si borras otro, y sigue contando fuera de la lista

## Qué pasa (leído en el código de `2.2`, sin medir en pantalla)

`ScheduledPaymentPendingDeletion` es el molde del que salió el borrado de registros (L10-15), y conserva los tres huecos
que el lote 12.5 cerró en `RecordPendingDeletion`:

1. **Un segundo borrado le quita el «Deshacer» al primero**: `DraftDiscardUndoNotice.show` llama a `hide()`, y el
   primer pago se borra a los 5 s sin botón.
2. **Mientras espera, el pago sigue fuera de la lista**: solo lo esconde `ScheduledPaymentsViewModel.loadPayments`; el
   Panel (pagos del mes, salud financiera), los widgets y el flujo de caja lo siguen contando.
3. **El borrado vence a la vez que el aviso** (`undoWindow`, sin margen): un «Deshacer» tocado al final puede llegar
   tarde. En registros espera `undoWindow + 400 ms` (review adversarial del 2026-10-20).

## Arreglo

El de registros (`RecordPendingDeletion`, 2026-10-25): un plazo compartido con aviso «Eliminaste N pagos · Deshacer»
que devuelve todos, `visible(_:)` en las cargas que cuentan pagos, y el margen de 400 ms. Con test de lógica y XCUITest
de dos borrados seguidos.
