//
//  GroupsAccountCardLogicTests.swift
//  YalaTests
//
//  Card extra de Jürgen (2026-11-03) · las cuentas de sistema de Grupos («Grupos PEN», «Grupos USD») ocupan un solo sitio
//  en «Tus finanzas», con una línea por grupo, y los saldos no cambian.
//

import Foundation
import Testing

@testable import Yala

@Suite("Panel · las cuentas de Grupos en una sola tarjeta")
struct GroupsAccountCardLogicTests {

    private struct Fake: Equatable { let name: String; let isSystem: Bool }

    private func card(_ name: String, system: Bool = false) -> AccountCard<Fake> {
        AccountCard(head: Fake(name: name, isSystem: system), lines: [])
    }

    @Test("las tarjetas de sistema se juntan en una, en el sitio de la primera; las demás no se mueven")
    func merge_putsTheSystemCardsTogether_whereTheFirstWas() {
        let cards = [card("Sueldo"), card("Grupos PEN", system: true), card("Visa"), card("Grupos USD", system: true)]
        let merged = GroupsAccountCardLogic.mergingSystemCards(cards, isSystem: \.isSystem)
        #expect(merged.map(\.head.name) == ["Sueldo", "Grupos PEN", "Visa"])
        #expect(merged[1].lines.map(\.name) == ["Grupos USD"])
        // Las mismas cuentas, ni una más ni una menos: los saldos que suma la tarjeta son los de antes.
        #expect(merged.flatMap(\.members).map(\.name).sorted() == cards.flatMap(\.members).map(\.name).sorted())
    }

    @Test("con una sola cuenta de sistema, o ninguna, las tarjetas quedan como estaban")
    func merge_withOneOrNone_isUnchanged() {
        let one = [card("Sueldo"), card("Grupos PEN", system: true)]
        #expect(GroupsAccountCardLogic.mergingSystemCards(one, isSystem: \.isSystem).map(\.head.name) == ["Sueldo", "Grupos PEN"])
        let none = [card("Sueldo"), card("Visa")]
        #expect(GroupsAccountCardLogic.mergingSystemCards(none, isSystem: \.isSystem).map(\.head.name) == ["Sueldo", "Visa"])
    }

    @Test("una línea por grupo y moneda; lo que no apunta a un grupo va aparte; la suma por moneda es el saldo")
    func groupLines_sumByGroupAndCurrency() {
        typealias M = GroupsAccountCardLogic.Movement
        let movements = [
            M(zoneID: "cusco", currencyCode: "PEN", amount: 150),
            M(zoneID: "cusco", currencyCode: "PEN", amount: -30),
            M(zoneID: "depa", currencyCode: "PEN", amount: -45),
            M(zoneID: "japon", currencyCode: "USD", amount: 80),
            M(zoneID: nil, currencyCode: "PEN", amount: 10),
            M(zoneID: "saldado", currencyCode: "PEN", amount: 20),
            M(zoneID: "saldado", currencyCode: "PEN", amount: -20),
        ]
        let lines = GroupsAccountCardLogic.groupLines(movements)
        #expect(lines.map(\.zoneID) == ["cusco", "japon", "depa", nil], "las mayores primero; un grupo saldado no ocupa sitio")
        #expect(lines.first?.value == 120)
        // La suma de las líneas de cada moneda es lo que sumaba la cuenta de sistema de esa moneda.
        for code in ["PEN", "USD"] {
            let fromLines = lines.filter { $0.currencyCode == code }.reduce(0) { $0 + $1.value }
            let fromAccount = movements.filter { $0.currencyCode == code }.reduce(0) { $0 + $1.amount }
            #expect(abs(fromLines - fromAccount) < 0.000_1)
        }
    }
}
