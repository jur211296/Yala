//
//  DebtSimplificationServiceTests.swift
//  YalaTests
//
//  Unit tests for DebtSimplificationService minimum cash flow algorithm.
//

import Foundation
import Testing

@testable import Yala

struct DebtSimplificationServiceTests {

    // MARK: - Empty / Trivial

    @Test func empty_returnsEmpty() {
        let result = DebtSimplificationService.simplify(debts: [])
        #expect(result.isEmpty)
    }

    @Test func singleDebt_passesThrough() {
        let debts = [Debt(fromMemberID: "A", toMemberID: "B", amount: 100, currencyCode: "PEN")]
        let result = DebtSimplificationService.simplify(debts: debts)

        #expect(result.count == 1)
        #expect(result[0].fromMemberID == "A")
        #expect(result[0].toMemberID == "B")
        #expect(result[0].amount == 100)
    }

    // MARK: - Two Members

    @Test func twoMembers_multipleDebts_consolidates() {
        // A owes B 50 twice = A owes B 100
        let debts = [
            Debt(fromMemberID: "A", toMemberID: "B", amount: 50, currencyCode: "PEN"),
            Debt(fromMemberID: "A", toMemberID: "B", amount: 50, currencyCode: "PEN"),
        ]
        let result = DebtSimplificationService.simplify(debts: debts)

        #expect(result.count == 1)
        #expect(result[0].amount == 100)
    }

    @Test func twoMembers_bidirectional_netsOut() {
        // A owes B 80, B owes A 50 → A owes B 30
        let debts = [
            Debt(fromMemberID: "A", toMemberID: "B", amount: 80, currencyCode: "PEN"),
            Debt(fromMemberID: "B", toMemberID: "A", amount: 50, currencyCode: "PEN"),
        ]
        let result = DebtSimplificationService.simplify(debts: debts)

        #expect(result.count == 1)
        #expect(result[0].fromMemberID == "A")
        #expect(result[0].toMemberID == "B")
        #expect(result[0].amount == 30)
    }

    @Test func twoMembers_equalOpposite_cancelsOut() {
        // A owes B 100, B owes A 100 → nothing
        let debts = [
            Debt(fromMemberID: "A", toMemberID: "B", amount: 100, currencyCode: "PEN"),
            Debt(fromMemberID: "B", toMemberID: "A", amount: 100, currencyCode: "PEN"),
        ]
        let result = DebtSimplificationService.simplify(debts: debts)
        #expect(result.isEmpty)
    }

    // MARK: - Three Members: Chain

    @Test func threeMembers_chain_simplifies() {
        // A→B 50, B→C 30 → simplified: A→B 20, A→C 30
        // Net: A=-50, B=+50-30=+20, C=+30
        let debts = [
            Debt(fromMemberID: "A", toMemberID: "B", amount: 50, currencyCode: "PEN"),
            Debt(fromMemberID: "B", toMemberID: "C", amount: 30, currencyCode: "PEN"),
        ]
        let result = DebtSimplificationService.simplify(debts: debts)

        // Should produce 2 transfers (A pays B 20, A pays C 30)
        #expect(result.count == 2)

        let totalAmount = result.reduce(0) { $0 + $1.amount }
        #expect(totalAmount == 50) // Total money moved = 50 (was 80 before)

        // All from A (the only debtor)
        for debt in result {
            #expect(debt.fromMemberID == "A")
        }
    }

    // MARK: - Three Members: Cycle

    @Test func threeMembers_perfectCycle_allCancels() {
        // A→B 100, B→C 100, C→A 100 → net all zero
        let debts = [
            Debt(fromMemberID: "A", toMemberID: "B", amount: 100, currencyCode: "PEN"),
            Debt(fromMemberID: "B", toMemberID: "C", amount: 100, currencyCode: "PEN"),
            Debt(fromMemberID: "C", toMemberID: "A", amount: 100, currencyCode: "PEN"),
        ]
        let result = DebtSimplificationService.simplify(debts: debts)
        #expect(result.isEmpty)
    }

    @Test func threeMembers_partialCycle_reducesToOne() {
        // A→B 100, B→C 100, C→A 70
        // Net: A=-100+70=-30, B=+100-100=0, C=+100-70=+30
        // Simplified: A→C 30
        let debts = [
            Debt(fromMemberID: "A", toMemberID: "B", amount: 100, currencyCode: "PEN"),
            Debt(fromMemberID: "B", toMemberID: "C", amount: 100, currencyCode: "PEN"),
            Debt(fromMemberID: "C", toMemberID: "A", amount: 70, currencyCode: "PEN"),
        ]
        let result = DebtSimplificationService.simplify(debts: debts)

        #expect(result.count == 1)
        #expect(result[0].fromMemberID == "A")
        #expect(result[0].toMemberID == "C")
        #expect(result[0].amount == 30)
    }

    // MARK: - Fan-in / Fan-out

    @Test func fanIn_multipleDebtorsToOneCreditor() {
        // A→C 40, B→C 60 → A→C 40, B→C 60 (already optimal)
        let debts = [
            Debt(fromMemberID: "A", toMemberID: "C", amount: 40, currencyCode: "PEN"),
            Debt(fromMemberID: "B", toMemberID: "C", amount: 60, currencyCode: "PEN"),
        ]
        let result = DebtSimplificationService.simplify(debts: debts)

        #expect(result.count == 2)
        let totalToC = result.filter { $0.toMemberID == "C" }.reduce(0) { $0 + $1.amount }
        #expect(totalToC == 100)
    }

    @Test func fanOut_oneDebtorToMultipleCreditors() {
        // A→B 30, A→C 50 → A→B 30, A→C 50 (already optimal)
        let debts = [
            Debt(fromMemberID: "A", toMemberID: "B", amount: 30, currencyCode: "PEN"),
            Debt(fromMemberID: "A", toMemberID: "C", amount: 50, currencyCode: "PEN"),
        ]
        let result = DebtSimplificationService.simplify(debts: debts)

        #expect(result.count == 2)
        let totalFromA = result.filter { $0.fromMemberID == "A" }.reduce(0) { $0 + $1.amount }
        #expect(totalFromA == 80)
    }

    // MARK: - Four Members Complex

    @Test func fourMembers_complex_reduces() {
        // A→B 10, B→C 10, C→D 10, D→A 10 → all cancel (cycle)
        let debts = [
            Debt(fromMemberID: "A", toMemberID: "B", amount: 10, currencyCode: "PEN"),
            Debt(fromMemberID: "B", toMemberID: "C", amount: 10, currencyCode: "PEN"),
            Debt(fromMemberID: "C", toMemberID: "D", amount: 10, currencyCode: "PEN"),
            Debt(fromMemberID: "D", toMemberID: "A", amount: 10, currencyCode: "PEN"),
        ]
        let result = DebtSimplificationService.simplify(debts: debts)
        #expect(result.isEmpty)
    }

    @Test func fourMembers_mixedDebts_simplifies() {
        // A→B 100, C→B 50, D→A 30
        // Net: A=-100+30=-70, B=+150, C=-50, D=-30
        // Simplified: max 3 transfers (fewer than 3 original)
        let debts = [
            Debt(fromMemberID: "A", toMemberID: "B", amount: 100, currencyCode: "PEN"),
            Debt(fromMemberID: "C", toMemberID: "B", amount: 50, currencyCode: "PEN"),
            Debt(fromMemberID: "D", toMemberID: "A", amount: 30, currencyCode: "PEN"),
        ]
        let result = DebtSimplificationService.simplify(debts: debts)

        // Verify net balances are preserved
        let totalToB = result.filter { $0.toMemberID == "B" }.reduce(0.0) { $0 + $1.amount }
        let totalFromB = result.filter { $0.fromMemberID == "B" }.reduce(0.0) { $0 + $1.amount }
        #expect(abs(totalToB - totalFromB - 150) < 0.01)

        // Should have <= 3 transfers
        #expect(result.count <= 3)
    }

    // MARK: - Multi-Currency

    @Test func multiCurrency_separateSimplification() {
        // PEN: A→B 100, B→A 100 → cancels
        // USD: A→B 50 → stays
        let debts = [
            Debt(fromMemberID: "A", toMemberID: "B", amount: 100, currencyCode: "PEN"),
            Debt(fromMemberID: "B", toMemberID: "A", amount: 100, currencyCode: "PEN"),
            Debt(fromMemberID: "A", toMemberID: "B", amount: 50, currencyCode: "USD"),
        ]
        let result = DebtSimplificationService.simplify(debts: debts)

        #expect(result.count == 1)
        #expect(result[0].currencyCode == "USD")
        #expect(result[0].amount == 50)
    }

    @Test func multiCurrency_eachSimplifiedIndependently() {
        // PEN: A→B 80, B→A 30 → A→B 50
        // USD: C→D 25 → C→D 25
        let debts = [
            Debt(fromMemberID: "A", toMemberID: "B", amount: 80, currencyCode: "PEN"),
            Debt(fromMemberID: "B", toMemberID: "A", amount: 30, currencyCode: "PEN"),
            Debt(fromMemberID: "C", toMemberID: "D", amount: 25, currencyCode: "USD"),
        ]
        let result = DebtSimplificationService.simplify(debts: debts)

        let penDebts = result.filter { $0.currencyCode == "PEN" }
        let usdDebts = result.filter { $0.currencyCode == "USD" }

        #expect(penDebts.count == 1)
        #expect(penDebts[0].amount == 50)
        #expect(usdDebts.count == 1)
        #expect(usdDebts[0].amount == 25)
    }

    // MARK: - Rounding

    @Test func rounding_threeWaySplit100_roundsCorrectly() {
        // 100 / 3 = 33.33 each. Two owe one.
        // A pays 100. B owes A 33.33, C owes A 33.33.
        // Net: A=+33.34 (overpaid), B=-33.33, C=-33.33
        let debts = [
            Debt(fromMemberID: "B", toMemberID: "A", amount: 33.33, currencyCode: "PEN"),
            Debt(fromMemberID: "C", toMemberID: "A", amount: 33.33, currencyCode: "PEN"),
        ]
        let result = DebtSimplificationService.simplify(debts: debts)

        #expect(result.count == 2)
        for debt in result {
            #expect(debt.amount == 33.33)
            #expect(debt.toMemberID == "A")
        }
    }

    @Test func rounding_verySmallAmounts_treatedAsZero() {
        // Amounts that cancel to near-zero should produce no debts
        let debts = [
            Debt(fromMemberID: "A", toMemberID: "B", amount: 0.001, currencyCode: "PEN"),
            Debt(fromMemberID: "B", toMemberID: "A", amount: 0.001, currencyCode: "PEN"),
        ]
        let result = DebtSimplificationService.simplify(debts: debts)
        #expect(result.isEmpty)
    }

    // MARK: - Preserved Invariants

    @Test func invariant_totalNetZero() {
        // For any set of debts, the simplified version must preserve net balances.
        let debts = [
            Debt(fromMemberID: "A", toMemberID: "B", amount: 120, currencyCode: "PEN"),
            Debt(fromMemberID: "B", toMemberID: "C", amount: 80, currencyCode: "PEN"),
            Debt(fromMemberID: "C", toMemberID: "A", amount: 45, currencyCode: "PEN"),
            Debt(fromMemberID: "A", toMemberID: "C", amount: 30, currencyCode: "PEN"),
        ]

        let result = DebtSimplificationService.simplify(debts: debts)

        // Calculate net from original
        func netBalances(_ debts: [Debt]) -> [String: Double] {
            var net: [String: Double] = [:]
            for d in debts {
                net[d.fromMemberID, default: 0] -= d.amount
                net[d.toMemberID, default: 0] += d.amount
            }
            return net
        }

        let originalNet = netBalances(debts)
        let simplifiedNet = netBalances(result)

        // Every member's net should be the same (within rounding)
        let allMembers = Set(originalNet.keys).union(simplifiedNet.keys)
        for member in allMembers {
            let original = originalNet[member] ?? 0
            let simplified = simplifiedNet[member] ?? 0
            #expect(abs(original - simplified) < 0.02, "Net mismatch for \(member): \(original) vs \(simplified)")
        }

        // Simplified should have fewer or equal transfers
        #expect(result.count <= debts.count)
    }
}
