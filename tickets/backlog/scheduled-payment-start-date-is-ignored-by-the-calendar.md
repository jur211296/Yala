---
id: scheduled-payment-start-date-is-ignored-by-the-calendar
status: backlog
priority: medium
area: "scheduled-payments, dates"
created: 2026-10-14
updated: 2026-10-14
source: "auditoría UX 2.2 · lote 10 (pagos planificados)"
---

# La «Fecha de inicio» de un pago no limita su calendario: la lista enseña fechas anteriores

Visto por la review adversarial del lote 10 (2026-10-14), en el código: el calendario de un pago (`ScheduledPaymentDateCalculator.applyPostFilters`) solo descarta las fechas anteriores a `createdAt`, no a la fecha de inicio, que no se guarda aparte (es el primer `nextDueDate`). Un pago creado hoy con inicio el 1 de enero enseña en la lista y en los totales las fechas de noviembre y diciembre, que nunca generan borrador. Relacionado: si la fecha de fin cae antes de la primera fecha del pago, el editor guarda la de inicio como primer vencimiento y nace un borrador ese día. Arreglarlo bien pide guardar la fecha de inicio (campo nuevo, migración y sync).

## Hecho cuando

Las fechas anteriores a la de inicio no salen en la lista, el calendario ni los totales, con test.
