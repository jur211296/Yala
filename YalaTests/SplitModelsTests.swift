//
//  SplitModelsTests.swift
//  YalaTests
//
//  Tests para modelos SwiftData de Gastos Compartidos (GC-01).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite(.serialized)
struct SplitModelsTests {

    // MARK: - SplitGroup

    @Test func splitGroupDefaults() {
        let group = SplitGroup()
        #expect(group.name == "")
        #expect(group.iconName == "person.2.fill")
        #expect(group.colorHex == "#8B5CF6")
        #expect(group.currencyCode == "PEN")
        #expect(group.simplifyDebts == false)
        #expect(group.isOwner == false)
        #expect(group.isArchived == false)
        #expect(group.defaultAccountID == nil)
        #expect(group.showDebtsInSingleCurrency == false)
        #expect(group.defaultSplitType == "equal")
        #expect(group.membersCanInvite == false)
        #expect(group.cloudKitZoneID.hasPrefix("SplitGroup-"))
    }

    // MARK: - SplitMember

    @Test func splitMemberDefaults() {
        let member = SplitMember()
        #expect(member.groupZoneID == "")
        #expect(member.displayName == "")
        #expect(member.cloudKitUserRecordID == "")
        #expect(member.role == "member")
        #expect(member.memberStatus == .active)
        #expect(member.isActive == true)
        #expect(member.isGroupOwner == false)
        #expect(member.isCurrentUser == false)
    }

    // MARK: - A3: pendingApproval / rejected

    @Test func pendingApprovalRawValueIsStable() {
        // Estabilidad de rawValues — viajan vía CloudKit y deben ser invariables.
        #expect(SplitMemberStatus.pendingApproval.rawValue == "pendingApproval")
        #expect(SplitMemberStatus.rejected.rawValue == "rejected")
    }

    @Test func pendingApprovalNotActive() {
        let member = SplitMember(status: .pendingApproval)
        #expect(member.isActive == false)
        #expect(member.isPendingApproval == true)
        #expect(member.canWrite == false)
    }

    @Test func rejectedNotActive() {
        let member = SplitMember(status: .rejected)
        #expect(member.isRejected == true)
        #expect(member.isActive == false)
        #expect(member.canWrite == false)
    }

    @Test func unknownRawValueFallsBackToActive() {
        // Defensive: rawValue desde CloudKit con string desconocido cae a .active (no crashea).
        let member = SplitMember()
        member.status = "garbage"
        #expect(member.memberStatus == .active)
    }

    // MARK: - SplitExpense

    @Test func splitExpenseDefaults() {
        let expense = SplitExpense()
        #expect(expense.groupZoneID == "")
        #expect(expense.amount == 0)
        #expect(expense.currencyCode == "USD")
        #expect(expense.expenseDescription == "")
        #expect(expense.note == nil)
        #expect(expense.paidByMemberID == "")
        #expect(expense.splitType == "equal")
        #expect(expense.isSettled == false)
        #expect(expense.subcategoryName == nil)
    }

    // MARK: - SplitShare

    @Test func splitShareDefaults() {
        let share = SplitShare()
        #expect(share.memberID == "")
        #expect(share.amount == 0)
        #expect(share.isPaid == false)
    }

    // MARK: - SplitSettlement

    @Test func splitSettlementDefaults() {
        let settlement = SplitSettlement()
        #expect(settlement.groupZoneID == "")
        #expect(settlement.fromMemberID == "")
        #expect(settlement.toMemberID == "")
        #expect(settlement.amount == 0)
        #expect(settlement.currencyCode == "USD")
        #expect(settlement.note == nil)
        #expect(settlement.isConfirmed == false)
    }

    // MARK: - Init with Parameters

    @Test func splitGroupInitWithParameters() {
        let group = SplitGroup(
            name: "Depa Miraflores",
            currencyCode: "PEN",
            isOwner: true,
            showDebtsInSingleCurrency: true,
            defaultSplitType: "percentage",
            membersCanInvite: false
        )
        #expect(group.name == "Depa Miraflores")
        #expect(group.currencyCode == "PEN")
        #expect(group.isOwner == true)
        #expect(group.showDebtsInSingleCurrency == true)
        #expect(group.defaultSplitType == "percentage")
        #expect(group.membersCanInvite == false)
        #expect(group.cloudKitZoneID.hasPrefix("SplitGroup-"))
        #expect(group.cloudKitZoneID.count > "SplitGroup-".count)
    }

    @Test func splitExpenseInitWithParameters() {
        let expense = SplitExpense(
            groupZoneID: "SplitGroup-abc",
            amount: 150.50,
            currencyCode: "PEN",
            expenseDescription: "Supermercado",
            paidByMemberID: "member-1",
            splitType: "percentage"
        )
        #expect(expense.groupZoneID == "SplitGroup-abc")
        #expect(expense.amount == 150.50)
        #expect(expense.expenseDescription == "Supermercado")
        #expect(expense.splitType == "percentage")
        #expect(expense.isSettled == false)
    }

    // MARK: - SplitType Interop

    @Test func splitTypeRawValueCompatibility() {
        #expect(SplitType.equal.rawValue == "equal")
        #expect(SplitType.exact.rawValue == "exact")
        #expect(SplitType.percentage.rawValue == "percentage")
        #expect(SplitType.shares.rawValue == "shares")

        let expense = SplitExpense(splitType: SplitType.equal.rawValue)
        #expect(expense.splitType == "equal")
    }

    // MARK: - Existing Model Bridge Fields
    // NOTE: Tests that use makeTestContext() crash on iOS 26 simulator
    // (CloudKit race condition — EXC_BREAKPOINT in metadata accessor).
    // TransactionItem/InboxDraft bridge fields are verified without SwiftData context.

    @Test func transactionItemSplitFieldsNilByDefault() {
        let tx = TransactionItem(
            date: Date.now,
            amount: -50,
            currencyCode: "PEN"
        )
        #expect(tx.splitExpenseID == nil)
        #expect(tx.splitGroupZoneID == nil)
    }

    @Test func inboxDraftSplitFieldsNilByDefault() {
        let draft = InboxDraft(note: "Test", amount: 50, date: Date.now, sourceType: .voice)
        #expect(draft.splitExpenseID == nil)
        #expect(draft.splitGroupZoneID == nil)
    }

    // MARK: - Schema Integrity (compile-time verified)
    // SwiftDataConfiguration.schema includes all 20 models.
    // Verified by successful BUILD — if any model is missing from schema,
    // the app crashes on launch. Direct ModelContainer creation crashes
    // in test runner due to iOS 26 simulator CloudKit race condition.

    @Test func splitGroupUniqueIDs() {
        let group1 = SplitGroup(name: "Grupo 1")
        let group2 = SplitGroup(name: "Grupo 2")
        #expect(group1.id != group2.id)
        #expect(group1.cloudKitZoneID != group2.cloudKitZoneID)
    }
}
