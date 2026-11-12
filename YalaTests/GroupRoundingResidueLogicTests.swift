//
//  GroupRoundingResidueLogicTests.swift
//  YalaTests
//
//  L19-10 · el residuo de redondeo no es una deuda; una deuda de céntimos de verdad, sí.
//
//  Sin `ModelContext`: los `@Model` se construyen sueltos y `GroupBalanceService` los lee como valores.
//

import Foundation
import Testing
@testable import Yala

@Suite("L19-10 · Residuo de redondeo")
@MainActor
struct GroupRoundingResidueLogicTests {

    private let zone = "zona-l19"

    /// Un gasto de `amount` que paga `payer`, con los repartos que se le pasen (pueden no sumar el importe).
    private func expense(
        _ amount: Double, paidBy payer: String, shares: [(String, Double)], currency: String = "USD"
    ) -> (SplitExpense, [SplitShare]) {
        let e = SplitExpense(groupZoneID: zone, amount: amount, currencyCode: currency, paidByMemberID: payer)
        let s = shares.map { SplitShare(expenseID: e.id, memberID: $0.0, amount: $0.1, groupZoneID: zone) }
        return (e, s)
    }

    private func settlement(_ from: String, _ to: String, _ amount: Double, currency: String = "USD") -> SplitSettlement {
        let s = SplitSettlement(groupZoneID: zone, fromMemberID: from, toMemberID: to, amount: amount, currencyCode: currency)
        s.isConfirmed = true
        return s
    }

    private func outstanding(
        _ items: [(SplitExpense, [SplitShare])], settlements: [SplitSettlement] = []
    ) -> (debts: [Debt], balances: [MemberBalance]) {
        let expenses = items.map(\.0)
        let shares = items.flatMap(\.1)
        let debts = GroupRoundingResidueLogic.outstandingDebts(expenses: expenses, shares: shares, settlements: settlements)
        let balances = GroupBalanceService.calculateBalances(
            expenses: expenses, shares: shares, members: [], settlements: settlements)
        return (debts, balances)
    }

    // MARK: - El caso medido: repartos que no suman el importe

    /// La semilla `grupos-saldado`: 50.00 y 80.00 entre tres a 16.67 y 26.67 (suman 50.01 y 80.01). Saldado lo que dicen
    /// los repartos, Beto queda con −0.02 de saldo neto, pero nadie le debe nada a nadie.
    @Test func sharesThatDoNotAddUp_leaveANetResidue_butNoDebt() {
        let taxi = expense(50, paidBy: "beto", shares: [("yo", 16.67), ("ana", 16.67), ("beto", 16.67)])
        let souvenirs = expense(80, paidBy: "beto", shares: [("yo", 26.67), ("ana", 26.67), ("beto", 26.67)])
        let result = outstanding([taxi, souvenirs],
                                 settlements: [settlement("yo", "beto", 43.34), settlement("ana", "beto", 43.34)])
        // Control: el saldo neto SÍ arrastra el residuo — es lo que bloqueaba antes.
        let beto = result.balances.first { $0.memberID == "beto" }?.netBalance ?? 0
        #expect(abs(beto + 0.02) < 1e-9, "Control: Beto queda en −0.02 (\(beto))")
        #expect(result.debts.isEmpty)
        #expect(!GroupRoundingResidueLogic.hasOutstanding(debts: result.debts, balances: result.balances))
    }

    /// El que la tolerancia de céntimos NO perdonaba: tres gastos de 10.00 a 3.33 dejan 0.03 que no debe nadie.
    @Test func residueLargerThanAFewCents_stillIsNotADebt() {
        let items = (0..<3).map { _ in expense(10, paidBy: "ana", shares: [("ana", 3.33), ("beto", 3.33), ("yo", 3.33)]) }
        let settled = [settlement("beto", "ana", 9.99), settlement("yo", "ana", 9.99)]
        let result = outstanding(items, settlements: settled)
        #expect(result.balances.contains { $0.memberID == "ana" && abs($0.netBalance - 0.03) < 1e-9 },
                "Control: el saldo neto de Ana arrastra 0.03")
        #expect(!GroupRoundingResidueLogic.hasOutstanding(debts: result.debts, balances: result.balances))
    }

    // MARK: - No esconde una deuda de verdad

    /// El que la tolerancia SÍ escondía: Beto debe 33.33 y liquida 33.31. Esos dos céntimos los enseña Saldos.
    @Test func aShortSettlement_isADebtEvenIfItIsTwoCents() {
        let dinner = expense(99.99, paidBy: "ana", shares: [("ana", 33.33), ("beto", 33.33), ("yo", 33.33)])
        let result = outstanding([dinner], settlements: [settlement("beto", "ana", 33.31), settlement("yo", "ana", 33.33)])
        #expect(GroupRoundingResidueLogic.hasOutstanding(debts: result.debts, balances: result.balances))
        #expect(GroupRoundingResidueLogic.hasOutstanding(debts: result.debts, memberID: "beto"))
        #expect(GroupRoundingResidueLogic.hasOutstanding(debts: result.debts, memberID: "ana"))
        #expect(!GroupRoundingResidueLogic.hasOutstanding(debts: result.debts, memberID: "yo"))
    }

    @Test func aRealDebt_isOutstanding_perPerson() {
        let rent = expense(80, paidBy: "yo", shares: [("yo", 40), ("ana", 40)], currency: "PEN")
        let result = outstanding([rent])
        #expect(GroupRoundingResidueLogic.hasOutstanding(debts: result.debts, balances: result.balances))
        #expect(result.debts == [Debt(fromMemberID: "ana", toMemberID: "yo", amount: 40, currencyCode: "PEN")])
    }

    /// Divisa por divisa: el residuo en dólares no tapa la deuda en soles.
    @Test func perCurrency_residueDoesNotHideAnotherCurrency() {
        let taxi = expense(50, paidBy: "beto", shares: [("yo", 16.67), ("ana", 16.67), ("beto", 16.67)])
        let rent = expense(80, paidBy: "yo", shares: [("yo", 40), ("ana", 40)], currency: "PEN")
        let result = outstanding([taxi, rent], settlements: [settlement("yo", "beto", 16.67), settlement("ana", "beto", 16.67)])
        #expect(result.debts.allSatisfy { $0.currencyCode == "PEN" })
        #expect(GroupRoundingResidueLogic.hasOutstanding(debts: result.debts, balances: result.balances))
    }

    // MARK: - Falla cerrado

    @Test func nonFiniteBalance_countsAsDebt() {
        let broken = MemberBalance(memberID: "a", displayName: "a", totalPaid: .nan, totalOwes: 0,
                                   netBalance: .nan, currencyCode: "USD")
        #expect(GroupRoundingResidueLogic.hasOutstanding(debts: [], balances: [broken]))
    }

    @Test func noExpenses_noDebt() {
        #expect(!GroupRoundingResidueLogic.hasOutstanding(debts: [], balances: []))
    }

    // MARK: - Card aeae · «Salir de todos mis grupos» y el borrado de cuenta deciden por persona

    /// La semilla `grupos-saldado` vista desde Beto: su saldo neto (−0.02) bloqueaba las dos superficies.
    @Test func memberHasOutstanding_residueOfTheSettledSeed_isNotADebt() {
        let taxi = expense(50, paidBy: "beto", shares: [("yo", 16.67), ("ana", 16.67), ("beto", 16.67)])
        let souvenirs = expense(80, paidBy: "beto", shares: [("yo", 26.67), ("ana", 26.67), ("beto", 26.67)])
        let settled = [settlement("yo", "beto", 43.34), settlement("ana", "beto", 43.34)]
        let items = [taxi, souvenirs]
        for member in ["beto", "yo", "ana"] {
            #expect(!GroupRoundingResidueLogic.memberHasOutstanding(
                memberID: member, expenses: items.map(\.0), shares: items.flatMap(\.1), members: [],
                settlements: settled), "\(member)")
        }
    }

    /// Liquidación corta de dos céntimos: es deuda para los dos que la comparten, y no para el tercero.
    @Test func memberHasOutstanding_shortSettlement_isADebtForBothEnds() {
        let dinner = expense(99.99, paidBy: "ana", shares: [("ana", 33.33), ("beto", 33.33), ("yo", 33.33)])
        let settled = [settlement("beto", "ana", 33.31), settlement("yo", "ana", 33.33)]
        func has(_ id: String) -> Bool {
            GroupRoundingResidueLogic.memberHasOutstanding(
                memberID: id, expenses: [dinner.0], shares: dinner.1, members: [], settlements: settled)
        }
        #expect(has("beto"))
        #expect(has("ana"))
        #expect(!has("yo"))
    }

    /// Falla cerrado: un importe no finito en el saldo PROPIO cuenta como deuda.
    @Test func memberHasOutstanding_nonFiniteOwnBalance_countsAsDebt() {
        let broken = expense(.nan, paidBy: "yo", shares: [("yo", 10), ("ana", 10)])
        #expect(GroupRoundingResidueLogic.memberHasOutstanding(
            memberID: "yo", expenses: [broken.0], shares: broken.1, members: [], settlements: []))
    }

    /// Las dos superficies del ticket llaman a la función, y ninguna vuelve al saldo neto.
    @Test func batchLeaveAndAccountDeletion_decideWithTheResidueRule() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let service = try String(contentsOf: root.appendingPathComponent("Yala/Services/Groups/GroupService.swift"),
                                 encoding: .utf8)
        #expect(service.components(separatedBy: "GroupRoundingResidueLogic.memberHasOutstanding(").count - 1 == 2)
        #expect(!service.contains("abs($0.netBalance) > 0.01"), "vuelve el saldo neto con tolerancia")
        #expect(!service.contains("perGroupUserNetBalances"), "el borrado de cuenta vuelve a contar netos")
    }
}
