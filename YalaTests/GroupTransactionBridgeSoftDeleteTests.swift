//
//  GroupTransactionBridgeSoftDeleteTests.swift
//  YalaTests
//
//  FU-02 cleanup pure-logic tests (regla R8 — sin context).
//  Cubre:
//   - `GroupTransactionBridge.classifyForSoftDelete` (clasificador TX cuenta real vs sistema).
//   - `GroupTransactionBridge.computeFreezePlan` (plan idempotente + preserva cached fields).
//   - `GroupTransactionBridge.shouldBridgeExpense` (guard hidden group).
//   - `SoftDeleteObserverLogic.shouldTriggerRemovedSelfCleanup` (observer flip detection).
//   - `PendingLeaveShareTracker` (persistencia + idempotency + JSON round-trip).
//

import Foundation
import Testing

@testable import Yala

struct GroupTransactionBridgeSoftDeleteTests {

    // MARK: - classifyForSoftDelete (pure-logic)

    @Test func classifyForSoftDelete_realAccount_releases() {
        let action = GroupTransactionBridge.classifyForSoftDelete(transactionAccountIsSystem: false)
        #expect(action == .releaseRealAccountTx)
    }

    @Test func classifyForSoftDelete_systemAccount_preserves() {
        let action = GroupTransactionBridge.classifyForSoftDelete(transactionAccountIsSystem: true)
        #expect(action == .preserveVirtualSystemTx)
    }

    // MARK: - computeFreezePlan (pure-logic, idempotency)

    @Test func computeFreezePlan_realAccountTx_includedInRelease() {
        let realAccount = Account(name: "BCP", currencyCode: "PEN", colorHex: "#000", iconName: "x", type: "bank", isSystemAccount: false)
        let tx = TransactionItem(date: .now, amount: -100, currencyCode: "PEN", account: realAccount)
        tx.splitExpenseID = "exp-1"
        tx.splitGroupZoneID = "SplitGroup-uuid"

        let plan = GroupTransactionBridge.computeFreezePlan(transactions: [tx], drafts: [])
        #expect(plan.txsToRelease.count == 1)
        #expect(plan.txsToRelease.first === tx)
        #expect(plan.draftsToConvert.isEmpty)
    }

    @Test func computeFreezePlan_systemAccountTx_excluded() {
        let systemAccount = Account(name: "Grupos PEN", currencyCode: "PEN", colorHex: "#000", iconName: "x", type: "system", isSystemAccount: true)
        let tx = TransactionItem(date: .now, amount: 50, currencyCode: "PEN", account: systemAccount)
        tx.splitExpenseID = "exp-1"
        tx.splitGroupZoneID = "SplitGroup-uuid"

        let plan = GroupTransactionBridge.computeFreezePlan(transactions: [tx], drafts: [])
        #expect(plan.txsToRelease.isEmpty, "TX virtual sistema debe preservarse intacta")
    }

    @Test func computeFreezePlan_groupExpenseDraft_includedInConvert_preservesCachedFields() {
        // Draft con todos los fields que NO deben ser tocados por el plan.
        let draft = InboxDraft(
            note: "Cena con amigos",
            amount: -85.50,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            sourceType: .groupExpense,
            originReasonKey: "groups.bridge.draftReasonRemoteCreate",
            originActorName: "Juan",
            originGroupName: "Viaje a Cusco"
        )
        draft.splitExpenseID = "exp-1"
        draft.splitGroupZoneID = "SplitGroup-uuid"
        draft.needsUserInput = ["account", "subcategory"]
        draft.cachedAccountName = "BCP"
        draft.cachedSubcategoryName = "Restaurantes"
        draft.cachedCategoryColorHex = "#FF6600"
        draft.cachedSubcategoryIcon = "fork.knife"
        draft.cachedCurrencyCode = "PEN"

        let plan = GroupTransactionBridge.computeFreezePlan(transactions: [], drafts: [draft])
        #expect(plan.draftsToConvert.count == 1)
        #expect(plan.draftsToConvert.first === draft)

        // Aplicamos manualmente la conversión que hace freezeForSoftDelete para validar field preservation.
        draft.sourceTypeRaw = DraftSourceType.manual.rawValue
        draft.splitExpenseID = nil
        draft.splitSettlementID = nil
        draft.splitGroupZoneID = nil
        draft.needsUserInput = []

        // Fields preservados (12 enumerados explícitos):
        #expect(draft.note == "Cena con amigos")
        #expect(draft.amount == -85.50)
        #expect(draft.date == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(draft.cachedAccountName == "BCP")
        #expect(draft.cachedSubcategoryName == "Restaurantes")
        #expect(draft.cachedCategoryColorHex == "#FF6600")
        #expect(draft.cachedSubcategoryIcon == "fork.knife")
        #expect(draft.cachedCurrencyCode == "PEN")
        #expect(draft.originActorName == "Juan")
        #expect(draft.originGroupName == "Viaje a Cusco")
        #expect(draft.originReasonKey == "groups.bridge.draftReasonRemoteCreate")
        // tags/account/subcategory quedan tal cual estaban (nil/empty en este test).

        // Fields tocados:
        #expect(draft.sourceTypeRaw == "manual")
        #expect(draft.sourceType == DraftSourceType.manual)
        #expect(draft.splitExpenseID == nil)
        #expect(draft.splitGroupZoneID == nil)
        #expect(draft.needsUserInput == [])
    }

    @Test func computeFreezePlan_groupSettlementDraft_includedInConvert() {
        let draft = InboxDraft(sourceType: .groupSettlement)
        draft.splitSettlementID = "settle-1"
        draft.splitGroupZoneID = "SplitGroup-uuid"

        let plan = GroupTransactionBridge.computeFreezePlan(transactions: [], drafts: [draft])
        #expect(plan.draftsToConvert.count == 1)
    }

    @Test func computeFreezePlan_otherSourceTypeDraftWithZoneID_excluded() {
        // Edge case defensivo: un draft .voice con splitGroupZoneID set por accidente.
        let draft = InboxDraft(sourceType: .voice)
        draft.splitGroupZoneID = "SplitGroup-uuid"

        let plan = GroupTransactionBridge.computeFreezePlan(transactions: [], drafts: [draft])
        #expect(plan.draftsToConvert.isEmpty, "Drafts no-grupo deben quedar intactos")
    }

    @Test func computeFreezePlan_emptyInputs_emptyPlan() {
        let plan = GroupTransactionBridge.computeFreezePlan(transactions: [], drafts: [])
        #expect(plan.txsToRelease.isEmpty)
        #expect(plan.draftsToConvert.isEmpty)
    }

    @Test func computeFreezePlan_alreadyCleanTx_excluded() {
        // Idempotency: TX ya sin IDs (cleanup previo corrió) no debe re-procesarse.
        let realAccount = Account(name: "BCP", currencyCode: "PEN", colorHex: "#000", iconName: "x", type: "bank", isSystemAccount: false)
        let tx = TransactionItem(date: .now, amount: -100, currencyCode: "PEN", account: realAccount)
        tx.splitExpenseID = nil
        tx.splitSettlementID = nil
        tx.splitGroupZoneID = nil

        let plan = GroupTransactionBridge.computeFreezePlan(transactions: [tx], drafts: [])
        #expect(plan.txsToRelease.isEmpty, "TX ya liberada debe excluirse")
    }

    // MARK: - computeFreezePlan (puntero [.subcategory] redundante → delete, no convert)

    @Test func computeFreezePlan_caseASubcategoryPointer_withRealTx_deleted() {
        // Bug B-S2-e: draft-puntero [.subcategory] Caso A cuya TX real se preserva en el freeze.
        // Convertirlo a manual lo volvería aprobable → insertaría una TX duplicada.
        let realAccount = Account(name: "BCP", currencyCode: "PEN", colorHex: "#000", iconName: "x", type: "bank", isSystemAccount: false)
        let tx = TransactionItem(date: .now, amount: -100, currencyCode: "PEN", account: realAccount)
        tx.splitExpenseID = "exp-A"
        tx.splitGroupZoneID = "SplitGroup-uuid"

        let draft = InboxDraft(sourceType: .groupExpense)
        draft.splitExpenseID = "exp-A"
        draft.splitGroupZoneID = "SplitGroup-uuid"
        draft.needsUserInput = [DraftInputRequirement.subcategory]

        let plan = GroupTransactionBridge.computeFreezePlan(transactions: [tx], drafts: [draft])
        #expect(plan.draftsToDelete.count == 1, "Puntero con TX real preservada debe borrarse, no convertirse")
        #expect(plan.draftsToDelete.first === draft)
        #expect(plan.draftsToConvert.isEmpty)
        #expect(plan.txsToRelease.count == 1, "La TX real se libera y persiste para clasificar editándola")
    }

    @Test func computeFreezePlan_caseBSubcategoryPointer_withVirtualSystemTx_deleted() {
        // Caso B (otro pagó): el puntero apunta a una TX virtual en cuenta sistema, que el freeze
        // preserva intacta (no la libera). El draft es igualmente redundante → delete.
        let systemAccount = Account(name: "Grupos PEN", currencyCode: "PEN", colorHex: "#000", iconName: "x", type: "system", isSystemAccount: true)
        let virtualTx = TransactionItem(date: .now, amount: -40, currencyCode: "PEN", account: systemAccount)
        virtualTx.splitExpenseID = "exp-B"
        virtualTx.splitGroupZoneID = "SplitGroup-uuid"

        let draft = InboxDraft(sourceType: .groupExpense)
        draft.splitExpenseID = "exp-B"
        draft.splitGroupZoneID = "SplitGroup-uuid"
        draft.needsUserInput = [DraftInputRequirement.subcategory]

        let plan = GroupTransactionBridge.computeFreezePlan(transactions: [virtualTx], drafts: [draft])
        #expect(plan.draftsToDelete.count == 1, "Puntero con TX virtual sistema preservada también es redundante")
        #expect(plan.txsToRelease.isEmpty, "La virtual sistema no se libera")
        #expect(plan.draftsToConvert.isEmpty)
    }

    @Test func computeFreezePlan_subcategoryPointer_orphanNoTx_convertedNotDeleted() {
        // Defensa: puntero [.subcategory] sin ninguna TX para su splitExpenseID (la TX desapareció).
        // Cae a convert, no a delete — no se pierde el rastro del gasto.
        let draft = InboxDraft(sourceType: .groupExpense)
        draft.splitExpenseID = "exp-orphan"
        draft.splitGroupZoneID = "SplitGroup-uuid"
        draft.needsUserInput = [DraftInputRequirement.subcategory]

        let plan = GroupTransactionBridge.computeFreezePlan(transactions: [], drafts: [draft])
        #expect(plan.draftsToDelete.isEmpty, "Sin TX coincidente el puntero no se borra")
        #expect(plan.draftsToConvert.count == 1)
    }

    @Test func computeFreezePlan_caseAAccountDraft_convertedNotDeleted() {
        // Caso A pendiente de cuenta: pide [.account, .subcategory], aún sin TX real. Aunque coexista
        // una TX virtual lent con su splitExpenseID, NO es puntero de clasificación → convert a manual.
        let systemAccount = Account(name: "Grupos PEN", currencyCode: "PEN", colorHex: "#000", iconName: "x", type: "system", isSystemAccount: true)
        let virtualLent = TransactionItem(date: .now, amount: 60, currencyCode: "PEN", account: systemAccount)
        virtualLent.splitExpenseID = "exp-C"
        virtualLent.splitGroupZoneID = "SplitGroup-uuid"

        let draft = InboxDraft(sourceType: .groupExpense)
        draft.splitExpenseID = "exp-C"
        draft.splitGroupZoneID = "SplitGroup-uuid"
        draft.needsUserInput = [DraftInputRequirement.account, DraftInputRequirement.subcategory]

        let plan = GroupTransactionBridge.computeFreezePlan(transactions: [virtualLent], drafts: [draft])
        #expect(plan.draftsToDelete.isEmpty, "Un draft que pide cuenta no es puntero de clasificación")
        #expect(plan.draftsToConvert.count == 1)
    }

    @Test func computeFreezePlan_groupExpenseEmptyNeedsInput_converted() {
        // Fallback: groupExpense sin needsUserInput (no es puntero [.subcategory]) → convert.
        let draft = InboxDraft(sourceType: .groupExpense)
        draft.splitExpenseID = "exp-D"
        draft.needsUserInput = []

        let plan = GroupTransactionBridge.computeFreezePlan(transactions: [], drafts: [draft])
        #expect(plan.draftsToDelete.isEmpty)
        #expect(plan.draftsToConvert.count == 1)
    }

    // MARK: - shouldBridgeExpense (pure-logic guard)

    @Test func shouldBridgeExpense_hiddenGroup_returnsFalse() {
        #expect(GroupTransactionBridge.shouldBridgeExpense(groupIsHidden: true) == false)
    }

    @Test func shouldBridgeExpense_activeGroup_returnsTrue() {
        #expect(GroupTransactionBridge.shouldBridgeExpense(groupIsHidden: false) == true)
    }

    // MARK: - shouldTriggerRemovedSelfCleanup · PendingLeaveShareTracker — RETIRADOS en la Fase 3
    //
    // Los 5 casos del observer probaban `SoftDeleteObserverLogic`, cuyo único consumidor de producción era
    // `SplitSyncManager.applyMember` (ver la re-medición de A1, hallazgo S6: huérfano total). Los 4 del
    // tracker probaban `PendingLeaveShareTracker`, el retry persistente de `leaveShare`. Los dos sujetos
    // se borraron con el transporte.
    //
    // Lo que sobrevive de este fichero —`classifyForSoftDelete`, `computeFreezePlan`, `shouldBridgeExpense`—
    // es del bridge personal, que es de los DOS canales y no se toca.
}
