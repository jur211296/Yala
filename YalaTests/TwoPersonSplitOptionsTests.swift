//
//  TwoPersonSplitOptionsTests.swift
//  YalaTests
//
//  Tests para TwoPersonSplitOptions — las 4 opciones rápidas de split en grupos de 2:
//  el estado que escribe cada opción, el match inverso y el saldo resultante.
//

import Foundation
import Testing

@testable import Yala

struct TwoPersonSplitOptionsTests {

    private let me = "me"
    private let other = "other"

    // MARK: - resolution

    @Test func resolution_iPaidEqual() {
        let r = TwoPersonSplitOptions.resolution(for: .iPaidEqual, currentMemberID: me, otherMemberID: other)
        #expect(r.paidBy == me)
        #expect(r.participants == [me, other])
        #expect(r.splitType == .equal)
    }

    @Test func resolution_iPaidOwedFull_onlyOtherParticipates() {
        let r = TwoPersonSplitOptions.resolution(for: .iPaidOwedFull, currentMemberID: me, otherMemberID: other)
        #expect(r.paidBy == me)
        #expect(r.participants == [other])   // pagador (yo) fuera: la otra persona debe el total
        #expect(r.splitType == .equal)
    }

    @Test func resolution_theyPaidEqual() {
        let r = TwoPersonSplitOptions.resolution(for: .theyPaidEqual, currentMemberID: me, otherMemberID: other)
        #expect(r.paidBy == other)
        #expect(r.participants == [me, other])
        #expect(r.splitType == .equal)
    }

    @Test func resolution_theyPaidOwedFull_onlyMeParticipates() {
        let r = TwoPersonSplitOptions.resolution(for: .theyPaidOwedFull, currentMemberID: me, otherMemberID: other)
        #expect(r.paidBy == other)
        #expect(r.participants == [me])   // solo yo participo: le debo el total
        #expect(r.splitType == .equal)
    }

    // MARK: - detect (los 4 patrones)

    @Test func detect_iPaidEqual() {
        let c = TwoPersonSplitOptions.detect(
            paidByMemberID: me, splitType: .equal, selectedMemberIDs: [me, other],
            currentMemberID: me, otherMemberID: other)
        #expect(c == .iPaidEqual)
    }

    @Test func detect_iPaidOwedFull() {
        let c = TwoPersonSplitOptions.detect(
            paidByMemberID: me, splitType: .equal, selectedMemberIDs: [other],
            currentMemberID: me, otherMemberID: other)
        #expect(c == .iPaidOwedFull)
    }

    @Test func detect_theyPaidEqual() {
        let c = TwoPersonSplitOptions.detect(
            paidByMemberID: other, splitType: .equal, selectedMemberIDs: [me, other],
            currentMemberID: me, otherMemberID: other)
        #expect(c == .theyPaidEqual)
    }

    @Test func detect_theyPaidOwedFull() {
        let c = TwoPersonSplitOptions.detect(
            paidByMemberID: other, splitType: .equal, selectedMemberIDs: [me],
            currentMemberID: me, otherMemberID: other)
        #expect(c == .theyPaidOwedFull)
    }

    // MARK: - detect (personalizado → nil)

    @Test func detect_nilForNonEqualSplitType() {
        for type in [SplitType.exact, .percentage, .shares] {
            let c = TwoPersonSplitOptions.detect(
                paidByMemberID: me, splitType: type, selectedMemberIDs: [me, other],
                currentMemberID: me, otherMemberID: other)
            #expect(c == nil)
        }
    }

    @Test func detect_nilForEmptyParticipants() {
        let c = TwoPersonSplitOptions.detect(
            paidByMemberID: me, splitType: .equal, selectedMemberIDs: [],
            currentMemberID: me, otherMemberID: other)
        #expect(c == nil)
    }

    @Test func detect_ignoresForeignMemberIDs() {
        // Un id ajeno (de otro grupo) no debe romper el match: se intersecta con los 2 miembros.
        let c = TwoPersonSplitOptions.detect(
            paidByMemberID: me, splitType: .equal, selectedMemberIDs: [me, other, "ghost"],
            currentMemberID: me, otherMemberID: other)
        #expect(c == .iPaidEqual)
    }

    // MARK: - debt

    @Test func debt_amountsAndDirection() {
        let iEq = TwoPersonSplitOptions.debt(for: .iPaidEqual, total: 50)
        #expect(iEq.direction == .theyOweMe)
        #expect(iEq.amount == 25)

        let iFull = TwoPersonSplitOptions.debt(for: .iPaidOwedFull, total: 50)
        #expect(iFull.direction == .theyOweMe)
        #expect(iFull.amount == 50)

        let theyEq = TwoPersonSplitOptions.debt(for: .theyPaidEqual, total: 50)
        #expect(theyEq.direction == .iOwe)
        #expect(theyEq.amount == 25)

        let theyFull = TwoPersonSplitOptions.debt(for: .theyPaidOwedFull, total: 50)
        #expect(theyFull.direction == .iOwe)
        #expect(theyFull.amount == 50)
    }

    // MARK: - round-trip

    @Test func roundTrip_detectOfResolutionIsIdentity() {
        for choice in TwoPersonSplitOptions.Choice.allCases {
            let r = TwoPersonSplitOptions.resolution(for: choice, currentMemberID: me, otherMemberID: other)
            let detected = TwoPersonSplitOptions.detect(
                paidByMemberID: r.paidBy, splitType: r.splitType, selectedMemberIDs: r.participants,
                currentMemberID: me, otherMemberID: other)
            #expect(detected == choice)
        }
    }
}
