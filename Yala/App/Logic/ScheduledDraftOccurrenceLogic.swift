//
//  ScheduledDraftOccurrenceLogic.swift
//  Yala
//
//  Qué ocurrencia de un pago programado tiene retenida un borrador de la Bandeja, y qué le pasa a esa
//  ocurrencia cuando el borrador se descarta, vuelve a pendientes o se aprueba. Lógica pura: la usan
//  `DraftService` (descartar, devolver) y `ScheduledPaymentDraftService` (aprobar, barrido de duplicados).
//
//  Ticket `inbox-dismiss-x-does-not-delete-the-draft-for-good`: descartar el borrador de un pago
//  programado personal no saltaba su ocurrencia y `processDuePayments` lo volvía a crear en cada arranque
//  o vuelta a primer plano.
//

import Foundation

enum ScheduledDraftOccurrenceLogic {

    /// Lo que la lógica necesita de un `ScheduledPayment`. Sin `@Model` para poder probarla sin contexto.
    struct Schedule: Equatable {
        let isRecurring: Bool
        let recurrenceType: String
        let recurrenceInterval: Int
        let dayOfMonth: Int?
        let nextDueDate: Date
        let lastPaidDate: Date?
    }

    /// Los orígenes cuyo borrador retiene una ocurrencia de un pago programado.
    static func holdsAnOccurrence(_ sourceType: DraftSourceType) -> Bool {
        sourceType == .scheduledPayment || sourceType == .subscription || sourceType == .groupScheduledExpense
    }

    /// La ocurrencia que retiene un borrador con fecha `draftDate`.
    ///
    /// `processDuePayments` crea el borrador con la fecha de `nextDueDate` y no mueve esa fecha hasta aprobar,
    /// así que un borrador pendiente retiene la próxima fecha del pago (lo mismo que asume `hasExistingDraft`:
    /// un pendiente cubre la próxima ocurrencia). La excepción es el borrador de una ocurrencia que la próxima
    /// fecha ya dejó atrás —volvió a pendientes desde Archivados, o lo creó otro dispositivo antes de saber
    /// que se saltó—: ese retiene la suya. La fecha del borrador solo se usa si cae EXACTAMENTE en el
    /// calendario del pago, porque la persona puede haberla editado y el adelanto (`createAdvancedDraft`) va
    /// fechado hoy.
    static func heldOccurrence(draftDate: Date, schedule: Schedule, calendar: Calendar = .current) -> Date {
        let draftDay = calendar.startOfDay(for: draftDate)
        let pointer = calendar.startOfDay(for: schedule.nextDueDate)
        if draftDay < pointer, isOccurrence(draftDay, before: pointer, schedule: schedule, calendar: calendar) {
            return draftDay
        }
        return pointer
    }

    /// La ocurrencia que hay que SALTAR al descartar (rechazar o borrar) un borrador PENDIENTE, o `nil` si no
    /// hay que saltar nada: el borrador es un duplicado de una ocurrencia que ya se pagó.
    static func occurrenceToSkipOnDismiss(
        draftDate: Date, schedule: Schedule, calendar: Calendar = .current
    ) -> Date? {
        let held = heldOccurrence(draftDate: draftDate, schedule: schedule, calendar: calendar)
        let pointer = calendar.startOfDay(for: schedule.nextDueDate)
        if held < pointer, let lastPaid = schedule.lastPaidDate, calendar.startOfDay(for: lastPaid) >= held {
            return nil
        }
        return held
    }

    /// La ocurrencia que hay que DESHACER del salto al devolver un borrador a pendientes, o `nil`.
    static func occurrenceToRestoreOnReturn(
        draftDate: Date, schedule: Schedule, isSkipped: (Date) -> Bool, calendar: Calendar = .current
    ) -> Date? {
        let held = heldOccurrence(draftDate: draftDate, schedule: schedule, calendar: calendar)
        return isSkipped(held) ? held : nil
    }

    /// Si un borrador PENDIENTE pertenece a una ocurrencia que la persona ya descartó (saltada), y por tanto
    /// es un duplicado que otro dispositivo creó antes de enterarse. Lo usa el barrido de `processDuePayments`.
    static func belongsToADismissedOccurrence(
        draftDate: Date, schedule: Schedule, isSkipped: (Date) -> Bool, calendar: Calendar = .current
    ) -> Bool {
        isSkipped(heldOccurrence(draftDate: draftDate, schedule: schedule, calendar: calendar))
    }

    /// Si aprobar el borrador tiene que AVANZAR la próxima fecha del pago.
    ///
    /// No avanza cuando el borrador es de una ocurrencia que la próxima fecha ya dejó atrás sin que nada la
    /// cubriera: se rechazó, la app pasó de largo y volvió a pendientes desde Archivados. Avanzar ahí se comería la
    /// ocurrencia siguiente. Sí avanza el borrador de la próxima fecha y el adelanto, también el fechado el día de
    /// una ocurrencia que ya está cubierta (`isAccountedFor`: saltada o con una transacción enlazada) o pagada ese
    /// día: es el pago adelantado de la siguiente.
    static func approvalAdvancesPointer(
        draftDate: Date, schedule: Schedule, isAccountedFor: (Date) -> Bool, calendar: Calendar = .current
    ) -> Bool {
        let draftDay = calendar.startOfDay(for: draftDate)
        let pointer = calendar.startOfDay(for: schedule.nextDueDate)
        guard draftDay < pointer,
              isOccurrence(draftDay, before: pointer, schedule: schedule, calendar: calendar) else { return true }
        if isAccountedFor(draftDay) { return true }
        if let lastPaid = schedule.lastPaidDate, calendar.isDate(lastPaid, inSameDayAs: draftDay) { return true }
        return false
    }

    // MARK: - Calendario del pago

    /// Si `day` es una ocurrencia del pago anterior a `pointer`. Recorre hacia atrás desde la próxima fecha
    /// con el MISMO paso que `ScheduledPaymentDraftService.advanceToNextDueDate` (y no con
    /// `ScheduledPaymentDateCalculator`, que filtra por `createdAt` y por los días de la semana: un pago dado de
    /// alta con fecha pasada perdería su primera ocurrencia).
    static func isOccurrence(_ day: Date, before pointer: Date, schedule: Schedule, calendar: Calendar = .current) -> Bool {
        guard schedule.isRecurring else { return false }
        let target = calendar.startOfDay(for: day)
        var current = calendar.startOfDay(for: pointer)
        let targetDay = schedule.dayOfMonth ?? calendar.component(.day, from: current)
        var steps = 0
        while current > target, steps < 2000 {
            guard let previous = retreat(current, schedule: schedule, monthlyDay: targetDay, calendar: calendar),
                  previous < current else { return false }
            current = previous
            steps += 1
        }
        return current == target
    }

    private static func retreat(_ date: Date, schedule: Schedule, monthlyDay: Int, calendar: Calendar) -> Date? {
        guard let type = RecurrenceType(rawValue: schedule.recurrenceType) else { return nil }
        let interval = max(1, schedule.recurrenceInterval)
        switch type {
        case .daily:
            return calendar.date(byAdding: .day, value: -interval, to: date)
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: -interval, to: date)
        case .monthly:
            guard let shifted = calendar.date(byAdding: .month, value: -interval, to: date) else { return nil }
            let maxDay = calendar.range(of: .day, in: .month, for: shifted)?.count ?? 28
            var components = calendar.dateComponents([.year, .month], from: shifted)
            components.day = min(monthlyDay, maxDay)
            return calendar.date(from: components).map { calendar.startOfDay(for: $0) }
        case .yearly:
            return calendar.date(byAdding: .year, value: -interval, to: date)
        }
    }
}

extension ScheduledPayment {
    /// El calendario del pago tal como lo lee `ScheduledDraftOccurrenceLogic`.
    var occurrenceSchedule: ScheduledDraftOccurrenceLogic.Schedule {
        ScheduledDraftOccurrenceLogic.Schedule(
            isRecurring: isRecurring,
            recurrenceType: recurrenceType,
            recurrenceInterval: recurrenceInterval,
            dayOfMonth: dayOfMonth,
            nextDueDate: nextDueDate,
            lastPaidDate: lastPaidDate
        )
    }
}
