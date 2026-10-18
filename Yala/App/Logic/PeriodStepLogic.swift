//
//  PeriodStepLogic.swift
//  Yala
//
//  UX 2.2 · L11-3. El período de Estadísticas no decía qué días cubre ni dejaba pasar al anterior: ver agosto exigía
//  «Personalizado» y dos ruedas de fecha. Ahora la píldora lleva flechas ‹ › que van al período anterior o siguiente
//  del mismo tipo —como Planificación— y debajo el rango en una línea («1–15 oct»).
//
//  Lógica pura: qué período sale al pulsar cada flecha, si la flecha está disponible y cómo se escribe el rango.
//

import Foundation

enum PeriodStepLogic {

    /// Un período elegido: el tipo y, si es `.custom`, su rango.
    struct Selection: Equatable {
        let period: DetailPeriod
        let customRange: DateInterval?
    }

    enum Direction {
        case previous
        case next
    }

    /// De qué tamaño es el paso. Los períodos fijos lo dicen su nombre; un rango propio se lee por su forma.
    enum Unit: Equatable {
        case week
        case month
        case year
        case days(Int)
    }

    /// «Todo el tiempo» no tiene anterior ni siguiente.
    static func isSteppable(_ period: DetailPeriod) -> Bool {
        period != .allTime
    }

    // MARK: - Paso

    /// El período al que lleva la flecha, o `nil` si no hay (el siguiente caería en el futuro, o «Todo el tiempo»).
    /// Cuando el destino coincide con un período fijo («Este mes», «Mes pasado», «Últimos 7 días»…) se devuelve ése y no
    /// un rango, así la píldora sigue diciendo su nombre.
    /// `unitHint`: el tamaño de paso con el que se llegó a un rango propio. Sin él, «los 7 días anteriores» de un domingo
    /// se leerían como una semana entera y la flecha de vuelta llevaría a «Esta semana» en vez de a «Últimos 7 días».
    static func step(
        _ selection: Selection,
        _ direction: Direction,
        unitHint: Unit? = nil,
        now: Date = .now,
        calendar: Calendar = userConfiguredCalendar()
    ) -> Selection? {
        guard isSteppable(selection.period) else { return nil }
        let interval = selection.period.dateInterval(customRange: selection.customRange, now: now, calendar: calendar)
        let resolvedUnit = selection.period == .custom && unitHint != nil
            ? unitHint
            : unit(of: selection, interval: interval, calendar: calendar)
        guard let unit = resolvedUnit else { return nil }
        let sign = direction == .previous ? -1 : 1
        let startOfToday = calendar.startOfDay(for: now)

        switch unit {
        case .month:
            let thisMonth = monthStart(of: now, calendar)
            guard let start = calendar.date(byAdding: .month, value: sign, to: monthStart(of: interval.start, calendar)) else {
                return nil
            }
            if start > thisMonth { return nil }
            if start == thisMonth { return Selection(period: .thisMonth, customRange: nil) }
            if let lastMonth = calendar.date(byAdding: .month, value: -1, to: thisMonth), start == lastMonth {
                return Selection(period: .lastMonth, customRange: nil)
            }
            return custom(start: start, adding: .month, calendar: calendar)

        case .year:
            guard let start = calendar.date(byAdding: .year, value: sign, to: yearStart(of: interval.start, calendar)) else {
                return nil
            }
            let thisYear = yearStart(of: now, calendar)
            if start > thisYear { return nil }
            if start == thisYear { return Selection(period: .thisYear, customRange: nil) }
            if let lastYear = calendar.date(byAdding: .year, value: -1, to: thisYear), start == lastYear {
                return Selection(period: .lastYear, customRange: nil)
            }
            return custom(start: start, adding: .year, calendar: calendar)

        case .week:
            guard let start = calendar.date(byAdding: .weekOfYear, value: sign, to: weekStart(of: interval.start, calendar)) else {
                return nil
            }
            let thisWeek = weekStart(of: now, calendar)
            if start > thisWeek { return nil }
            if start == thisWeek { return Selection(period: .thisWeek, customRange: nil) }
            return custom(start: start, adding: .weekOfYear, calendar: calendar)

        case .days(let count):
            guard let start = calendar.date(byAdding: .day, value: sign * count, to: calendar.startOfDay(for: interval.start)) else {
                return nil
            }
            // El tramo que acaba hoy es el período fijo, si lo hay.
            if let rollingStart = calendar.date(byAdding: .day, value: -(count - 1), to: startOfToday), start == rollingStart {
                switch count {
                case 7: return Selection(period: .last7Days, customRange: nil)
                case 30: return Selection(period: .last30Days, customRange: nil)
                default: break
                }
            }
            if start > startOfToday { return nil }
            guard let next = calendar.date(byAdding: .day, value: count, to: start),
                  let rawEnd = calendar.date(byAdding: .second, value: -1, to: next) else { return nil }
            // Un tramo propio que asomaría al futuro se corta hoy a medianoche menos un segundo.
            let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday)
                .flatMap { calendar.date(byAdding: .second, value: -1, to: $0) } ?? rawEnd
            return Selection(period: .custom, customRange: DateInterval(start: start, end: min(rawEnd, endOfToday)))
        }
    }

    /// El tamaño del paso de un período. Un rango propio que cubre un mes, un año o una semana enteros avanza por mes,
    /// año o semana; cualquier otro, por bloques de sus mismos días.
    static func unit(
        of selection: Selection,
        interval: DateInterval,
        calendar: Calendar = userConfiguredCalendar()
    ) -> Unit? {
        switch selection.period {
        case .thisMonth, .lastMonth: return .month
        case .thisYear, .lastYear: return .year
        case .thisWeek: return .week
        case .last7Days: return .days(7)
        case .last30Days: return .days(30)
        case .allTime: return nil
        case .custom:
            let start = interval.start
            let lastDay = calendar.startOfDay(for: displayEnd(of: interval, calendar: calendar))
            if calendar.startOfDay(for: start) == start {
                if start == monthStart(of: start, calendar),
                   let next = calendar.date(byAdding: .month, value: 1, to: start),
                   let last = calendar.date(byAdding: .day, value: -1, to: next), last == lastDay {
                    return .month
                }
                if start == yearStart(of: start, calendar),
                   let next = calendar.date(byAdding: .year, value: 1, to: start),
                   let last = calendar.date(byAdding: .day, value: -1, to: next), last == lastDay {
                    return .year
                }
                if start == weekStart(of: start, calendar),
                   let last = calendar.date(byAdding: .day, value: 6, to: start), last == lastDay {
                    return .week
                }
            }
            let days = (calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: lastDay).day ?? 0) + 1
            return .days(max(1, days))
        }
    }

    // MARK: - Rango en texto

    /// «1–15 oct», «29 sept – 5 oct», «1 ene – 31 dic 2025». El año solo sale si no es el actual. `nil` para «Todo el
    /// tiempo», que no tiene un rango que se pueda leer.
    static func rangeText(
        period: DetailPeriod,
        customRange: DateInterval?,
        now: Date = .now,
        calendar: Calendar = userConfiguredCalendar(),
        locale: Locale = AppLocale.current
    ) -> String? {
        guard period != .allTime else { return nil }
        let interval = period.dateInterval(customRange: customRange, now: now, calendar: calendar)
        return format(interval, now: now, calendar: calendar, locale: locale)
    }

    /// El texto de un intervalo cualquiera, con el mismo criterio que `rangeText`.
    static func format(
        _ interval: DateInterval,
        now: Date = .now,
        calendar: Calendar = userConfiguredCalendar(),
        locale: Locale = AppLocale.current
    ) -> String {
        let start = interval.start
        let end = displayEnd(of: interval, calendar: calendar)
        let currentYear = calendar.component(.year, from: now)
        let showsYear = calendar.component(.year, from: start) != currentYear
            || calendar.component(.year, from: end) != currentYear
        let formatter = DateIntervalFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateTemplate = showsYear ? "dMMMy" : "dMMM"
        return formatter.string(from: start, to: end)
    }

    /// El título de la píldora para un rango propio: «agosto de 2026» si es un mes entero, «2024» si es un año, y si
    /// no el rango. Antes salía «1 ago. 26 - 31 ago. 26».
    static func customTitle(
        _ range: DateInterval,
        now: Date = .now,
        calendar: Calendar = userConfiguredCalendar(),
        locale: Locale = AppLocale.current
    ) -> String {
        let selection = Selection(period: .custom, customRange: range)
        switch unit(of: selection, interval: range, calendar: calendar) {
        case .month:
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.setLocalizedDateFormatFromTemplate("MMMMy")
            return formatter.string(from: range.start)
        case .year:
            return String(calendar.component(.year, from: range.start))
        default:
            return format(range, now: now, calendar: calendar, locale: locale)
        }
    }

    // MARK: - Helpers

    /// El último instante que cuenta. Los períodos en curso cierran en la medianoche de mañana (`DateInterval` es
    /// cerrado): para escribirlos, el último día es hoy.
    static func displayEnd(of interval: DateInterval, calendar: Calendar) -> Date {
        let end = interval.end
        guard calendar.startOfDay(for: end) == end, end > interval.start else { return end }
        return calendar.date(byAdding: .second, value: -1, to: end) ?? end
    }

    private static func custom(start: Date, adding component: Calendar.Component, calendar: Calendar) -> Selection? {
        guard let next = calendar.date(byAdding: component, value: 1, to: start),
              let end = calendar.date(byAdding: .second, value: -1, to: next) else { return nil }
        return Selection(period: .custom, customRange: DateInterval(start: start, end: end))
    }

    private static func monthStart(of date: Date, _ calendar: Calendar) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? calendar.startOfDay(for: date)
    }

    private static func yearStart(of date: Date, _ calendar: Calendar) -> Date {
        calendar.date(from: calendar.dateComponents([.year], from: date)) ?? calendar.startOfDay(for: date)
    }

    private static func weekStart(of date: Date, _ calendar: Calendar) -> Date {
        calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))
            ?? calendar.startOfDay(for: date)
    }
}
