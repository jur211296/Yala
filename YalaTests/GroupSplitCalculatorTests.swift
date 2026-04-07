//
//  GroupSplitCalculatorTests.swift
//  YalaTests
//
//  Tests para GroupSplitCalculator — split por participante para gastos de grupo.
//

import Foundation
import Testing

@testable import Yala

struct GroupSplitCalculatorTests {

    // MARK: - Helpers

    private func participants(_ ids: [String], values: [Double] = []) -> [GroupSplitCalculator.Participant] {
        ids.enumerated().map { i, id in
            GroupSplitCalculator.Participant(
                memberID: id,
                value: i < values.count ? values[i] : 0
            )
        }
    }

    private func shares(_ result: [(memberID: String, amount: Double)]?) -> [String: Double] {
        guard let result else { return [:] }
        return Dictionary(result.map { ($0.memberID, $0.amount) }, uniquingKeysWith: { a, _ in a })
    }

    // MARK: - Equal Split

    @Test func equalTwoParticipants() {
        let result = GroupSplitCalculator.calculate(
            total: 100,
            splitType: .equal,
            participants: participants(["A", "B"])
        )
        let s = shares(result)
        #expect(s["A"] == 50.0)
        #expect(s["B"] == 50.0)
    }

    @Test func equalThreeParticipantsRounding() {
        let result = GroupSplitCalculator.calculate(
            total: 100,
            splitType: .equal,
            participants: participants(["A", "B", "C"])
        )
        guard let result else {
            Issue.record("Expected non-nil result")
            return
        }
        let sum = result.reduce(0.0) { $0 + $1.amount }
        #expect(abs(sum - 100) < 0.01)
        // One participant gets the extra cent
        let amounts = result.map(\.amount).sorted()
        #expect(amounts[0] == 33.33)
        #expect(amounts[1] == 33.33)
        #expect(amounts[2] == 33.34)
    }

    @Test func equalFourParticipants() {
        let result = GroupSplitCalculator.calculate(
            total: 100,
            splitType: .equal,
            participants: participants(["A", "B", "C", "D"])
        )
        let s = shares(result)
        #expect(s["A"] == 25.0)
        #expect(s["B"] == 25.0)
        #expect(s["C"] == 25.0)
        #expect(s["D"] == 25.0)
    }

    @Test func equalSingleParticipant() {
        let result = GroupSplitCalculator.calculate(
            total: 75.50,
            splitType: .equal,
            participants: participants(["A"])
        )
        let s = shares(result)
        #expect(s["A"] == 75.50)
    }

    @Test func equalOddAmountFiveParticipants() {
        let result = GroupSplitCalculator.calculate(
            total: 10.01,
            splitType: .equal,
            participants: participants(["A", "B", "C", "D", "E"])
        )
        guard let result else {
            Issue.record("Expected non-nil result")
            return
        }
        let sum = result.reduce(0.0) { $0 + $1.amount }
        #expect(abs(sum - 10.01) < 0.01)
    }

    // MARK: - Exact Split

    @Test func exactValidSum() {
        let result = GroupSplitCalculator.calculate(
            total: 100,
            splitType: .exact,
            participants: participants(["A", "B", "C"], values: [50, 30, 20])
        )
        let s = shares(result)
        #expect(s["A"] == 50)
        #expect(s["B"] == 30)
        #expect(s["C"] == 20)
    }

    @Test func exactSumExceedsTotal() {
        let result = GroupSplitCalculator.calculate(
            total: 100,
            splitType: .exact,
            participants: participants(["A", "B"], values: [60, 50])
        )
        #expect(result == nil)
    }

    @Test func exactSumUnderTotal() {
        let result = GroupSplitCalculator.calculate(
            total: 100,
            splitType: .exact,
            participants: participants(["A", "B"], values: [30, 20])
        )
        #expect(result == nil)
    }

    @Test func exactWithZeroAmount() {
        let result = GroupSplitCalculator.calculate(
            total: 100,
            splitType: .exact,
            participants: participants(["A", "B"], values: [100, 0])
        )
        let s = shares(result)
        #expect(s["A"] == 100)
        #expect(s["B"] == 0)
    }

    @Test func exactNegativeValueReturnsNil() {
        let result = GroupSplitCalculator.calculate(
            total: 100,
            splitType: .exact,
            participants: participants(["A", "B"], values: [120, -20])
        )
        #expect(result == nil)
    }

    // MARK: - Percentage Split

    @Test func percentageFiftyFifty() {
        let result = GroupSplitCalculator.calculate(
            total: 200,
            splitType: .percentage,
            participants: participants(["A", "B"], values: [50, 50])
        )
        let s = shares(result)
        #expect(s["A"] == 100)
        #expect(s["B"] == 100)
    }

    @Test func percentageUnevenSplit() {
        let result = GroupSplitCalculator.calculate(
            total: 100,
            splitType: .percentage,
            participants: participants(["A", "B", "C"], values: [60, 20, 20])
        )
        let s = shares(result)
        #expect(s["A"] == 60)
        #expect(s["B"] == 20)
        #expect(s["C"] == 20)
    }

    @Test func percentageNotSumTo100ReturnsNil() {
        let result = GroupSplitCalculator.calculate(
            total: 100,
            splitType: .percentage,
            participants: participants(["A", "B"], values: [50, 40])
        )
        #expect(result == nil)
    }

    @Test func percentageRoundingAdjustment() {
        // 33.33% + 33.33% + 33.34% = 100%
        let result = GroupSplitCalculator.calculate(
            total: 100,
            splitType: .percentage,
            participants: participants(["A", "B", "C"], values: [33.33, 33.33, 33.34])
        )
        guard let result else {
            Issue.record("Expected non-nil result")
            return
        }
        let sum = result.reduce(0.0) { $0 + $1.amount }
        #expect(abs(sum - 100) < 0.01)
    }

    // MARK: - Shares Split

    @Test func sharesEqualRatio() {
        let result = GroupSplitCalculator.calculate(
            total: 90,
            splitType: .shares,
            participants: participants(["A", "B", "C"], values: [1, 1, 1])
        )
        let s = shares(result)
        #expect(s["A"] == 30)
        #expect(s["B"] == 30)
        #expect(s["C"] == 30)
    }

    @Test func sharesUnevenRatio() {
        let result = GroupSplitCalculator.calculate(
            total: 100,
            splitType: .shares,
            participants: participants(["A", "B", "C"], values: [2, 3, 5])
        )
        let s = shares(result)
        #expect(s["A"] == 20)
        #expect(s["B"] == 30)
        #expect(s["C"] == 50)
    }

    @Test func sharesSingleParticipant() {
        let result = GroupSplitCalculator.calculate(
            total: 100,
            splitType: .shares,
            participants: participants(["A"], values: [3])
        )
        let s = shares(result)
        #expect(s["A"] == 100)
    }

    @Test func sharesZeroShareReturnsNil() {
        let result = GroupSplitCalculator.calculate(
            total: 100,
            splitType: .shares,
            participants: participants(["A", "B"], values: [3, 0])
        )
        #expect(result == nil)
    }

    // MARK: - Edge Cases

    @Test func emptyParticipantsReturnsNil() {
        let result = GroupSplitCalculator.calculate(
            total: 100,
            splitType: .equal,
            participants: []
        )
        #expect(result == nil)
    }

    @Test func zeroTotalReturnsNil() {
        let result = GroupSplitCalculator.calculate(
            total: 0,
            splitType: .equal,
            participants: participants(["A", "B"])
        )
        #expect(result == nil)
    }

    @Test func negativeTotalReturnsNil() {
        let result = GroupSplitCalculator.calculate(
            total: -50,
            splitType: .equal,
            participants: participants(["A", "B"])
        )
        #expect(result == nil)
    }

    @Test func sumAlwaysMatchesTotal() {
        // Verify across all split types that distributed amounts sum to total
        let total = 99.99
        let members = participants(["A", "B", "C"])

        // Equal
        if let result = GroupSplitCalculator.calculate(total: total, splitType: .equal, participants: members) {
            let sum = result.reduce(0.0) { $0 + $1.amount }
            #expect(abs(sum - total) < 0.02)
        }

        // Percentage
        let pctMembers = participants(["A", "B", "C"], values: [40, 35, 25])
        if let result = GroupSplitCalculator.calculate(total: total, splitType: .percentage, participants: pctMembers) {
            let sum = result.reduce(0.0) { $0 + $1.amount }
            #expect(abs(sum - total) < 0.02)
        }

        // Shares
        let shareMembers = participants(["A", "B", "C"], values: [2, 3, 5])
        if let result = GroupSplitCalculator.calculate(total: total, splitType: .shares, participants: shareMembers) {
            let sum = result.reduce(0.0) { $0 + $1.amount }
            #expect(abs(sum - total) < 0.02)
        }
    }
}
