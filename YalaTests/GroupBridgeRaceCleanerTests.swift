//
//  GroupBridgeRaceCleanerTests.swift
//  YalaTests
//
//  M6: tests pure-logic del helper `computeCleanupPlan`. Race autodelete
//  de drafts pendientes Caso A cuando ya existe TX cuenta real para el mismo splitID.
//

import Foundation
import Testing

@testable import Yala

@MainActor
struct GroupBridgeRaceCleanerTests {

    // MARK: - Helpers

    private func makeGroupExpenseDraftPendingAccount(splitID: String) -> InboxDraft {
        InboxDraft(
            note: "Cena",
            amount: -100,
            sourceType: .groupExpense,
            needsUserInput: ["account"],
            splitExpenseID: splitID,
            splitGroupZoneID: "zone-1",
            originReasonKey: "groups.bridge.draftReasonRemoteCreate"
        )
    }

    private func makeGroupExpenseDraftPendingSubcat(splitID: String) -> InboxDraft {
        // M5 path: Caso B con auto-match falló — pide subcat (no account).
        InboxDraft(
            note: "Cena",
            amount: -50,
            sourceType: .groupExpense,
            needsUserInput: ["subcategory"],
            splitExpenseID: splitID,
            splitGroupZoneID: "zone-1"
        )
    }

    private func makeGroupExpenseOptInDraft(splitID: String) -> InboxDraft {
        // Opt-in personal (bridge OFF): misma forma que el pending-account pero con
        // `optInPersonalOnly=true` — intent del user pendiente de aprobación.
        InboxDraft(
            note: "Cena",
            amount: -100,
            sourceType: .groupExpense,
            needsUserInput: ["account"],
            splitExpenseID: splitID,
            splitGroupZoneID: "zone-1",
            optInPersonalOnly: true
        )
    }

    // MARK: - computeCleanupPlan

    @Test func computeCleanupPlan_emptyDrafts() {
        let plan = GroupBridgeRaceCleaner.computeCleanupPlan(
            drafts: [],
            realTxExistsForSplitID: { _ in false }
        )
        #expect(plan.isEmpty)
    }

    @Test func computeCleanupPlan_keepsDraftWithoutMatchingTX() {
        let draft = makeGroupExpenseDraftPendingAccount(splitID: "expense-1")
        let plan = GroupBridgeRaceCleaner.computeCleanupPlan(
            drafts: [draft],
            realTxExistsForSplitID: { _ in false }
        )
        #expect(plan.isEmpty)
    }

    @Test func computeCleanupPlan_deletesDraftWithMatchingTX() {
        let draft = makeGroupExpenseDraftPendingAccount(splitID: "expense-1")
        let plan = GroupBridgeRaceCleaner.computeCleanupPlan(
            drafts: [draft],
            realTxExistsForSplitID: { id in id == "expense-1" }
        )
        #expect(plan.count == 1)
        #expect(plan.first?.splitExpenseID == "expense-1")
    }

    @Test func computeCleanupPlan_ignoresPendingSubcatDrafts() {
        // M5 path: drafts con needsUserInput=["subcategory"] no son del race M6.
        let draft = makeGroupExpenseDraftPendingSubcat(splitID: "expense-1")
        let plan = GroupBridgeRaceCleaner.computeCleanupPlan(
            drafts: [draft],
            realTxExistsForSplitID: { _ in true }
        )
        #expect(plan.isEmpty)
    }

    @Test func computeCleanupPlan_partialDeletion() {
        // 3 drafts: 2 con TX real, 1 sin → solo 2 a borrar.
        let draftWithTx1 = makeGroupExpenseDraftPendingAccount(splitID: "exp-1")
        let draftWithTx2 = makeGroupExpenseDraftPendingAccount(splitID: "exp-2")
        let draftAlone = makeGroupExpenseDraftPendingAccount(splitID: "exp-3")
        let realTxLookup: Set<String> = ["exp-1", "exp-2"]
        let plan = GroupBridgeRaceCleaner.computeCleanupPlan(
            drafts: [draftWithTx1, draftWithTx2, draftAlone],
            realTxExistsForSplitID: { realTxLookup.contains($0) }
        )
        #expect(plan.count == 2)
        let ids = Set(plan.compactMap(\.splitExpenseID))
        #expect(ids == ["exp-1", "exp-2"])
    }

    @Test func computeCleanupPlan_ignoresOptInDrafts() {
        // Opt-in draft con TX real coexistente: NO se borra — es intent pendiente del user
        // (la TX real pudo llegar de otro device vía sync). Simétrico con el bridge.
        let draft = makeGroupExpenseOptInDraft(splitID: "expense-1")
        let plan = GroupBridgeRaceCleaner.computeCleanupPlan(
            drafts: [draft],
            realTxExistsForSplitID: { _ in true }
        )
        #expect(plan.isEmpty)
    }

    @Test func computeCleanupPlan_optInCoexistsWithAutoDraft() {
        // Mezcla: un draft auto (pending-account) y uno opt-in para distintos splitIDs, ambos
        // con TX real. Solo el auto se borra; el opt-in sobrevive.
        let autoDraft = makeGroupExpenseDraftPendingAccount(splitID: "auto-1")
        let optInDraft = makeGroupExpenseOptInDraft(splitID: "optin-1")
        let plan = GroupBridgeRaceCleaner.computeCleanupPlan(
            drafts: [autoDraft, optInDraft],
            realTxExistsForSplitID: { _ in true }
        )
        #expect(plan.count == 1)
        #expect(plan.first?.splitExpenseID == "auto-1")
    }

    @Test func computeCleanupPlan_ignoresNonGroupExpenseSources() {
        let voiceDraft = InboxDraft(
            note: "Coffee",
            amount: -5,
            sourceType: .voice,
            needsUserInput: ["account"]  // mismo flag pero source distinto
        )
        let plan = GroupBridgeRaceCleaner.computeCleanupPlan(
            drafts: [voiceDraft],
            realTxExistsForSplitID: { _ in true }
        )
        #expect(plan.isEmpty)
    }
}
