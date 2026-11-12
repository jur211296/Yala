//
//  L10n+TarjetaCredito.swift
//  Yala
//
//  Textos de la tarjeta de crédito con día de corte (card nmtk): el formulario, el estado de cuenta de la ficha, el aviso
//  antes de pagar y la fila del flujo de caja. En su propio fichero, como los de cada lote, para no pisar `L10n.swift`.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` allí.
private func lcc(_ key: String) -> String {
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

extension L10n.Account.CreditCard {
    static var statementDay: String { lcc("account.creditCard.statementDay") }
    static var statementDayNone: String { lcc("account.creditCard.statementDayNone") }
    static func cycleFooterNextMonth(_ statementDay: Int, _ paymentDay: Int) -> String {
        String(format: lcc("account.creditCard.cycleFooterNextMonth %1$d %2$d"), statementDay, paymentDay)
    }
    static func cycleFooterSameMonth(_ statementDay: Int, _ paymentDay: Int) -> String {
        String(format: lcc("account.creditCard.cycleFooterSameMonth %1$d %2$d"), statementDay, paymentDay)
    }
    static var cycleFooterNoStatement: String { lcc("account.creditCard.cycleFooterNoStatement") }
    static var reminderSection: String { lcc("account.creditCard.reminderSection") }
    static var reminderWhen: String { lcc("account.creditCard.reminderWhen") }
    static var reminderSameDay: String { lcc("account.creditCard.reminderSameDay") }
    static var reminderOneDayBefore: String { lcc("account.creditCard.reminderOneDayBefore") }
    static func reminderDaysBefore(_ days: Int) -> String {
        String(format: lcc("account.creditCard.reminderDaysBefore %d"), days)
    }
    static func reminderFooterNext(_ day: String) -> String {
        String(format: lcc("account.creditCard.reminderFooterNext %@"), day)
    }
    static var reminderFooterNoStatement: String { lcc("account.creditCard.reminderFooterNoStatement") }
}

extension L10n {
    /// El estado de cuenta de la ficha y el texto del aviso (card nmtk).
    enum CreditCardStatement {
        static func title(_ statementDate: String) -> String {
            String(format: lcc("creditCardStatement.title %@"), statementDate)
        }
        static var billed: String { lcc("creditCardStatement.billed") }
        static var unbilled: String { lcc("creditCardStatement.unbilled") }
        static func payBy(_ date: String) -> String { String(format: lcc("creditCardStatement.payBy %@"), date) }
        static func overdue(_ date: String) -> String { String(format: lcc("creditCardStatement.overdue %@"), date) }
        static var nothingDue: String { lcc("creditCardStatement.nothingDue") }
        static func nextStatement(_ date: String) -> String {
            String(format: lcc("creditCardStatement.nextStatement %@"), date)
        }
        static func reminderPayBy(_ amount: String, _ date: String) -> String {
            String(format: lcc("creditCardStatement.reminderPayBy %1$@ %2$@"), amount, date)
        }
        static func reminderDueToday(_ amount: String) -> String {
            String(format: lcc("creditCardStatement.reminderDueToday %@"), amount)
        }
        static func reminderPayByNoAmount(_ date: String) -> String {
            String(format: lcc("creditCardStatement.reminderPayByNoAmount %@"), date)
        }
    }
}

extension L10n.CashFlowPlan {
    static func cardPaymentTitle(_ cardName: String, _ date: String) -> String {
        String(format: lcc("cashFlowPlan.cardPaymentTitle %1$@ %2$@"), cardName, date)
    }
    static var cardPaymentNote: String { lcc("cashFlowPlan.cardPaymentNote") }
}
