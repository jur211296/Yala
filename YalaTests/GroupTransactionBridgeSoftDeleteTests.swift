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

    // MARK: - shouldBridgeExpense (pure-logic guard)

    @Test func shouldBridgeExpense_hiddenGroup_returnsFalse() {
        #expect(GroupTransactionBridge.shouldBridgeExpense(groupIsHidden: true) == false)
    }

    @Test func shouldBridgeExpense_activeGroup_returnsTrue() {
        #expect(GroupTransactionBridge.shouldBridgeExpense(groupIsHidden: false) == true)
    }

    // MARK: - shouldTriggerRemovedSelfCleanup (pure-logic observer)

    @Test func shouldTriggerRemovedSelfCleanup_activeCurrentToRemoved_returnsTrue() {
        let result = SoftDeleteObserverLogic.shouldTriggerRemovedSelfCleanup(
            wasActiveAndCurrentUser: true,
            newStatus: .removed
        )
        #expect(result == true)
    }

    @Test func shouldTriggerRemovedSelfCleanup_activeNotCurrentToRemoved_returnsFalse() {
        let result = SoftDeleteObserverLogic.shouldTriggerRemovedSelfCleanup(
            wasActiveAndCurrentUser: false,
            newStatus: .removed
        )
        #expect(result == false, "Admin removiendo OTRO miembro no debe disparar cleanup local")
    }

    @Test func shouldTriggerRemovedSelfCleanup_inactiveCurrentToRemoved_returnsFalse() {
        // Edge case: current user ya .left local + admin remoto lo marca .removed.
        let result = SoftDeleteObserverLogic.shouldTriggerRemovedSelfCleanup(
            wasActiveAndCurrentUser: false, // wasActive=false
            newStatus: .removed
        )
        #expect(result == false)
    }

    @Test func shouldTriggerRemovedSelfCleanup_activeCurrentToLeft_returnsFalse() {
        // .left es local-only (leaveGroup hace cleanup ahí mismo, no via observer).
        let result = SoftDeleteObserverLogic.shouldTriggerRemovedSelfCleanup(
            wasActiveAndCurrentUser: true,
            newStatus: .left
        )
        #expect(result == false)
    }

    @Test func shouldTriggerRemovedSelfCleanup_activeCurrentToActive_returnsFalse() {
        // No flip — update benigno (e.g. displayName change).
        let result = SoftDeleteObserverLogic.shouldTriggerRemovedSelfCleanup(
            wasActiveAndCurrentUser: true,
            newStatus: .active
        )
        #expect(result == false)
    }

    // MARK: - PendingLeaveShareTracker (persistencia + idempotency + JSON round-trip)

    @Test @MainActor func pendingLeaveShareTracker_addRemoveAndPersist() {
        let isolatedDefaults = makeIsolatedDefaults(prefix: "fu02.tracker")
        let originalDefaults = PendingLeaveShareTracker.defaults
        PendingLeaveShareTracker.defaults = isolatedDefaults
        defer { PendingLeaveShareTracker.defaults = originalDefaults }

        let entry1 = PendingLeaveShareEntry(zoneName: "SplitGroup-aaa", zoneOwnerName: "ownerA")
        let entry2 = PendingLeaveShareEntry(zoneName: "SplitGroup-bbb", zoneOwnerName: "ownerB")

        // Inicial vacío.
        #expect(PendingLeaveShareTracker.all().isEmpty)

        // Add idempotente.
        PendingLeaveShareTracker.add(entry1)
        #expect(PendingLeaveShareTracker.all() == [entry1])
        PendingLeaveShareTracker.add(entry1)
        #expect(PendingLeaveShareTracker.all().count == 1, "Add duplicado debe ser idempotente")

        // Add segundo entry.
        PendingLeaveShareTracker.add(entry2)
        #expect(PendingLeaveShareTracker.all() == [entry1, entry2])

        // JSON round-trip: tras un nuevo `all()`, ambos entries deben preservar zoneName + ownerName.
        let reloaded = PendingLeaveShareTracker.all()
        #expect(reloaded.contains(entry1))
        #expect(reloaded.contains(entry2))

        // Remove no-op si no existía.
        let phantom = PendingLeaveShareEntry(zoneName: "ghost", zoneOwnerName: "ghostOwner")
        PendingLeaveShareTracker.remove(phantom)
        #expect(PendingLeaveShareTracker.all().count == 2)

        // Remove existing.
        PendingLeaveShareTracker.remove(entry1)
        #expect(PendingLeaveShareTracker.all() == [entry2])

        // Clear.
        PendingLeaveShareTracker.clear()
        #expect(PendingLeaveShareTracker.all().isEmpty)
    }
}
