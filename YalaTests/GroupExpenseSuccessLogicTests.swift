//
//  GroupExpenseSuccessLogicTests.swift
//  YalaTests
//
//  Tests pure-logic para GroupExpenseSuccessLogic (deuda del usuario tras crear/editar
//  un gasto de grupo). Sin SwiftData/ModelContext — verifica solo la decisión a partir
//  del reparto ya calculado.
//

import Foundation
import Testing

@testable import Yala

struct GroupExpenseSuccessLogicTests {

    private let me = "AAAAAAAA-0000-0000-0000-000000000001"
    private let other = "BBBBBBBB-0000-0000-0000-000000000002"

    // MARK: - Yo pagué

    @Test func iPaid_equalSplit_theyOweMeTheRest() {
        // Total 100, dividido en 2 iguales → mi parte 50, me deben 50.
        let shares = [(memberID: me, amount: 50.0), (memberID: other, amount: 50.0)]
        #expect(GroupExpenseSuccessLogic.debt(
            total: 100, shares: shares, currentUserMemberID: me, paidByMemberID: me) == .theyOweMe(50))
    }

    @Test func iPaid_unequalSplit_theyOweMeTheRest() {
        // Total 100, mi parte 30 (exact/percentage) → me deben 70.
        let shares = [(memberID: me, amount: 30.0), (memberID: other, amount: 70.0)]
        #expect(GroupExpenseSuccessLogic.debt(
            total: 100, shares: shares, currentUserMemberID: me, paidByMemberID: me) == .theyOweMe(70))
    }

    @Test func iPaid_soleParticipant_settled() {
        // Yo pagué y era el único participante → nadie me debe.
        let shares = [(memberID: me, amount: 100.0)]
        #expect(GroupExpenseSuccessLogic.debt(
            total: 100, shares: shares, currentUserMemberID: me, paidByMemberID: me) == .settled)
    }

    @Test func iPaid_roundingRemainder_settled() {
        // Resto por redondeo por debajo del epsilon → settled (no "te deben 0.00").
        let shares = [(memberID: me, amount: 99.998)]
        #expect(GroupExpenseSuccessLogic.debt(
            total: 100, shares: shares, currentUserMemberID: me, paidByMemberID: me) == .settled)
    }

    // MARK: - Pagó otro

    @Test func otherPaid_iOweMyShare() {
        // Otro pagó; mi parte 50 → le debo 50.
        let shares = [(memberID: me, amount: 50.0), (memberID: other, amount: 50.0)]
        #expect(GroupExpenseSuccessLogic.debt(
            total: 100, shares: shares, currentUserMemberID: me, paidByMemberID: other) == .iOwe(50))
    }

    @Test func otherPaid_iDontParticipate_settled() {
        // Otro pagó y yo no participo (sin parte) → no debo nada.
        let shares = [(memberID: other, amount: 100.0)]
        #expect(GroupExpenseSuccessLogic.debt(
            total: 100, shares: shares, currentUserMemberID: me, paidByMemberID: other) == .settled)
    }

    // MARK: - Edge

    @Test func unknownIdentity_settled() {
        // No sé quién soy en el grupo → conservador, sin deuda.
        let shares = [(memberID: me, amount: 50.0), (memberID: other, amount: 50.0)]
        #expect(GroupExpenseSuccessLogic.debt(
            total: 100, shares: shares, currentUserMemberID: nil, paidByMemberID: other) == .settled)
    }

    @Test func emptyShares_settled() {
        #expect(GroupExpenseSuccessLogic.debt(
            total: 0, shares: [], currentUserMemberID: me, paidByMemberID: me) == .settled)
    }
}
