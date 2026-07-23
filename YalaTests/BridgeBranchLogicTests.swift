//
//  BridgeBranchLogicTests.swift
//  YalaTests
//
//  Pure-logic tests para `BridgeBranchLogic.decideCaseAPath`. Sin SwiftData (R8).
//

import Foundation
import Testing

@testable import Yala

@Suite("Bridge opt-out — branch logic")
struct BridgeBranchLogicTests {

    @Test
    func groupInvite_alwaysReturnsVirtualPair_regardlessOfEffective() {
        // .groupInvite tiene prioridad sobre el opt-out: no hay cuentas reales en ese flow.
        #expect(BridgeBranchLogic.decideCaseAPath(
            isGroupInviteMode: true, effectiveBridgeEnabled: true
        ) == .groupInviteVirtualPair)
        #expect(BridgeBranchLogic.decideCaseAPath(
            isGroupInviteMode: true, effectiveBridgeEnabled: false
        ) == .groupInviteVirtualPair)
    }

    @Test
    func nonGroupInvite_effectiveOff_returnsOptoutVirtualOnly() {
        #expect(BridgeBranchLogic.decideCaseAPath(
            isGroupInviteMode: false, effectiveBridgeEnabled: false
        ) == .optoutVirtualOnly)
    }

    @Test
    func nonGroupInvite_effectiveOn_returnsFullPair() {
        #expect(BridgeBranchLogic.decideCaseAPath(
            isGroupInviteMode: false, effectiveBridgeEnabled: true
        ) == .fullPair)
    }

    // MARK: - decideVirtualReconciliation (B6-25)

    @Test
    func noRealTx_returnsMyShareCost() {
        // Bridge-OFF puro sin opt-in: el virtual -myShare ES mi costo (correcto).
        #expect(BridgeBranchLogic.decideVirtualReconciliation(
            hasRealTx: false, lentAmount: 20
        ) == .myShareCost)
        #expect(BridgeBranchLogic.decideVirtualReconciliation(
            hasRealTx: false, lentAmount: 0
        ) == .myShareCost)
    }

    @Test
    func realTx_withLent_returnsLendingToCompensate() {
        // 2 miembros: total 40, myShare 20, lent 20. Con real -40, el virtual debe ser +20
        // → net = -20 = mi parte (no -60). Idéntico a bridge-ON Caso A.
        #expect(BridgeBranchLogic.decideVirtualReconciliation(
            hasRealTx: true, lentAmount: 20
        ) == .lendingToCompensateReal)
    }

    @Test
    func realTx_zeroLent_returnsNoVirtual() {
        // Solo-yo: total 40, myShare 40, lent 0. Con real -40, sin virtual → net = -40 (no -80).
        #expect(BridgeBranchLogic.decideVirtualReconciliation(
            hasRealTx: true, lentAmount: 0
        ) == .noVirtual)
    }

    @Test
    func realTx_negativeLent_returnsNoVirtual() {
        // Borde defensivo: lent negativo (data inconsistente) no debe crear un virtual.
        #expect(BridgeBranchLogic.decideVirtualReconciliation(
            hasRealTx: true, lentAmount: -5
        ) == .noVirtual)
    }

    // MARK: - partitionVirtualTxs (Caso B preserve+update)

    private func shape(
        nilSub: Bool = false, systemSub: Bool = false, meta: Bool = false,
        date: Date = Date(timeIntervalSince1970: 1_000), createdAt: Date = Date(timeIntervalSince1970: 1_000)
    ) -> BridgeBranchLogic.VirtualTxShape {
        BridgeBranchLogic.VirtualTxShape(
            subcategoryIsNil: nilSub, subcategoryIsSystem: systemSub,
            hasUserMetadata: meta, date: date, createdAt: createdAt
        )
    }

    @Test
    func partition_empty_returnsNothing() {
        let r = BridgeBranchLogic.partitionVirtualTxs([])
        #expect(r.preservedIndex == nil)
        #expect(r.deletedIndices.isEmpty)
    }

    @Test
    func partition_onlyDerived_preservesNoneDeletesAll() {
        // Dos derivadas (lent + opening balance): ambas subcat de sistema → nada clasificable.
        let r = BridgeBranchLogic.partitionVirtualTxs([
            shape(systemSub: true), shape(systemSub: true),
        ])
        #expect(r.preservedIndex == nil)
        #expect(r.deletedIndices == [0, 1])
    }

    @Test
    func partition_oneClassifiable_amongDerived_preservesIt() {
        // idx1 = myShare clasificable (subcat de usuario); idx0/idx2 derivadas.
        let r = BridgeBranchLogic.partitionVirtualTxs([
            shape(systemSub: true),
            shape(nilSub: false, systemSub: false, meta: true),
            shape(systemSub: true),
        ])
        #expect(r.preservedIndex == 1)
        #expect(r.deletedIndices == [0, 2])
    }

    @Test
    func partition_nilSubcat_isClassifiable() {
        // Una virtual myShare sin clasificar (subcat nil) SÍ es clasificable (preservable).
        let r = BridgeBranchLogic.partitionVirtualTxs([shape(nilSub: true)])
        #expect(r.preservedIndex == 0)
        #expect(r.deletedIndices.isEmpty)
    }

    @Test
    func partition_duplicates_metadataWinsOverBare() {
        // idx0 sin metadata, idx1 con subcat de usuario/tags → gana idx1.
        let r = BridgeBranchLogic.partitionVirtualTxs([
            shape(nilSub: true),                       // clasificable, sin metadata
            shape(nilSub: false, systemSub: false, meta: true),  // clasificable con metadata
        ])
        #expect(r.preservedIndex == 1)
        #expect(r.deletedIndices == [0])
    }

    @Test
    func partition_duplicates_tieByMetadata_oldestWins() {
        // Ambas con metadata: gana la más antigua por date.
        let older = Date(timeIntervalSince1970: 100)
        let newer = Date(timeIntervalSince1970: 500)
        let r = BridgeBranchLogic.partitionVirtualTxs([
            shape(meta: true, date: newer),
            shape(meta: true, date: older),
        ])
        #expect(r.preservedIndex == 1)
        #expect(r.deletedIndices == [0])
    }

    @Test
    func partition_duplicates_tieByDate_stableByCreatedAtThenIndex() {
        // Empate en metadata + date → desempata por createdAt, luego índice (determinista).
        let d = Date(timeIntervalSince1970: 100)
        let r = BridgeBranchLogic.partitionVirtualTxs([
            shape(meta: true, date: d, createdAt: Date(timeIntervalSince1970: 200)),
            shape(meta: true, date: d, createdAt: Date(timeIntervalSince1970: 150)),
        ])
        #expect(r.preservedIndex == 1)  // createdAt más antiguo
        #expect(r.deletedIndices == [0])
    }
}
