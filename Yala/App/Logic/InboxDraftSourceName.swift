//
//  InboxDraftSourceName.swift
//  Yala
//
//  De dónde llegó un borrador, en palabras (UX 2.2 · L4-8): la fila de la Bandeja lo dice con una etiqueta pequeña, y
//  el editor ya lo decía. Una sola fuente para los dos sitios.
//

import Foundation

extension InboxDraft {
    var sourceDisplayName: String {
        switch sourceType {
        case .voice: return L10n.Inbox.sourceVoice
        case .receiptPhoto: return L10n.Inbox.sourceReceipt
        case .screenshotList: return L10n.Inbox.sourceScreenshotList
        case .screenshotSingle: return L10n.Inbox.sourceScreenshot
        case .emailAlert: return L10n.Inbox.sourceEmail
        case .scheduledPayment: return L10n.Inbox.sourceScheduledPayment
        case .subscription: return L10n.Inbox.sourceSubscription
        case .applePay: return L10n.Inbox.sourceApplePay
        case .automation:
            // Atajo del banco (2.3, B1): «Aviso de BCP» / «No entendimos este aviso».
            return BankNoticeOrigin.label(sourceType: sourceType, evidence: evidence, hasAmount: amount != nil)
                ?? L10n.Inbox.sourceAutomation
        case .siri: return L10n.Inbox.sourceSiri
        case .groupExpense: return L10n.Inbox.sourceGroupExpense
        case .groupSettlement: return L10n.Inbox.sourceGroupSettlement
        case .manual: return L10n.Inbox.sourceManual
        case .groupScheduledExpense: return L10n.Inbox.sourceGroupScheduledExpense
        // «Conecta tu IA» (decisión 6 de Jürgen, 23-nov): el nombre de la IA que lo apuntó («Claude»); «Tu IA» si no se sabe.
        case .aiConnector: return ConectaTuIALogic.aiName(evidence: evidence) ?? L10n.Inbox.sourceAIConnector
        }
    }
}

// MARK: - Lo que falta (UX 2.2 · L4-7)

extension InboxDraft {
    /// El nombre de un dato que falta, como lo dice la fila de la Bandeja («Cuenta», «Subcategoría», «Sin monto»).
    static func localizedMissingField(_ field: String) -> String {
        switch field {
        case DraftInputRequirement.account: return L10n.Inbox.needsAccount
        case DraftInputRequirement.subcategory: return L10n.Inbox.needsSubcategory
        case DraftInputRequirement.amount: return L10n.Inbox.noAmount
        default: return field
        }
    }
}

enum InboxSaveReadyLogic {
    /// Los borradores que se pueden guardar de un toque: completos y sin formulario propio (un pago planificado de
    /// grupo abre el suyo). Mismo criterio que deslizar para guardar.
    static func ready(_ drafts: [InboxDraft]) -> [InboxDraft] {
        drafts.filter { $0.status == .pending && $0.isReadyToApprove && !$0.requiresApprovalForm }
    }

    /// «Quedan pendientes: 1 · Falta: Subcategoría». Los datos que faltan, sin repetir y en el orden en que aparecen.
    /// `nil` si no queda nada.
    static func leftoverLine(_ remaining: [InboxDraft]) -> String? {
        guard !remaining.isEmpty else { return nil }
        var fields: [String] = []
        for draft in remaining {
            for field in draft.needsUserInput where !fields.contains(field) {
                fields.append(field)
            }
        }
        let head = L10n.Inbox.stillPending(remaining.count)
        guard !fields.isEmpty else { return head }
        let names = fields.map(InboxDraft.localizedMissingField).joined(separator: ", ")
        return "\(head) · \(L10n.Inbox.missingLabel) \(names)"
    }
}
