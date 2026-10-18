//
//  L10n+UXAudit22Lote10.swift
//  Yala
//
//  Textos de la auditoría UX 2.2, lote 10 (pagos planificados). Van en su propio fichero para no pisar `L10n.swift`
//  con los otros lotes de la misma tanda.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` en su
/// fichero. Repetirla aquí es lo que permite que este lote viva aparte.
private func l10(_ key: String) -> String {
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
    enum UXL10 {

        // MARK: - Estado de una fecha (L10-1, L10-3, L10-8)

        static var stateOverdue: String { l10("scheduled.l10.state.overdue") }
        static var stateToday: String { l10("scheduled.l10.state.today") }
        static var stateTomorrow: String { l10("scheduled.l10.state.tomorrow") }
        static func stateInDays(_ days: Int) -> String { String(format: l10("scheduled.l10.state.inDays"), days) }
        static var statePaid: String { l10("scheduled.l10.state.paid") }
        static var stateReceived: String { l10("scheduled.l10.state.received") }
        static var stateSkipped: String { l10("scheduled.l10.state.skipped") }
        static var statePaused: String { l10("scheduled.l10.state.paused") }
        static var stateFinished: String { l10("scheduled.l10.state.finished") }
        static var statePending: String { l10("scheduled.l10.state.pending") }

        // Detalle: el estado de la próxima fecha, en frase («Vence mañana»).
        static var dueOverdue: String { l10("scheduled.l10.due.overdue") }
        static var dueToday: String { l10("scheduled.l10.due.today") }
        static var dueTomorrow: String { l10("scheduled.l10.due.tomorrow") }
        static func dueInDays(_ days: Int) -> String { String(format: l10("scheduled.l10.due.inDays"), days) }

        // MARK: - Secciones y vistas (L10-1)

        static var sectionToPay: String { l10("scheduled.l10.section.toPay") }
        static var sectionPaid: String { l10("scheduled.l10.section.paid") }
        static var sectionSkipped: String { l10("scheduled.l10.section.skipped") }
        static var sectionPaused: String { l10("scheduled.l10.section.paused") }
        static var viewList: String { l10("scheduled.l10.view.list") }
        static var viewTimeline: String { l10("scheduled.l10.view.timeline") }
        static var viewCalendar: String { l10("scheduled.l10.view.calendar") }

        // MARK: - Cabecera (L10-2)

        static var heroToPay: String { l10("scheduled.l10.hero.toPay") }
        /// «Pagaste S/ 2,350 de S/ 2,753»
        static func heroPaidOf(_ paid: String, _ total: String) -> String {
            String(format: l10("scheduled.l10.hero.paidOf"), paid, total)
        }
        static var heroScope: String { l10("scheduled.l10.hero.scope") }

        // MARK: - Detalle (L10-7, L10-8, L10-10)

        /// «Octubre de 2026 ya está pagado»
        static func monthAlreadyPaid(_ month: String) -> String {
            String(format: l10("scheduled.l10.detail.monthPaid"), month)
        }
        static var actionPaid: String { l10("scheduled.l10.action.paid") }
        static var actionReceived: String { l10("scheduled.l10.action.received") }
        static var actionSkipMonth: String { l10("scheduled.l10.action.skipMonth") }
        static var actionSkipHelp: String { l10("scheduled.l10.action.skipHelp") }
        static var actionPause: String { l10("scheduled.l10.action.pause") }
        static var actionResume: String { l10("scheduled.l10.action.resume") }
        static var actionPauseHelp: String { l10("scheduled.l10.action.pauseHelp") }
        static var actionSkip: String { l10("scheduled.l10.action.skip") }
        static var dateActions: String { l10("scheduled.l10.dateActions") }
        /// «Saltaste el pago del 15 de octubre»
        static func skipped(_ date: String) -> String { String(format: l10("scheduled.l10.skipped"), date) }

        // MARK: - «Ya lo pagué» (L10-9)

        static var recordNow: String { l10("scheduled.l10.paid.recordNow") }
        /// «Lo apuntamos en Cuenta Principal. Puedes cambiar el monto.»
        static func recordNowHelp(_ account: String) -> String {
            String(format: l10("scheduled.l10.paid.recordNowHelp"), account)
        }
        static func recordButton(_ amount: String) -> String {
            String(format: l10("scheduled.l10.paid.recordButton"), amount)
        }
        static var alreadyRecorded: String { l10("scheduled.l10.paid.alreadyRecorded") }
        static var alreadyRecordedHelp: String { l10("scheduled.l10.paid.alreadyRecordedHelp") }
        static var candidatesExpenses: String { l10("scheduled.l10.paid.candidatesExpenses") }
        static var candidatesIncome: String { l10("scheduled.l10.paid.candidatesIncome") }
        static var candidatesEmpty: String { l10("scheduled.l10.paid.candidatesEmpty") }
        static func confirmTitle(_ name: String) -> String { String(format: l10("scheduled.l10.paid.confirmTitle"), name) }
        static var confirmMessage: String { l10("scheduled.l10.paid.confirmMessage") }
        static var confirmYes: String { l10("scheduled.l10.paid.confirmYes") }
        /// «Pagar ahora el del 18 de octubre» (L10-11)
        static func payNowTitle(_ date: String) -> String { String(format: l10("scheduled.l10.payNow.title"), date) }
        /// «Apuntar el del 15 de octubre»
        static func recordTitle(_ date: String) -> String { String(format: l10("scheduled.l10.record.title"), date) }

        // MARK: - Tras guardar (L10-5)

        static func savedFirstPayment(_ date: String) -> String {
            String(format: l10("scheduled.l10.saved.firstPayment"), date)
        }
        static var savedView: String { l10("scheduled.l10.saved.view") }

        // MARK: - Borrar (L10-15)

        static func deleteTitle(_ name: String) -> String { String(format: l10("scheduled.l10.delete.title"), name) }
        static var deleteKeepsRecords: String { l10("scheduled.l10.delete.keepsRecords") }
        static func deleted(_ name: String) -> String { String(format: l10("scheduled.l10.deleted"), name) }

        // MARK: - Editor (L10-4, L10-16)

        static var moreOptions: String { l10("scheduled.l10.editor.moreOptions") }
        static var when: String { l10("scheduled.l10.editor.when") }
        static var optional: String { l10("scheduled.l10.editor.optional") }
        static var missing: String { l10("scheduled.l10.editor.missing") }
        static var today: String { l10("scheduled.l10.summary.today") }
        /// «S/ 45.00 una sola vez, el 14 de octubre.»
        static func summaryOnce(_ amount: String, _ date: String) -> String {
            String(format: l10("scheduled.l10.summary.once"), amount, date)
        }
        /// «S/ 45.00 cada mes, el día 14. Primer pago: hoy.»
        static func summaryRecurring(_ amount: String, _ cadence: String, _ first: String) -> String {
            String(format: l10("scheduled.l10.summary.recurring"), amount, cadence, first)
        }
        static func cadenceMonthly(interval: Int, day: Int) -> String {
            interval == 1
                ? String(format: l10("scheduled.l10.cadence.month"), day)
                : String(format: l10("scheduled.l10.cadence.months"), interval, day)
        }
        static func cadenceWeekly(interval: Int) -> String {
            interval == 1 ? l10("scheduled.l10.cadence.week") : String(format: l10("scheduled.l10.cadence.weeks"), interval)
        }
        static func cadenceDaily(interval: Int) -> String {
            interval == 1 ? l10("scheduled.l10.cadence.day") : String(format: l10("scheduled.l10.cadence.days"), interval)
        }
        static func cadenceYearly(interval: Int, date: String) -> String {
            interval == 1
                ? String(format: l10("scheduled.l10.cadence.year"), date)
                : String(format: l10("scheduled.l10.cadence.years"), interval, date)
        }
    }
}
