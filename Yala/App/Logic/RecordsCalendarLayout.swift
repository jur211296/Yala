//
//  RecordsCalendarLayout.swift
//  Yala
//
//  Decide la forma del calendario de Registros según el rango del periodo activo.
//

import Foundation

/// Resuelve cómo renderizar el calendario según el span del rango:
///
/// - `.continuous`: tira vertical de las filas de semana que cubren el rango
///   (≤ 6 filas → cabe en ~1 mes o menos: semana, 7/30 días, mes). Sin navegación;
///   el selector de periodo del hero es el único control.
/// - `.paged`: un grid mensual por página (> 6 filas → varios meses: año, allTime).
///
/// El umbral por "filas de semana" mantiene `last7Days` cruzando fin de mes como
/// una tira continua, y a `thisMonth` como su propio mes — en vez de fragmentar por
/// "cuántos meses calendario toca".
enum RecordsCalendarLayout: Equatable {
    /// Cada semana es un array de 7 fechas (`startOfDay`), alineadas a `firstWeekday`.
    case continuous(weeks: [[Date]])
    /// `startOfMonth` de cada mes que intersecta el rango.
    case paged(months: [Date])

    /// Máximo de filas de semana para preferir la tira continua sobre la paginación.
    static let maxContinuousWeekRows = 6

    static func resolve(
        range: DateInterval,
        firstWeekday: Int,
        calendar: Calendar = .current
    ) -> RecordsCalendarLayout {
        var cal = calendar
        cal.firstWeekday = firstWeekday

        // Contamos las filas de semana por aritmética (sin materializarlas): para rangos
        // largos (año, allTime) esto evita generar cientos de arrays solo para decidir el modo.
        if weekRowCount(in: range, calendar: cal) <= maxContinuousWeekRows {
            return .continuous(weeks: weekRows(in: range, calendar: cal))
        }
        return .paged(months: monthStarts(in: range, calendar: cal))
    }

    /// Número de filas de semana que cubren el rango, sin materializarlas.
    /// Coincide con `weekRows(in:calendar:).count`.
    static func weekRowCount(in range: DateInterval, calendar: Calendar) -> Int {
        let firstDay = calendar.startOfDay(for: range.start)
        guard let firstWeek = calendar.dateInterval(of: .weekOfYear, for: firstDay) else { return 0 }
        let firstWeekStart = calendar.startOfDay(for: firstWeek.start)
        let lastDay = calendar.startOfDay(for: range.end.addingTimeInterval(-1))
        guard let lastWeek = calendar.dateInterval(of: .weekOfYear, for: lastDay) else { return 1 }
        let lastWeekStart = calendar.startOfDay(for: lastWeek.start)
        let days = calendar.dateComponents([.day], from: firstWeekStart, to: lastWeekStart).day ?? 0
        return max(1, days / 7 + 1)
    }

    /// Filas de semana (7 fechas consecutivas cada una) que intersectan el rango,
    /// empezando por el inicio de la semana que contiene `range.start`.
    static func weekRows(in range: DateInterval, calendar: Calendar) -> [[Date]] {
        let firstDay = calendar.startOfDay(for: range.start)
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: firstDay) else { return [] }
        var weekStart = calendar.startOfDay(for: weekInterval.start)

        var rows: [[Date]] = []
        while weekStart < range.end {
            var week: [Date] = []
            for offset in 0..<7 {
                if let day = calendar.date(byAdding: .day, value: offset, to: weekStart) {
                    week.append(calendar.startOfDay(for: day))
                }
            }
            rows.append(week)
            guard let nextWeek = calendar.date(byAdding: .day, value: 7, to: weekStart) else { break }
            weekStart = nextWeek
        }
        return rows
    }

    /// `startOfMonth` de cada mes que intersecta el rango.
    static func monthStarts(in range: DateInterval, calendar: Calendar) -> [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: range.start) else { return [] }
        var monthStart = monthInterval.start

        var months: [Date] = []
        while monthStart < range.end {
            months.append(monthStart)
            guard let next = calendar.date(byAdding: .month, value: 1, to: monthStart) else { break }
            monthStart = next
        }
        return months
    }
}
