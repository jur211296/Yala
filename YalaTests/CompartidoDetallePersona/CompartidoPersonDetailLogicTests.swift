//
//  CompartidoPersonDetailLogicTests.swift
//  YalaTests
//
//  Lote 2 de Compartido (26-nov-2026): el detalle de una persona. Lógica pura: el filtro de grupo, la cifra, el
//  desglose, «Saldar todo» (un pago por grupo y moneda que suma exactamente lo de «Todos los grupos») y qué gastos son
//  «con la persona».
//

import Foundation
import Testing
@testable import Yala

@Suite("Compartido · detalle de persona: filtro, cifra y saldar")
@MainActor
struct CompartidoPersonDetailLogicTests {

    typealias Logic = CompartidoPersonDetailLogic

    private func debt(_ from: String, _ to: String, _ amount: Double, _ currency: String = "PEN") -> Debt {
        Debt(fromMemberID: from, toMemberID: to, amount: amount, currencyCode: currency)
    }

    private func slice(
        _ key: String, _ name: String, me: String? = "yo", person: Set<String> = ["beto"], debts: [Debt],
        isPerson: Bool = false, converted: Bool = false
    ) -> Logic.Slice {
        Logic.Slice(
            groupKey: key, groupName: name, isPerson: isPerson, myMemberID: me, personMemberIDs: person,
            debts: debts, debtsWereConverted: converted)
    }

    /// Beto en tres sitios: «Viaje a Cusco» (S/ y $), «Piso compartido» (le debes) y lo sin grupo. Ana anda por medio.
    private var beto: [Logic.Slice] {
        [
            slice("cusco", "Viaje a Cusco", me: "yo1", person: ["b1"], debts: [
                debt("b1", "yo1", 110), debt("b1", "yo1", 40, "USD"), debt("ana", "yo1", 80), debt("b1", "ana", 15),
            ]),
            slice("piso", "Piso compartido", me: "yo2", person: ["b2"], debts: [debt("yo2", "b2", 30.33)]),
            slice("dos", "Sin grupo", me: "yo3", person: ["b3"], debts: [debt("b3", "yo3", 20.01)], isPerson: true),
        ]
    }

    // MARK: - Filtro

    @Test("El filtro ofrece «Todos», cada grupo en su orden y «Sin grupo» al final")
    func filterOptions_inOrder_withNoGroupLast() {
        let options = Logic.filterOptions(beto)
        #expect(options == [.all, .group("cusco"), .group("piso"), .noGroup])
    }

    @Test("Sin grupo de dos, no hay «Sin grupo»")
    func filterOptions_withoutPersonGroup_hasNoNoGroup() {
        let options = Logic.filterOptions(Array(beto.prefix(2)))
        #expect(!options.contains(.noGroup))
    }

    @Test("Un filtro que ya no existe vuelve a «Todos los grupos»")
    func resolved_fallsBackToAll() {
        let options = Logic.filterOptions(beto)
        #expect(Logic.resolved(.group("borrado"), options: options) == .all)
        #expect(Logic.resolved(.group("piso"), options: options) == .group("piso"))
    }

    // MARK: - Cifra

    @Test("Solo cuenta lo que hay entre los dos: la deuda de Ana y la de Beto con Ana no entran")
    func pairNet_ignoresThirdParties() {
        let net = Logic.pairNetCents(beto[0])
        #expect(net == ["PEN": 11_000, "USD": 4_000])
    }

    @Test("Con todos los grupos, la cifra suma por moneda y lo que le debes resta")
    func hero_all_netsAcrossGroups() {
        let hero = Logic.hero(beto, filter: .all)
        // 110 − 30,33 + 20,01 = 99,68 en soles; 40 en dólares.
        #expect(hero.owedToMe.map(\.currencyCode) == ["PEN", "USD"])
        #expect(hero.owedToMe.map(\.amount) == [99.68, 40])
        #expect(hero.iOwe.isEmpty)
    }

    @Test("Con un grupo elegido, solo ese grupo")
    func hero_group_onlyThatGroup() {
        let hero = Logic.hero(beto, filter: .group("piso"))
        #expect(hero.owedToMe.isEmpty)
        #expect(hero.iOwe.map(\.amount) == [30.33])
    }

    @Test("«Sin grupo» es el grupo de dos")
    func hero_noGroup_isThePersonGroup() {
        let hero = Logic.hero(beto, filter: .noGroup)
        #expect(hero.owedToMe.map(\.amount) == [20.01])
    }

    @Test("«≈» por moneda: una moneda sin grupos convertidos nunca se marca")
    func estimatedCurrencies_exactCurrencyIsNotMarked() {
        let slices = [
            slice("viaje", "Viaje", me: "m1", person: ["p1"], debts: [debt("p1", "m1", 10)], converted: true),
            slice("piso", "Piso", me: "m2", person: ["p2"], debts: [debt("p2", "m2", 10), debt("p2", "m2", 40, "USD")]),
        ]
        let marked = Logic.estimatedCurrencies(slices, filter: .all)
        #expect(marked == ["PEN"])
        #expect(Logic.estimatedCurrencies(slices, filter: .group("piso")).isEmpty)
    }

    @Test("«≈» por moneda: lo convertido se compara con el neto que se pinta, con el umbral de la app")
    func estimatedCurrencies_usesTheShownNetAsDenominator() {
        // S/ 10 convertidos sobre un neto de S/ 20 → se marca; sobre uno de S/ 1,000 → no (1 %, bajo el umbral).
        let small = [
            slice("viaje", "Viaje", me: "m1", person: ["p1"], debts: [debt("p1", "m1", 10)], converted: true),
            slice("piso", "Piso", me: "m2", person: ["p2"], debts: [debt("p2", "m2", 10)]),
        ]
        let large = [
            slice("viaje", "Viaje", me: "m1", person: ["p1"], debts: [debt("p1", "m1", 10)], converted: true),
            slice("piso", "Piso", me: "m2", person: ["p2"], debts: [debt("p2", "m2", 990)]),
        ]
        #expect(Logic.estimatedCurrencies(small, filter: .all) == ["PEN"])
        #expect(Logic.estimatedCurrencies(large, filter: .all).isEmpty)
        // Con grupos de signo contrario el denominador es el neto que se pinta (S/ 10), no la suma de magnitudes
        // (S/ 1,090): S/ 50 convertidos marcan. Con la suma de magnitudes, 50/1090 = 4,6 % y no marcaría.
        let netted = [
            slice("viaje", "Viaje", me: "m1", person: ["p1"], debts: [debt("p1", "m1", 50)], converted: true),
            slice("piso", "Piso", me: "m2", person: ["p2"], debts: [debt("p2", "m2", 500)]),
            slice("casa", "Casa", me: "m3", person: ["p3"], debts: [debt("m3", "p3", 540)]),
        ]
        #expect(Logic.netCents(netted, filter: .all) == ["PEN": 1_000])
        #expect(Logic.estimatedCurrencies(netted, filter: .all) == ["PEN"])
    }

    @Test("Cada fila del desglose, de «Saldar todo» y de «Por grupo» lleva la marca de SU grupo")
    func rowsCarryTheirOwnGroupMark() {
        let slices = [
            slice("viaje", "Viaje", me: "m1", person: ["p1"], debts: [debt("p1", "m1", 10)], converted: true),
            slice("piso", "Piso", me: "m2", person: ["p2"], debts: [debt("p2", "m2", 990)]),
        ]
        #expect(Logic.breakdown(slices, filter: .all).map(\.isEstimate) == [true, false])
        #expect(Logic.settlePlan(slices, filter: .all).map(\.isEstimate) == [true, false])
        #expect(Logic.byGroup(slices).map(\.isEstimate) == [true, false])
    }

    @Test("Te debe en un grupo y le debes en otro: la cifra lo sabe para no decir «Tú no le debes nada»")
    func hasOpposingGroups_detectsMixedDirections() {
        #expect(Logic.hasOpposingGroups(beto, filter: .all))
        #expect(!Logic.hasOpposingGroups(beto, filter: .group("cusco")))
        #expect(!Logic.hasOpposingGroups([beto[0], beto[2]], filter: .all))
    }

    // MARK: - Desglose y saldar

    @Test("El desglose va por grupo, con lo sin grupo al final y sin los grupos a cero")
    func breakdown_orderAndSkipsZero() {
        var slices = beto
        slices.insert(slice("lima", "Viaje a Lima", me: "yo4", person: ["b4"], debts: [debt("ana", "yo4", 5)]), at: 1)
        let rows = Logic.breakdown(slices, filter: .all)
        #expect(rows.map(\.groupKey) == ["cusco", "piso", "dos"])
        #expect(rows.map(\.groupName) == ["Viaje a Cusco", "Piso compartido", "Sin grupo"])
    }

    @Test("Saldar todo: un pago por grupo y moneda, cada uno en su sentido")
    func settlePlan_onePaymentPerGroupAndCurrency() {
        let plan = Logic.settlePlan(beto, filter: .all)
        #expect(plan.map(\.id) == ["cusco-PEN", "cusco-USD", "piso-PEN", "dos-PEN"])
        #expect(plan[0].debt == debt("b1", "yo1", 110))
        #expect(plan[1].debt == debt("b1", "yo1", 40, "USD"))
        #expect(plan[2].debt == debt("yo2", "b2", 30.33))
        #expect(plan[2].iPay)
        #expect(!plan[0].iPay)
        #expect(plan[3].debt == debt("b3", "yo3", 20.01))
    }

    @Test("Lo que se salda grupo a grupo suma EXACTAMENTE lo de «Todos los grupos», moneda a moneda")
    func settlePlan_perGroupSumsExactlyToAll() {
        // Céntimos que no cierran en binario: 33,33 + 33,33 + 33,34 y una deuda partida en dos filas.
        let slices = [
            slice("a", "A", me: "m1", person: ["p1"], debts: [debt("p1", "m1", 33.33), debt("p1", "m1", 0.1, "USD")]),
            slice("b", "B", me: "m2", person: ["p2"], debts: [debt("p2", "m2", 33.33), debt("m2", "p2", 0.2, "USD")]),
            slice("c", "C", me: "m3", person: ["p3", "p3b"], debts: [debt("p3", "m3", 20.34), debt("p3b", "m3", 13)]),
            slice("d", "Sin grupo", me: "m4", person: ["p4"], debts: [debt("m4", "p4", 0.07)], isPerson: true),
        ]
        func signedCents(_ plan: [Logic.SettleItem]) -> [String: Int] {
            plan.reduce(into: [String: Int]()) { result, item in
                let cents = Int((item.debt.amount * 100).rounded())
                result[item.debt.currencyCode, default: 0] += item.iPay ? -cents : cents
            }
        }
        let all = Logic.netCents(slices, filter: .all)
        #expect(all == ["PEN": 9_993, "USD": -10])
        #expect(signedCents(Logic.settlePlan(slices, filter: .all)) == all)

        var byGroup: [String: Int] = [:]
        for option in Logic.filterOptions(slices) where option != .all {
            for (currency, cents) in signedCents(Logic.settlePlan(slices, filter: option)) {
                byGroup[currency, default: 0] += cents
            }
        }
        #expect(byGroup == all)
    }

    @Test("Saldar un grupo elegido salda solo ese grupo")
    func settlePlan_groupFilter_onlyThatGroup() {
        let plan = Logic.settlePlan(beto, filter: .group("cusco"))
        #expect(plan.map(\.groupKey) == ["cusco", "cusco"])
    }

    @Test("Sin mi fila en un grupo no hay nada mío que saldar ni contar")
    func withoutMe_nothingCounts() {
        let slices = [slice("x", "X", me: nil, debts: [debt("beto", "yo", 10)])]
        #expect(Logic.netCents(slices, filter: .all).isEmpty)
        #expect(Logic.settlePlan(slices, filter: .all).isEmpty)
    }

    @Test("Las deudas del par: solo entre tú y la persona, en los dos sentidos")
    func pairDebts_onlyThePair() {
        let pair = Logic.pairDebts(beto[0])
        #expect(pair == [debt("b1", "yo1", 110), debt("b1", "yo1", 40, "USD")])
    }

    // MARK: - Gastos

    @Test("Un gasto es con la persona si estáis los dos")
    func isSharedExpense_cases() {
        let person: Set<String> = ["b"]
        #expect(Logic.isSharedExpense(paidBy: "yo", participants: ["yo", "b"], myMemberID: "yo", personMemberIDs: person))
        #expect(Logic.isSharedExpense(paidBy: "yo", participants: ["b"], myMemberID: "yo", personMemberIDs: person))
        #expect(Logic.isSharedExpense(paidBy: "ana", participants: ["yo", "b"], myMemberID: "yo", personMemberIDs: person))
        #expect(!Logic.isSharedExpense(paidBy: "ana", participants: ["yo", "ana"], myMemberID: "yo",
                                       personMemberIDs: person))
        #expect(!Logic.isSharedExpense(paidBy: "b", participants: ["ana"], myMemberID: "yo", personMemberIDs: person))
        #expect(!Logic.isSharedExpense(paidBy: "yo", participants: ["yo", "b"], myMemberID: nil,
                                       personMemberIDs: person))
    }

    @Test("Un pago es con la persona si va de uno al otro")
    func isSharedSettlement_cases() {
        #expect(Logic.isSharedSettlement(from: "b", to: "yo", myMemberID: "yo", personMemberIDs: ["b"]))
        #expect(Logic.isSharedSettlement(from: "yo", to: "b", myMemberID: "yo", personMemberIDs: ["b"]))
        #expect(!Logic.isSharedSettlement(from: "ana", to: "yo", myMemberID: "yo", personMemberIDs: ["b"]))
        #expect(!Logic.isSharedSettlement(from: "b", to: "ana", myMemberID: "yo", personMemberIDs: ["b"]))
    }

    // MARK: - Estadísticas

    @Test("Los alias juntan tus filas en la primera y las de la persona en la suya")
    func memberAliases_mergeAcrossGroups() {
        let result = Logic.memberAliases(beto)
        #expect(result.me == "yo1")
        #expect(result.aliases["yo2"] == "yo1")
        #expect(result.aliases["yo3"] == "yo1")
        #expect(result.aliases["b2"] == "b1")
        #expect(result.aliases["b3"] == "b1")
        #expect(result.aliases["ana"] == nil)
    }

    @Test("«Por grupo»: una fila por grupo con algo pendiente y la barra proporcional a lo mayor")
    func byGroup_rowsAndFraction() {
        let rows = Logic.byGroup(beto)
        #expect(rows.map(\.groupKey) == ["cusco", "piso", "dos"])
        #expect(rows[0].fraction == 1)
        #expect(abs(rows[1].fraction - 3_033.0 / 11_000.0) < 0.000_1)
        #expect(abs(rows[2].fraction - 2_001.0 / 11_000.0) < 0.000_1)
    }

    @Test("«Por grupo» no sale con un solo grupo pendiente")
    func byGroup_singleGroup_isEmpty() {
        #expect(Logic.byGroup([beto[0]]).isEmpty)
    }
}
