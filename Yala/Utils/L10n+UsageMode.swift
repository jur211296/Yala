//
//  L10n+UsageMode.swift
//  Yala
//
//  Textos de «Cómo usas Yala»: pasar de Yala completo a solo grupos y volver (card p0iu, lienzo elegido por Jürgen el
//  2026-10-26). En su propio fichero, como los de cada lote, para no pisar `L10n.swift` con otras sesiones.
//  «registros» y no «movimientos» (L7-18, `docs/glosario.md`), y «este dispositivo», como «Vaciar datos».
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` allí.
private func usageModeString(_ key: String) -> String {
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

private func plural(_ key: String, _ count: Int) -> String {
    String.localizedStringWithFormat(usageModeString(key), count)
}

extension L10n {
    enum UsageMode {
        // MARK: - Ajustes › «Cómo usas Yala»
        static var rowTitle: String { usageModeString("usageMode.row.title") }
        static var fullTitle: String { usageModeString("usageMode.full.title") }
        static var fullBody: String { usageModeString("usageMode.full.body") }
        static var groupsOnlyTitle: String { usageModeString("usageMode.groupsOnly.title") }
        /// Para quien tiene datos personales guardados: dice que no se borran.
        static var groupsOnlyBody: String { usageModeString("usageMode.groupsOnly.body") }
        /// Para quien nunca tuvo Yala completo: no hay nada guardado de qué hablar.
        static var groupsOnlyBodyNew: String { usageModeString("usageMode.groupsOnly.bodyNew") }
        static var screenIntro: String { usageModeString("usageMode.screen.intro") }
        static var screenFooter: String { usageModeString("usageMode.screen.footer") }

        // MARK: - Ida
        static var leaveTitle: String { usageModeString("usageMode.leave.title") }
        static var leaveBody: String { usageModeString("usageMode.leave.body") }
        static var leaveGroupsStay: String { usageModeString("usageMode.leave.groupsStay") }
        static var leavePaused: String { usageModeString("usageMode.leave.paused") }
        static var leavePro: String { usageModeString("usageMode.leave.pro") }
        static var leaveConfirm: String { usageModeString("usageMode.leave.confirm") }

        // MARK: - Vuelta
        static var backTitle: String { usageModeString("usageMode.back.title") }
        static var backSubtitle: String { usageModeString("usageMode.back.subtitle") }
        static var backToast: String { usageModeString("usageMode.back.toast") }
        static func savedTitle(_ records: Int) -> String { plural("usageMode.back.savedTitle", records) }
        static func savedQuestion(_ records: Int) -> String { plural("usageMode.back.savedQuestion", records) }
        static func savedRange(from: String, to: String, accounts: Int) -> String {
            String(format: usageModeString("usageMode.back.range"), from, to, accountsCount(accounts))
        }
        static func savedRangeSameDay(_ day: String, accounts: Int) -> String {
            String(format: usageModeString("usageMode.back.rangeSameDay"), day, accountsCount(accounts))
        }
        static var keepTitle: String { usageModeString("usageMode.back.keepTitle") }
        static var keepBody: String { usageModeString("usageMode.back.keepBody") }
        static var freshTitle: String { usageModeString("usageMode.back.freshTitle") }
        static var freshBody: String { usageModeString("usageMode.back.freshBody") }
        static var continueAction: String { usageModeString("usageMode.back.continue") }
        static var notNow: String { usageModeString("usageMode.back.notNow") }

        // MARK: - «Empezar de cero»
        static var confirmTitle: String { usageModeString("usageMode.fresh.confirmTitle") }
        /// «Se borran N registros, N cuentas y N presupuestos de este dispositivo y de tu iCloud / de tu cuenta de Yala».
        static func confirmMessage(records: Int, accounts: Int, budgets: Int, inCloudAccount: Bool) -> String {
            let key = inCloudAccount ? "usageMode.fresh.confirmCloud" : "usageMode.fresh.confirmICloud"
            return String(format: usageModeString(key), recordsCount(records), accountsCount(accounts),
                          budgetsCount(budgets))
        }
        static var confirmButton: String { usageModeString("usageMode.fresh.confirmButton") }
        static var accountTitle: String { usageModeString("usageMode.account.title") }
        static var accountBody: String { usageModeString("usageMode.account.body") }
        static var accountNameLabel: String { usageModeString("usageMode.account.nameLabel") }
        static var accountCurrency: String { usageModeString("usageMode.account.currency") }
        static var accountFootnote: String { usageModeString("usageMode.account.footnote") }
        static var accountStart: String { usageModeString("usageMode.account.start") }
        static var working: String { usageModeString("usageMode.account.working") }
        static var error: String { usageModeString("usageMode.error") }

        static func recordsCount(_ count: Int) -> String { plural("usageMode.count.records", count) }
        static func accountsCount(_ count: Int) -> String { plural("usageMode.count.accounts", count) }
        static func budgetsCount(_ count: Int) -> String { plural("usageMode.count.budgets", count) }
    }
}
