//
//  SystemFlagsModelTests.swift
//  YalaTests
//
//  F1 — A0-Bridge: tests para flags `isSystemAccount`, `isSystem` (Subcategory + Category),
//  helper `isAnySystem`, `splitSettlementID` (TransactionItem) y nuevos campos de InboxDraft
//  (`groupExpense`/`groupSettlement` source types + `targetTransactionID`).
//
//  NOTA: tests sin makeTestContext (evita CloudKit race según patrón Subset 1).
//  Se valida vía instanciación directa de @Model + lectura de propiedades.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("F1 — System flags en modelos")
struct SystemFlagsModelTests {

    // MARK: - Account.isSystemAccount

    @MainActor @Test func account_isSystemAccount_defaultsFalse() {
        let account = Account(
            name: "Tarjeta",
            currencyCode: "PEN",
            colorHex: "#6366F1",
            iconName: "creditcard",
            type: "credit"
        )
        #expect(account.isSystemAccount == false)
    }

    @MainActor @Test func account_isSystemAccount_settable() {
        let account = Account(
            name: "Grupos PEN",
            currencyCode: "PEN",
            colorHex: "#7C3AED",
            iconName: "person.2.circle.fill",
            type: "system",
            isSystemAccount: true
        )
        #expect(account.isSystemAccount == true)
    }

    @MainActor @Test func account_isSystemAccount_settableViaProperty() {
        let account = Account(
            name: "Test",
            currencyCode: "USD",
            colorHex: "#000000",
            iconName: "creditcard",
            type: "checking"
        )
        account.isSystemAccount = true
        #expect(account.isSystemAccount == true)
    }

    // MARK: - Subcategory.isSystem y isAnySystem

    @MainActor @Test func subcategory_isSystem_defaultsFalse() {
        let cat = YalaCategory(name: "Comida", colorHex: "#FF0000", isIncome: false)
        let sub = Subcategory(name: "Restaurantes", category: cat)
        #expect(sub.isSystem == false)
        #expect(sub.isAnySystem == false)
    }

    @MainActor @Test func subcategory_isSystem_settable_makesIsAnySystemTrue() {
        let cat = YalaCategory(name: "Grupos", colorHex: "#7C3AED", isIncome: false, isSystem: true)
        let sub = Subcategory(
            name: "Préstamo a grupos",
            isSystem: true,
            category: cat
        )
        #expect(sub.isSystem == true)
        #expect(sub.isAnySystem == true)
    }

    @MainActor @Test
    func subcategory_legacyIsSystemSubcategory_makesIsAnySystemTrue_evenWhenIsSystemFalse() {
        let cat = YalaCategory(name: "Sistema", colorHex: "#000000", isIncome: false)
        // Nombre legacy (matches transferNames) → computed isSystemSubcategory == true
        let sub = Subcategory(
            name: "Transferencia entre cuentas",
            category: cat
        )
        #expect(sub.isSystem == false)
        #expect(sub.isSystemSubcategory == true)
        #expect(sub.isAnySystem == true)
    }

    @MainActor @Test
    func subcategory_neitherSystemNorLegacy_isAnySystemFalse() {
        let cat = YalaCategory(name: "Comida", colorHex: "#FF0000", isIncome: false)
        let sub = Subcategory(name: "Restaurantes", category: cat)
        #expect(sub.isSystemSubcategory == false)
        #expect(sub.isSystem == false)
        #expect(sub.isAnySystem == false)
    }

    // MARK: - Category.isSystem

    @MainActor @Test func category_isSystem_defaultsFalse() {
        let cat = YalaCategory(name: "Comida", colorHex: "#FF0000", isIncome: false)
        #expect(cat.isSystem == false)
    }

    @MainActor @Test func category_isSystem_settable() {
        let cat = YalaCategory(
            name: "Cobros de grupos",
            colorHex: "#10B981",
            isIncome: true,
            isSystem: true
        )
        #expect(cat.isSystem == true)
        #expect(cat.isIncome == true)
    }

    // MARK: - TransactionItem.splitSettlementID

    @MainActor @Test func transactionItem_splitSettlementID_defaultsNil() {
        let tx = TransactionItem(
            date: .now,
            amount: -100,
            currencyCode: "PEN"
        )
        #expect(tx.splitSettlementID == nil)
    }

    @MainActor @Test func transactionItem_splitSettlementID_settable() {
        let tx = TransactionItem(
            date: .now,
            amount: 100,
            currencyCode: "PEN"
        )
        let settlementID = UUID().uuidString
        tx.splitSettlementID = settlementID
        #expect(tx.splitSettlementID == settlementID)
    }

    @MainActor @Test
    func transactionItem_splitSettlementID_independentFromSplitExpenseID() {
        let tx = TransactionItem(
            date: .now,
            amount: -50,
            currencyCode: "PEN"
        )
        tx.splitExpenseID = UUID().uuidString
        tx.splitSettlementID = UUID().uuidString
        #expect(tx.splitExpenseID != nil)
        #expect(tx.splitSettlementID != nil)
        #expect(tx.splitExpenseID != tx.splitSettlementID)
    }

    // MARK: - InboxDraft sources de grupo

    @MainActor @Test func inboxDraft_sourceType_defaultsVoice() {
        let draft = InboxDraft()
        #expect(draft.sourceType == .voice)
        #expect(draft.isFromGroup == false)
    }

    @MainActor @Test func inboxDraft_groupExpenseSource_isFromGroup() {
        let draft = InboxDraft(
            sourceType: .groupExpense,
            splitExpenseID: UUID().uuidString,
            splitGroupZoneID: "zone-XYZ",
            targetTransactionID: UUID().uuidString
        )
        #expect(draft.sourceType == .groupExpense)
        #expect(draft.isFromGroup == true)
        #expect(draft.targetTransactionID != nil)
        #expect(draft.splitExpenseID != nil)
    }

    @MainActor @Test func inboxDraft_groupSettlementSource_isFromGroup() {
        let draft = InboxDraft(
            sourceType: .groupSettlement,
            splitGroupZoneID: "zone-ABC",
            splitSettlementID: UUID().uuidString
        )
        #expect(draft.sourceType == .groupSettlement)
        #expect(draft.isFromGroup == true)
        #expect(draft.splitSettlementID != nil)
        #expect(draft.targetTransactionID == nil) // settlements no apuntan a TX existente
    }

    @MainActor @Test func inboxDraft_groupExpenseIcon_isPersonGroup() {
        let draft = InboxDraft(sourceType: .groupExpense)
        #expect(draft.sourceIcon == "person.2.fill")
    }

    @MainActor @Test func inboxDraft_groupSettlementIcon_isArrowExchange() {
        let draft = InboxDraft(sourceType: .groupSettlement)
        #expect(draft.sourceIcon == "arrow.left.arrow.right.circle.fill")
    }

    @MainActor @Test func inboxDraft_targetTransactionID_settable() {
        let txID = UUID().uuidString
        let draft = InboxDraft(
            sourceType: .groupExpense,
            targetTransactionID: txID
        )
        #expect(draft.targetTransactionID == txID)
    }

    @MainActor @Test func inboxDraft_splitSettlementID_settable() {
        let settlementID = UUID().uuidString
        let draft = InboxDraft(
            sourceType: .groupSettlement,
            splitSettlementID: settlementID
        )
        #expect(draft.splitSettlementID == settlementID)
    }

    // MARK: - DraftSourceType enum

    @Test func draftSourceType_isFromGroup_returnsFalseForNonGroupSources() {
        let nonGroupSources: [DraftSourceType] = [
            .voice, .receiptPhoto, .screenshotList, .screenshotSingle,
            .emailAlert, .scheduledPayment, .subscription, .applePay,
            .automation, .siri
        ]
        for source in nonGroupSources {
            #expect(source.isFromGroup == false, "\(source) NO debe ser fromGroup")
        }
    }

    @Test func draftSourceType_isFromGroup_returnsTrueForGroupSources() {
        #expect(DraftSourceType.groupExpense.isFromGroup == true)
        #expect(DraftSourceType.groupSettlement.isFromGroup == true)
    }

    @Test func draftSourceType_rawValues_areStable() {
        // Stability check: rawValues persisted en sourceTypeRaw deben ser estables
        #expect(DraftSourceType.groupExpense.rawValue == "groupExpense")
        #expect(DraftSourceType.groupSettlement.rawValue == "groupSettlement")
    }
}
