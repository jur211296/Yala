//
//  CreditCardStatementLogic.swift
//  Yala
//
//  El estado de cuenta de una tarjeta de crédito (card nmtk, spec `tickets/.../credit-card-statement-cycle.md`): con el
//  día de corte y el día de pago, qué parte de lo que se debe ya está FACTURADA (cerró en el último corte y hay que
//  pagarla en la fecha de pago) y qué parte está POR FACTURAR (entra en el corte siguiente). Lo usan la ficha de la
//  cuenta, el aviso antes de pagar y el flujo de caja. Pura: sin SwiftData, sin `Date.now` ni `Calendar.current`.
//
//  Definiciones, fijadas en el spec para que nadie las reinvente:
//  - El último corte es el día de corte más reciente que no está en el futuro (hoy incluido).
//  - La fecha de pago es el primer día de pago POSTERIOR a ese corte: si el día de pago no es mayor que el de corte,
//    cae en el mes siguiente. Siempre antes del corte siguiente, así que hay como mucho un pago abierto.
//  - La deuda al corte es el saldo al terminar el día de corte. El límite es EXCLUSIVO (`< inicio del día siguiente`):
//    así un movimiento fechado a medianoche del día después no cae en los dos lados (la trampa del `DateInterval`
//    cerrado del `CLAUDE.md`), y uno fechado a medianoche del día de corte sí entra en el corte.
//  - Lo pagado desde el corte son las ENTRADAS a la tarjeta después del corte y hasta hoy (transferencias, ingresos,
//    devoluciones), sin los ajustes de saldo: un ajuste corrige el saldo, no paga nada.
//  - Facturado = deuda al corte − lo pagado, sin bajar de 0 y sin pasar de la deuda de hoy. Por facturar = lo que
//    falta hasta la deuda de hoy. Los dos suman la deuda de hoy: el «Por pagar» de la ficha no cambia.
//  - Días 1…28, como el día de pago de siempre: todos los meses los tienen.
//

import Foundation

nonisolated enum CreditCardStatementLogic {

    /// Los días que se pueden elegir para el corte y para el pago.
    static let dayRange = 1...28

    /// Las antelaciones del aviso que se ofrecen (D3-A de Jürgen): el mismo día, 1, 3 o 5 días antes.
    static let reminderLeadOptions = [0, 1, 3, 5]

    /// La hora del aviso cuando el usuario no tiene puesto el resumen de pagos planificados (que trae la suya).
    static let defaultReminderHour = 9
    static let defaultReminderMinute = 0

    /// Un día válido, o `nil` si viene de fuera del rango (un dato viejo o de otro teléfono).
    static func validDay(_ day: Int?) -> Int? {
        guard let day, dayRange.contains(day) else { return nil }
        return day
    }

    /// Una antelación válida: las que no se ofrecen se leen como «el mismo día».
    static func validLead(_ days: Int) -> Int {
        reminderLeadOptions.contains(days) ? days : 0
    }

    // MARK: - El ciclo

    struct Cycle: Equatable, Sendable {
        /// Inicio del día del último corte.
        let statementDate: Date
        /// Primer instante que ya NO entra en ese corte (inicio del día siguiente).
        let statementClosesAt: Date
        /// Inicio del día en que hay que pagar lo facturado.
        let paymentDate: Date
        /// Inicio del día del corte siguiente.
        let nextStatementDate: Date
    }

    /// El ciclo vigente a `now`: el del último corte. `nil` si los días no son válidos.
    static func cycle(statementDay: Int, paymentDay: Int, now: Date, calendar: Calendar) -> Cycle? {
        guard dayRange.contains(statementDay), dayRange.contains(paymentDay) else { return nil }
        let today = calendar.startOfDay(for: now)
        let todayParts = calendar.dateComponents([.year, .month, .day], from: today)
        guard let todayDay = todayParts.day,
              let monthStart = calendar.date(from: DateComponents(year: todayParts.year, month: todayParts.month, day: 1))
        else { return nil }
        let statementMonth = todayDay >= statementDay
            ? monthStart
            : calendar.date(byAdding: .month, value: -1, to: monthStart)
        guard let statementMonth else { return nil }
        return cycle(statementMonth: statementMonth, statementDay: statementDay, paymentDay: paymentDay, calendar: calendar)
    }

    /// El ciclo siguiente al vigente (su corte aún no ha llegado).
    static func nextCycle(after cycle: Cycle, statementDay: Int, paymentDay: Int, calendar: Calendar) -> Cycle? {
        shifted(cycle, by: 1, statementDay: statementDay, paymentDay: paymentDay, calendar: calendar)
    }

    /// El ciclo anterior al vigente. Solo importa con el día de pago IGUAL al de corte: su pago cae el día del corte
    /// siguiente, y ese día el ciclo vigente ya es el nuevo (lo cazó la review).
    static func previousCycle(before cycle: Cycle, statementDay: Int, paymentDay: Int, calendar: Calendar) -> Cycle? {
        shifted(cycle, by: -1, statementDay: statementDay, paymentDay: paymentDay, calendar: calendar)
    }

    private static func shifted(_ cycle: Cycle, by months: Int, statementDay: Int, paymentDay: Int,
                                calendar: Calendar) -> Cycle? {
        let parts = calendar.dateComponents([.year, .month], from: cycle.statementDate)
        guard let month = calendar.date(from: DateComponents(year: parts.year, month: parts.month, day: 1)),
              let target = calendar.date(byAdding: .month, value: months, to: month)
        else { return nil }
        return self.cycle(statementMonth: target, statementDay: statementDay, paymentDay: paymentDay, calendar: calendar)
    }

    private static func cycle(statementMonth: Date, statementDay: Int, paymentDay: Int, calendar: Calendar) -> Cycle? {
        guard let statement = day(statementDay, inMonthOf: statementMonth, calendar: calendar),
              let closes = calendar.date(byAdding: .day, value: 1, to: statement),
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: statementMonth),
              let nextStatement = day(statementDay, inMonthOf: nextMonth, calendar: calendar)
        else { return nil }
        let paymentMonth = paymentDay > statementDay ? statementMonth : nextMonth
        guard let payment = day(paymentDay, inMonthOf: paymentMonth, calendar: calendar) else { return nil }
        return Cycle(statementDate: statement, statementClosesAt: calendar.startOfDay(for: closes),
                     paymentDate: payment, nextStatementDate: nextStatement)
    }

    private static func day(_ day: Int, inMonthOf month: Date, calendar: Calendar) -> Date? {
        let parts = calendar.dateComponents([.year, .month], from: month)
        guard let date = calendar.date(from: DateComponents(year: parts.year, month: parts.month, day: day)) else { return nil }
        return calendar.startOfDay(for: date)
    }

    // MARK: - El estado de cuenta

    /// Un movimiento de la tarjeta (de UNA línea: cada divisa se factura por separado).
    struct Entry: Equatable, Sendable {
        let date: Date
        let amount: Double
        /// Saldo inicial o ajuste de saldo (`balanceAdjustmentType != nil`): cuenta en el saldo, no como pago.
        let isBalanceAdjustment: Bool
    }

    struct Statement: Equatable, Sendable {
        /// Lo que se debía al cerrar el último corte.
        let debtAtStatement: Double
        /// Lo que entró en la tarjeta después del corte y hasta hoy.
        let paidSinceStatement: Double
        /// Lo que se debe hoy (el «Por pagar» de la ficha).
        let debtToday: Double
        /// Lo que falta pagar de ese corte.
        let billed: Double
        /// Lo gastado desde el corte que aún no se ha facturado.
        let unbilled: Double
    }

    static func statement(entries: [Entry], cycle: Cycle, now: Date, calendar: Calendar) -> Statement {
        let startOfTomorrow = calendar.dateInterval(of: .day, for: now)?.end
            ?? calendar.startOfDay(for: now).addingTimeInterval(86_400)
        var atStatement = Decimal(0)
        var today = Decimal(0)
        var paid = Decimal(0)
        for entry in entries where entry.date < startOfTomorrow {
            let amount = Decimal(entry.amount)
            today += amount
            if entry.date < cycle.statementClosesAt {
                atStatement += amount
            } else if entry.amount > 0 && !entry.isBalanceAdjustment {
                paid += amount
            }
        }
        let debtAtStatement = max(0, -atStatement)
        let debtToday = max(0, -today)
        let billed = min(debtToday, max(0, debtAtStatement - paid))
        let unbilled = max(0, debtToday - billed)
        return Statement(
            debtAtStatement: rounded(debtAtStatement), paidSinceStatement: rounded(paid), debtToday: rounded(debtToday),
            billed: rounded(billed), unbilled: rounded(unbilled))
    }

    private static func rounded(_ value: Decimal) -> Double {
        var input = value
        var output = Decimal()
        // 3 decimales: limpia el ruido de pasar `Double` a `Decimal` sin recortar las divisas de 3 (KWD, BHD…).
        NSDecimalRound(&output, &input, 3, .plain)
        return (output as NSDecimalNumber).doubleValue
    }

    // MARK: - Qué dice la línea de «Facturado»

    enum BilledStatus: Equatable, Sendable {
        /// Queda algo por pagar y la fecha de pago es hoy o después.
        case payBy(Date)
        /// Queda algo por pagar y la fecha de pago ya pasó.
        case overdue(Date)
        /// No queda nada de ese corte.
        case settled
    }

    static func billedStatus(billed: Double, cycle: Cycle, now: Date, calendar: Calendar) -> BilledStatus {
        guard billed > 0 else { return .settled }
        return cycle.paymentDate >= calendar.startOfDay(for: now) ? .payBy(cycle.paymentDate) : .overdue(cycle.paymentDate)
    }

    // MARK: - El aviso antes de pagar

    /// Un importe de una línea de la tarjeta, en su divisa.
    struct LineAmount: Equatable, Sendable {
        let amount: Double
        let currencyCode: String
    }

    /// Un aviso que hay que dejar programado.
    struct Reminder: Equatable, Sendable {
        /// Día del aviso (inicio del día), y su clave `yyyyMMdd` para el identificador y el dedup.
        let day: Date
        let fireDate: Date
        /// La fecha de pago a la que avisa.
        let paymentDate: Date
        /// `nil` = el corte de ese pago aún no ha cerrado (o la tarjeta no tiene día de corte): el aviso va sin importe.
        let amounts: [LineAmount]?
        /// Días entre el aviso y el pago (0 = el mismo día).
        let leadDays: Int
    }

    /// Los avisos pendientes de una tarjeta, en orden: como mucho el del pago abierto y el del siguiente. Incluye uno de
    /// HOY cuya hora ya pasó (`fireDate <= now`): quien programa decide si lo manda ya o ya salió.
    ///
    /// - `billed`: lo facturado de un ciclo ya cerrado, por línea. Solo se llama con ciclos cuyo corte cerró. Un aviso
    ///   cuyas líneas están todas en 0 no se programa: ya está pagado (o no hubo gasto).
    /// - Sin día de corte el aviso solo puede ser el mismo día del pago y va sin importe (spec).
    static func reminders(
        statementDay: Int?,
        paymentDay: Int,
        leadDays: Int,
        hour: Int,
        minute: Int,
        now: Date,
        calendar: Calendar,
        billed: (Cycle) -> [LineAmount]
    ) -> [Reminder] {
        guard dayRange.contains(paymentDay) else { return [] }
        let today = calendar.startOfDay(for: now)
        var result: [Reminder] = []

        func reminder(payment: Date, lead: Int, amounts: [LineAmount]?) -> Reminder? {
            guard let day = calendar.date(byAdding: .day, value: -lead, to: payment),
                  let fire = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
            else { return nil }
            guard calendar.startOfDay(for: day) >= today else { return nil }
            return Reminder(day: calendar.startOfDay(for: day), fireDate: fire, paymentDate: payment,
                            amounts: amounts, leadDays: lead)
        }

        guard let statementDay = validDay(statementDay) else {
            // Sin corte: el día de pago de este mes y el del siguiente, el mismo día y sin importe.
            let parts = calendar.dateComponents([.year, .month], from: today)
            guard let monthStart = calendar.date(from: DateComponents(year: parts.year, month: parts.month, day: 1)) else { return [] }
            for offset in 0...1 {
                guard let month = calendar.date(byAdding: .month, value: offset, to: monthStart),
                      let payment = day(paymentDay, inMonthOf: month, calendar: calendar),
                      let item = reminder(payment: payment, lead: 0, amounts: nil)
                else { continue }
                result.append(item)
            }
            return result
        }

        let lead = validLead(leadDays)
        guard let current = cycle(statementDay: statementDay, paymentDay: paymentDay, now: now, calendar: calendar) else { return [] }
        let next = nextCycle(after: current, statementDay: statementDay, paymentDay: paymentDay, calendar: calendar)
        let previous = previousCycle(before: current, statementDay: statementDay, paymentDay: paymentDay, calendar: calendar)
        // El anterior solo si su pago aún no ha pasado (pago = corte); en los demás casos ya pasó y `reminder` lo descarta.
        for candidate in [previous, current, next].compactMap({ $0 }) {
            let closed = candidate.statementClosesAt <= now
            var amounts: [LineAmount]?
            if closed {
                let lines = billed(candidate).filter { $0.amount > 0 }
                guard !lines.isEmpty else { continue }
                amounts = lines
            }
            if let item = reminder(payment: candidate.paymentDate, lead: lead, amounts: amounts) {
                result.append(item)
            }
        }
        return result
    }

    /// `yyyyMMdd` en el calendario dado: la clave del aviso de ese día.
    static func dayKey(_ day: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        return String(format: "%04d%02d%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
