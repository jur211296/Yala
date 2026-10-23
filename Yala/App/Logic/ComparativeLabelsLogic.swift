//
//  ComparativeLabelsLogic.swift
//  Yala
//
//  Auditoría UX 2.2 · L18-3 (opción D, variante 3): la tabla de la Comparativa no decía qué era cada número. Ahora dice
//  arriba «Octubre comparado con setiembre», los chips en palabras («Con el mes anterior», «Con octubre de 2025») y las
//  columnas llevan el nombre de cada período. Esta lógica pone esos nombres.
//
//  Un período que cubre un mes entero se nombra por el mes («setiembre»); si no, por sus días («1–21 sept»). El tramo con
//  el que se compara es el que de verdad entra en la tabla: con «Este mes» a medias, los mismos días del mes anterior
//  (`ComparisonPhraseLogic.comparedInterval`, el mismo que usa Estadísticas). Así la cabecera no promete «setiembre»
//  entero cuando la tabla suma del 1 al 21.
//
//  Lógica pura: calendario, fecha y locale inyectables.
//

import Foundation

enum ComparativeLabelsLogic {

    /// Cómo se escribe un período, en dos formas: para una columna o un chip (corta) y para la frase de arriba.
    struct Name: Equatable {
        /// «Setiembre», «2026», «13–19 oct». Con mayúscula inicial (cabecera de columna).
        let column: String
        /// «setiembre», «2026», «13–19 de octubre». Para dentro de una frase.
        let inSentence: String
        /// `true` si es un tramo de días y no un mes o un año enteros: la frase lleva entonces el artículo («el 1–21 de…»).
        let isDayRange: Bool
    }

    /// El nombre del período que se mira.
    static func currentName(
        period: DetailPeriod, customRange: DateInterval?,
        now: Date = .now, calendar: Calendar = .current, locale: Locale = AppLocale.current
    ) -> Name {
        let interval = period.dateInterval(customRange: customRange, now: now, calendar: calendar)
        switch period {
        case .thisMonth, .lastMonth:
            return monthName(of: interval.start, now: now, calendar: calendar, locale: locale)
        case .thisYear, .lastYear:
            return yearName(of: interval.start, calendar: calendar)
        default:
            return name(of: interval, now: now, calendar: calendar, locale: locale)
        }
    }

    /// El nombre del tramo con el que se compara (`nil` en «Todo el tiempo»).
    static func comparedName(
        period: DetailPeriod, mode: ComparisonMode, customRange: DateInterval?, dataEnd: Date?,
        now: Date = .now, calendar: Calendar = .current, locale: Locale = AppLocale.current
    ) -> Name? {
        guard let interval = ComparisonPhraseLogic.comparedInterval(
            period: period, mode: mode, customRange: customRange, dataEnd: dataEnd, now: now, calendar: calendar
        ) else { return nil }
        return name(of: interval, now: now, calendar: calendar, locale: locale)
    }

    /// El texto del chip de «mismo período del año pasado»: el nombre del período de hace un año, sin recortar
    /// («Con octubre de 2025»): el chip nombra la opción; los días exactos los dice la cabecera.
    static func yearAgoChipName(
        period: DetailPeriod, customRange: DateInterval?,
        now: Date = .now, calendar: Calendar = .current, locale: Locale = AppLocale.current
    ) -> String {
        let previous = PreviousPeriodHelper.previousInterval(for: period, mode: .year, customRange: customRange, now: now)
        switch period {
        case .thisMonth, .lastMonth:
            return monthName(of: previous.start, now: now, calendar: calendar, locale: locale, forceYear: true).inSentence
        default:
            return name(of: previous, now: now, calendar: calendar, locale: locale, forceYear: true).inSentence
        }
    }

    /// El texto del chip de «período anterior», según lo que se mira.
    static func previousChipTitle(for period: DetailPeriod) -> String {
        switch period {
        case .thisWeek: return L10n.UXL18.chipPreviousWeek
        case .last7Days: return L10n.UXL18.chipPrevious7Days
        case .last30Days: return L10n.UXL18.chipPrevious30Days
        case .thisMonth, .lastMonth: return L10n.UXL18.chipPreviousMonth
        case .thisYear, .lastYear, .allTime, .custom: return L10n.UXL18.chipPreviousPeriod
        }
    }

    /// La frase de arriba: «Octubre comparado con setiembre» o «Octubre comparado con el 1–21 de setiembre».
    static func heading(current: Name, compared: Name) -> String {
        compared.isDayRange
            ? L10n.UXL18.headingRange(current.column, compared.inSentence)
            : L10n.UXL18.heading(current.column, compared.inSentence)
    }

    // MARK: - Nombres

    /// Un intervalo: por su mes si lo cubre entero, por su año si lo cubre entero, y si no por sus días.
    static func name(
        of interval: DateInterval, now: Date, calendar: Calendar, locale: Locale, forceYear: Bool = false
    ) -> Name {
        let end = PeriodStepLogic.displayEnd(of: interval, calendar: calendar)
        if let month = calendar.dateInterval(of: .month, for: interval.start),
           calendar.isDate(interval.start, inSameDayAs: month.start),
           calendar.isDate(end, inSameDayAs: PeriodStepLogic.displayEnd(of: month, calendar: calendar)) {
            return monthName(of: interval.start, now: now, calendar: calendar, locale: locale, forceYear: forceYear)
        }
        if let year = calendar.dateInterval(of: .year, for: interval.start),
           calendar.isDate(interval.start, inSameDayAs: year.start),
           calendar.isDate(end, inSameDayAs: PeriodStepLogic.displayEnd(of: year, calendar: calendar)) {
            return yearName(of: interval.start, calendar: calendar)
        }
        let currentYear = calendar.component(.year, from: now)
        let showsYear = forceYear
            || calendar.component(.year, from: interval.start) != currentYear
            || calendar.component(.year, from: end) != currentYear
        let short = DateIntervalFormatter()
        short.locale = locale
        short.calendar = calendar
        short.timeZone = calendar.timeZone
        short.dateTemplate = showsYear ? "dMMMy" : "dMMM"
        let shortText = short.string(from: interval.start, to: end)
        let long = ComparisonPhraseLogic.rangeText(interval, now: now, calendar: calendar, locale: locale)
        return Name(column: shortText, inSentence: long, isDayRange: true)
    }

    static func monthName(
        of date: Date, now: Date, calendar: Calendar, locale: Locale, forceYear: Bool = false
    ) -> Name {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        let showsYear = forceYear || calendar.component(.year, from: date) != calendar.component(.year, from: now)
        // El mes en su forma de dentro de una frase (`MMMM`, «octubre»); la cabecera le pone la mayúscula. `LLLL` (la
        // forma suelta) ya viene con mayúscula en español y no sirve para la frase. Con año, la plantilla del idioma.
        if showsYear {
            formatter.setLocalizedDateFormatFromTemplate("MMMMy")
        } else {
            formatter.dateFormat = "MMMM"
        }
        let text = formatter.string(from: date)
        return Name(column: capitalizedFirst(text, locale: locale), inSentence: text, isDayRange: false)
    }

    static func yearName(of date: Date, calendar: Calendar) -> Name {
        let year = String(calendar.component(.year, from: date))
        return Name(column: year, inSentence: year, isDayRange: false)
    }

    static func capitalizedFirst(_ text: String, locale: Locale) -> String {
        guard let first = text.first else { return text }
        return String(first).uppercased(with: locale) + text.dropFirst()
    }
}
