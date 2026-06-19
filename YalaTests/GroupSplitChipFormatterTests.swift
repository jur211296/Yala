//
//  GroupSplitChipFormatterTests.swift
//  YalaTests
//
//  Tests pure-logic para GroupSplitChipFormatter — formato del chip-detalle
//  bajo el monto en GroupExpenseFormView. Sin context (R8-safe).
//

import Foundation
import Testing

@testable import Yala

struct GroupSplitChipFormatterTests {

    // MARK: - Helpers

    /// Closure de formato de monto determinístico para tests.
    /// Usa "$ 50.00" simple sin depender de locale ni AppPreferences.
    private static let formatAmount: (Double) -> String = { value in
        String(format: "$ %.2f", value)
    }

    private static let sharesWord = "partes"

    /// Convenience builder.
    private func makeInput(
        total: Double = 100,
        splitType: SplitType = .equal,
        calculatedShares: [(memberID: String, amount: Double)]? = nil,
        participantValues: [String: Double] = [:],
        currentUserMemberID: String? = "me",
        paidByMemberID: String = "me",
        selectedMemberIDs: Set<String> = ["me", "bob"]
    ) -> GroupSplitChipFormatter.Input {
        GroupSplitChipFormatter.Input(
            total: total,
            splitType: splitType,
            calculatedShares: calculatedShares,
            participantValues: participantValues,
            currentUserMemberID: currentUserMemberID,
            paidByMemberID: paidByMemberID,
            selectedMemberIDs: selectedMemberIDs,
            formatAmount: Self.formatAmount,
            localizedSharesWord: Self.sharesWord
        )
    }

    // MARK: - Mode .fallbackTypeName

    @Test func totalZeroFallsBackToTypeName_equal() {
        let out = GroupSplitChipFormatter.format(input: makeInput(total: 0, splitType: .equal))
        #expect(out.mode == .fallbackTypeName)
    }

    @Test func totalZeroFallsBackToTypeName_percentage() {
        let out = GroupSplitChipFormatter.format(input: makeInput(total: 0, splitType: .percentage))
        #expect(out.mode == .fallbackTypeName)
    }

    @Test func calculatedSharesNilWithoutUserShareFallsBack() {
        // User en split, calculatedShares no nil, pero NO contiene al user → fallback.
        let out = GroupSplitChipFormatter.format(input: makeInput(
            splitType: .equal,
            calculatedShares: [(memberID: "bob", amount: 100)],
            selectedMemberIDs: ["me", "bob"]
        ))
        #expect(out.mode == .fallbackTypeName)
    }

    // MARK: - Mode .warningUnbalanced

    @Test func userInSplitButCalculatedSharesNilWarns_exact() {
        let out = GroupSplitChipFormatter.format(input: makeInput(
            splitType: .exact,
            calculatedShares: nil,
            selectedMemberIDs: ["me", "bob"]
        ))
        #expect(out.mode == .warningUnbalanced)
    }

    @Test func userInSplitButCalculatedSharesNilWarns_percentage() {
        let out = GroupSplitChipFormatter.format(input: makeInput(
            splitType: .percentage,
            calculatedShares: nil
        ))
        #expect(out.mode == .warningUnbalanced)
    }

    // MARK: - Mode .notIncluded

    @Test func currentUserNotInSplitAndNotPayer_notIncluded() {
        let out = GroupSplitChipFormatter.format(input: makeInput(
            calculatedShares: [(memberID: "bob", amount: 50), (memberID: "alice", amount: 50)],
            currentUserMemberID: "me",
            paidByMemberID: "bob",  // payer = otro, not current user
            selectedMemberIDs: ["bob", "alice"]
        ))
        #expect(out.mode == .notIncluded(total: "$ 100.00"))
    }

    @Test func currentUserMemberIDNilTreatsAsNotIncluded() {
        let out = GroupSplitChipFormatter.format(input: makeInput(
            calculatedShares: [(memberID: "bob", amount: 100)],
            currentUserMemberID: nil,
            paidByMemberID: "bob",
            selectedMemberIDs: ["bob"]
        ))
        #expect(out.mode == .notIncluded(total: "$ 100.00"))
    }

    // MARK: - Mode .youPaidAll

    @Test func currentUserIsPayerButNotInSplit_youPaidAll() {
        let out = GroupSplitChipFormatter.format(input: makeInput(
            calculatedShares: [(memberID: "bob", amount: 50), (memberID: "alice", amount: 50)],
            currentUserMemberID: "me",
            paidByMemberID: "me",  // current user paga
            selectedMemberIDs: ["bob", "alice"]  // pero no participa
        ))
        #expect(out.mode == .youPaidAll(total: "$ 100.00"))
    }

    // MARK: - Mode .youOnly

    @Test func onlyCurrentUserInSplit_youOnly() {
        let out = GroupSplitChipFormatter.format(input: makeInput(
            calculatedShares: [(memberID: "me", amount: 100)],
            selectedMemberIDs: ["me"]
        ))
        #expect(out.mode == .youOnly(yourAmount: "$ 100.00"))
    }

    // MARK: - Mode .youAndRest (2 miembros)

    @Test func equalTwoMembers_youAndRestNoSuffix() {
        let out = GroupSplitChipFormatter.format(input: makeInput(
            splitType: .equal,
            calculatedShares: [(memberID: "me", amount: 50), (memberID: "bob", amount: 50)],
            selectedMemberIDs: ["me", "bob"]
        ))
        guard case .youAndRest(let you, let rest) = out.mode else {
            Issue.record("Expected .youAndRest, got \(out.mode)")
            return
        }
        #expect(you.amountString == "$ 50.00")
        #expect(you.suffix == nil)
        #expect(rest.amountString == "$ 50.00")
        #expect(rest.suffix == nil)
    }

    @Test func exactTwoMembers_youAndRestNoSuffix() {
        let out = GroupSplitChipFormatter.format(input: makeInput(
            splitType: .exact,
            calculatedShares: [(memberID: "me", amount: 30), (memberID: "bob", amount: 70)],
            participantValues: ["me": 30, "bob": 70],
            selectedMemberIDs: ["me", "bob"]
        ))
        guard case .youAndRest(let you, let rest) = out.mode else {
            Issue.record("Expected .youAndRest")
            return
        }
        #expect(you.amountString == "$ 30.00")
        #expect(you.suffix == nil)
        #expect(rest.amountString == "$ 70.00")
        #expect(rest.suffix == nil)
    }

    @Test func percentageTwoMembers_youAndRestWithPercentSuffix() {
        let out = GroupSplitChipFormatter.format(input: makeInput(
            splitType: .percentage,
            calculatedShares: [(memberID: "me", amount: 60), (memberID: "bob", amount: 40)],
            participantValues: ["me": 60, "bob": 40],
            selectedMemberIDs: ["me", "bob"]
        ))
        guard case .youAndRest(let you, let rest) = out.mode else {
            Issue.record("Expected .youAndRest")
            return
        }
        #expect(you.amountString == "$ 60.00")
        #expect(you.suffix == "(60%)")
        #expect(rest.amountString == "$ 40.00")
        #expect(rest.suffix == "(40%)")
    }

    @Test func percentageTwoMembersDecimal_trimsToOneDecimal() {
        let out = GroupSplitChipFormatter.format(input: makeInput(
            total: 100,
            splitType: .percentage,
            calculatedShares: [(memberID: "me", amount: 33.3), (memberID: "bob", amount: 66.7)],
            participantValues: ["me": 33.3, "bob": 66.7]
        ))
        guard case .youAndRest(let you, let rest) = out.mode else {
            Issue.record("Expected .youAndRest")
            return
        }
        #expect(you.suffix == "(33.3%)")
        #expect(rest.suffix == "(66.7%)")
    }

    @Test func sharesTwoMembers_youAndRestWithSharesSuffix() {
        let out = GroupSplitChipFormatter.format(input: makeInput(
            total: 100,
            splitType: .shares,
            calculatedShares: [(memberID: "me", amount: 25), (memberID: "bob", amount: 75)],
            participantValues: ["me": 1, "bob": 3]
        ))
        guard case .youAndRest(let you, let rest) = out.mode else {
            Issue.record("Expected .youAndRest")
            return
        }
        #expect(you.amountString == "$ 25.00")
        #expect(you.suffix == "(1/4 partes)")
        #expect(rest.amountString == "$ 75.00")
        #expect(rest.suffix == "(3/4 partes)")
    }

    // MARK: - Mode .youAndRest (3+ miembros agrupa Resto)

    @Test func equalThreeMembers_restIsAggregate() {
        let out = GroupSplitChipFormatter.format(input: makeInput(
            total: 99,
            splitType: .equal,
            calculatedShares: [
                (memberID: "me", amount: 33),
                (memberID: "bob", amount: 33),
                (memberID: "alice", amount: 33)
            ],
            selectedMemberIDs: ["me", "bob", "alice"]
        ))
        guard case .youAndRest(let you, let rest) = out.mode else {
            Issue.record("Expected .youAndRest")
            return
        }
        #expect(you.amountString == "$ 33.00")
        // Rest = total - you = 99 - 33 = 66
        #expect(rest.amountString == "$ 66.00")
    }

    @Test func percentageThreeMembers_restPctIsComplement() {
        // me=50, bob=30, alice=20 → rest = 50 (30+20), restPct = 50
        let out = GroupSplitChipFormatter.format(input: makeInput(
            total: 100,
            splitType: .percentage,
            calculatedShares: [
                (memberID: "me", amount: 50),
                (memberID: "bob", amount: 30),
                (memberID: "alice", amount: 20)
            ],
            participantValues: ["me": 50, "bob": 30, "alice": 20],
            selectedMemberIDs: ["me", "bob", "alice"]
        ))
        guard case .youAndRest(let you, let rest) = out.mode else {
            Issue.record("Expected .youAndRest")
            return
        }
        #expect(you.suffix == "(50%)")
        #expect(rest.suffix == "(50%)")
    }

    @Test func sharesThreeMembers_restSharesIsComplement() {
        // me=1, bob=2, alice=3 → totalShares=6, restShares=5
        let out = GroupSplitChipFormatter.format(input: makeInput(
            total: 60,
            splitType: .shares,
            calculatedShares: [
                (memberID: "me", amount: 10),
                (memberID: "bob", amount: 20),
                (memberID: "alice", amount: 30)
            ],
            participantValues: ["me": 1, "bob": 2, "alice": 3],
            selectedMemberIDs: ["me", "bob", "alice"]
        ))
        guard case .youAndRest(let you, let rest) = out.mode else {
            Issue.record("Expected .youAndRest")
            return
        }
        #expect(you.amountString == "$ 10.00")
        #expect(you.suffix == "(1/6 partes)")
        #expect(rest.amountString == "$ 50.00")
        #expect(rest.suffix == "(5/6 partes)")
    }

    @Test func exactThreeMembers_restIsAggregateNoSuffix() {
        let out = GroupSplitChipFormatter.format(input: makeInput(
            total: 100,
            splitType: .exact,
            calculatedShares: [
                (memberID: "me", amount: 20),
                (memberID: "bob", amount: 30),
                (memberID: "alice", amount: 50)
            ],
            participantValues: ["me": 20, "bob": 30, "alice": 50],
            selectedMemberIDs: ["me", "bob", "alice"]
        ))
        guard case .youAndRest(let you, let rest) = out.mode else {
            Issue.record("Expected .youAndRest")
            return
        }
        #expect(you.amountString == "$ 20.00")
        #expect(you.suffix == nil)
        #expect(rest.amountString == "$ 80.00")
        #expect(rest.suffix == nil)
    }

    // MARK: - Edge cases

    @Test func paidByEmpty_treatedAsNotPayer() {
        let out = GroupSplitChipFormatter.format(input: makeInput(
            calculatedShares: [(memberID: "bob", amount: 100)],
            currentUserMemberID: "me",
            paidByMemberID: "",  // empty
            selectedMemberIDs: ["bob"]  // me NOT in split
        ))
        #expect(out.mode == .notIncluded(total: "$ 100.00"))
    }

    @Test func percentageWithZeroForUser_suffixIsZeroPercent() {
        // Edge: user incluido con 0%
        let out = GroupSplitChipFormatter.format(input: makeInput(
            total: 100,
            splitType: .percentage,
            calculatedShares: [
                (memberID: "me", amount: 0),
                (memberID: "bob", amount: 100)
            ],
            participantValues: ["me": 0, "bob": 100],
            selectedMemberIDs: ["me", "bob"]
        ))
        guard case .youAndRest(let you, let rest) = out.mode else {
            Issue.record("Expected .youAndRest")
            return
        }
        #expect(you.suffix == "(0%)")
        #expect(rest.suffix == "(100%)")
    }
}
