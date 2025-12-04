// PanelPeriodFilter.swift

import Foundation

enum PanelPeriodType: String {
    case thisYear
    case thisMonth
    case thisWeek
    case custom
}

/// Modelo puro que representa el filtro de periodo activo en el Panel.
struct PanelPeriodFilter: Equatable {
    var type: PanelPeriodType
    var customStartDate: Date?
    var customEndDate: Date?

    /// Devuelve el intervalo de fechas efectivo según el tipo seleccionado.
    func dateInterval(
        calendar: Calendar = .current,
        timeZone: TimeZone = .current
    ) -> DateInterval {
        var calendar = calendar
        calendar.timeZone = timeZone

        let now = Date()

        switch type {
        case .thisYear:
            let year = calendar.component(.year, from: now)
            let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
            let end = calendar.date(from: DateComponents(year: year, month: 12, day: 31, hour: 23, minute: 59, second: 59))!
            return DateInterval(start: start, end: end)

        case .thisMonth:
            let components = calendar.dateComponents([.year, .month], from: now)
            let start = calendar.date(from: DateComponents(year: components.year, month: components.month, day: 1))!
            let range = calendar.range(of: .day, in: .month, for: start)!
            let lastDay = range.count
            let end = calendar.date(from: DateComponents(year: components.year, month: components.month, day: lastDay, hour: 23, minute: 59, second: 59))!
            return DateInterval(start: start, end: end)

        case .thisWeek:
            let weekday = calendar.component(.weekday, from: now)
            // Lunes como primer día de la semana: ajustamos según tu calendario
            let daysFromMonday = (weekday + 5) % 7
            let start = calendar.date(byAdding: .day, value: -daysFromMonday, to: calendar.startOfDay(for: now))!
            let end = calendar.date(byAdding: .day, value: 6, to: start)!
            let endWithTime = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: end)!
            return DateInterval(start: start, end: endWithTime)

        case .custom:
            // Seguridad: si no hay fechas personalizadas válidas, por defecto usa "Este mes".
            guard let start = customStartDate, let end = customEndDate, start <= end else {
                return PanelPeriodFilter(type: .thisMonth, customStartDate: nil, customEndDate: nil)
                    .dateInterval(calendar: calendar, timeZone: timeZone)
            }
            // Ajustar a inicio de día y fin de día
            let startDay = calendar.startOfDay(for: start)
            let endDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? end
            return DateInterval(start: startDay, end: endDay)
        }
    }
}
