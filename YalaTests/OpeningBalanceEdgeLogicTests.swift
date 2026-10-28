//
//  OpeningBalanceEdgeLogicTests.swift
//  YalaTests
//
//  Card t3fq · la lógica pura de los saldos iniciales: qué saldo reemplaza uno nuevo (uno por pareja y moneda), qué
//  abre «Saldo inicial» desde el menú de una persona y que la fecha no vaya al futuro.
//

import Foundation
import Testing

@testable import Yala

@Suite("Saldos iniciales · pareja, persona y fecha (card t3fq)")
struct OpeningBalanceEdgeLogicTests {

    private typealias Edge = OpeningBalanceEdgeLogic.Edge

    private let ana = "ana"
    private let yo = "yo"
    private let luis = "luis"

    private func edge(_ debtor: String, _ creditor: String, _ currency: String = "PEN", id: UUID = UUID()) -> Edge {
        Edge(id: id, debtorMemberID: debtor, creditorMemberID: creditor, currencyCode: currency)
    }

    // MARK: - Uno por pareja y moneda

    @Test("Un saldo nuevo de la misma pareja y moneda reemplaza al que había")
    func samePairAndCurrency_isReplaced() {
        let existing = edge(ana, yo)
        let found = OpeningBalanceEdgeLogic.replaceable(among: [existing], memberA: ana, memberB: yo, currencyCode: "PEN")
        #expect(found == existing)
    }

    @Test("En el sentido contrario también: es la misma pareja")
    func reversedPair_isReplaced() {
        let existing = edge(ana, yo)
        let found = OpeningBalanceEdgeLogic.replaceable(among: [existing], memberA: yo, memberB: ana, currencyCode: "PEN")
        #expect(found == existing)
    }

    @Test("Otra moneda es otro saldo")
    func otherCurrency_isNotReplaced() {
        let found = OpeningBalanceEdgeLogic.replaceable(
            among: [edge(ana, yo, "USD")], memberA: ana, memberB: yo, currencyCode: "PEN"
        )
        #expect(found == nil)
    }

    @Test("Otra pareja con una persona en común es otro saldo")
    func pairSharingOnePerson_isNotReplaced() {
        let found = OpeningBalanceEdgeLogic.replaceable(
            among: [edge(ana, luis)], memberA: ana, memberB: yo, currencyCode: "PEN"
        )
        #expect(found == nil)
    }

    @Test("Con varios de antes de la regla, se reemplaza el primero recibido (el más antiguo)")
    func severalLegacy_replacesTheFirst() {
        let oldest = edge(ana, yo)
        let newer = edge(yo, ana)
        let found = OpeningBalanceEdgeLogic.replaceable(among: [oldest, newer], memberA: ana, memberB: yo, currencyCode: "PEN")
        #expect(found == oldest)
    }

    // MARK: - Qué abre el menú de una persona

    @Test("Sin saldo, abre uno nuevo con la persona en «Quién debe»")
    func memberWithoutEdges_createsWithPrefill() {
        let entry = OpeningBalanceEdgeLogic.memberEntry(for: ana, among: [edge(luis, yo)])
        #expect(entry == .create(prefillDebtorMemberID: ana))
    }

    @Test("Con un saldo en el que debe, edita ése")
    func memberWithOneEdgeAsDebtor_editsIt() {
        let id = UUID()
        let entry = OpeningBalanceEdgeLogic.memberEntry(for: ana, among: [edge(ana, yo, id: id), edge(luis, yo)])
        #expect(entry == .edit(id))
    }

    @Test("Con un saldo en el que le deben, también edita ése")
    func memberWithOneEdgeAsCreditor_editsIt() {
        let id = UUID()
        let entry = OpeningBalanceEdgeLogic.memberEntry(for: ana, among: [edge(yo, ana, id: id)])
        #expect(entry == .edit(id))
    }

    @Test("Con dos saldos no elige uno a ciegas: abre uno nuevo con la persona puesta")
    func memberWithTwoEdges_createsWithPrefill() {
        let entry = OpeningBalanceEdgeLogic.memberEntry(for: ana, among: [edge(ana, yo), edge(luis, ana)])
        #expect(entry == .create(prefillDebtorMemberID: ana))
    }

    // MARK: - Fecha

    @Test("La fecha elegida se guarda tal cual si no es futura")
    func pastDate_isKept() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let chosen = now.addingTimeInterval(-90 * 86_400)
        #expect(OpeningBalanceEdgeLogic.storedDate(chosen, now: now) == chosen)
    }

    @Test("Una fecha futura se queda en hoy")
    func futureDate_isClampedToNow() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(OpeningBalanceEdgeLogic.storedDate(now.addingTimeInterval(86_400), now: now) == now)
    }
}
