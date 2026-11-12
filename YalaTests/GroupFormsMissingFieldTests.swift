//
//  GroupFormsMissingFieldTests.swift
//  YalaTests
//
//  Lote 12.3 (card rhgi): «Apuntar pago» y el «Guardar» del saldo inicial se quedan activos y, al tocarlos con algo
//  pendiente, dicen qué falta (molde de L13-9 en el gasto de grupo). Aquí, el orden y los casos de la lógica pura; el
//  recorrido en pantalla lo fija `GroupFormsMissingFieldUITests`.
//

import Testing
@testable import Yala

@Suite("Lote 12.3 · qué falta en el saldo inicial")
struct GroupOpeningBalanceMissingFieldLogicTests {

    @Test("Vacío: falta primero quién debe")
    func empty_asksForTheDebtorFirst() {
        #expect(GroupOpeningBalanceMissingFieldLogic.firstMissing(debtorMemberID: "", creditorMemberID: "", amount: 0) == .debtor)
    }

    @Test("Con quien debe y sin a quién: falta a quién")
    func debtorOnly_asksForTheCreditor() {
        #expect(GroupOpeningBalanceMissingFieldLogic.firstMissing(debtorMemberID: "ana", creditorMemberID: "", amount: 50) == .creditor)
    }

    @Test("La misma persona en los dos lados no se puede guardar")
    func samePerson_isMissing() {
        #expect(GroupOpeningBalanceMissingFieldLogic.firstMissing(debtorMemberID: "ana", creditorMemberID: "ana", amount: 50) == .samePerson)
    }

    @Test("Con las dos personas y sin importe (o negativo): falta el importe", arguments: [0.0, -10.0, .nan])
    func peopleWithoutAmount_asksForTheAmount(amount: Double) {
        #expect(GroupOpeningBalanceMissingFieldLogic.firstMissing(debtorMemberID: "ana", creditorMemberID: "beto", amount: amount) == .amount)
    }

    @Test("Completo: no falta nada")
    func complete_isNil() {
        #expect(GroupOpeningBalanceMissingFieldLogic.firstMissing(debtorMemberID: "ana", creditorMemberID: "beto", amount: 0.01) == nil)
    }
}

@Suite("Lote 12.3 · qué falta en «Apuntar pago»")
struct SettlementMissingFieldLogicTests {

    @Test("Sin importe, a cero o negativo falta el importe", arguments: [0.0, -1.0, .nan])
    func noAmount_isMissing(amount: Double) {
        #expect(SettlementMissingFieldLogic.amountMissing(amount))
    }

    @Test("Con importe se puede apuntar")
    func amount_isNotMissing() {
        #expect(!SettlementMissingFieldLogic.amountMissing(0.01))
    }
}
