//
//  L10n+GruposSaldar23.swift
//  Yala
//
//  Textos de la decisión 37 de la revisión 2.3 (Grupos: saldar como en Splitwise, C1 + C2 + C3). En su propio fichero,
//  como los de cada lote, para no pisar `L10n.swift` con otras sesiones. «Deshacer» reusa `L10n.UXL19.undo`, y «Falta
//  que X lo confirme» de la lista sigue en `L10n.UXL13.pendingWaitingFor`.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` allí.
private func gs23(_ key: String) -> String {
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
    enum GruposSaldar23 {

        // MARK: - C1 · Cualquiera apunta, quien recibe confirma

        /// En «Saldar», cuando lo apunta alguien que no paga ni recibe.
        static func thirdPartyHint(_ receiver: String) -> String {
            String(format: gs23("groups.saldar23.thirdPartyHint"), receiver)
        }
        /// En la lista de pagos, delante de «Falta que X lo confirme».
        static func recordedBy(_ name: String) -> String { String(format: gs23("groups.saldar23.recordedBy"), name) }
        static var recordedByYou: String { gs23("groups.saldar23.recordedByYou") }
        /// La tarjeta «¿Lo recibiste?» cuando el pago lo apuntó un tercero.
        static func pendingTitleOther(recorder: String, from: String, amount: String) -> String {
            String(format: gs23("groups.saldar23.pendingTitleOther"), recorder, from, amount)
        }

        // MARK: - C2 · Todo o una parte

        static var scopeA11y: String { gs23("groups.saldar23.scopeA11y") }
        static func scopeAll(_ amount: String) -> String { String(format: gs23("groups.saldar23.scopeAll"), amount) }
        static var scopePart: String { gs23("groups.saldar23.scopePart") }
        static func settlesWith(_ name: String) -> String { String(format: gs23("groups.saldar23.settlesWith"), name) }
        static func settlesOthers(from: String, to: String) -> String {
            String(format: gs23("groups.saldar23.settlesOthers"), from, to)
        }
        static func leavesYouPay(amount: String, to: String) -> String {
            String(format: gs23("groups.saldar23.leaves.youPay"), amount, to)
        }
        static func leavesPaysYou(from: String, amount: String) -> String {
            String(format: gs23("groups.saldar23.leaves.paysYou"), from, amount)
        }
        static func leavesOthers(from: String, amount: String, to: String) -> String {
            String(format: gs23("groups.saldar23.leaves.others"), from, amount, to)
        }
        static func overpaysYouPay(owed: String, to: String, excess: String) -> String {
            String(format: gs23("groups.saldar23.overpays.youPay"), owed, to, excess)
        }
        static func overpaysPaysYou(owed: String, excess: String, from: String) -> String {
            String(format: gs23("groups.saldar23.overpays.paysYou"), owed, excess, from)
        }
        static func overpaysOthers(from: String, to: String, owed: String, excess: String) -> String {
            String(format: gs23("groups.saldar23.overpays.others"), from, to, owed, excess)
        }
        static var saveAnyway: String { gs23("groups.saldar23.saveAnyway") }

        // MARK: - C3 · El aviso al guardar

        static func noticeYouPaid(amount: String, to: String) -> String {
            String(format: gs23("groups.saldar23.notice.youPaid"), amount, to)
        }
        static func noticePaidYou(from: String, amount: String) -> String {
            String(format: gs23("groups.saldar23.notice.paidYou"), from, amount)
        }
        static func noticeOthersPaid(from: String, amount: String, to: String) -> String {
            String(format: gs23("groups.saldar23.notice.othersPaid"), from, amount, to)
        }
        static func noticeWaitingFor(_ name: String) -> String {
            String(format: gs23("groups.saldar23.notice.waitingFor"), name)
        }
        static var noticeSettled: String { gs23("groups.saldar23.notice.settled") }
        static func noticeNowYouOwe(amounts: String, to: String) -> String {
            String(format: gs23("groups.saldar23.notice.nowYouOwe"), amounts, to)
        }
        static func noticeNowOwesYou(from: String, amounts: String) -> String {
            String(format: gs23("groups.saldar23.notice.nowOwesYou"), from, amounts)
        }
        static func noticeNowOthersOwe(from: String, amounts: String, to: String) -> String {
            String(format: gs23("groups.saldar23.notice.nowOthersOwe"), from, amounts, to)
        }
    }
}
