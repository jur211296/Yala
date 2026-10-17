//
//  UXAudit22Lote4LogicTests.swift
//  YalaTests
//
//  La lógica pura del lote 4 de la auditoría UX 2.2 (voz, foto y Bandeja): lo que queda pendiente tras guardar los
//  listos (L4-7) y el origen de cada borrador (L4-8).
//

import Foundation
import Testing

@testable import Yala

@MainActor
@Suite("UX 2.2 · lote 4 · lógica")
struct UXAudit22Lote4LogicTests {

    @Test func leftover_nothingLeft_isNil() {
        #expect(InboxSaveReadyLogic.leftoverLine([]) == nil)
    }

    /// «Quedan pendientes: 1 · Falta: Subcategoría»: cuántos y qué les falta, sin repetir.
    @Test func leftover_saysHowManyAndWhatIsMissing_withoutRepeating() {
        let a = InboxDraft(note: "a", amount: -10, needsUserInput: [DraftInputRequirement.subcategory])
        let b = InboxDraft(note: "b", amount: -20, needsUserInput: [DraftInputRequirement.subcategory, DraftInputRequirement.account])
        let line = InboxSaveReadyLogic.leftoverLine([a, b])
        let expected = "\(L10n.Inbox.stillPending(2)) · \(L10n.Inbox.missingLabel) "
            + "\(L10n.Inbox.needsSubcategory), \(L10n.Inbox.needsAccount)"
        #expect(line == expected)
    }

    @Test func leftover_withoutMissingFields_saysOnlyHowMany() {
        let a = InboxDraft(note: "a", amount: -10, needsUserInput: [])
        #expect(InboxSaveReadyLogic.leftoverLine([a]) == L10n.Inbox.stillPending(1))
    }

    /// Cada origen tiene su nombre (no el crudo del enum), el mismo en la fila y en el editor.
    @Test func sourceName_isLocalizedForEverySource() {
        let sources: [DraftSourceType] = [
            .voice, .receiptPhoto, .screenshotList, .screenshotSingle, .emailAlert, .scheduledPayment, .subscription,
            .applePay, .automation, .siri, .groupExpense, .groupSettlement, .manual, .groupScheduledExpense,
        ]
        for source in sources {
            let draft = InboxDraft(note: "x", sourceType: source)
            #expect(!draft.sourceDisplayName.isEmpty)
            #expect(draft.sourceDisplayName != source.rawValue, "\(source) enseña su nombre interno")
        }
        #expect(InboxDraft(note: "x", sourceType: .voice).sourceDisplayName == L10n.Inbox.sourceVoice)
    }
}
