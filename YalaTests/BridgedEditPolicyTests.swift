//
//  BridgedEditPolicyTests.swift
//  YalaTests
//
//  Pure-logic tests para `BridgedEditPolicy` (edición de TX bridgeadas). Sin SwiftUI/SwiftData.
//

import Foundation
import Testing

@testable import Yala

@Suite("BridgedEditPolicy — permisos de edición + banner")
struct BridgedEditPolicyTests {

    private func shape(
        expense: Bool = false, settlement: Bool = false,
        accountNil: Bool = false, accountSystem: Bool = false, subcatSystem: Bool = false,
        pointer: Bool = false
    ) -> BridgedEditPolicy.TxShape {
        BridgedEditPolicy.TxShape(
            hasSplitExpenseID: expense, hasSplitSettlementID: settlement,
            accountIsNil: accountNil, accountIsSystem: accountSystem,
            subcategoryIsSystem: subcatSystem, hasPendingPointerDraft: pointer
        )
    }

    // MARK: - classify

    @Test func classify_notBridged() {
        #expect(BridgedEditPolicy.classify(shape()) == .notBridged)
    }

    @Test func classify_caseAReal_expenseWithUserAccount() {
        #expect(BridgedEditPolicy.classify(shape(expense: true, accountSystem: false)) == .caseAReal)
    }

    @Test func classify_caseBClassifiable_systemAccount_userOrNilSubcat() {
        // Cuenta sistema + subcat de usuario → clasificable.
        #expect(BridgedEditPolicy.classify(shape(expense: true, accountSystem: true, subcatSystem: false)) == .caseBClassifiable)
        // Cuenta sistema + subcat nil → clasificable (myShare sin clasificar).
        #expect(BridgedEditPolicy.classify(shape(expense: true, accountSystem: true, subcatSystem: false, pointer: true)) == .caseBClassifiable)
    }

    @Test func classify_derivedVirtual_systemAccount_systemSubcat() {
        #expect(BridgedEditPolicy.classify(shape(expense: true, accountSystem: true, subcatSystem: true)) == .derivedVirtual)
    }

    @Test func classify_settlement_takesPrecedence() {
        // Settlement manda aunque tenga cuenta de sistema y hasta un splitExpenseID espurio.
        #expect(BridgedEditPolicy.classify(shape(settlement: true, accountSystem: true)) == .settlement)
        #expect(BridgedEditPolicy.classify(shape(expense: true, settlement: true)) == .settlement)
    }

    @Test func classify_accountNotHydrated_conservativeAllBlocked() {
        // Cuenta CloudKit-lazy sin hidratar: sin cuenta no se distingue Caso A de virtual →
        // conservador (derivada, todo bloqueado), en paridad con `isBridgedCasoA == false`.
        #expect(BridgedEditPolicy.classify(shape(expense: true, accountNil: true)) == .derivedVirtual)
        // No bridgeada con cuenta nil (creación) sigue siendo notBridged.
        #expect(BridgedEditPolicy.classify(shape(accountNil: true)) == .notBridged)
    }

    // MARK: - permisos (tabla)

    @Test func permissions_table() {
        let cases: [(BridgedEditPolicy.Classification, Bool, Bool, Bool)] = [
            // (clasificación, canEditAccount, canEditSubcatTags, canSave)
            (.notBridged,         true,  true,  true),
            (.caseAReal,          true,  true,  true),
            (.caseBClassifiable,  false, true,  true),
            (.derivedVirtual,     false, false, false),
            (.settlement,         false, false, false),
        ]
        for (c, acc, sub, save) in cases {
            #expect(BridgedEditPolicy.canEditAccount(c) == acc, "canEditAccount \(c)")
            #expect(BridgedEditPolicy.canEditSubcategoryAndTags(c) == sub, "canEditSubcategoryAndTags \(c)")
            #expect(BridgedEditPolicy.canSave(c) == save, "canSave \(c)")
        }
    }

    // MARK: - banner (matriz explícita)

    @Test func banner_notBridged_none() {
        #expect(BridgedEditPolicy.banner(shape()) == BridgedEditPolicy.Banner.none)
    }

    @Test func banner_pointerPending_assignFromInbox_takesPrecedence() {
        // Un draft-puntero pendiente manda sobre Caso B / derivadas.
        #expect(BridgedEditPolicy.banner(shape(expense: true, accountSystem: true, subcatSystem: false, pointer: true)) == .assignFromInbox)
        #expect(BridgedEditPolicy.banner(shape(expense: true, accountSystem: true, subcatSystem: true, pointer: true)) == .assignFromInbox)
    }

    @Test func banner_settlement_editSettlementInGroup() {
        #expect(BridgedEditPolicy.banner(shape(settlement: true, accountSystem: true)) == .editSettlementInGroup)
    }

    @Test func banner_caseAReal_editPartial() {
        #expect(BridgedEditPolicy.banner(shape(expense: true, accountSystem: false)) == .editPartial)
    }

    @Test func banner_caseBClassifiable_editPartialCaseB() {
        #expect(BridgedEditPolicy.banner(shape(expense: true, accountSystem: true, subcatSystem: false)) == .editPartialCaseB)
    }

    @Test func banner_derivedVirtual_editFromGroup() {
        #expect(BridgedEditPolicy.banner(shape(expense: true, accountSystem: true, subcatSystem: true)) == .editFromGroup)
    }
}
