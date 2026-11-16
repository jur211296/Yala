//
//  L10n+GruposNecesarias23Lote06.swift
//  Yala
//
//  Textos de «Mejoras necesarias 2.3 · Grupos: saldos que se contradicen y lectura con VoiceOver» (lote 06). En su propio
//  fichero, como los de cada lote, para no pisar `L10n.swift` con otras sesiones. «Sin gastos» reusa
//  `L10n.Groups.Expense.noExpenses`, el vacío de la pestaña Gastos.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` allí.
private func g06(_ key: String) -> String {
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
    enum GroupsNecesarias06 {

        // MARK: - 1 · La frase de la cifra

        /// «Te deben S/ 30.00 y tú debes S/ 40.00.»: cuando en una moneda debes y te deben a la vez («Menos pagos»
        /// apagado), con las sumas de las tarjetas de debajo.
        static func summaryBoth(owedToMe: String, iOwe: String) -> String {
            String(format: g06("groups.n23l06.summaryBoth"), owedToMe, iOwe)
        }

        /// El rótulo sobre la cifra cuando el neto es cero pero debes y te deben: «Estás a mano» lo negaba.
        static var summaryEvenCaption: String { g06("groups.n23l06.summaryEvenCaption") }

        // MARK: - 2 · «Beto te paga»

        /// El texto que sigue al nombre en la tarjeta de una deuda que te pagan a ti.
        static var paysYou: String { g06("groups.n23l06.paysYou") }

        /// VoiceOver de esa tarjeta: «Beto te paga: S/ 30.00».
        static func debtA11yToMe(from: String, amounts: String) -> String {
            String(format: g06("groups.n23l06.debtA11yToMe"), from, amounts)
        }

        // MARK: - 4 · VoiceOver: importes con nombre y pagos en una frase

        static var expenseAmountA11y: String { g06("groups.n23l06.expenseAmountA11y") }
        static var settlementAmountA11y: String { g06("groups.n23l06.settlementAmountA11y") }
        static var settlementCurrencyA11y: String { g06("groups.n23l06.settlementCurrencyA11y") }
        /// El valor de un importe sin escribir (VoiceOver leía el ejemplo «0.00»).
        static var amountEmptyA11y: String { g06("groups.n23l06.amountEmptyA11y") }

        /// «Le pagaste a Ana S/ 10.00, 10 nov 2026. Confirmada.»
        static func settlementFromMe(to: String, amount: String, date: String, status: String) -> String {
            String(format: g06("groups.n23l06.settlementA11y.fromMe"), to, amount, date, status)
        }

        /// «Beto te pagó S/ 10.00, 10 nov 2026. Confirmada.»
        static func settlementToMe(from: String, amount: String, date: String, status: String) -> String {
            String(format: g06("groups.n23l06.settlementA11y.toMe"), from, amount, date, status)
        }

        /// «Beto le pagó a Ana S/ 10.00, 10 nov 2026. Falta que Ana lo confirme.»
        static func settlementOthers(from: String, to: String, amount: String, date: String, status: String) -> String {
            String(format: g06("groups.n23l06.settlementA11y.others"), from, to, amount, date, status)
        }
    }
}
