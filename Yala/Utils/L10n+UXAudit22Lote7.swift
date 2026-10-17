//
//  L10n+UXAudit22Lote7.swift
//  Yala
//
//  Textos de la auditoría UX 2.2, lote 7 (cuentas, categorías, etiquetas, favoritos e importar).
//  Van en su propio fichero para no pisar `L10n.swift` con los otros lotes de la misma tanda.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es
/// `private` en su fichero. Repetirla aquí es lo que permite que este lote viva aparte.
private func l7(_ key: String) -> String {
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
    enum UXL7 {

        // MARK: - Formulario de cuenta (L7-1 … L7-4)

        static var balanceRequiredHint: String { l7("account.form.balanceRequiredHint") }
        static var generalTypeHint: String { l7("account.type.generalHint") }

        // MARK: - Editar el saldo (L7-6)

        enum BalanceEdit {
            static var sectionTitle: String { l7("account.balanceEdit.sectionTitle") }
            static var yalaSays: String { l7("account.balanceEdit.yalaSays") }
            static var question: String { l7("account.balanceEdit.question") }
            static var questionHint: String { l7("account.balanceEdit.questionHint") }
            static var difference: String { l7("account.balanceEdit.difference") }
            static var matches: String { l7("account.balanceEdit.matches") }
            static var howTitle: String { l7("account.balanceEdit.howTitle") }
            static var byEntryTitle: String { l7("account.balanceEdit.byEntryTitle") }
            static var byEntryDesc: String { l7("account.balanceEdit.byEntryDesc") }
            static var initialTitle: String { l7("account.balanceEdit.initialTitle") }
            static var initialDesc: String { l7("account.balanceEdit.initialDesc") }
            static func initialChange(_ before: String, _ after: String) -> String {
                String(format: l7("account.balanceEdit.initialChange"), before, after)
            }
            static func result(_ accountName: String, _ amount: String) -> String {
                String(format: l7("account.balanceEdit.result"), accountName, amount)
            }
        }

        // MARK: - Cambiar la moneda (L7-7)

        static var currencyIncludesInitialBalance: String { l7("account.currencyChange.includesInitialBalance") }
        static func currencyBalanceLine(_ before: String, _ after: String) -> String {
            String(format: l7("account.currencyChange.balanceLine"), before, after)
        }

        // MARK: - La moneda nueva en el Panel (L7-8)

        enum Secondary {
            static func addTitle(_ code: String) -> String {
                String(format: l7("account.secondaryCurrency.addTitle"), code)
            }
            static func addMessage(_ code: String, _ preferred: String) -> String {
                String(
                    format: l7("account.secondaryCurrency.addMessage"),
                    code, preferred, L10n.Profile.title, L10n.Settings.currencyAndExchange)
            }
            static var addAccept: String { l7("account.secondaryCurrency.addAccept") }
            static var replaceTitle: String { l7("account.secondaryCurrency.replaceTitle") }
            static func replaceMessage(_ first: String, _ second: String, _ new: String) -> String {
                String(format: l7("account.secondaryCurrency.replaceMessage"), first, second, new)
            }
            static func replaceButton(_ old: String, _ new: String) -> String {
                String(format: l7("account.secondaryCurrency.replaceButton"), old, new)
            }
            static var keep: String { l7("account.secondaryCurrency.keep") }
        }
    }
}
