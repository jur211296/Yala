---
id: yearly-scheduled-payment-on-feb-29-skips-common-years
status: done
priority: low
area: "scheduled-payments, dates"
created: 2026-10-14
updated: 2026-11-05
card: tablero-pagos-planificados-adelantar-gasto-ofrec-flvl
source: "auditoría UX 2.2 · lote 10 (pagos planificados)"
---

# Un pago anual el 29 de febrero no tiene fecha en los años no bisiestos

Visto por la review adversarial del lote 10 (2026-10-14) y comprobado con `DateFormatter`: en `ScheduledPaymentDateCalculator.yearlyDates`, `Calendar.date(from:)` convierte el 29-feb de un año no bisiesto en el 1-mar, así que el respaldo «último día del mes» nunca corre y ese año se queda sin fecha. Con el arreglo B10 del lote 10, un pago así creado el 14-oct-2026 guarda como primer vencimiento el 29-feb-2028: 2027 no tiene borrador ni aviso.

## Hecho cuando

En un año no bisiesto el pago cae el 28 de febrero, con test.

## Resolución (2026-11-05, lote P1)

Medido, eran dos fallos: el calendario no daba fecha en 2027, y además `advanceToNextDueDate` sumaba un año con `byAdding`,
que deja el 28 y ya no vuelve al 29 (2032 caía el 28). Ahora `ScheduledPaymentDateCalculator.yearlyDate` acota el día al
largo del mes y lo usan el calendario, el avance y la vuelta atrás de `ScheduledDraftOccurrenceLogic` (que gana
`Schedule.yearlyDay`): 28-feb en los años comunes y 29 en los bisiestos. Cuatro tests unitarios, los cuatro rojos con la
lógica vieja.
