//
//  L10n+UXAudit22Lote12y13.swift
//  Yala
//
//  Textos de la auditoría UX 2.2, lotes 12 y 13 (Grupos: entrar, crear, invitar; gastos y saldar). Van en su propio
//  fichero para no pisar `L10n.swift` con los otros lotes de la misma tanda.
//

import Foundation

/// La misma cadena de búsqueda que `ls()` de `L10n.swift` (variante → padre → main → key), que es `private` en su
/// fichero. Repetirla aquí es lo que permite que este lote viva aparte.
private func l1213(_ key: String) -> String {
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
    enum UXL12 {

        // MARK: - L12-2 · Los estados vacíos con sus tres pasos

        static var stepsTitle: String { l1213("groups.l12.steps.title") }
        static var stepAccount: String { l1213("groups.l12.steps.account") }
        static var stepConsent: String { l1213("groups.l12.steps.consent") }
        static var stepCreate: String { l1213("groups.l12.steps.create") }
        static var stepsTellMe: String { l1213("groups.l12.steps.tellMe") }
        static var stepsFootnote: String { l1213("groups.l12.steps.footnote") }
        static func stepDoneA11y(_ step: String) -> String { String(format: l1213("groups.l12.steps.a11yDone"), step) }
        static func stepCurrentA11y(_ step: String) -> String {
            String(format: l1213("groups.l12.steps.a11yCurrent"), step)
        }
        static func stepNextA11y(_ step: String) -> String { String(format: l1213("groups.l12.steps.a11yNext"), step) }

        // MARK: - L12-10 · Tras crear el grupo, invitar

        static func createdTitle(_ name: String) -> String { String(format: l1213("groups.l12.created.title"), name) }
        static var createdMessage: String { l1213("groups.l12.created.message") }
        static var createdInvite: String { l1213("groups.l12.created.invite") }
        static var createdLater: String { l1213("groups.l12.created.later") }

        // MARK: - L12-13 · Invitar desde Miembros

        static var inviteTitle: String { l1213("groups.l12.invite.title") }
        static var inviteMessage: String { l1213("groups.l12.invite.message") }
        static var inviteShare: String { l1213("groups.l12.invite.share") }
    }

    enum UXL13 {

        // MARK: - L13-1 · Saldos

        static var summaryOwedToMe: String { l1213("groups.l13.summary.owedToMe") }
        static var summaryIOwe: String { l1213("groups.l13.summary.iOwe") }
        static var summarySettled: String { l1213("groups.l13.summary.settled") }
        static var summaryOwedToMeDetail: String { l1213("groups.l13.summary.owedToMeDetail") }
        static var summaryIOweDetail: String { l1213("groups.l13.summary.iOweDetail") }
        static func summaryAlsoOwe(_ amounts: String) -> String {
            String(format: l1213("groups.l13.summary.alsoOwe"), amounts)
        }
        static var summarySettledDetail: String { l1213("groups.l13.summary.settledDetail") }
        static var settleUpTitle: String { l1213("groups.l13.settleUp.title") }
        static var you: String { l1213("groups.l13.you") }
        static var settle: String { l1213("groups.l13.settle") }
        static var youPayTo: String { l1213("groups.l13.youPayTo") }
        static func debtA11yMe(to: String, amounts: String) -> String {
            String(format: l1213("groups.l13.debtA11yMe"), to, amounts)
        }
        static func debtA11y(from: String, to: String, amounts: String) -> String {
            String(format: l1213("groups.l13.debtA11y"), from, to, amounts)
        }

        // MARK: - L13-2 · Un pago que te toca confirmar

        static func pendingTitle(name: String, amount: String) -> String {
            String(format: l1213("groups.l13.pending.title"), name, amount)
        }
        static var pendingQuestion: String { l1213("groups.l13.pending.question") }
        static var pendingYes: String { l1213("groups.l13.pending.yes") }
        static var pendingNo: String { l1213("groups.l13.pending.no") }
        static func pendingRejectMessage(_ name: String) -> String {
            String(format: l1213("groups.l13.pending.rejectMessage"), name)
        }
        static var pendingRejectConfirm: String { l1213("groups.l13.pending.rejectConfirm") }
        static var pendingRejectMessageOther: String { l1213("groups.l13.pending.rejectMessageOther") }
        static func pendingWaitingFor(_ name: String) -> String {
            String(format: l1213("groups.l13.pending.waitingFor"), name)
        }

        // MARK: - L13-3 · Qué pasó con tu dinero

        static func successOwedTitle(_ amount: String) -> String {
            String(format: l1213("groups.l13.success.owedTitle"), amount)
        }
        static func successOwedEach(names: String, amount: String) -> String {
            String(format: l1213("groups.l13.success.owedEach"), names, amount)
        }
        static func successIOweTitle(_ amount: String) -> String {
            String(format: l1213("groups.l13.success.iOweTitle"), amount)
        }
        static func successIOweTo(_ name: String) -> String { String(format: l1213("groups.l13.success.iOweTo"), name) }
        static var successSettledTitle: String { l1213("groups.l13.success.settledTitle") }
        static func successAccountTitle(amount: String, account: String) -> String {
            String(format: l1213("groups.l13.success.accountTitle"), amount, account)
        }
        static var successAccountDetail: String { l1213("groups.l13.success.accountDetail") }
        static var successInboxTitle: String { l1213("groups.l13.success.inboxTitle") }
        static func successInboxDetail(_ amount: String) -> String {
            String(format: l1213("groups.l13.success.inboxDetail"), amount)
        }
        static func successShareTitle(_ amount: String) -> String {
            String(format: l1213("groups.l13.success.shareTitle"), amount)
        }
        static var successShareDetail: String { l1213("groups.l13.success.shareDetail") }
    }
}
