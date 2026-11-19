//
//  ComparisonPhraseLogic.swift
//  Yala
//
//  UX 2.2 · L11-4. Estadísticas decía con qué compara con dos círculos, «P-1» y «A-1», y debajo «vs Set 26», que se lee
//  como «el 26 de septiembre». Ahora lo dice la frase «Comparado con el 1–15 de septiembre», título de los dos chips
//  que eligen con qué comparar (`ComparisonModeChips`, el mismo control que la Comparativa de Reportes). El tramo es el que de verdad entra en la comparación: con «Este mes», el mismo tramo de días
//  del mes anterior (`DateAlignmentHelper.alignedPreviousInterval`), no el mes entero.
//
//  Lógica pura: el tramo y cómo se escribe.
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
        let periodCalendar = periodCalendar(in: calendar.timeZone)
        let current = period.dateInterval(customRange: customRange, now: now, calendar: periodCalendar)
        let previous = PreviousPeriodHelper.previousInterval(
            for: period, mode: mode, customRange: customRange, now: now, calendar: periodCalendar
        )
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

    /// El calendario con el que se cortan los períodos: el del usuario (su `firstWeekday`), en la zona del calendario que
    /// recibe la frase. En la app las dos zonas son la del proceso y esto da `userConfiguredCalendar()`, lo de siempre;
    /// un llamador que fija otra zona (los tests) corta los períodos en la suya y no en la del simulador.
    static func periodCalendar(in timeZone: TimeZone) -> Calendar {
        var calendar = userConfiguredCalendar()
        calendar.timeZone = timeZone
        return calendar
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
}

// MARK: - La marca de cambio de la Comparativa

/// Cómo se pinta el cambio de una fila de la Comparativa de Reportes (pedido de Jürgen del 17-nov: «más simple y visual»).
/// Una flecha y el porcentaje, en verde si el cambio te favorece y en rosa si no; en gris si no cambió casi nada.
///
/// Lógica pura: la vista solo elige color y texto a partir de esto.
enum ComparisonChange: Equatable {
    /// Subió o bajó al menos un 1 %. `isGood`: más ingresos o menos gasto.
    case up(percent: Double, isGood: Bool)
    case down(percent: Double, isGood: Bool)
    /// Se movió, pero menos de un 1 %: flecha sin bueno ni malo.
    case minorUp(percent: Double)
    case minorDown(percent: Double)
    /// Redondea a 0 %: «igual».
    case same
    /// No hubo nada en el período anterior y ahora sí: «nuevo», nunca un % infinito.
    case new
    /// Ni antes ni ahora: «—».
    case empty

    /// Por debajo de este cambio (en %) la flecha va en gris.
    static let minorThreshold: Double = 1
    /// Por debajo de esto el porcentaje redondea a 0: «igual».
    static let sameThreshold: Double = 0.05

    /// - Parameters:
    ///   - variation: el cambio en % (`PivotNode.variation`): positivo si el monto creció, también en gastos (se calcula
    ///     sobre los valores absolutos).
    ///   - hasPrevious: si hubo movimientos en el período anterior.
    ///   - currentAmount: el monto actual, para separar «nuevo» de «—».
    ///   - isExpense: un gasto que sube es malo; un ingreso o lo que te quedó que sube es bueno.
    static func make(variation: Double?, hasPrevious: Bool, currentAmount: Double, isExpense: Bool) -> ComparisonChange {
        guard hasPrevious, let variation, variation.isFinite else {
            return currentAmount == 0 ? .empty : .new
        }
        let magnitude = abs(variation)
        if magnitude < sameThreshold { return .same }
        if magnitude < minorThreshold {
            return variation > 0 ? .minorUp(percent: magnitude) : .minorDown(percent: magnitude)
        }
        let isGood = isExpense ? variation < 0 : variation > 0
        return variation > 0 ? .up(percent: magnitude, isGood: isGood) : .down(percent: magnitude, isGood: isGood)
    }

    /// El porcentaje sin signo («27 %», «4,5 %»): la dirección la dice la flecha. Sin decimales desde el 10 %; más de
    /// 999 % se escribe «> 999 %».
    static func percentText(_ percent: Double, locale: Locale = AppLocale.current) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.locale = locale
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = percent < 10 ? 1 : 0
        if percent > 999 {
            let capped = formatter.string(from: NSNumber(value: 9.99)) ?? "999%"
            return "> \(capped)"
        }
        return formatter.string(from: NSNumber(value: percent / 100)) ?? "\(Int(percent.rounded()))%"
    }

    /// El texto visible de la marca, sin la flecha.
    func text(locale: Locale = AppLocale.current) -> String {
        switch self {
        case .up(let p, _), .down(let p, _), .minorUp(let p), .minorDown(let p):
            return Self.percentText(p, locale: locale)
        case .same: return L10n.UXL18.changeSame
        case .new: return L10n.UXL18.changeNew
        case .empty: return "—"
        }
    }

    /// La flecha (símbolo SF), o `nil` si la marca es una palabra.
    var arrowSymbol: String? {
        switch self {
        case .up, .minorUp: return "arrow.up"
        case .down, .minorDown: return "arrow.down"
        case .same, .new, .empty: return nil
        }
    }

    /// `true` bueno, `false` malo, `nil` neutro (sin color).
    var isGood: Bool? {
        switch self {
        case .up(_, let good), .down(_, let good): return good
        default: return nil
        }
    }

    /// Lo que lee VoiceOver tras el monto: «subió 27 % frente a octubre». `versus` ya trae la preposición
    /// (`ComparativaSimpleText.versus`).
    func accessibilityText(versus: String, locale: Locale = AppLocale.current) -> String {
        switch self {
        case .up(let p, _), .minorUp(let p):
            return ComparativaSimpleText.up(Self.percentText(p, locale: locale), versus)
        case .down(let p, _), .minorDown(let p):
            return ComparativaSimpleText.down(Self.percentText(p, locale: locale), versus)
        case .same: return ComparativaSimpleText.same(versus)
        case .new: return ComparativaSimpleText.new
        case .empty: return ComparativaSimpleText.nothing
        }
    }
}

// MARK: - Textos

/// Los textos de la Comparativa simple, en su tabla propia (`ComparativaSimple.strings`), con la misma cadena de idiomas
/// que `ls()`: el idioma elegido dentro de Yala, su variante y su idioma padre.
enum ComparativaSimpleText {
    static let table = "ComparativaSimple"

    static func string(_ key: String, resolution: LocaleResolution = LanguageManager.resolved) -> String {
        let sentinel = "__YALA_MISSING__"
        let fullKey = "comparativaSimple.\(key)"
        var value = resolution.bundle.localizedString(forKey: fullKey, value: sentinel, table: table)
        if value == sentinel, let parent = resolution.parentBundle {
            value = parent.localizedString(forKey: fullKey, value: sentinel, table: table)
        }
        if value == sentinel {
            value = Bundle.main.localizedString(forKey: fullKey, value: sentinel, table: table)
        }
        return value == sentinel ? fullKey : value
    }

    /// «frente a octubre» / «frente al 1–17 de octubre» (un tramo de días lleva artículo).
    static func versus(_ period: String, isDayRange: Bool) -> String {
        String(format: string(isDayRange ? "versusRange" : "versus"), period)
    }
    static func up(_ percent: String, _ versus: String) -> String { String(format: string("a11y.up"), percent, versus) }
    static func down(_ percent: String, _ versus: String) -> String { String(format: string("a11y.down"), percent, versus) }
    static func same(_ versus: String) -> String { String(format: string("a11y.same"), versus) }
    /// «nuevo, antes no había nada»: sin período, que no aporta nada a VoiceOver.
    static var new: String { string("a11y.new") }
    /// Ni antes ni ahora.
    static var nothing: String { string("a11y.none") }
    /// «antes, S/ 9,976».
    static func before(_ amount: String) -> String { String(format: string("a11y.before"), amount) }
}
