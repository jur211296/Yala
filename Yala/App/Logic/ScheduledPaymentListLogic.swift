//
//  ScheduledPaymentListLogic.swift
//  Yala
//
//  Auditoría UX 2.2 · lote 10 (pagos planificados). La pregunta con la que se abre la pantalla es «¿qué me falta
//  pagar?», y la lista la contestaba con secciones por FECHA (Vencidos, Hoy, Próximos): un pago ya hecho salía bajo
//  «Vencidos», en rosa. Aquí viven las reglas que separan lo hecho de lo pendiente (L10-1), el estado de cada fecha
//  (la píldora de la lista, del calendario y del detalle), qué es un pago PAUSADO (L10-7) y las cifras de la cabecera
//  (L10-2), separadas de las vistas para poder probarlas.
//

import Foundation

/// El estado de UNA fecha de un pago, tal como lo enseña la píldora.
enum ScheduledPaymentRowState: Equatable {
    case overdue
    case dueToday
    case dueTomorrow
    case dueInDays(Int)
    case paid
    case skipped
    case paused
}

/// Las secciones de la lista (L10-1): lo que falta, lo hecho, lo saltado y lo pausado, en ese orden.
enum ScheduledPaymentListSection: String, CaseIterable, Identifiable {
    case toPay
    case paid
    case skipped
    case paused

    var id: String { rawValue }
}

/// Cómo se pinta un punto del calendario (L10-3): un color, un significado.
enum ScheduledPaymentDotStatus: Equatable {
    case paid
    case overdue
    case pending
}

enum ScheduledPaymentListLogic {

    // MARK: - Pausado o terminado

    /// Un pago que ya no toca: uno de una sola vez que se pagó, o uno que se repite y pasó su fecha de fin. Los dos
    /// dejan `isActive == false` igual que pausarlo, y «Reanudar» no puede ofrecerse en ellos.
    static func isFinished(
        isActive: Bool,
        isRecurring: Bool,
        lastPaidDate: Date?,
        nextDueDate: Date,
        endDate: Date?
    ) -> Bool {
        guard !isActive else { return false }
        if !isRecurring { return lastPaidDate != nil }
        if let endDate { return nextDueDate > endDate }
        return false
    }

    /// Pausado por la persona: inactivo y no terminado.
    static func isPaused(
        isActive: Bool,
        isRecurring: Bool,
        lastPaidDate: Date?,
        nextDueDate: Date,
        endDate: Date?
    ) -> Bool {
        !isActive && !isFinished(
            isActive: isActive, isRecurring: isRecurring, lastPaidDate: lastPaidDate,
            nextDueDate: nextDueDate, endDate: endDate
        )
    }

    // MARK: - Estado de una fecha

    /// Lo pagado gana a todo; después lo saltado y lo pausado; si no, lo que dice la fecha.
    static func rowState(
        isPaid: Bool,
        isSkipped: Bool,
        isPaused: Bool,
        daysUntilDue: Int
    ) -> ScheduledPaymentRowState {
        if isPaid { return .paid }
        if isSkipped { return .skipped }
        if isPaused { return .paused }
        switch daysUntilDue {
        case ..<0: return .overdue
        case 0: return .dueToday
        case 1: return .dueTomorrow
        default: return .dueInDays(daysUntilDue)
        }
    }

    static func section(for state: ScheduledPaymentRowState) -> ScheduledPaymentListSection {
        switch state {
        case .paid: return .paid
        case .skipped: return .skipped
        case .paused: return .paused
        case .overdue, .dueToday, .dueTomorrow, .dueInDays: return .toPay
        }
    }

    /// Solo lo vencido avisa en rosa (L10-1): los importes de lo demás van en color de texto.
    static func isAlert(_ state: ScheduledPaymentRowState) -> Bool {
        state == .overdue
    }

    /// El punto del calendario: índigo pagado, rosa vencido, gris lo demás (también saltado y pausado).
    static func dotStatus(for state: ScheduledPaymentRowState) -> ScheduledPaymentDotStatus {
        switch state {
        case .paid: return .paid
        case .overdue: return .overdue
        case .dueToday, .dueTomorrow, .dueInDays, .skipped, .paused: return .pending
        }
    }

    /// Agrupa en las secciones de L10-1, cada una por fecha, sin secciones vacías. `state` resuelve el estado de cada
    /// elemento.
    static func sections<T>(
        _ items: [T],
        date: (T) -> Date,
        state: (T) -> ScheduledPaymentRowState
    ) -> [(section: ScheduledPaymentListSection, items: [T])] {
        let grouped = Dictionary(grouping: items) { section(for: state($0)) }
        return ScheduledPaymentListSection.allCases.compactMap { section in
            guard let rows = grouped[section], !rows.isEmpty else { return nil }
            return (section, rows.sorted { date($0) < date($1) })
        }
    }

    // MARK: - Cabecera (L10-2)

    /// Las tres cifras de la cabecera: lo que falta, lo pagado y su suma. El total sale de las otras dos para que
    /// «Pagaste Y de Z» y «Te falta X» cuadren siempre.
    struct Hero: Equatable {
        let pending: Double
        let paid: Double
        var total: Double { pending + paid }
        /// Proporción pagada, entre 0 y 1. Sin nada en el mes, 0.
        var paidFraction: Double { total > 0 ? min(max(paid / total, 0), 1) : 0 }
        var isEmpty: Bool { total <= 0 }
    }

    // MARK: - Reanudar (L10-7)

    /// Al reanudar, la próxima fecha es la primera del calendario del pago desde HOY: lo que cayó en pausa no se cobra
    /// ni deja un borrador en la Bandeja. `datesInMonth` es el calendario del pago (SSOT: `ScheduledPaymentDateCalculator`).
    static func resumedNextDueDate(
        current: Date,
        today: Date,
        monthsAhead: Int = 24,
        calendar: Calendar = .current,
        datesInMonth: (Date) -> [Date]
    ) -> Date {
        let todayStart = calendar.startOfDay(for: today)
        guard calendar.startOfDay(for: current) < todayStart else { return current }
        let firstMonth = calendar.startOfMonth(for: todayStart)
        for offset in 0...monthsAhead {
            guard let month = calendar.date(byAdding: .month, value: offset, to: firstMonth) else { continue }
            if let next = datesInMonth(month).sorted().first(where: { calendar.startOfDay(for: $0) >= todayStart }) {
                return next
            }
        }
        return current
    }

    // MARK: - Día del calendario (L10-3)

    /// El importe que cabe bajo el número del día: la suma de las fechas de ese día si comparten divisa, en formato
    /// corto. Con divisas mezcladas no hay una cifra honesta y no se enseña.
    static func dayAmount(_ amounts: [(amount: Double, currencyCode: String)]) -> (value: Double, currencyCode: String)? {
        guard let first = amounts.first else { return nil }
        guard amounts.allSatisfy({ $0.currencyCode == first.currencyCode }) else { return nil }
        return (amounts.reduce(0) { $0 + abs($1.amount) }, first.currencyCode)
    }
}
