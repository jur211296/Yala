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
        Self.sourceDisplayName(sourceType: sourceType, evidence: evidence, hasAmount: amount != nil)
    }

    /// El nombre de una fuente, de un borrador o de lo que un borrador unido absorbió (lote 3 de la Bandeja sin
    /// duplicados): el mismo texto que tendría en su propia fila.
    static func sourceDisplayName(sourceType: DraftSourceType, evidence: String?, hasAmount: Bool) -> String {
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
            return BankNoticeOrigin.label(sourceType: sourceType, evidence: evidence, hasAmount: hasAmount)
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

// MARK: - Las fuentes de un pendiente unido (Bandeja sin duplicados, lote 3)

/// Una fuente de un pendiente unido, como la enseña la fila: su nombre y su icono.
struct InboxJoinedSource: Equatable {
    let name: String
    let icon: String
}

extension InboxDraft {
    /// De dónde llegó un pendiente que la Bandeja unió: el suyo y el de cada fuente que absorbió, en el orden en que
    /// llegaron. `nil` si no es un pendiente unido o su registro de unión no se entiende: entonces la fila enseña su
    /// origen de siempre.
    @MainActor
    var joinedSources: [InboxJoinedSource]? {
        guard status == .pending, case .record(let record) = InboxJoinRecord.read(joinRecordRaw),
              !record.members.isEmpty else { return nil }
        var sources = [InboxJoinedSource(name: sourceDisplayName, icon: sourceIcon)]
        for member in record.members {
            guard let type = DraftSourceType(rawValue: member.sourceTypeRaw) else {
                // Un origen que este build no conoce: el nombre genérico de su fuente en el emparejador.
                let name = InboxMatchLogic.Source(rawValue: member.facts.source).map(L10n.BandejaUnir.fuente)
                    ?? L10n.Inbox.sourceAutomation
                sources.append(InboxJoinedSource(name: name, icon: "tray"))
                continue
            }
            sources.append(InboxJoinedSource(
                name: Self.sourceDisplayName(sourceType: type, evidence: member.evidence,
                                             hasAmount: member.fields.amount != nil),
                icon: Self.sourceIcon(for: type)))
        }
        return sources
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
