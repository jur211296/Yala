//
//  L10n+UXAudit22Lote11.swift
//  Yala
//
//  Textos de la implementación de la auditoría UX 2.2, lote 11 (Estadísticas). Van en su propio fichero para no pisar
//  `L10n.swift` con los otros lotes de la misma tanda.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` en su
/// fichero. Repetirla aquí es lo que permite que este lote viva aparte.
private func l11(_ key: String) -> String {
    let resolution = LanguageManager.resolved
    let sentinel = "__YALA_MISSING__"
    let variantValue = NSLocalizedString(key, bundle: resolution.bundle, value: sentinel, comment: "")
    if variantValue != sentinel { return variantValue }
    if let parent = resolution.parentBundle {
        let parentValue = NSLocalizedString(key, bundle: parent, value: sentinel, comment: "")
        if parentValue != sentinel { return parentValue }
    }
    let mainValue = NSLocalizedString(key, bundle: .main, value: sentinel, comment: "")
    if mainValue != sentinel { return mainValue }
    return key
}

extension L10n {
    enum UXL11 {

        // MARK: - Período: flechas y rango (L11-3)

        static var previousPeriod: String { l11("stats.l11.period.previous") }
        static var nextPeriod: String { l11("stats.l11.period.next") }
        static func periodRangeAccessibility(_ range: String) -> String {
            String(format: l11("stats.l11.period.rangeA11y"), range)
        }

        // MARK: - Con qué se compara (L11-4)

        static func comparedWith(_ range: String) -> String { String(format: l11("stats.l11.compare.with"), range) }
        static var comparisonHint: String { l11("stats.l11.compare.hint") }
        static var optionPreviousWeek: String { l11("stats.l11.compare.previousWeek") }
        static var optionPrevious7Days: String { l11("stats.l11.compare.previous7Days") }
        static var optionPrevious30Days: String { l11("stats.l11.compare.previous30Days") }
        static var optionPreviousMonth: String { l11("stats.l11.compare.previousMonth") }
        static var optionPreviousPeriod: String { l11("stats.l11.compare.previousPeriod") }
        static var optionPreviousYear: String { l11("stats.l11.compare.previousYear") }

        // MARK: - Gasto por día de la semana (L11-11)

        static var weekdayTitle: String { l11("stats.l11.weekday.title") }
        static var weekdayWeeklyCaption: String { l11("stats.l11.weekday.weeklyCaption") }
        /// «Los lunes son tu día más caro». Una frase por día (1 = domingo … 7 = sábado, como `Calendar`): el plural del
        /// día y la concordancia cambian de un idioma a otro y no se pueden armar con el nombre suelto.
        static func priciestWeekday(_ weekday: Int) -> String {
            l11("stats.l11.weekday.priciest.\(min(max(weekday, 1), 7))")
        }
    }
}
