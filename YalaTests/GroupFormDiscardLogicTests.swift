//
//  GroupFormDiscardLogicTests.swift
//  YalaTests
//
//  Decisión 39 de la revisión 2.3 (F1 + F3): cuándo un formulario de Grupos pregunta antes de cerrarse, qué se lleva
//  «Nuevo gasto» al cambiar de grupo y en qué grupo abre.
//

import Foundation
import Testing

@testable import Yala

@Suite("Grupos: no tirar lo escrito (decisión 39 de 2.3)")
struct GroupFormDiscardLogicTests {

    // MARK: - Preguntar antes de descartar

    @Test("Igual que al abrir: cierra sin preguntar")
    func unchangedClosesWithoutAsking() {
        #expect(!GroupFormDiscardLogic.asksBeforeDiscarding(current: "60.00", baseline: "60.00"))
    }

    @Test("Con algo cambiado respecto a lo de partida: pregunta")
    func changedAsks() {
        #expect(GroupFormDiscardLogic.asksBeforeDiscarding(current: "65.00", baseline: "60.00"))
    }

    @Test("Sin foto de partida todavía: no pregunta")
    func noBaselineDoesNotAsk() {
        #expect(!GroupFormDiscardLogic.asksBeforeDiscarding(current: "65.00", baseline: nil as String?))
    }

    // MARK: - Lo que se lleva al cambiar de grupo

    private func carryOver(description: String = "", amount: String = "", note: String = "") -> GroupExpenseCarryOver {
        GroupExpenseCarryOver(expenseDescription: description, amountString: amount, note: note, date: .distantPast,
                              currencyCode: "PEN", subcategory: nil, account: nil)
    }

    @Test("Sin nada escrito no hay nada que llevarse")
    func emptyHasNoContent() {
        #expect(!carryOver().hasContent)
        #expect(!carryOver(description: "   ", amount: "0").hasContent)
    }

    @Test("La descripción, el importe o la nota cuentan como escrito")
    func anyWrittenFieldCounts() {
        #expect(carryOver(description: "Cena").hasContent)
        #expect(carryOver(amount: "400").hasContent)
        #expect(carryOver(note: "con propina").hasContent)
    }

    // MARK: - El grupo en el que abre «Nuevo gasto»

    private let cusco = UUID()
    private let lima = UUID()

    @Test("Abre en el último grupo donde se apuntó un gasto")
    func opensInTheLastGroup() {
        #expect(LastExpenseGroupMark.initialGroupID(eligibleIDs: [cusco, lima], lastID: lima) == lima)
    }

    @Test("Si ese grupo ya no admite gastos, o no hay ninguno apuntado, abre en el primero")
    func fallsBackToTheFirst() {
        #expect(LastExpenseGroupMark.initialGroupID(eligibleIDs: [cusco, lima], lastID: UUID()) == cusco)
        #expect(LastExpenseGroupMark.initialGroupID(eligibleIDs: [cusco, lima], lastID: nil) == cusco)
        #expect(LastExpenseGroupMark.initialGroupID(eligibleIDs: [], lastID: lima) == nil)
    }

    @Test("La marca se guarda, se lee y se borra en el almacén que se le da")
    func markRoundTrip() {
        let defaults = makeIsolatedDefaults()
        #expect(LastExpenseGroupMark.lastGroupID(defaults: defaults) == nil)
        LastExpenseGroupMark.record(lima, defaults: defaults)
        #expect(LastExpenseGroupMark.lastGroupID(defaults: defaults) == lima)
        LastExpenseGroupMark.clear(defaults)
        #expect(LastExpenseGroupMark.lastGroupID(defaults: defaults) == nil)
    }
}
