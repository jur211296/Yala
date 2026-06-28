//
//  GroupHeaderBalanceTests.swift
//  YalaTests
//
//  Pure-logic tests for GroupBalanceService.computeGroupHeaderBalance.
//  Builds [Debt] directly — no ModelContext (avoids CloudKit race crashes, regla R8).
//

import Foundation
import Testing

@testable import Yala

struct GroupHeaderBalanceTests {

    private let me = "me"

    private func debt(from: String, to: String, _ amount: Double, _ currency: String = "USD") -> Debt {
        Debt(fromMemberID: from, toMemberID: to, amount: amount, currencyCode: currency)
    }

    // MARK: - theyOweMe

    @Test func theyOweMe_singleCurrency() {
        let result = GroupBalanceService.computeGroupHeaderBalance(
            debts: [debt(from: "ana", to: me, 100)],
            currentMemberID: me
        )
        #expect(result.state == .theyOweMe)
        #expect(result.owedToMe == ["USD": 100])
        #expect(result.iOwe.isEmpty)
    }

    @Test func theyOweMe_multiCurrency() {
        let result = GroupBalanceService.computeGroupHeaderBalance(
            debts: [debt(from: "ana", to: me, 246.23, "USD"),
                    debt(from: "ana", to: me, 112.91, "PEN")],
            currentMemberID: me
        )
        #expect(result.state == .theyOweMe)
        #expect(result.owedToMe == ["USD": 246.23, "PEN": 112.91])
        #expect(result.iOwe.isEmpty)
    }

    /// Netea entre contrapartes en la misma moneda: Ana me debe 50, yo debo a Beto 30 → me deben 20.
    @Test func theyOweMe_netsAcrossCounterparties() {
        let result = GroupBalanceService.computeGroupHeaderBalance(
            debts: [debt(from: "ana", to: me, 50), debt(from: me, to: "beto", 30)],
            currentMemberID: me
        )
        #expect(result.state == .theyOweMe)
        #expect(result.owedToMe == ["USD": 20])
        #expect(result.iOwe.isEmpty)
    }

    // MARK: - iOwe

    @Test func iOwe_singleCurrency() {
        let result = GroupBalanceService.computeGroupHeaderBalance(
            debts: [debt(from: me, to: "ana", 75)],
            currentMemberID: me
        )
        #expect(result.state == .iOwe)
        #expect(result.iOwe == ["USD": 75])
        #expect(result.owedToMe.isEmpty)
    }

    // MARK: - mixed

    @Test func mixed_oweOneCurrencyOwedAnother() {
        let result = GroupBalanceService.computeGroupHeaderBalance(
            debts: [debt(from: "ana", to: me, 50, "USD"),
                    debt(from: me, to: "beto", 30, "PEN")],
            currentMemberID: me
        )
        #expect(result.state == .mixed)
        #expect(result.owedToMe == ["USD": 50])
        #expect(result.iOwe == ["PEN": 30])
    }

    // MARK: - settled

    @Test func settled_empty() {
        let result = GroupBalanceService.computeGroupHeaderBalance(debts: [], currentMemberID: me)
        #expect(result.state == .settled)
        #expect(result.owedToMe.isEmpty)
        #expect(result.iOwe.isEmpty)
    }

    /// Cancelación exacta en la misma moneda (to==me 50 + from==me 50) → neto 0 → settled.
    @Test func settled_cancellation() {
        let result = GroupBalanceService.computeGroupHeaderBalance(
            debts: [debt(from: "ana", to: me, 50), debt(from: me, to: "beto", 50)],
            currentMemberID: me
        )
        #expect(result.state == .settled)
        #expect(result.owedToMe.isEmpty)
        #expect(result.iOwe.isEmpty)
    }

    /// Neto por debajo del epsilon (0.01) se trata como saldado.
    @Test func settled_belowEpsilon() {
        let result = GroupBalanceService.computeGroupHeaderBalance(
            debts: [debt(from: "ana", to: me, 0.005)],
            currentMemberID: me
        )
        #expect(result.state == .settled)
        #expect(result.owedToMe.isEmpty)
    }

    // MARK: - edge cases

    /// Multi-moneda parcial: USD con saldo + PEN que netea a 0 → theyOweMe sin PEN.
    @Test func partial_oneCurrencyNetsToZero() {
        let result = GroupBalanceService.computeGroupHeaderBalance(
            debts: [debt(from: "ana", to: me, 100, "USD"),
                    debt(from: "ana", to: me, 30, "PEN"),
                    debt(from: me, to: "ana", 30, "PEN")],
            currentMemberID: me
        )
        #expect(result.state == .theyOweMe)
        #expect(result.owedToMe == ["USD": 100])
        #expect(result.iOwe.isEmpty)
        #expect(result.owedToMe["PEN"] == nil)
    }

    /// Deudas que no involucran al usuario actual se ignoran por completo.
    @Test func ignoresDebtsNotInvolvingCurrentUser() {
        let result = GroupBalanceService.computeGroupHeaderBalance(
            debts: [debt(from: "ana", to: "beto", 100)],
            currentMemberID: me
        )
        #expect(result.state == .settled)
        #expect(result.owedToMe.isEmpty)
        #expect(result.iOwe.isEmpty)
    }
}
