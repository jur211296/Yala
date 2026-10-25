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

    // MARK: - Card aeae · el residuo de redondeo no es una deuda

    /// Siembra la semilla `grupos-saldado` vista desde Beto (el pagador): 50.00 y 80.00 entre tres a 16.67 y 26.67, y
    /// los otros dos le liquidan 43.34. Su saldo neto queda en −0.02, pero nadie le debe nada a nadie. Con `short`, Ana
    /// liquida dos céntimos menos: esa sí es una deuda, y Saldos la enseña.
    private func seedResidueGroup(_ ctx: ModelContext, shortSettlement: Bool) throws {
        let group = SplitGroup(name: "Viaje", isOwner: true)
        ctx.insert(group)
        let zone = group.cloudKitZoneID
        let beto = SplitMember(groupZoneID: zone, displayName: "Beto", isCurrentUser: true)
        let yo = SplitMember(groupZoneID: zone, displayName: "Yo")
        let ana = SplitMember(groupZoneID: zone, displayName: "Ana")
        [beto, yo, ana].forEach { ctx.insert($0) }
        for (amount, share) in [(50.0, 16.67), (80.0, 26.67)] {
            let expense = SplitExpense(groupZoneID: zone, amount: amount, currencyCode: "USD",
                                       paidByMemberID: beto.id.uuidString)
            ctx.insert(expense)
            for member in [beto, yo, ana] {
                ctx.insert(SplitShare(expenseID: expense.id, memberID: member.id.uuidString, amount: share,
                                      groupZoneID: zone))
            }
        }
        for (from, amount) in [(yo, 43.34), (ana, shortSettlement ? 43.32 : 43.34)] {
            let settlement = SplitSettlement(groupZoneID: zone, fromMemberID: from.id.uuidString,
                                             toMemberID: beto.id.uuidString, amount: amount, currencyCode: "USD")
            settlement.isConfirmed = true
            ctx.insert(settlement)
        }
        try ctx.save()
    }

    /// Con el saldo NETO (`abs > 0.01`), esta cuenta avisaba de una deuda que nadie cobra.
    @Test func roundingResidue_isNotADebt() throws {
        let ctx = try makeTestContext()
        try seedResidueGroup(ctx, shortSettlement: false)
        let s = summary(ctx)
        #expect(s.outstandingDebtGroupCount == 0, "el residuo de redondeo cuenta como deuda")
        #expect(s.hasGroups, "Control: el grupo está vivo")
    }

    @Test func shortSettlementOfTwoCents_isADebt() throws {
        let ctx = try makeTestContext()
        try seedResidueGroup(ctx, shortSettlement: true)
        #expect(summary(ctx).outstandingDebtGroupCount == 1, "una deuda real de céntimos se esconde")
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

    /// **C3 · el caveat GDPR no se apaga al ocultar.** La huella es un hecho del servidor de Apple: la zona
    /// CloudKit sigue ahí con el nombre del usuario dentro (`groups_forget_user` anonimiza SOLO el backend).
    /// `LegacyGroupsRetirement` retira los grupos de esa era poniéndoles `isHiddenForAll = true`, así que con
    /// el filtro que este método tenía la retirada BORRABA el aviso `.legacyFootprint` del diálogo de
    /// «Eliminar mi cuenta» sin borrar ni una zona. Mutación: devolver el `#Predicate` de `isHiddenForAll`
    /// deja este test en rojo con los ocho de al lado en verde.
    @Test func legacyFootprint_survivesWhenTheGroupIsHidden() throws {
        let ctx = try makeTestContext()
        try seedGroup(ctx, hidden: true, currentUserNet: 0, ckSystemFields: Data([0x01]))
        let s = summary(ctx)
        #expect(s.hasLegacyCloudKitFootprint)
        // Y la otra mitad sigue siendo de los grupos VIVOS: un grupo oculto no cuenta como grupo.
        #expect(!s.hasGroups)
    }
}
