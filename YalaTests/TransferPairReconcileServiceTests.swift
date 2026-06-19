//
//  TransferPairReconcileServiceTests.swift
//  YalaTests
//
//  Pure-logic tests para `TransferPairReconcileService.computeReconcilePlan` y `.computePairingPlan`.
//  Sin ModelContext (R8: avoid makeTestContext flake).
//

import Foundation
import Testing

@testable import Yala

private func info(
    id: UUID = UUID(),
    date: Date = Date(timeIntervalSince1970: 1_700_000_000),
    amount: Double,
    currencyCode: String = "USD",
    transferPairID: String? = nil,
    isTransferType: Bool = true
) -> TransferPairReconcileService.TransferInfo {
    TransferPairReconcileService.TransferInfo(
        id: id,
        date: date,
        amount: amount,
        currencyCode: currencyCode,
        transferPairID: transferPairID,
        isTransferType: isTransferType
    )
}

struct TransferPairReconcileServiceTests {

    // MARK: - computeReconcilePlan

    @Test("Empty input produces empty plan")
    func computeReconcilePlan_emptyInput() {
        let plan = TransferPairReconcileService.computeReconcilePlan(transactions: [])
        #expect(plan.orphansToClearIDs.isEmpty)
        #expect(plan.malformedToClearIDs.isEmpty)
        #expect(plan.pairings.isEmpty)
        #expect(plan.collisions.isEmpty)
    }

    @Test("Valid pair (N=2) produces no actions")
    func computeReconcilePlan_validPairNoAction() {
        let pairID = UUID().uuidString
        let plan = TransferPairReconcileService.computeReconcilePlan(transactions: [
            info(amount: -100, transferPairID: pairID),
            info(amount: 100, transferPairID: pairID),
        ])
        #expect(plan.orphansToClearIDs.isEmpty)
        #expect(plan.malformedToClearIDs.isEmpty)
        #expect(plan.pairings.isEmpty)
        #expect(plan.collisions.isEmpty)
    }

    @Test("Lone orphan (1-of-1 with pairID) is cleared")
    func computeReconcilePlan_clearsLoneOrphan() {
        let lonely = UUID()
        let plan = TransferPairReconcileService.computeReconcilePlan(transactions: [
            info(id: lonely, amount: -100, transferPairID: UUID().uuidString),
        ])
        #expect(plan.orphansToClearIDs == [lonely])
        #expect(plan.collisions.isEmpty)
    }

    @Test("Collision (3+ TXs sharing pairID) reports but does NOT auto-repair")
    func computeReconcilePlan_reportsCollisionWithoutRepair() {
        let pairID = UUID().uuidString
        let plan = TransferPairReconcileService.computeReconcilePlan(transactions: [
            info(amount: -100, transferPairID: pairID),
            info(amount: 100, transferPairID: pairID),
            info(amount: -100, transferPairID: pairID),
        ])
        #expect(plan.collisions.count == 1)
        #expect(plan.collisions[0].count == 3)
        #expect(plan.collisions[0].pairID == pairID)
        // No auto-repair: orphans no se clearean ni se splitean
        #expect(plan.orphansToClearIDs.isEmpty)
        #expect(plan.pairings.isEmpty)
    }

    @Test("Malformed pairID (not a UUID) is cleared")
    func computeReconcilePlan_clearsMalformedPairID() {
        let tx = UUID()
        let plan = TransferPairReconcileService.computeReconcilePlan(transactions: [
            info(id: tx, amount: -100, transferPairID: "abc-not-uuid"),
        ])
        #expect(plan.malformedToClearIDs == [tx])
    }

    @Test("Whitespace-only pairID is treated as malformed")
    func computeReconcilePlan_clearsWhitespacePairID() {
        let tx = UUID()
        let plan = TransferPairReconcileService.computeReconcilePlan(transactions: [
            info(id: tx, amount: -100, transferPairID: "   "),
        ])
        #expect(plan.malformedToClearIDs == [tx])
    }

    // MARK: - computePairingPlan

    @Test("Pairs balanced N=2 group (1 negative + 1 positive)")
    func computePairingPlan_pairsBalancedN2() {
        let neg = UUID()
        let pos = UUID()
        let pairings = TransferPairReconcileService.computePairingPlan(orphans: [
            info(id: neg, amount: -100),
            info(id: pos, amount: 100),
        ])
        #expect(pairings.count == 1)
        let pair = pairings[0]
        #expect(Set([pair.txAID, pair.txBID]) == Set([neg, pos]))
        #expect(UUID(uuidString: pair.pairID) != nil)
    }

    @Test("Skips N>2 balanced groups (ambiguity — can't know which neg pairs with which pos)")
    func computePairingPlan_skipsN4BalancedGroup() {
        let pairings = TransferPairReconcileService.computePairingPlan(orphans: [
            info(amount: -100),
            info(amount: 100),
            info(amount: -100),
            info(amount: 100),
        ])
        // N=4 grupo (2 neg + 2 pos) es ambiguous: heurística no puede saber qué neg va con qué pos.
        // Skip total — el reconciler dejará todos como orphans hasta intervención manual.
        #expect(pairings.isEmpty)
    }

    @Test("Skips imbalanced group (3 negatives + 1 positive)")
    func computePairingPlan_skipsImbalanced() {
        let pairings = TransferPairReconcileService.computePairingPlan(orphans: [
            info(amount: -100),
            info(amount: 100),
            info(amount: -100),
            info(amount: -100),
        ])
        #expect(pairings.isEmpty)
    }

    @Test("Skips group with all same sign")
    func computePairingPlan_skipsAllSameSign() {
        let pairings = TransferPairReconcileService.computePairingPlan(orphans: [
            info(amount: 100),
            info(amount: 100),
        ])
        #expect(pairings.isEmpty)
    }

    @Test("Does not pair across different days")
    func computePairingPlan_doesNotPairAcrossDays() {
        let day1 = Date(timeIntervalSince1970: 1_700_000_000)
        let day2 = day1.addingTimeInterval(86400 * 2)  // 2 días después
        let pairings = TransferPairReconcileService.computePairingPlan(orphans: [
            info(date: day1, amount: -100),
            info(date: day2, amount: 100),
        ])
        #expect(pairings.isEmpty)
    }

    @Test("Does not pair across different currencies")
    func computePairingPlan_doesNotPairAcrossCurrencies() {
        let pairings = TransferPairReconcileService.computePairingPlan(orphans: [
            info(amount: -100, currencyCode: "USD"),
            info(amount: 100, currencyCode: "PEN"),
        ])
        #expect(pairings.isEmpty)
    }

    @Test("Multiple separate N=2 groups (different days/amounts) each pair independently")
    func computePairingPlan_multipleSeparateGroupsPairIndependently() {
        let day1 = Date(timeIntervalSince1970: 1_700_000_000)
        let day2 = day1.addingTimeInterval(86400 * 2)
        let pairings = TransferPairReconcileService.computePairingPlan(orphans: [
            // Day 1 / amount 100 — 1 neg + 1 pos → pair
            info(date: day1, amount: -100),
            info(date: day1, amount: 100),
            // Day 2 / amount 200 — 1 neg + 1 pos → pair
            info(date: day2, amount: -200),
            info(date: day2, amount: 200),
        ])
        #expect(pairings.count == 2)
        #expect(Set(pairings.map { $0.pairID }).count == 2)
    }
}
