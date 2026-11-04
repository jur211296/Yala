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
        /// «Hoy puedes gastar S/ 42.30»
        static func canSpendToday(_ amount: String) -> String {
            String(format: dailyAllowanceString("budgets.daily.canSpend"), amount)
        }

        /// «Hoy te pasaste por S/ 8.00»
        static func overToday(_ amount: String) -> String {
            String(format: dailyAllowanceString("budgets.daily.overToday"), amount)
        }
    }
}
