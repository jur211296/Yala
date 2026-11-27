//
//  CompartidoPersonasLogicTests.swift
//  YalaTests
//
//  El chip «Personas» de Compartido (lote 1, 26-nov-2026): quién sale, con qué neto y en qué lista. Lógica pura.
//

import Foundation
import Testing
@testable import Yala

@Suite("Compartido · personas: neto por cuenta entre grupos")
@MainActor
struct CompartidoPersonasLogicTests {

    typealias Logic = CompartidoPersonasLogic

    private func member(_ id: String, _ name: String, account: String? = nil) -> Logic.Member {
        Logic.Member(id: id, name: name, accountKey: account)
    }

    private func group(
        _ key: String, _ name: String, members: [Logic.Member], me: String = "yo",
        debts: [Debt] = [], interacted: Set<String> = []
    ) -> Logic.GroupInput {
        Logic.GroupInput(
            groupKey: key, groupName: name, members: [member(me, "Tú")] + members, myMemberIDs: [me],
            debts: debts, interactedMemberIDs: interacted)
    }

    private func debt(_ from: String, _ to: String, _ amount: Double, _ currency: String = "PEN") -> Debt {
        Debt(fromMemberID: from, toMemberID: to, amount: amount, currencyCode: currency)
    }

    @Test("La misma cuenta en dos grupos es una persona, y su neto suma los dos")
    func sameAccountAcrossGroups_isOnePerson() throws {
        let result = Logic.people(from: [
            group("g1", "Viaje a Cusco", members: [member("a1", "Ana", account: "u:ana")],
                  debts: [debt("a1", "yo", 50)]),
            group("g2", "Piso compartido", members: [member("a2", "Ana P.", account: "u:ana")],
                  debts: [debt("yo", "a2", 20)]),
        ])
        #expect(result.active.count == 1)
        let ana = try #require(result.active.first)
        #expect(ana.name == "Ana")
        #expect(ana.netByCurrency == ["PEN": 30])
        #expect(ana.groupNames == ["Viaje a Cusco", "Piso compartido"])
    }

    @Test("Sin cuenta, dos personas con el mismo nombre se quedan aparte")
    func noAccount_sameName_staysApart() {
        let result = Logic.people(from: [
            group("g1", "Viaje", members: [member("b1", "Beto")], debts: [debt("b1", "yo", 10)]),
            group("g2", "Piso", members: [member("b2", "Beto")], debts: [debt("b2", "yo", 15)]),
        ])
        #expect(result.active.count == 2)
        #expect(Set(result.active.map(\.id)).count == 2)
    }

    @Test("Monedas distintas no se suman: una fila por moneda, primero lo que debes")
    func currenciesStayApart() throws {
        let result = Logic.people(from: [
            group("g1", "Viaje", members: [member("a", "Ana", account: "u:ana")],
                  debts: [debt("a", "yo", 40, "USD"), debt("yo", "a", 25, "PEN")]),
        ])
        let ana = try #require(result.active.first)
        #expect(ana.netByCurrency == ["USD": 40, "PEN": -25])
        #expect(ana.rows.map(\.currencyCode) == ["PEN", "USD"])
        #expect(ana.rows.map(\.perspective) == [.iOwe, .theyOweMe])
        #expect(ana.rows.allSatisfy { $0.amount > 0 })
    }

    @Test("Neto cero con gastos en común va a liquidadas; sin gastos en común no sale")
    func settledAndUninvolved() {
        let result = Logic.people(from: [
            group("g1", "Viaje",
                  members: [member("a", "Ana", account: "u:ana"), member("c", "Caro", account: "u:caro")],
                  debts: [debt("a", "yo", 10)], interacted: ["a"]),
            group("g2", "Piso", members: [member("a2", "Ana", account: "u:ana")],
                  debts: [debt("yo", "a2", 10)]),
        ])
        #expect(result.active.isEmpty)
        #expect(result.settled.map(\.name) == ["Ana"])
        #expect(!result.settled.contains { $0.name == "Caro" })
    }

    @Test("Un resto de céntimos del redondeo cuenta como a mano")
    func roundingResidue_isSettled() {
        let result = Logic.people(from: [
            group("g1", "Viaje", members: [member("a", "Ana")], debts: [debt("a", "yo", 0.004)], interacted: ["a"]),
        ])
        #expect(result.active.isEmpty)
        #expect(result.settled.count == 1)
    }

    @Test("Las deudas entre otros dos no son mías")
    func debtsBetweenOthers_areIgnored() {
        let result = Logic.people(from: [
            group("g1", "Viaje", members: [member("a", "Ana"), member("b", "Beto")], debts: [debt("a", "b", 30)]),
        ])
        #expect(result.isEmpty)
    }

    @Test("Con pendientes, de mayor a menor importe")
    func activeOrder_byLargestAmount() {
        let result = Logic.people(from: [
            group("g1", "Viaje", members: [member("a", "Ana"), member("b", "Beto"), member("c", "Caro")],
                  debts: [debt("a", "yo", 10), debt("yo", "b", 80), debt("c", "yo", 30)]),
        ])
        #expect(result.active.map(\.name) == ["Beto", "Caro", "Ana"])
    }

    @Test("La cuenta: userID primero, luego CloudKit, y un miembro eliminado no tiene")
    func accountKey() {
        #expect(Logic.accountKey(userID: "x", cloudKitUserRecordID: "ck", displayName: "Ana") == "u:x")
        #expect(Logic.accountKey(userID: nil, cloudKitUserRecordID: "ck", displayName: "Ana") == "ck:ck")
        #expect(Logic.accountKey(userID: "", cloudKitUserRecordID: "", displayName: "Ana") == nil)
        #expect(Logic.accountKey(userID: "x", cloudKitUserRecordID: "ck",
                                 displayName: SplitMember.deletedUserSentinel) == nil)
    }

    @Test("Con quién tuve gastos o pagos")
    func interactions() {
        let e1 = UUID(), e2 = UUID(), e3 = UUID()
        let ids = Logic.interactedMemberIDs(
            myMemberIDs: ["yo"],
            expenses: [(e1, "yo"), (e2, "a"), (e3, "b")],
            shares: [(e1, "yo"), (e1, "c"), (e2, "yo"), (e2, "a"), (e3, "b"), (e3, "d")],
            settlements: [("e", "yo"), ("f", "g")])
        // c tuvo parte en lo que pagué; a pagó algo en lo que tengo parte; e me pagó. b, d, f y g, no conmigo.
        #expect(ids == ["c", "a", "e"])
    }
}

@Suite("Compartido · qué chip manda")
@MainActor
struct CompartidoChipLogicTests {
    @Test("Personas solo manda con la lista de grupos a la vista")
    func peopleOnlyWithTheList() {
        #expect(CompartidoChipLogic.shown(selected: .people, hasLoaded: true, hasActiveGroups: true) == .people)
        #expect(CompartidoChipLogic.shown(selected: .people, hasLoaded: false, hasActiveGroups: true) == .groups)
        #expect(CompartidoChipLogic.shown(selected: .people, hasLoaded: true, hasActiveGroups: false) == .groups)
        #expect(CompartidoChipLogic.shown(selected: .groups, hasLoaded: true, hasActiveGroups: true) == .groups)
    }
}
