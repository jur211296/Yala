---
id: one-off-scheduled-payment-row-says-monthly
status: qa
priority: medium
area: "pagos-programados"
created: 2026-10-14
updated: 2026-10-14
source: "auditoría UX 2.2 · lote 4 (voz, foto, compartir y la Bandeja), 2026-10-14; encontrado fuera del lote"
---

# Un pago planificado «una sola vez» sale como «Mensual» en la lista

## Qué le pasa al usuario

En Planificación › Pagos planificados, un pago de una sola vez lleva la etiqueta «Mensual». Quien lo creó para un solo
mes cree que se va a repetir.

## Medido y leído

- **Medido** (2026-10-14, iPhone 17 Pro, iOS 27.0): con `-uitest-scheduled-due-today`, el pago «Recibo vence hoy» se
  siembra con `isRecurring: false` y `recurrenceType: "monthly"`; su fila dice «Hoy · Cuenta Principal · Mensual».
- **Leído, sin medir con un pago creado a mano:** `ScheduledPaymentRowView.recurrenceBadge` pinta
  `RecurrenceType(rawValue: recurrenceType).localizedName` sin mirar `isRecurring`, y
  `ScheduledPaymentEditorViewModel` guarda `recurrenceType` aunque `isRecurring` sea `false`. Si el formulario deja
  «Mensual» elegido por defecto al marcar «Una sola vez», un pago real sale igual.

## Hecho cuando

Un pago con `isRecurring == false` dice «Una vez» (o nada) en su fila, con test, y se comprueba creando uno a mano.

## Arreglado (2026-10-14, auditoría UX 2.2, lote 10, B1)

La fila de la lista, el detalle, Ajustes › Pagos planificados y el flujo de caja nombran la frecuencia con una sola regla (`ScheduledPaymentDetailLogic.frequencyText`): «Una sola vez», «Mensual» o «Cada 2 meses». Medido en el simulador creando un pago «una sola vez» a mano (`B1-despues-lista.png` en la entrega del lote 10). Tests: `ScheduledPaymentDetailLogicTests`, `ScheduledPaymentWiringTests`. Falta el QA en un iPhone.

Es el mismo bug que `scheduled-payment-once-labeled-monthly`.
