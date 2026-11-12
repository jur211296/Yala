//
//  L10n+GruposNoTirar23.swift
//  Yala
//
//  Textos de la decisión 39 de la revisión 2.3 (Grupos: no tirar lo escrito). En su propio fichero, como los de cada
//  lote, para no pisar `L10n.swift` con otras sesiones. Los botones reusan «Descartar» y «Seguir editando» de
//  `L10n.Alert`, los mismos de «¿Descartar este registro?».
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` allí.
private func gnt(_ key: String) -> String {
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
    enum GroupsDiscard {
        /// «¿Descartar este gasto?»: la X o deslizar «Nuevo gasto» (o su edición) con algo cambiado.
        static var expenseTitle: String { gnt("groups.discard.expenseTitle") }
        /// «¿Descartar este pago?»: la X o deslizar «Saldar» con algo cambiado.
        static var paymentTitle: String { gnt("groups.discard.paymentTitle") }
        /// «¿Descartar este saldo inicial?»: la X o deslizar «Saldo inicial» con algo cambiado.
        static var openingBalanceTitle: String { gnt("groups.discard.openingBalanceTitle") }
        /// Bajo el grupo, tras cambiarlo en «Nuevo gasto» con algo escrito (F3).
        static var groupChangedNotice: String { gnt("groups.expense.groupChangedNotice") }
    }
}
