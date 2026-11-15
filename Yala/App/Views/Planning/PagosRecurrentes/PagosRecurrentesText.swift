//
//  PagosRecurrentesText.swift
//  Yala
//
//  Textos de «Pagos que se repiten» (lote S1). En su propio fichero, como `L10n+UXAudit22Lote10.swift`, para no tocar
//  `L10n.swift`. Sin plurales: la frase lleva el número detrás de dos puntos («Cobros encontrados: 5»).
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

    static func chargesFound(_ count: String) -> String { String(format: pr("sheet.chargesFound"), count) }
    static func lastCharge(_ date: String) -> String { String(format: pr("sheet.lastCharge"), date) }
    static var amount: String { pr("sheet.amount") }
    static var frequency: String { pr("sheet.frequency") }
    static var frequencyMonthly: String { pr("sheet.frequencyMonthly") }
    static var frequencyWeekly: String { pr("sheet.frequencyWeekly") }
    static var nextCharge: String { pr("sheet.nextCharge") }
    static var account: String { pr("sheet.account") }
    static var chooseAccount: String { pr("sheet.chooseAccount") }
    static var category: String { pr("sheet.category") }
    static var notify: String { pr("sheet.notify") }
    static var variableAmount: String { pr("sheet.variable") }
    static var create: String { pr("sheet.create") }
    static var notFixed: String { pr("sheet.notFixed") }
    static var notNow: String { pr("sheet.notNow") }

    static var notifyNone: String { pr("notify.none") }
    static var notifySameDay: String { pr("notify.sameDay") }
    static var notifyOneDay: String { pr("notify.oneDay") }
    static var notifyThreeDays: String { pr("notify.threeDays") }
    static var notifyOneWeek: String { pr("notify.oneWeek") }

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
