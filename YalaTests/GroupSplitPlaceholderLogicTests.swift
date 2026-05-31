//
//  GroupSplitPlaceholderLogicTests.swift
//  YalaTests
//
//  Tests pure-logic para GroupSplitPlaceholderLogic — placeholders dinámicos
//  por miembro en GroupSplitSelectorView. Sin context (R8-safe).
//

import Foundation
import Testing

@testable import Yala

struct GroupSplitPlaceholderLogicTests {

    // MARK: - .equal

    @Test func equalAlwaysReturnsEmpty() {
        let p = GroupSplitPlaceholderLogic.placeholder(
            forMemberID: "A",
            orderedMemberIDs: ["A", "B"],
            currentInputs: ["A": "", "B": "50"],
            splitType: .equal,
            total: 100
        )
        #expect(p == "")
    }

    // MARK: - .shares

    @Test func sharesAlwaysReturnsOne_empty() {
        let p = GroupSplitPlaceholderLogic.placeholder(
            forMemberID: "A",
            orderedMemberIDs: ["A", "B"],
            currentInputs: [:],
            splitType: .shares,
            total: 100
        )
        #expect(p == "1")
    }

    @Test func sharesAlwaysReturnsOne_partiallyFilled() {
        let p = GroupSplitPlaceholderLogic.placeholder(
            forMemberID: "B",
            orderedMemberIDs: ["A", "B", "C"],
            currentInputs: ["A": "3"],
            splitType: .shares,
            total: 100
        )
        #expect(p == "1")
    }

    // MARK: - .exact

    @Test func exactNoInputs_returnsZero() {
        let p = GroupSplitPlaceholderLogic.placeholder(
            forMemberID: "A",
            orderedMemberIDs: ["A", "B"],
            currentInputs: [:],
            splitType: .exact,
            total: 100
        )
        #expect(p == "0")
    }

    @Test func exactFirstEmptyShowsRemaining() {
        // A=30 lleno, B vacío. B placeholder = 70.00
        let p = GroupSplitPlaceholderLogic.placeholder(
            forMemberID: "B",
            orderedMemberIDs: ["A", "B"],
            currentInputs: ["A": "30"],
            splitType: .exact,
            total: 100
        )
        #expect(p == "70.00")
    }

    @Test func exactSecondEmptyReturnsZero() {
        // A=30 lleno, B vacío (primer empty), C vacío (no primero).
        // B → "70.00", C → "0"
        let pB = GroupSplitPlaceholderLogic.placeholder(
            forMemberID: "B",
            orderedMemberIDs: ["A", "B", "C"],
            currentInputs: ["A": "30"],
            splitType: .exact,
            total: 100
        )
        let pC = GroupSplitPlaceholderLogic.placeholder(
            forMemberID: "C",
            orderedMemberIDs: ["A", "B", "C"],
            currentInputs: ["A": "30"],
            splitType: .exact,
            total: 100
        )
        #expect(pB == "70.00")
        #expect(pC == "0")
    }

    @Test func exactTwoFilledOneEmpty() {
        // A=30, B=50 → C empty → placeholder = 20.00
        let p = GroupSplitPlaceholderLogic.placeholder(
            forMemberID: "C",
            orderedMemberIDs: ["A", "B", "C"],
            currentInputs: ["A": "30", "B": "50"],
            splitType: .exact,
            total: 100
        )
        #expect(p == "20.00")
    }

    @Test func exactOverflow_clampsToZero() {
        // A=60, B=50 → suma 110 > 100. C empty → max(0, 100-110)=0 → "0"
        let p = GroupSplitPlaceholderLogic.placeholder(
            forMemberID: "C",
            orderedMemberIDs: ["A", "B", "C"],
            currentInputs: ["A": "60", "B": "50"],
            splitType: .exact,
            total: 100
        )
        #expect(p == "0")
    }

    @Test func exactExactlyFull_returnsZero() {
        // A=60, B=40 → suma=100. C empty → remaining=0 → "0"
        let p = GroupSplitPlaceholderLogic.placeholder(
            forMemberID: "C",
            orderedMemberIDs: ["A", "B", "C"],
            currentInputs: ["A": "60", "B": "40"],
            splitType: .exact,
            total: 100
        )
        #expect(p == "0")
    }

    @Test func exactTotalZero_returnsZero() {
        let p = GroupSplitPlaceholderLogic.placeholder(
            forMemberID: "A",
            orderedMemberIDs: ["A", "B"],
            currentInputs: [:],
            splitType: .exact,
            total: 0
        )
        #expect(p == "0")
    }

    @Test func exactWithDecimalValues() {
        // A=30.25 lleno, B vacío. B → 100 - 30.25 = 69.75
        let p = GroupSplitPlaceholderLogic.placeholder(
            forMemberID: "B",
            orderedMemberIDs: ["A", "B"],
            currentInputs: ["A": "30.25"],
            splitType: .exact,
            total: 100
        )
        #expect(p == "69.75")
    }

    // MARK: - .percentage

    @Test func percentageNoInputs_returnsZero() {
        let p = GroupSplitPlaceholderLogic.placeholder(
            forMemberID: "A",
            orderedMemberIDs: ["A", "B"],
            currentInputs: [:],
            splitType: .percentage,
            total: 100
        )
        #expect(p == "0")
    }

    @Test func percentageFirstEmptyShowsRemaining() {
        // A=60 lleno, B vacío. B → 100 - 60 = 40
        let p = GroupSplitPlaceholderLogic.placeholder(
            forMemberID: "B",
            orderedMemberIDs: ["A", "B"],
            currentInputs: ["A": "60"],
            splitType: .percentage,
            total: 100
        )
        #expect(p == "40")
    }

    @Test func percentageDecimalRemaining() {
        // A=33.3 lleno, B vacío. B → 100 - 33.3 = 66.7
        let p = GroupSplitPlaceholderLogic.placeholder(
            forMemberID: "B",
            orderedMemberIDs: ["A", "B"],
            currentInputs: ["A": "33.3"],
            splitType: .percentage,
            total: 100
        )
        #expect(p == "66.7")
    }

    @Test func percentageOverflow_clampsToZero() {
        // A=60, B=50 → 110 > 100. C empty → "0"
        let p = GroupSplitPlaceholderLogic.placeholder(
            forMemberID: "C",
            orderedMemberIDs: ["A", "B", "C"],
            currentInputs: ["A": "60", "B": "50"],
            splitType: .percentage,
            total: 100
        )
        #expect(p == "0")
    }

    @Test func percentageExactlyFull_returnsZero() {
        // A=60, B=40 → suma=100. C empty → remaining=0 → "0"
        let p = GroupSplitPlaceholderLogic.placeholder(
            forMemberID: "C",
            orderedMemberIDs: ["A", "B", "C"],
            currentInputs: ["A": "60", "B": "40"],
            splitType: .percentage,
            total: 100
        )
        #expect(p == "0")
    }

    @Test func percentageThreeFilledOneEmpty() {
        // A=30, B=30, D=20 → C empty → 100-(30+30+20)=20
        let p = GroupSplitPlaceholderLogic.placeholder(
            forMemberID: "C",
            orderedMemberIDs: ["A", "B", "C", "D"],
            currentInputs: ["A": "30", "B": "30", "D": "20"],
            splitType: .percentage,
            total: 100
        )
        #expect(p == "20")
    }

    @Test func percentageSecondEmptyReturnsZero() {
        // A=30, B vacío (primer empty), C vacío. B → "70", C → "0"
        let pB = GroupSplitPlaceholderLogic.placeholder(
            forMemberID: "B",
            orderedMemberIDs: ["A", "B", "C"],
            currentInputs: ["A": "30"],
            splitType: .percentage,
            total: 100
        )
        let pC = GroupSplitPlaceholderLogic.placeholder(
            forMemberID: "C",
            orderedMemberIDs: ["A", "B", "C"],
            currentInputs: ["A": "30"],
            splitType: .percentage,
            total: 100
        )
        #expect(pB == "70")
        #expect(pC == "0")
    }

    // MARK: - Orden estable

    @Test func firstEmptyIsRespectedByOrder() {
        // Si A está vacío y B lleno y C vacío, primer empty = A (no C).
        // Pero A es el target → muestra remaining; C es target → "0".
        let pA = GroupSplitPlaceholderLogic.placeholder(
            forMemberID: "A",
            orderedMemberIDs: ["A", "B", "C"],
            currentInputs: ["B": "40"],
            splitType: .percentage,
            total: 100
        )
        let pC = GroupSplitPlaceholderLogic.placeholder(
            forMemberID: "C",
            orderedMemberIDs: ["A", "B", "C"],
            currentInputs: ["B": "40"],
            splitType: .percentage,
            total: 100
        )
        #expect(pA == "60")
        #expect(pC == "0")
    }
}
