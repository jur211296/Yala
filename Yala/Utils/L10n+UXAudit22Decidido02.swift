//
//  L10n+UXAudit22Decidido02.swift
//  Yala
//
//  Textos del lote decidido 2.2 · 02, sesión A: el formulario de registro (L2-1…L2-15 y las dos cards que se le
//  sumaron). En su propio fichero, como los de cada lote, para no pisar `L10n.swift` con otras sesiones.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` allí.
private func l2d(_ key: String) -> String {
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
    enum UXL2 {

        // MARK: - L2-2 · Lo que falta para guardar

        /// «Para guardar, falta %@». %@ = la lista de lo que falta, ya unida («la cuenta y la categoría»).
        static func missingToSave(_ list: String) -> String { String(format: l2d("l2d.missing.toSave"), list) }
        static var missingAmount: String { l2d("l2d.missing.amount") }
        static var missingAccount: String { l2d("l2d.missing.account") }
        static var missingCategory: String { l2d("l2d.missing.category") }
        static var missingSourceAccount: String { l2d("l2d.missing.sourceAccount") }
        static var missingDestinationAccount: String { l2d("l2d.missing.destinationAccount") }
        static var chooseTwoDifferentAccounts: String { l2d("l2d.missing.twoDifferentAccounts") }
        /// Valor de VoiceOver de un chip que falta para guardar («Falta»).
        static var missingChipValue: String { l2d("l2d.missing.chipValue") }

        // MARK: - L2-4 · Descartar

        static var discardTitle: String { l2d("l2d.discard.title") }

        // MARK: - L2-5 · El aviso tras guardar

        static func savedExpense(_ amount: String) -> String { String(format: l2d("l2d.saved.expense"), amount) }
        static func savedIncome(_ amount: String) -> String { String(format: l2d("l2d.saved.income"), amount) }
        static func savedTransfer(_ amount: String) -> String { String(format: l2d("l2d.saved.transfer"), amount) }
        static var savedChanges: String { l2d("l2d.saved.changes") }
        static var savedRepeatsWeekly: String { l2d("l2d.saved.repeatsWeekly") }
        static var savedRepeatsMonthly: String { l2d("l2d.saved.repeatsMonthly") }
        static var savedRepeatsYearly: String { l2d("l2d.saved.repeatsYearly") }

        // MARK: - L2-6 · Transferencia con una sola cuenta

        static var needsAnotherAccount: String { l2d("l2d.transfer.needsAnotherAccount") }
        static var createAnotherAccount: String { l2d("l2d.transfer.createAnotherAccount") }

        // MARK: - L2-7 · La fecha

        static var dayBeforeYesterday: String { l2d("l2d.date.dayBeforeYesterday") }
        /// Lleva un enlace en markdown a Pagos planificados (`yala-form://scheduled`).
        static var futureDaysNote: String { l2d("l2d.date.futureDaysNote") }

        // MARK: - L2-13 · Favoritos

        static var favoritesSeeAll: String { l2d("l2d.favorites.seeAll") }
        static func useFavorite(_ name: String) -> String { String(format: l2d("l2d.favorites.use"), name) }
        static var transferFavoriteHelp: String { l2d("l2d.favorites.transferHelp") }

        // MARK: - L2-15 · Hacer recurrente

        static var recurringTitle: String { l2d("l2d.recurring.title") }
        static var recurringHeader: String { l2d("l2d.recurring.header") }
        /// %@ = el día de la semana («martes»).
        static func recurringWeekly(_ weekday: String) -> String { String(format: l2d("l2d.recurring.weekly"), weekday) }
        /// %d = el día del mes.
        static func recurringMonthly(_ day: Int) -> String { String(format: l2d("l2d.recurring.monthly"), day) }
        /// %@ = día y mes («13 de octubre»).
        static func recurringYearly(_ dayMonth: String) -> String { String(format: l2d("l2d.recurring.yearly"), dayMonth) }
        static var recurringMoreOptions: String { l2d("l2d.recurring.moreOptions") }
    }
}
