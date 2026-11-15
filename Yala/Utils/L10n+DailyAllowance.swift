//
//  L10n+DailyAllowance.swift
//  Yala
//
//  «Cuánto puedo gastar hoy» (2.3): el cupo del día de un presupuesto. En su propio fichero, como los lotes de 2.2.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` en su
/// fichero.
private func dailyAllowanceString(_ key: String) -> String {
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
    enum DailyAllowance {
        /// La línea neutra del cupo del día (decisión 23 de 2.3). Cada importe llega ya formateado; `spentToday` y
        /// `overPerDay` en `nil` cuando no hay nada que decir de hoy.
        ///
        /// - Sin gasto hoy: «Quedan 5 días y S/ 400.00: unos S/ 80.00 al día.»
        /// - Con gasto hoy: «Empezaste el día con S/ 400.00 para 5 días: unos S/ 80.00 al día. Hoy llevas S/ 120.00,
        ///   S/ 40.00 más que eso.» Lo de antes de hoy va como «al empezar el día» para no contradecir el «Te quedan» de
        ///   arriba, que ya descuenta lo de hoy.
        /// - El último día: «Último día: quedan S/ 50.00.» / «Empezaste el último día con S/ 50.00. Hoy llevas S/ 30.00.»
        static func guide(
            daysRemaining: Int,
            leftAtStartOfDay: String,
            perDay: String,
            spentToday: String?,
            overPerDay: String?
        ) -> String {
            var sentences: [String] = []
            if daysRemaining <= 1 {
                let key = spentToday == nil ? "budgets.daily.lastDay" : "budgets.daily.lastDayFromStartOfDay"
                sentences.append(String(format: dailyAllowanceString(key), leftAtStartOfDay))
            } else {
                let days = L10n.UXL9.shortDays(daysRemaining)
                let key = spentToday == nil ? "budgets.daily.plan" : "budgets.daily.planFromStartOfDay"
                sentences.append(String(format: dailyAllowanceString(key), days, leftAtStartOfDay, perDay))
            }
            if let spentToday {
                if let overPerDay {
                    sentences.append(String(format: dailyAllowanceString("budgets.daily.spentTodayAbove"), spentToday, overPerDay))
                } else {
                    sentences.append(String(format: dailyAllowanceString("budgets.daily.spentToday"), spentToday))
                }
            }
            return sentences.joined(separator: " ")
        }
    }
}
