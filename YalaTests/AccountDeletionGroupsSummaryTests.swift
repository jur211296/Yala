//
//  AccountDeletionGroupsSummaryTests.swift
//  YalaTests
//
//  D5 (§3.3.4): la GLUE SwiftData→resumen de `GroupService.accountDeletionGroupsSummary(context:)`
//  — el filtro `isHiddenForAll`, la resolución del member del usuario (`isCurrentUser`), el matching
//  `balances.memberID == me.id.uuidString`, la detección de huella CloudKit (`ckSystemFieldsData != nil`)
//  y el skip cuando no hay member del usuario. Read-only (cero saves; el aviso solo informa). Se inyecta
//  el `context` de test ⇒ NO se muta el singleton `.shared`. `@Suite(.serialized)` por el reuso per-file
//  del container de `makeTestContext` (cada llamada vacía el store → aislamiento por test).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite(.serialized)
struct AccountDeletionGroupsSummaryTests {

    private func summary(_ ctx: ModelContext) -> AccountDeletionGroupsSummary {
        GroupService.shared.accountDeletionGroupsSummary(context: ctx)
    }

    /// Siembra un grupo. Con `currentUserNet != 0`, el member del usuario actual queda con ese neto
    /// (paga `amount`, su share = `amount - net` ⇒ net = amount - (amount - net)). Devuelve la zona.
    @discardableResult
    private func seedGroup(
        _ ctx: ModelContext,
        hidden: Bool = false,
        withCurrentUser: Bool = true,
        currentUserNet: Double = 0,
        ckSystemFields: Data? = nil
    ) throws -> String {
        let group = SplitGroup(name: "G", isOwner: true)
        group.isHiddenForAll = hidden
        group.ckSystemFieldsData = ckSystemFields
        ctx.insert(group)
        let zone = group.cloudKitZoneID

        let other = SplitMember(groupZoneID: zone, displayName: "B", isCurrentUser: false)
        ctx.insert(other)

        var payerID = other.id.uuidString
        if withCurrentUser {
            let me = SplitMember(groupZoneID: zone, displayName: "Me", isCurrentUser: true)
            ctx.insert(me)
            payerID = me.id.uuidString
        }

        if currentUserNet != 0 {
            let amount = 100.0
            let expense = SplitExpense(
                groupZoneID: zone, amount: amount, currencyCode: "USD", paidByMemberID: payerID)
            ctx.insert(expense)
            // payer debe `amount - net`; el otro debe `net` (total shares = amount, split consistente).
            ctx.insert(SplitShare(
                expenseID: expense.id, memberID: payerID, amount: amount - currentUserNet, groupZoneID: zone))
            ctx.insert(SplitShare(
                expenseID: expense.id, memberID: other.id.uuidString, amount: currentUserNet, groupZoneID: zone))
        }
        try ctx.save()
        return zone
    }

    @Test func emptyStore_returnsEmpty() throws {
        let ctx = try makeTestContext()
        #expect(summary(ctx) == .empty)
    }

    @Test func currentUserWithDebt_counted() throws {
        let ctx = try makeTestContext()
        try seedGroup(ctx, currentUserNet: 50)
        let s = summary(ctx)
        #expect(s.outstandingDebtGroupCount == 1)
        #expect(s.hasOutstandingDebt)
    }

    @Test func currentUserZeroBalance_notCounted() throws {
        let ctx = try makeTestContext()
        try seedGroup(ctx, currentUserNet: 0)  // member presente pero sin gastos ⇒ early-exit
        #expect(summary(ctx).outstandingDebtGroupCount == 0)
    }

    @Test func softDeletedGroup_excluded() throws {
        let ctx = try makeTestContext()
        try seedGroup(ctx, hidden: true, currentUserNet: 50)
        #expect(summary(ctx).outstandingDebtGroupCount == 0)
    }

    @Test func noCurrentUserMember_skipped() throws {
        let ctx = try makeTestContext()
        // Grupo con deuda pero sin member `isCurrentUser` (el pagador es el otro) ⇒ se salta, no cuenta.
        try seedGroup(ctx, withCurrentUser: false, currentUserNet: 50)
        #expect(summary(ctx).outstandingDebtGroupCount == 0)
    }

    @Test func multipleGroups_countsOnlyThoseWithUserDebt() throws {
        let ctx = try makeTestContext()
        try seedGroup(ctx, currentUserNet: 50)                 // cuenta
        try seedGroup(ctx, currentUserNet: 0)                  // sin gastos → no cuenta
        try seedGroup(ctx, hidden: true, currentUserNet: 30)   // soft-deleted → no cuenta
        #expect(summary(ctx).outstandingDebtGroupCount == 1)
    }

    @Test func legacyFootprint_trueWhenGroupHasCkSystemFields() throws {
        let ctx = try makeTestContext()
        try seedGroup(ctx, currentUserNet: 0, ckSystemFields: Data([0x01]))
        #expect(summary(ctx).hasLegacyCloudKitFootprint)
    }

    @Test func legacyFootprint_falseWhenNoCloudKitZone() throws {
        let ctx = try makeTestContext()
        try seedGroup(ctx, currentUserNet: 0, ckSystemFields: nil)
        #expect(!summary(ctx).hasLegacyCloudKitFootprint)
    }
}
