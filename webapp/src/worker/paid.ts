/**
 * «Ya pagado» en los próximos cobros (lote 2b), con la regla de la lista de Pagos planificados del iPhone:
 *
 * - `ScheduledPaymentPaidStatusHelper.loadPaidAmounts` cuenta, en el mes, los borradores aprobados
 *   (`sourceScheduledPaymentID`) y los movimientos enlazados al pago (`scheduledPaymentID`). Un movimiento del mismo
 *   pago y día que un borrador aprobado no se cuenta otra vez; dos movimientos del mismo día, sí (cada uno es una pieza).
 * - `ScheduledPaymentsViewModel.calculatePaymentData` reparte esas N piezas entre las fechas del mes por orden: la
 *   primera fecha no saltada se lleva la primera, y así. Una fecha saltada no gasta ninguna.
 *
 * Aquí solo entran los movimientos enlazados: aprobar un borrador enlaza su movimiento al pago
 * (`ScheduledPaymentDraftService.handleDraftApproved`), así que lo aprobado ya está. Diferencias que quedan, aceptadas
 * (decisión 2 del Paso 0 del ticket `yala-web-lote-2b`; el rol de la web no lee `inbox_drafts.source_scheduled_payment_ref`):
 * un borrador aprobado cuyo movimiento se borró después, o cuyo movimiento se guardó con otra fecha, cuenta para el
 * iPhone y no para la web.
 *
 * El mes es el mes civil en la zona de la persona, y el día de un movimiento es el que se enseña (`txDay`: `local_day` si
 * el teléfono lo mandó), como en el resto de la web. El iPhone mira `date` en la zona que tenga ahora: un movimiento
 * guardado en otra zona justo al cambiar de mes puede caer en un mes distinto (medido por la revisión del lote 2b).
 */
import { monthStart, txDay, type Day } from "../../../shared-core/src/logic/dates";
import { paymentDatesInMonth, skipKey, skippedKeys, type ScheduleRow } from "../../../shared-core/src/logic/schedule";

export interface LinkedTx {
  scheduled_payment_ref: string | null;
  date: string | null;
  local_day: string | null;
}

/** Clave de una fecha de cobro: pago y día. */
export function chargeKey(id: string, day: Day): string {
  return `${id.toLowerCase()}|${day}`;
}

/**
 * Las fechas de cobro pagadas de los meses que empiezan en `months`, como claves `pago|día`.
 * `months`: primeros días de mes (`YYYY-MM-01`).
 */
export function paidCharges(payments: ScheduleRow[], linked: LinkedTx[], months: Day[], tz: string, firstWeekday: 1 | 2): Set<string> {
  // Piezas de pago por (pago, mes). Sin borradores no hay nada que deduplicar: cada movimiento es una pieza.
  const wanted = new Set(months);
  const pieces = new Map<string, number>();
  for (const tx of linked) {
    const id = tx.scheduled_payment_ref?.trim().toLowerCase();
    if (!id) continue;
    const day = txDay(tx, tz);
    if (!day) continue;
    const month = monthStart(day);
    if (!wanted.has(month)) continue;
    const key = `${id}|${month}`;
    pieces.set(key, (pieces.get(key) ?? 0) + 1);
  }

  const paid = new Set<string>();
  for (const p of payments) {
    const id = p.sync_id.toLowerCase();
    const skipped = skippedKeys(p);
    for (const month of months) {
      let left = pieces.get(`${id}|${month}`) ?? 0;
      if (left === 0) continue;
      for (const d of [...paymentDatesInMonth(p, month, tz, firstWeekday)].sort()) {
        if (left === 0) break;
        if (skipped.has(skipKey(d, tz))) continue;
        paid.add(chargeKey(id, d));
        left -= 1;
      }
    }
  }
  return paid;
}
