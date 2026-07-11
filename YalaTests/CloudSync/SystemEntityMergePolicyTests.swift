//
//  SystemEntityMergePolicyTests.swift
//  YalaTests / CloudSync
//
//  Política v1 PURA para entidades de sistema (residual del gate de flags). Sin `ModelContext` — se ejercita
//  con un struct fixture. Cubre: determinismo (cualquier orden → mismo ganador), criterio idéntico al del
//  bridge `(name, shortcutID.uuidString)` asc, grupos de 1 → no-op, y multi-groupKey (currency) independiente.
//

import Foundation
import Testing

@testable import Yala

@Suite("SystemEntityMergePolicy · política v1 pura")
struct SystemEntityMergePolicyTests {

    private struct Row: Hashable {
        let name: String
        let sid: String
        let currency: String
    }

    private func plan(_ rows: [Row]) -> [SystemEntityMergePolicy.MergeResult<Row>] {
        SystemEntityMergePolicy.plan(
            rows, groupKey: { $0.currency }, name: { $0.name }, tiebreak: { $0.sid })
    }

    @Test("grupo de 1 → no-op (sin merge)")
    func singleRow_noMerge() {
        let result = plan([Row(name: "Grupos PEN", sid: "a", currency: "PEN")])
        #expect(result.isEmpty)
    }

    @Test("ganador por name ascendente; el resto perdedores")
    func winnerByName() {
        let rows = [
            Row(name: "Grupos PEN", sid: "z", currency: "PEN"),   // 'Gru' vs 'Gro'
            Row(name: "Groups PEN", sid: "a", currency: "PEN"),
        ]
        let result = plan(rows)
        #expect(result.count == 1)
        #expect(result[0].winner.name == "Groups PEN")  // "Groups" < "Grupos" (o < r)
        #expect(result[0].losers.map(\.name) == ["Grupos PEN"])
    }

    @Test("empate de name → desempata por tiebreak (shortcutID) ascendente")
    func tiebreakBySID() {
        let rows = [
            Row(name: "Grupos PEN", sid: "ffff", currency: "PEN"),
            Row(name: "Grupos PEN", sid: "0001", currency: "PEN"),
        ]
        let result = plan(rows)
        #expect(result.count == 1)
        #expect(result[0].winner.sid == "0001")
        #expect(result[0].losers.map(\.sid) == ["ffff"])
    }

    @Test("determinismo: cualquier orden de entrada → mismo ganador y mismos perdedores")
    func deterministicRegardlessOfOrder() {
        let base = [
            Row(name: "Grupos PEN", sid: "m", currency: "PEN"),
            Row(name: "Groups PEN", sid: "a", currency: "PEN"),
            Row(name: "Grupos PEN", sid: "b", currency: "PEN"),
        ]
        let forward = plan(base)
        let reversed = plan(base.reversed())
        let shuffled = plan([base[2], base[0], base[1]])
        #expect(forward.count == 1)
        #expect(forward[0].winner == reversed[0].winner)
        #expect(forward[0].winner == shuffled[0].winner)
        #expect(forward[0].winner.name == "Groups PEN")  // menor por name
        #expect(Set(forward[0].losers) == Set(reversed[0].losers))
        #expect(Set(forward[0].losers) == Set(shuffled[0].losers))
    }

    @Test("multi-currency: cada groupKey se resuelve INDEPENDIENTE")
    func multiCurrencyIndependentGroups() {
        let rows = [
            Row(name: "Grupos PEN", sid: "z", currency: "PEN"),
            Row(name: "Groups PEN", sid: "a", currency: "PEN"),
            Row(name: "Grupos USD", sid: "q", currency: "USD"),
            Row(name: "Groups USD", sid: "b", currency: "USD"),
            Row(name: "Grupos EUR", sid: "solo", currency: "EUR"),  // grupo de 1 → sin merge
        ]
        let result = plan(rows)
        #expect(result.count == 2)  // PEN y USD; EUR omitido
        let byWinnerCurrency = Dictionary(uniqueKeysWithValues: result.map { ($0.winner.currency, $0) })
        #expect(byWinnerCurrency["PEN"]?.winner.name == "Groups PEN")
        #expect(byWinnerCurrency["USD"]?.winner.name == "Groups USD")
        #expect(byWinnerCurrency["EUR"] == nil)
    }

    @Test("balanceAdjustment cross-idioma: UN grupo constante colapsa a un ganador")
    func balanceAdjustmentSingleGroup() {
        // Simula 3 nombres distintos del set multi-idioma con groupKey constante.
        let rows = [
            Row(name: "Ajustes de saldo", sid: "z", currency: "-"),
            Row(name: "Balance adjustments", sid: "a", currency: "-"),
            Row(name: "Saldoanpassungen", sid: "m", currency: "-"),
        ]
        let result = SystemEntityMergePolicy.plan(
            rows, groupKey: { _ in "balanceAdjustment" }, name: { $0.name }, tiebreak: { $0.sid })
        #expect(result.count == 1)
        #expect(result[0].winner.name == "Ajustes de saldo")  // menor lexicográfico
        #expect(result[0].losers.count == 2)
    }
}
