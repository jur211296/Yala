//
//  L10n+UXAudit22Decidido02B.swift
//  Yala
//
//  Textos del lote decidido 2.2 · 02, sesión B: los textos y lo visual del formulario de registro (L2-3, L2-8…L2-12,
//  L2-16…L2-18). En su propio fichero, como los de cada lote, para no pisar `L10n.swift` con otras sesiones.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` allí.
private func l2b(_ key: String) -> String {
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
    enum UXL2B {

        // MARK: - L2-3 · Elegir la categoría

        /// «No hay ninguna categoría con «x»». %@ = lo escrito en el buscador.
        static func categorySearchEmpty(_ query: String) -> String {
            String(format: l2b("l2d.category.searchEmpty"), query)
        }

        // MARK: - L2-8 · La descripción

        static var noteExample: String { l2b("l2d.note.example") }
        static var hintCategory: String { l2b("l2d.hint.category") }
        static var hintTag: String { l2b("l2d.hint.tag") }
        static var hintAccount: String { l2b("l2d.hint.account") }

        // MARK: - L2-9 · La necesidad

        static var needPurpose: String { l2b("l2d.need.purpose") }

        // MARK: - L2-10 · Etiqueta nueva

        static var createTag: String { l2b("l2d.tag.create") }

        // MARK: - L2-11 y L2-18 · El tipo de cambio

        static var rateToday: String { l2b("l2d.rate.today") }
        /// %@ = el día del registro («19 oct»).
        static func rateOnDate(_ day: String) -> String { String(format: l2b("l2d.rate.onDate"), day) }
        /// %@ = «Tipo de cambio de hoy» o «… del 19 oct».
        static func rateWithHint(_ caption: String) -> String { String(format: l2b("l2d.rate.withHint"), caption) }
        static var rateEditHint: String { l2b("l2d.rate.editHint") }

        // MARK: - L2-12 · Mi parte

        static var splitButton: String { l2b("l2d.split.button") }
        static func splitChipEqual(total: String, people: Int) -> String {
            String(format: l2b("l2d.split.chip.equal"), total, people)
        }
        static func splitChipPercentage(total: String, percent: String) -> String {
            String(format: l2b("l2d.split.chip.percentage"), total, percent)
        }
        static func splitChipShares(total: String, mine: Int, of totalShares: Int) -> String {
            String(format: l2b("l2d.split.chip.shares"), total, mine, totalShares)
        }
        static func splitChipExact(total: String) -> String { String(format: l2b("l2d.split.chip.exact"), total) }

        // MARK: - L2-16 · La pregunta del monto

        static var questionExpense: String { l2b("l2d.amount.question.expense") }
        static var questionIncome: String { l2b("l2d.amount.question.income") }
        static var questionTransfer: String { l2b("l2d.amount.question.transfer") }

        // MARK: - L2-17 · El resultado de «Mi parte»

        static var splitYouPay: String { l2b("l2d.split.youPay") }
        static func splitFormulaEqual(total: String, people: Int, each: String) -> String {
            String(format: l2b("l2d.split.formula.equal"), total, people, each)
        }
        static func splitFormulaPercentage(percent: String, total: String) -> String {
            String(format: l2b("l2d.split.formula.percentage"), percent, total)
        }
        static func splitFormulaShares(mine: Int, of totalShares: Int, total: String) -> String {
            String(format: l2b("l2d.split.formula.shares"), mine, totalShares, total)
        }
        static func splitFormulaExact(mine: String, total: String) -> String {
            String(format: l2b("l2d.split.formula.exact"), mine, total)
        }
        static func splitBarYou(_ amount: String) -> String { String(format: l2b("l2d.split.bar.you"), amount) }
        static func splitBarOthers(_ amount: String) -> String { String(format: l2b("l2d.split.bar.others"), amount) }
    }
}
