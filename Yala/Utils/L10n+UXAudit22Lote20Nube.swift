//
//  L10n+UXAudit22Lote20Nube.swift
//  Yala
//
//  Textos de las decisiones de Jürgen sobre el lote 20 de la auditoría UX 2.2 · nube e iCloud (L20-11…18): la hoja única
//  de activar la nube, la pantalla de iCloud y la instrucción única de reabrir Yala. En su propio fichero, como los de
//  cada lote, para no pisar `L10n.swift` con otras sesiones. «registros» y no «movimientos»: L7-18.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` allí.
private func l20n(_ key: String) -> String {
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
    enum UXL20N {

        // MARK: - L20-11 / L20-12 · la hoja única de activar la nube

        static var sheetTitle: String { l20n("l20n.sheet.title") }
        static var anyPhoneTitle: String { l20n("l20n.sheet.anyPhoneTitle") }
        static var anyPhoneDetail: String { l20n("l20n.sheet.anyPhoneDetail") }
        static var seesTitle: String { l20n("l20n.sheet.seesTitle") }
        static var seesDetail: String { l20n("l20n.sheet.seesDetail") }
        static var accessTitle: String { l20n("l20n.sheet.accessTitle") }
        static var accessDetail: String { l20n("l20n.sheet.accessDetail") }
        static var exportCopy: String { l20n("l20n.sheet.exportCopy") }
        static var details: String { l20n("l20n.sheet.details") }
        static var hideDetails: String { l20n("l20n.sheet.hideDetails") }
        /// El punto de la entrada del contrato, sin la ruta «Ajustes → Exportar datos»: la hoja lleva el botón (L20-12).
        static var detailsAccess: String { l20n("l20n.sheet.detailsAccess") }
        static var continueCurrent: String { l20n("l20n.sheet.continueCurrent") }

        /// «Pasarán 32 registros, 2 cuentas y 6 presupuestos.» Cada cifra con su plural (stringsdict).
        static func willMove(records: Int, accounts: Int, budgets: Int) -> String {
            String(format: l20n("l20n.sheet.willMove"),
                   String.localizedStringWithFormat(l20n("l20n.count.records"), records),
                   String.localizedStringWithFormat(l20n("l20n.count.accounts"), accounts),
                   String.localizedStringWithFormat(l20n("l20n.count.budgets"), budgets))
        }

        // MARK: - L20-18 · reabrir Yala

        static var relaunchAlmostTitle: String { l20n("l20n.relaunch.almostTitle") }
        static var relaunchDoneSignedOut: String { l20n("l20n.relaunch.doneSignedOut") }
        static var relaunchAfterSignOut: String { l20n("l20n.relaunch.afterSignOut") }
        static var relaunchAfterGroupsOnly: String { l20n("l20n.relaunch.afterGroupsOnly") }
        static var relaunchDoneInCloud: String { l20n("l20n.relaunch.doneInCloud") }
        static var relaunchDoneOnPhone: String { l20n("l20n.relaunch.doneOnPhone") }
        static var relaunchAfterToICloud: String { l20n("l20n.relaunch.afterToICloud") }
        static var relaunchDoneReverseStopped: String { l20n("l20n.relaunch.doneReverseStopped") }
        static var relaunchPending: String { l20n("l20n.relaunch.pending") }
        static var relaunchToFinish: String { l20n("l20n.relaunch.toFinish") }
        static var relaunchStep1: String { l20n("l20n.relaunch.step1") }
        static var relaunchStep1HomeButton: String { l20n("l20n.relaunch.step1HomeButton") }
        static var relaunchStep2: String { l20n("l20n.relaunch.step2") }
        static var relaunchStep3: String { l20n("l20n.relaunch.step3") }
        static var relaunchPendingA11y: String { l20n("l20n.relaunch.pendingA11y") }
        static func relaunchDoneA11y(_ line: String) -> String {
            String(format: l20n("l20n.relaunch.doneA11y"), line)
        }
        /// «iCloud ya disponible»: el motivo y los tres pasos numerados.
        static func mismatchMessage(steps: String) -> String {
            String(format: l20n("l20n.relaunch.mismatchMessage"), steps)
        }

        // MARK: - L20-14 · la pantalla de iCloud

        static var icloudNoAccountDetail: String { l20n("l20n.icloud.noAccountDetail") }
        static var icloudOpenSettings: String { l20n("l20n.icloud.openSettings") }
        static var icloudMailSubject: String { l20n("l20n.icloud.mailSubject") }
        static var icloudContactFooter: String { l20n("l20n.icloud.contactFooter") }
    }
}
