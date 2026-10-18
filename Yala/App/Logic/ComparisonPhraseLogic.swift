//
//  ComparisonPhraseLogic.swift
//  Yala
//
//  UX 2.2 · L11-4. Estadísticas decía con qué compara con dos círculos, «P-1» y «A-1», y debajo «vs Set 26», que se lee
//  como «el 26 de septiembre». Ahora lo dice una frase que hace de botón: «Comparado con el 1–15 de septiembre ▾», que
//  abre las dos opciones. El tramo es el que de verdad entra en la comparación: con «Este mes», el mismo tramo de días
//  del mes anterior (`DateAlignmentHelper.alignedPreviousInterval`), no el mes entero.
//
//  Lógica pura: el tramo, cómo se escribe y cómo se llama cada opción.
//

import Foundation

enum ComparisonPhraseLogic {

    /// El tramo con el que se compara el período elegido: el anterior alineado al día equivalente cuando el actual va
    /// por la mitad (mes, semana o año en curso), y si no, el anterior entero. `nil` para «Todo el tiempo».
    ///
    /// `dataEnd`: el último día con movimientos del período actual. Resumen alinea con hoy
    /// (`InsightsCalculator`); Tendencias y Distribución, con el último día con datos (`alignedPreviousTotal`,
    /// `alignedPreviousItems`), así que su frase lo pasa para decir el mismo tramo (review del 2026-10-18).
    static func comparedInterval(
        period: DetailPeriod,
        mode: ComparisonMode,
        customRange: DateInterval?,
        dataEnd: Date? = nil,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> DateInterval? {
        guard period != .allTime else { return nil }
        let current = period.dateInterval(customRange: customRange, now: now)
        let previous = PreviousPeriodHelper.previousInterval(for: period, mode: mode, customRange: customRange, now: now)
        let asOf = dataEnd.map { min($0, now) } ?? now
        return DateAlignmentHelper.alignedPreviousInterval(
            currentInterval: current,
            previousInterval: previous,
            asOf: asOf,
            period: period,
            comparisonMode: mode,
            calendar: calendar
        )
    }

    /// «1–15 de septiembre» si el tramo cae en un solo mes; «29 sept – 5 oct» si cruza meses (con el mes largo no
    /// cabría en una línea). El año sale solo si no es el actual.
    static func rangeText(
        _ interval: DateInterval,
        now: Date = .now,
        calendar: Calendar = .current,
        locale: Locale = AppLocale.current
    ) -> String {
        let end = PeriodStepLogic.displayEnd(of: interval, calendar: calendar)
        let currentYear = calendar.component(.year, from: now)
        let showsYear = calendar.component(.year, from: interval.start) != currentYear
            || calendar.component(.year, from: end) != currentYear
        let sameMonth = calendar.isDate(interval.start, equalTo: end, toGranularity: .month)
        let formatter = DateIntervalFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        switch (sameMonth, showsYear) {
        case (true, false): formatter.dateTemplate = "dMMMM"
        case (true, true): formatter.dateTemplate = "dMMMMy"
        case (false, false): formatter.dateTemplate = "dMMM"
        case (false, true): formatter.dateTemplate = "dMMMy"
        }
        return formatter.string(from: interval.start, to: end)
    }

    /// La frase entera, «Comparado con el 1–15 de septiembre», o `nil` si el período no se compara con nada.
    static func phrase(
        period: DetailPeriod,
        mode: ComparisonMode,
        customRange: DateInterval?,
        dataEnd: Date? = nil,
        now: Date = .now,
        calendar: Calendar = .current,
        locale: Locale = AppLocale.current
    ) -> String? {
        guard let interval = comparedInterval(
            period: period, mode: mode, customRange: customRange, dataEnd: dataEnd, now: now, calendar: calendar
        ) else { return nil }
        return L10n.UXL11.comparedWith(rangeText(interval, now: now, calendar: calendar, locale: locale))
    }

    /// El nombre de la opción «período anterior» según lo que se mira: con «Esta semana» compara con la semana
    /// anterior, no con un mes. La de «año anterior» es igual para todos.
    static func previousOptionTitle(for period: DetailPeriod) -> String {
        switch period {
        case .thisWeek: return L10n.UXL11.optionPreviousWeek
        case .last7Days: return L10n.UXL11.optionPrevious7Days
        case .last30Days: return L10n.UXL11.optionPrevious30Days
        case .thisMonth, .lastMonth: return L10n.UXL11.optionPreviousMonth
        case .thisYear, .lastYear, .allTime, .custom: return L10n.UXL11.optionPreviousPeriod
        }
    }
}
