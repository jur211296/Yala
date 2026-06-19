//
//  GroupDraftFinalizationLogicTests.swift
//  YalaTests
//
//  Pure-logic tests para `GroupDraftFinalizationLogic` (Enfoque B). Sin SwiftData (R8).
//

import Foundation
import Testing

@testable import Yala

@Suite("Group draft finalization — Enfoque B logic")
@MainActor
struct GroupDraftFinalizationLogicTests {

    // MARK: - caseADraftNeedsUserInput

    @Test
    func caseADraft_matchOK_asksAccountOnly() {
        #expect(GroupDraftFinalizationLogic.caseADraftNeedsUserInput(needsSubcategory: false)
                == [DraftInputRequirement.account])
    }

    @Test
    func caseADraft_matchFails_asksAccountAndSubcategory() {
        #expect(GroupDraftFinalizationLogic.caseADraftNeedsUserInput(needsSubcategory: true)
                == [DraftInputRequirement.account, DraftInputRequirement.subcategory])
    }

    // MARK: - shouldOfferCaseASubcategoryFallback

    @Test
    func fallback_allConditionsAlign_true() {
        // TX real existe, sin subcat, match falla, fuera de DraftService.approve.
        #expect(GroupDraftFinalizationLogic.shouldOfferCaseASubcategoryFallback(
            skipDraftCleanup: false, hasRealTx: true, realTxSubcategoryIsNil: true, autoMatchFailed: true
        ) == true)
    }

    @Test
    func fallback_duringApprove_false() {
        // skipDraftCleanup=true: el user ya asignó subcat en el sheet; no recrear draft.
        #expect(GroupDraftFinalizationLogic.shouldOfferCaseASubcategoryFallback(
            skipDraftCleanup: true, hasRealTx: true, realTxSubcategoryIsNil: true, autoMatchFailed: true
        ) == false)
    }

    @Test
    func fallback_noRealTx_false() {
        // Sin TX real (el draft [.account(+subcategory)] ya cubre el ask vía createDraftCaseA).
        #expect(GroupDraftFinalizationLogic.shouldOfferCaseASubcategoryFallback(
            skipDraftCleanup: false, hasRealTx: false, realTxSubcategoryIsNil: true, autoMatchFailed: true
        ) == false)
    }

    @Test
    func fallback_realTxAlreadyClassified_false() {
        // El user ya clasificó la TX real: no recrear el draft (preserve+update no toca subcat).
        #expect(GroupDraftFinalizationLogic.shouldOfferCaseASubcategoryFallback(
            skipDraftCleanup: false, hasRealTx: true, realTxSubcategoryIsNil: false, autoMatchFailed: true
        ) == false)
    }

    @Test
    func fallback_autoMatchSucceeds_false() {
        // El auto-match resolvió la subcat: no hace falta pedir nada.
        #expect(GroupDraftFinalizationLogic.shouldOfferCaseASubcategoryFallback(
            skipDraftCleanup: false, hasRealTx: true, realTxSubcategoryIsNil: true, autoMatchFailed: false
        ) == false)
    }

    // MARK: - shouldCreateVirtualSubcategoryPointer

    @Test
    func virtualPointer_matchFails_noOptIn_true() {
        // Comportamiento clásico (Caso B / M5): sin opt-in pendiente, el puntero se crea.
        #expect(GroupDraftFinalizationLogic.shouldCreateVirtualSubcategoryPointer(
            autoMatchFailed: true, optInDraftCoversSubcategory: false
        ) == true)
    }

    @Test
    func virtualPointer_optInAlreadyAsksSubcategory_false() {
        // B6-26 parte 2: el opt-in combinado [.account, .subcategory] ya pide la subcat.
        // Re-crear el puntero en cada re-bridge duplicaba el draft en el Inbox.
        #expect(GroupDraftFinalizationLogic.shouldCreateVirtualSubcategoryPointer(
            autoMatchFailed: true, optInDraftCoversSubcategory: true
        ) == false)
    }

    @Test
    func virtualPointer_matchSucceeds_false() {
        // Subcat resuelta: nunca hay puntero, con o sin opt-in.
        #expect(GroupDraftFinalizationLogic.shouldCreateVirtualSubcategoryPointer(
            autoMatchFailed: false, optInDraftCoversSubcategory: false
        ) == false)
        #expect(GroupDraftFinalizationLogic.shouldCreateVirtualSubcategoryPointer(
            autoMatchFailed: false, optInDraftCoversSubcategory: true
        ) == false)
    }

    // MARK: - route

    @Test
    func route_m5InheritedPointer_subcategoryOnly_regardlessOfNeeds() {
        // targetTransactionID != nil (M5 heredado): siempre subcategoryOnly, intacto.
        #expect(GroupDraftFinalizationLogic.route(
            targetTransactionIDIsNil: false, needsAccount: true, needsSubcategory: true
        ) == .subcategoryOnly)
        #expect(GroupDraftFinalizationLogic.route(
            targetTransactionIDIsNil: false, needsAccount: true, needsSubcategory: false
        ) == .subcategoryOnly)
    }

    @Test
    func route_bothNeeds_accountAndSubcategory() {
        #expect(GroupDraftFinalizationLogic.route(
            targetTransactionIDIsNil: true, needsAccount: true, needsSubcategory: true
        ) == .accountAndSubcategory)
    }

    @Test
    func route_accountOnly() {
        #expect(GroupDraftFinalizationLogic.route(
            targetTransactionIDIsNil: true, needsAccount: true, needsSubcategory: false
        ) == .accountOnly)
    }

    @Test
    func route_subcategoryOnly() {
        #expect(GroupDraftFinalizationLogic.route(
            targetTransactionIDIsNil: true, needsAccount: false, needsSubcategory: true
        ) == .subcategoryOnly)
    }

    @Test
    func route_neitherNeed_degeneratesToSubcategoryOnly() {
        // Borde defensivo: sin cuenta ni subcat pendientes (no debería ocurrir en grupos) →
        // subcategoryOnly es el fallback seguro (sheet sin acciones de cuenta).
        #expect(GroupDraftFinalizationLogic.route(
            targetTransactionIDIsNil: true, needsAccount: false, needsSubcategory: false
        ) == .subcategoryOnly)
    }

    // MARK: - resolveMissingPointerTarget

    @Test
    func missingPointer_txAlreadyClassified_discardRedundant() {
        // La TX ya se clasificó en otro device (sync). El draft es redundante → idempotente.
        #expect(GroupDraftFinalizationLogic.resolveMissingPointerTarget(
            existsAnyTxForSplitID: true
        ) == .discardRedundant)
    }

    @Test
    func missingPointer_noTxAtAll_deleteStaleAndThrow() {
        // No existe NINGUNA TX → el expense se borró remotamente. NO materializar TX nueva
        // (fantasma): limpiar el draft stale y lanzar error.
        #expect(GroupDraftFinalizationLogic.resolveMissingPointerTarget(
            existsAnyTxForSplitID: false
        ) == .deleteStaleAndThrow)
    }
}
