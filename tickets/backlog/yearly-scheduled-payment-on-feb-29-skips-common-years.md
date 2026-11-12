---
id: yearly-scheduled-payment-on-feb-29-skips-common-years
status: backlog
priority: low
area: "scheduled-payments, dates"
created: 2026-10-14
updated: 2026-10-14
source: "auditoría UX 2.2 · lote 10 (pagos planificados)"
---

# Un pago anual el 29 de febrero no tiene fecha en los años no bisiestos

Visto por la review adversarial del lote 10 (2026-10-14) y comprobado con `DateFormatter`: en `ScheduledPaymentDateCalculator.yearlyDates`, `Calendar.date(from:)` convierte el 29-feb de un año no bisiesto en el 1-mar, así que el respaldo «último día del mes» nunca corre y ese año se queda sin fecha. Con el arreglo B10 del lote 10, un pago así creado el 14-oct-2026 guarda como primer vencimiento el 29-feb-2028: 2027 no tiene borrador ni aviso.

## Hecho cuando

En un año no bisiesto el pago cae el 28 de febrero, con test.
