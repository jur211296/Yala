//
//  GroupSplitConversionTests.swift
//  YalaTests
//
//  Tests para GroupSplitConversion — conversión inteligente entre tipos de
//  división y cálculo incremental de lo asignado (restante).
//

import Foundation
import Testing

@testable import Yala

struct GroupSplitConversionTests {

    // MARK: - Helpers

    private func participants(_ pairs: [(String, Double)]) -> [(id: String, rawValue: Double)] {
        pairs.map { (id: $0.0, rawValue: $0.1) }
    }
    private func amountsDict(_ r: [(id: String, amount: Double)]) -> [String: Double] {
        Dictionary(r.map { ($0.id, $0.amount) }, uniquingKeysWith: { a, _ in a })
    }
    private func countsDict(_ r: [(id: String, count: Int)]) -> [String: Int] {
        Dictionary(r.map { ($0.id, $0.count) }, uniquingKeysWith: { a, _ in a })
    }

    // MARK: - effectiveAmounts

    @Test func effectiveAmounts_equal() {
        let r = amountsDict(GroupSplitConversion.effectiveAmounts(
            splitType: .equal, total: 100, participants: participants([("A", 0), ("B", 0)])))
        #expect(r["A"] == 50)
        #expect(r["B"] == 50)
    }

    @Test func effectiveAmounts_exact() {
        let r = amountsDict(GroupSplitConversion.effectiveAmounts(
            splitType: .exact, total: 100, participants: participants([("A", 60), ("B", 40)])))
        #expect(r["A"] == 60)
        #expect(r["B"] == 40)
    }

    @Test func effectiveAmounts_percentage() {
        let r = amountsDict(GroupSplitConversion.effectiveAmounts(
            splitType: .percentage, total: 100, participants: participants([("A", 60), ("B", 40)])))
        #expect(r["A"] == 60)
        #expect(r["B"] == 40)
    }

    @Test func effectiveAmounts_shares() {
        let r = amountsDict(GroupSplitConversion.effectiveAmounts(
            splitType: .shares, total: 100, participants: participants([("A", 3), ("B", 2)])))
        #expect(abs((r["A"] ?? 0) - 60) < 0.001)
        #expect(abs((r["B"] ?? 0) - 40) < 0.001)
    }

    @Test func effectiveAmounts_zeroTotalIsAllZero() {
        let r = amountsDict(GroupSplitConversion.effectiveAmounts(
            splitType: .exact, total: 0, participants: participants([("A", 60)])))
        #expect(r["A"] == 0)
    }

    // MARK: - assignedAmount (restante incremental)

    @Test func assignedAmount_percentageIncremental() {
        // 10% de 100 = 10 asignado → restante 90 (lo calcula el VM: total - assigned).
        #expect(GroupSplitConversion.assignedAmount(splitType: .percentage, total: 100, enteredValues: [10]) == 10)
    }

    @Test func assignedAmount_exactSum() {
        #expect(GroupSplitConversion.assignedAmount(splitType: .exact, total: 100, enteredValues: [60, 30]) == 90)
    }

    @Test func assignedAmount_equalAndSharesUseTotal() {
        #expect(GroupSplitConversion.assignedAmount(splitType: .equal, total: 100, enteredValues: []) == 100)
        #expect(GroupSplitConversion.assignedAmount(splitType: .shares, total: 100, enteredValues: [3, 2]) == 100)
    }

    @Test func assignedAmount_overAllocatedExact() {
        // 60 + 60 = 120 > 100 → restante negativo (te pasaste por 20).
        let assigned = GroupSplitConversion.assignedAmount(splitType: .exact, total: 100, enteredValues: [60, 60])
        #expect(assigned == 120)
        #expect(100 - assigned == -20)
    }

    // MARK: - deriveCounts (proporción mínima)

    @Test func deriveCounts_60_40_to_3_2() {
        let r = countsDict(GroupSplitConversion.deriveCounts(amounts: [(id: "A", amount: 60), (id: "B", amount: 40)]))
        #expect(r["A"] == 3)
        #expect(r["B"] == 2)
    }

    @Test func deriveCounts_50_50_to_1_1() {
        let r = countsDict(GroupSplitConversion.deriveCounts(amounts: [(id: "A", amount: 50), (id: "B", amount: 50)]))
        #expect(r["A"] == 1)
        #expect(r["B"] == 1)
    }

    @Test func deriveCounts_75_25_to_3_1() {
        let r = countsDict(GroupSplitConversion.deriveCounts(amounts: [(id: "A", amount: 75), (id: "B", amount: 25)]))
        #expect(r["A"] == 3)
        #expect(r["B"] == 1)
    }

    @Test func deriveCounts_equalThirdsToleratesRounding() {
        // 33.33 / 33.33 / 33.34 → 1/1/1 (no conteos enormes).
        let r = countsDict(GroupSplitConversion.deriveCounts(amounts: [
            (id: "A", amount: 33.33), (id: "B", amount: 33.33), (id: "C", amount: 33.34)]))
        #expect(r["A"] == 1)
        #expect(r["B"] == 1)
        #expect(r["C"] == 1)
    }

    // MARK: - Conversión end-to-end (60/40 % → monto → partes 3/2)

    @Test func endToEnd_percentageToShares() {
        let eff = GroupSplitConversion.effectiveAmounts(
            splitType: .percentage, total: 100, participants: participants([("A", 60), ("B", 40)]))
        let counts = countsDict(GroupSplitConversion.deriveCounts(amounts: eff))
        #expect(counts["A"] == 3)
        #expect(counts["B"] == 2)
    }
}
