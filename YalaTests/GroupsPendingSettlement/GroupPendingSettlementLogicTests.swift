//
//  GroupPendingSettlementLogicTests.swift
//  YalaTests
//
//  Grupos 2.3 · una deuda con un pago esperando confirmación (opción B; Jürgen, 2026-11-13). Lógica pura de
//  `GroupPendingSettlementLogic` y, contra el servicio de saldos real, el caso de la review adversarial del 2026-11-12:
//  Lucía apunta «Ana → Beto, S/ 50» (pendiente), Ana lo salda ella misma (nace confirmado) y Beto toca «Sí, lo recibí».
//  El cableado en pantalla lo fija `GruposPagoPorConfirmarUITests`.
//

import Foundation
import Testing
@testable import Yala

@Suite("Grupos 2.3 · pago por confirmar sobre la deuda")
@MainActor
struct GroupPendingSettlementLogicTests {

    private let ana = "ana"
    private let beto = "beto"
    private let lucia = "lucia"

    private typealias Logic = GroupPendingSettlementLogic

    private func payment(
        _ from: String, _ to: String, _ amount: Double, _ currency: String = "PEN", confirmed: Bool = false
    ) -> Logic.Payment {
        Logic.Payment(fromMemberID: from, toMemberID: to, amount: amount, currencyCode: currency, isConfirmed: confirmed)
    }

    private func debt(_ from: String, _ to: String, _ amount: Double, _ currency: String = "PEN") -> Debt {
        Debt(fromMemberID: from, toMemberID: to, amount: amount, currencyCode: currency)
    }

    // MARK: - La tarjeta de la deuda

    @Test func aPendingPayment_isSaidOnItsDebt_andSettleOffersOnlyWhatIsLeft() throws {
        let owed = debt(beto, ana, 50)
        let payments = [payment(beto, ana, 30)]

        let pending = try #require(Logic.pending(on: owed, payments: payments))
        #expect(pending.pendingAmount == 30)
        #expect(pending.count == 1)
        #expect(pending.remaining == 20)
        #expect(!pending.coversDebt)
        #expect(Logic.debtToSettle(owed, payments: payments) == debt(beto, ana, 20))
    }

    @Test func aPendingPaymentThatCoversTheDebt_leavesNothingToSettle() throws {
        let owed = debt(beto, ana, 30)
        let payments = [payment(beto, ana, 30)]

        #expect(try #require(Logic.pending(on: owed, payments: payments)).coversDebt)
        #expect(Logic.debtToSettle(owed, payments: payments) == nil)
    }

    @Test func moreThanTheDebtPending_neverLeavesANegativeRemainder() throws {
        let pending = try #require(Logic.pending(on: debt(beto, ana, 30), payments: [payment(beto, ana, 50)]))
        #expect(pending.remaining == 0)
        #expect(pending.coversDebt)
    }

    @Test func severalPendingPayments_addUp() throws {
        let owed = debt(beto, ana, 100)
        let pending = try #require(Logic.pending(on: owed, payments: [payment(beto, ana, 30), payment(beto, ana, 50)]))
        #expect(pending.pendingAmount == 80)
        #expect(pending.count == 2)
        #expect(Logic.debtToSettle(owed, payments: [payment(beto, ana, 30), payment(beto, ana, 50)])
                == debt(beto, ana, 20))
    }

    /// Medio céntimo de resto no cuenta: «33.33» pendiente sobre una deuda de 100 / 3 no deja «Saldar S/ 0.00».
    @Test func lessThanHalfACentLeft_coversTheDebt() {
        #expect(Logic.debtToSettle(debt(beto, ana, 100.0 / 3), payments: [payment(beto, ana, 33.33)]) == nil)
    }

    @Test func onlyThatPair_direction_andCurrencyCount() {
        let owed = debt(beto, ana, 50)
        let others = [
            payment(beto, ana, 50, confirmed: true),  // ya confirmado: ya está restado en la deuda
            payment(ana, beto, 50),                   // al revés
            payment(beto, lucia, 50),                 // otra pareja
            payment(beto, ana, 50, "USD"),            // otra moneda
            payment(beto, ana, 0),                    // vacío
        ]
        #expect(Logic.pending(on: owed, payments: others) == nil)
        #expect(Logic.debtToSettle(owed, payments: others) == owed)
    }

    // MARK: - «Sí, lo recibí»

    @Test func aPaymentThatFitsTheDebt_confirmsWithoutAsking() {
        #expect(Logic.confirmCheck(payment(ana, beto, 50), pairDebts: [debt(ana, beto, 50)], debtsWereConverted: false)
                == .fits)
        #expect(Logic.confirmCheck(payment(ana, beto, 30), pairDebts: [debt(ana, beto, 50)], debtsWereConverted: false)
                == .fits)
    }

    @Test func aPaymentOnASettledDebt_warns() {
        #expect(Logic.confirmCheck(payment(ana, beto, 50), pairDebts: [], debtsWereConverted: false) == .alreadySettled)
        // Una deuda en otra moneda, o al revés, no cuenta como «lo que se debe».
        #expect(Logic.confirmCheck(
            payment(ana, beto, 50), pairDebts: [debt(ana, beto, 50, "USD"), debt(beto, ana, 20)],
            debtsWereConverted: false) == .alreadySettled)
    }

    @Test func aPaymentBiggerThanWhatIsLeft_saysWhatWasLeft() {
        #expect(Logic.confirmCheck(payment(ana, beto, 50), pairDebts: [debt(ana, beto, 20)], debtsWereConverted: false)
                == .exceeds(owed: 20))
    }

    @Test func convertedDebts_orAConfirmedPayment_neverWarn() {
        #expect(Logic.confirmCheck(payment(ana, beto, 50), pairDebts: [], debtsWereConverted: true) == .fits)
        #expect(Logic.confirmCheck(payment(ana, beto, 50, confirmed: true), pairDebts: [], debtsWereConverted: false)
                == .fits)
    }

    // MARK: - El caso de la review, con el servicio de saldos real

    /// Beto pagó una cena de S/ 100 a medias con Ana: Ana le debe S/ 50 a Beto.
    private func dinner() -> (expense: SplitExpense, shares: [SplitShare]) {
        let expense = SplitExpense(
            groupZoneID: "z", amount: 100, currencyCode: "PEN", expenseDescription: "Cena",
            paidByMemberID: beto, splitType: "equal")
        let shares = [
            SplitShare(expenseID: expense.id, memberID: beto, amount: 50, isPaid: true, groupZoneID: "z"),
            SplitShare(expenseID: expense.id, memberID: ana, amount: 50, groupZoneID: "z"),
        ]
        return (expense, shares)
    }

    private func settlement(_ from: String, _ to: String, _ amount: Double, recordedBy: String) -> SplitSettlement {
        let s = SplitSettlement(groupZoneID: "z", fromMemberID: from, toMemberID: to, amount: amount, currencyCode: "PEN")
        s.recordedByMemberID = recordedBy
        s.isConfirmed = SettlementSaldar23Logic.confirmsOnRecord(
            recorderMemberID: recordedBy, fromMemberID: from, toMemberID: to)
        return s
    }

    private func debts(_ dinner: (expense: SplitExpense, shares: [SplitShare]), _ settlements: [SplitSettlement]) -> [Debt] {
        GroupBalanceService.calculateDebts(
            expenses: [dinner.expense], shares: dinner.shares, settlements: settlements, simplifyDebts: false)
    }

    private func asPayment(_ s: SplitSettlement) -> Logic.Payment {
        payment(s.fromMemberID, s.toMemberID, s.amount, s.currencyCode, confirmed: s.isConfirmed)
    }

    @Test func reviewCase_luciaRecords_anaSettlesHerself_betoIsWarnedBeforeConfirming() throws {
        let dinner = dinner()

        // 1. Lucía apunta «Ana → Beto, S/ 50»: queda pendiente y la deuda sigue (los saldos solo cuentan lo confirmado).
        let byLucia = settlement(ana, beto, 50, recordedBy: lucia)
        #expect(!byLucia.isConfirmed)
        let before = debts(dinner, [byLucia])
        #expect(before == [debt(ana, beto, 50)])

        // 2. Ana ve su deuda con el pago por confirmar, y «Saldar» ya no le ofrece pagar otra vez lo mismo.
        let owed = try #require(before.first)
        #expect(try #require(Logic.pending(on: owed, payments: [asPayment(byLucia)])).coversDebt)
        #expect(Logic.debtToSettle(owed, payments: [asPayment(byLucia)]) == nil)

        // 3. Ana lo salda igual por su cuenta (lo apunta quien paga: nace confirmado). La deuda queda a cero.
        let byAna = settlement(ana, beto, 50, recordedBy: ana)
        #expect(byAna.isConfirmed)
        let after = debts(dinner, [byLucia, byAna])
        #expect(after.isEmpty)

        // 4. Beto toca «Sí, lo recibí» en el de Lucía: antes de confirmar, la app avisa que ya está saldada.
        #expect(Logic.confirmCheck(asPayment(byLucia), pairDebts: after, debtsWereConverted: false) == .alreadySettled)

        // Sin el aviso, confirmar lo dejaba pagado de más: Beto pasaba a deberle S/ 50 a Ana.
        byLucia.isConfirmed = true
        #expect(debts(dinner, [byLucia, byAna]) == [debt(beto, ana, 50)])
    }
}
