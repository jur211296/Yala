//
//  RecurringProposalPlan.swift
//  Yala
//
//  De una propuesta a los datos del pago planificado que se crea (lote S1). Puro: lo usa la hoja de propuesta para
//  llamar a `ScheduledPaymentEditorViewModel.savePayment`, el mismo guardado del editor, y lo fijan los tests.
//

import Foundation

struct RecurringProposalPlan: Equatable {

    /// Cuándo avisar. La maqueta propone «1 día antes» (con el aviso del mismo día, como el editor).
    enum Reminder: Int, CaseIterable, Identifiable {
        case none = -1
        case sameDay = 0
        case oneDay = 1
        case threeDays = 3
        case oneWeek = 7

        var id: Int { rawValue }
        var notifyOnDueDate: Bool { self != .none }
        var notifyDaysBefore: Int { max(rawValue, 0) }

        static let `default`: Reminder = .oneDay
    }

    let recurrenceType: RecurrenceType
    let dayOfMonth: Int?
    let weekdays: Set<Int>
    let paymentDate: Date
    let paymentCategory: PaymentCategory
    let isVariableAmount: Bool
    let notifyOnDueDate: Bool
    let notifyDaysBefore: Int

    /// `firstCharge` es la fecha que la persona dejó en «Próximo cobro» (por defecto, la que calculó el detector). El
    /// día del mes o de la semana sale de ella: si la mueve, el pago se repite desde ahí.
    init(
        proposal: RecurringPaymentDetector.Proposal,
        firstCharge: Date,
        reminder: Reminder,
        calendar: Calendar = .current
    ) {
        let start = calendar.startOfDay(for: firstCharge)
        switch proposal.cadence {
        case .monthly(let typicalDay, _):
            recurrenceType = .monthly
            dayOfMonth = Self.dayOfMonth(firstCharge: start, typicalDay: typicalDay, calendar: calendar)
            weekdays = []
        case .weekly:
            recurrenceType = .weekly
            dayOfMonth = nil
            weekdays = [calendar.component(.weekday, from: start)]
        }
        paymentDate = start
        paymentCategory = proposal.isSubscriptionBrand ? .subscription : .recurring
        isVariableAmount = proposal.isVariableAmount
        notifyOnDueDate = reminder.notifyOnDueDate
        notifyDaysBefore = reminder.notifyDaysBefore
    }

    /// El día del mes que se guarda. Si la fecha elegida es el último día de un mes corto y el día típico no cabía en él
    /// (cobros el 31, próximo el 30 de noviembre), se guarda el típico: el calendario ya lo acorta en cada mes corto, y
    /// guardar el 30 dejaría el pago un día antes para siempre.
    static func dayOfMonth(firstCharge: Date, typicalDay: Int, calendar: Calendar) -> Int {
        let chosen = calendar.component(.day, from: firstCharge)
        guard typicalDay > chosen,
              let monthLength = calendar.range(of: .day, in: .month, for: firstCharge)?.count,
              chosen == monthLength else { return chosen }
        return typicalDay
    }

    /// El primer aviso que recibirá: los días de antes, o el mismo día si esos días ya pasaron. `nil` sin aviso.
    static func firstReminderDate(
        dueDate: Date, reminder: Reminder, now: Date = .now, calendar: Calendar = .current
    ) -> Date? {
        guard reminder != .none else { return nil }
        let due = calendar.startOfDay(for: dueDate)
        guard let before = calendar.date(byAdding: .day, value: -reminder.notifyDaysBefore, to: due) else { return due }
        return before >= calendar.startOfDay(for: now) ? before : due
    }
}
