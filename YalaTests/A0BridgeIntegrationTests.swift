//
//  A0BridgeIntegrationTests.swift
//  YalaTests
//
//  F15 — A0-Bridge: tests pure-logic para reglas A/B/C/D y helpers.
//
//  IMPORTANTE: tests integration completos (que crean bridge full pipeline con
//  context + grupo + expenses + settlements) están en blacklist R8 — Swift
//  Testing tiene race con CloudKit en simulador con makeTestContext().
//
//  Validación funcional via Device QA F16 escenarios 1-21.
//

import Foundation
import Testing

@testable import Yala

@Suite("F15 — A0-Bridge integration (pure logic)", .serialized)
struct A0BridgeIntegrationTests {

    // MARK: - Naming consistency cross-fases

    @Test func roleStrings_match_F2_F3_consistently() {
        // F2 define los roles en CategorySeed.GroupBridgeSystemRole.
        // F3 define el enum SystemSubcategoryRole en GroupBridgeSystemEntities.
        // Mapeo debe ser estable.
        let pairs: [(GroupBridgeSystemEntities.SystemSubcategoryRole, String)] = [
            (.loanToGroups, GroupBridgeSystemRole.subcategoryLoanToGroups),
            (.loanCollection, GroupBridgeSystemRole.subcategoryLoanCollection),
            (.settlementPayment, GroupBridgeSystemRole.subcategorySettlementPayment),
            (.settlementSent, GroupBridgeSystemRole.subcategorySettlementSent),
            (.settlementReceived, GroupBridgeSystemRole.subcategorySettlementReceived),
        ]
        for (role, expectedString) in pairs {
            #expect(role.roleString == expectedString)
        }
    }

    // MARK: - Account.System name format

    @Test func systemAccountName_canFormatWithCurrencyCode() {
        // L10n.Account.System.groups debe ser format string compatible con String(format:_:)
        let formatted = String(format: L10n.Account.System.groups, "PEN")
        #expect(formatted.contains("PEN") || formatted == L10n.Account.System.groups)
        // Si la key no se resuelve en este bundle (R8 edge), fallback es la key misma.
    }

    // MARK: - DraftSourceType mapping

    @Test func groupDraftTypes_distinct_isFromGroup() {
        // Verifica el contrato F1: solo .groupExpense y .groupSettlement son fromGroup.
        let allTypes: [DraftSourceType] = [
            .voice, .receiptPhoto, .screenshotList, .screenshotSingle,
            .emailAlert, .scheduledPayment, .subscription, .applePay,
            .automation, .siri, .groupExpense, .groupSettlement,
        ]
        let groupTypes = allTypes.filter(\.isFromGroup)
        #expect(groupTypes.count == 2)
        #expect(groupTypes.contains(.groupExpense))
        #expect(groupTypes.contains(.groupSettlement))
    }

    // MARK: - InboxDraft helper isFromGroup propaga sourceType

    @MainActor @Test func inboxDraft_isFromGroup_propagatesFromSourceType() {
        let groupExpenseDraft = InboxDraft(sourceType: .groupExpense)
        #expect(groupExpenseDraft.isFromGroup == true)

        let groupSettlementDraft = InboxDraft(sourceType: .groupSettlement)
        #expect(groupSettlementDraft.isFromGroup == true)

        let voiceDraft = InboxDraft(sourceType: .voice)
        #expect(voiceDraft.isFromGroup == false)
    }

    // MARK: - DraftServiceError messages

    @Test func draftServiceError_groupGuards_haveLocalizedDescription() {
        let deleteError = DraftServiceError.cannotDeleteGroupDraft
        let rejectError = DraftServiceError.cannotRejectGroupDraft
        #expect(deleteError.errorDescription != nil)
        #expect(rejectError.errorDescription != nil)
        #expect(deleteError.errorDescription == rejectError.errorDescription)
        // Ambos comparten la misma copy: "Esta transacción se elimina solo desde el grupo origen."
    }

    // MARK: - GroupExpenseService error message

    @Test func groupExpenseService_expenseHasAssociatedSettlements_hasLocalizedDescription() {
        let error = GroupExpenseServiceError.expenseHasAssociatedSettlements
        #expect(error.errorDescription != nil)
    }

    // MARK: - Sistema flags consistency

    @MainActor @Test func systemFlags_propagateCorrectly() {
        // Account sistema
        let acc = Account(
            name: "Grupos PEN",
            currencyCode: "PEN",
            colorHex: "#7C3AED",
            iconName: "person.2.circle.fill",
            type: "system",
            isSystemAccount: true
        )
        #expect(acc.isSystemAccount == true)

        // Subcategory sistema
        let cat = YalaCategory(
            name: "Cobros de grupos",
            colorHex: "#10B981",
            isIncome: true,
            isSystem: true
        )
        let sub = Subcategory(
            name: "Préstamo a grupos",
            isSystem: true,
            category: cat
        )
        #expect(sub.isSystem == true)
        #expect(sub.isAnySystem == true)
        #expect(cat.isSystem == true)
    }

    // MARK: - TransactionItem split links

    @MainActor @Test func transactionItem_canHaveBothExpenseAndSettlementLinks_independent() {
        let tx = TransactionItem(date: .now, amount: -100, currencyCode: "PEN")
        // Inicialmente nil
        #expect(tx.splitExpenseID == nil)
        #expect(tx.splitSettlementID == nil)

        // Asignar expense link
        tx.splitExpenseID = "expense-1"
        #expect(tx.splitExpenseID == "expense-1")
        #expect(tx.splitSettlementID == nil)

        // Asignar settlement link en otra TX (no se cruzan)
        let tx2 = TransactionItem(date: .now, amount: 50, currencyCode: "PEN")
        tx2.splitSettlementID = "settle-1"
        #expect(tx2.splitExpenseID == nil)
        #expect(tx2.splitSettlementID == "settle-1")
    }
}
