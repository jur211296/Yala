//
//  PagosRecurrentesText.swift
//  Yala
//
//  Textos de «Pagos que se repiten» (lote S1). En su propio fichero, como `L10n+UXAudit22Lote10.swift`, para no tocar
//  `L10n.swift`. El único plural, el del banner, vive en el `.stringsdict`.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` en su
/// fichero.
private func pr(_ key: String) -> String {
    let fullKey = "pagosRecurrentes.\(key)"
    let resolution = LanguageManager.resolved
    let sentinel = "__YALA_MISSING__"
    let variantValue = NSLocalizedString(fullKey, bundle: resolution.bundle, value: sentinel, comment: "")
    if variantValue != sentinel { return variantValue }
    if let parent = resolution.parentBundle {
        let parentValue = NSLocalizedString(fullKey, bundle: parent, value: sentinel, comment: "")
        if parentValue != sentinel { return parentValue }
    }
    let mainValue = NSLocalizedString(fullKey, bundle: .main, value: sentinel, comment: "")
    if mainValue != sentinel { return mainValue }
    return fullKey
}

enum PagosRecurrentesText {
    static var cardTitle: String { pr("card.title") }
    static var cardSubtitle: String { pr("card.subtitle") }
    static var cardManage: String { pr("card.manage") }
    static var cardManageA11y: String { pr("card.manageA11y") }

    static func cadenceMonthly(day: String) -> String { String(format: pr("cadence.monthly"), day) }
    static func cadenceMonthlyApprox(day: String) -> String { String(format: pr("cadence.monthlyApprox"), day) }
    static func cadenceWeekly(weekday: String) -> String { String(format: pr("cadence.weekly"), weekday) }

    /// «Encontramos 3 pagos que se repiten. Puedes agregarlos a tus pagos planificados.» Plural del `.stringsdict`.
    static func bannerFound(_ count: Int) -> String {
        String.localizedStringWithFormat(pr("banner.found"), count)
    }
    static var listFooter: String { pr("list.footer") }
    static var create: String { pr("sheet.create") }
    static var notFixed: String { pr("sheet.notFixed") }
    static var notNow: String { pr("sheet.notNow") }

    static func createdNotice(name: String, reminderDate: String) -> String {
        String(format: pr("created.notice"), name, reminderDate)
    }
    static func createdNoticeNoReminder(name: String) -> String { String(format: pr("created.noticeNoReminder"), name) }
    static var createdView: String { pr("created.view") }

    static var settingsTitle: String { pr("settings.title") }
    static var settingsToggle: String { pr("settings.toggle") }
    static var settingsFooter: String { pr("settings.footer") }
    static var settingsDismissed: String { pr("settings.dismissed") }
    static func settingsDismissedOn(_ date: String) -> String { String(format: pr("settings.dismissedOn"), date) }
    static var settingsRestore: String { pr("settings.restore") }
    static var settingsDone: String { pr("settings.done") }

    static var footerLink: String { pr("footer.link") }
    static var footerOff: String { pr("footer.off") }
}
