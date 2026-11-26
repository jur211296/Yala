//
//  ScheduledPaymentsUpcomingLogic.swift
//  Yala
//
//  «Próximos» del widget de Pagos planificados del Panel (observación del iPhone 14, 25-nov-2026; opción 1 de Jürgen).
//  El widget calculaba solo las fechas del mes a la vista: un pago creado después de su fecha de este mes (el paso 4 de
//  Primeros pasos, «Películas y series» el 20 de diciembre) no salía, y el widget decía «Sin pagos próximos» justo
//  después de que la persona aceptara verlo en su Panel. Ahora la lista de próximos sigue con el siguiente vencimiento de
//  cada pago que ya no tiene nada pendiente este mes, aunque caiga el mes que viene. Lo de «este mes» (el total, lo
//  pagado, el anillo y lo que falta pagar) no cambia: sigue siendo del mes.
//

import Foundation

enum ScheduledPaymentsUpcomingLogic {

    /// Cuántos próximos enseña el widget.
    static let maxItems = 3

    /// Cuántos meses se busca hacia adelante: cubre un pago anual y uno «cada 2 años» sin recorrer la eternidad.
    static let monthsAhead = 24

    /// Solo se mira más allá del mes cuando el mes a la vista es el de hoy: «próximos» es desde hoy. Con «Mes pasado» o un
    /// rango propio el widget sigue enseñando lo de ese mes.
    static func looksAhead(displayMonth: Date, now: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(displayMonth, equalTo: now, toGranularity: .month)
    }

    /// El primer vencimiento sin saltar de los meses SIGUIENTES al de `month`, o `nil` si no hay ninguno en `monthsAhead`
    /// meses (un pago de una vez ya pasado, una fecha de fin).
    static func nextOccurrence(
        afterMonthOf month: Date,
        params: ScheduledPaymentDateCalculator.PaymentParams,
        isSkipped: (Date) -> Bool,
        calendar: Calendar = .current
    ) -> Date? {
        guard let monthStart = calendar.dateInterval(of: .month, for: month)?.start else { return nil }
        for offset in 1...monthsAhead {
            guard let next = calendar.date(byAdding: .month, value: offset, to: monthStart) else { break }
            let dates = ScheduledPaymentDateCalculator.paymentDatesInMonth(params: params, month: next, calendar: calendar)
            if let first = dates.sorted().first(where: { !isSkipped($0) }) { return first }
        }
        return nil
    }
}
