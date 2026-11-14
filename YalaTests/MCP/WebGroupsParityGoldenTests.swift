//
//  WebGroupsParityGoldenTests.swift
//  YalaTests / MCP
//
//  Golden de paridad de Grupos para Yala web (lote 3): `mcp/test/golden/groups-parity.json`.
//
//  Las entradas son gastos, repartos y pagos escritos a mano, con las claves de miembro del backend. Este test los
//  pasa por el código de producción de la app, sin réplicas:
//
//  - saldos por miembro y divisa: `GroupBalanceService.calculateBalances`, y los que enseña Saldos con «una sola
//    moneda» (`consolidatedBalances` si alguna divisa no es la del grupo, como `GroupDetailViewModel.recalculate`);
//  - deudas como las enseña la tarjeta y Saldos: `GroupBalanceService.shownDebts` (con «Menos pagos entre ustedes» y
//    «una sola moneda»);
//  - la banda del detalle: `GroupBalanceService.computeGroupHeaderBalance`;
//  - el resumen de la lista: `GroupBalanceService.globalSummary`.
//
//  `shared-core/src/logic/groupBalances.ts` los calcula en TypeScript y `mcp/test/groups-parity.test.ts` exige lo
//  mismo. La conversión de «una sola moneda» usa un conversor fijo con las tasas del escenario (`ratesPerUSD`): el
//  golden mide la regla de los saldos, no de dónde sale la tasa.
//
//  Dos modos, como `MCPAppParityGoldenTests`: por defecto VERIFICA; con `TEST_RUNNER_YALA_WRITE_MCP_GOLDENS=1` ESCRIBE
//  los `expected`.
//

import Foundation
import Testing

@testable import Yala

@Suite("Yala web · los saldos de Grupos cuadran con la app (golden)", .serialized)
@MainActor
struct WebGroupsParityGoldenTests {

    private static var goldenURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // YalaTests/MCP/
            .deletingLastPathComponent()  // YalaTests/
            .deletingLastPathComponent()  // raíz del repo
            .appendingPathComponent("mcp/test/golden/groups-parity.json")
    }

    private static var writeMode: Bool {
        ProcessInfo.processInfo.environment["YALA_WRITE_MCP_GOLDENS"] == "1"
    }

    private static let tolerance = 1e-6

    // MARK: - Entradas

    private struct Golden: Decodable { let scenarios: [Scenario] }

    private struct Scenario: Decodable {
        let id: String
        let ratesPerUSD: [String: Double]
        let groups: [Group]
    }

    private struct Group: Decodable {
        let id: String
        let simplifyDebts: Bool
        let singleCurrency: String?
        let me: String
        let expenses: [Expense]
        let shares: [Share]
        let settlements: [Settlement]
    }

    private struct Expense: Decodable {
        let id: String
        let amount: Double
        let currency: String
        let paidBy: String
        let isSettled: Bool
    }

    private struct Share: Decodable {
        let expenseId: String
        let member: String
        let amount: Double
    }

    private struct Settlement: Decodable {
        let from: String
        let to: String
        let amount: Double
        let currency: String
        let isConfirmed: Bool
    }

    /// Conversor fijo: `importe / tasa(from) × tasa(to)`, con las tasas por dólar del escenario.
    private struct FixedRates: CurrencyConverting {
        let perUSD: [String: Decimal]

        private func factor(_ from: String, _ to: String) -> Decimal {
            guard let f = perUSD[from], let t = perUSD[to], f != 0 else { return 1 }
            return t / f
        }
        func convert(_ amount: Decimal, from: String, to: String, on date: Date) -> Decimal {
            from == to ? amount : amount * factor(from, to)
        }
        func convertWithLatestRate(_ amount: Decimal, from: String, to: String) -> Decimal {
            from == to ? amount : amount * factor(from, to)
        }
        func convertChecked(_ amount: Decimal, from: String, to: String, on date: Date) -> (amount: Decimal, quality: RateQuality) {
            (convert(amount, from: from, to: to, on: date), .exact)
        }
        func convertCheckedWithLatestRate(_ amount: Decimal, from: String, to: String) -> (amount: Decimal, quality: RateQuality) {
            (convertWithLatestRate(amount, from: from, to: to), .exact)
        }
    }

    private enum GoldenError: Error, CustomStringConvertible {
        case bad(String)
        var description: String { if case .bad(let m) = self { return m }; return "" }
    }

    // MARK: - Test

    @Test func theWebGroupsGoldenMatchesTheApp() throws {
        let data = try Data(contentsOf: Self.goldenURL)
        let golden = try JSONDecoder().decode(Golden.self, from: data)
        guard var root = try JSONSerialization.jsonObject(with: data, options: [.mutableContainers]) as? [String: Any],
              var rawScenarios = root["scenarios"] as? [[String: Any]],
              rawScenarios.count == golden.scenarios.count
        else { throw GoldenError.bad("groups-parity.json no tiene la forma esperada") }

        #expect(!golden.scenarios.isEmpty)
        let computed = golden.scenarios.map(compute)

        if Self.writeMode {
            for i in rawScenarios.indices { rawScenarios[i]["expected"] = computed[i] }
            root["scenarios"] = rawScenarios
            let out = try JSONSerialization.data(
                withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
            try (out + Data("\n".utf8)).write(to: Self.goldenURL)
            return
        }

        for (i, scenario) in golden.scenarios.enumerated() {
            guard let expected = rawScenarios[i]["expected"], !(expected is NSNull) else {
                Issue.record("[\(scenario.id)] sin expected: genera el golden con TEST_RUNNER_YALA_WRITE_MCP_GOLDENS=1")
                continue
            }
            compare(computed[i], expected, path: scenario.id)
        }
    }

    // MARK: - Cálculo con el código de la app

    private func compute(_ scenario: Scenario) -> [String: Any] {
        let converter = FixedRates(perUSD: scenario.ratesPerUSD.mapValues { Decimal($0) })
        var perGroup: [String: Any] = [:]
        var sources: [GroupBalanceService.GroupSummarySource] = []
        var me = Set<String>()

        for group in scenario.groups {
            var expenseByID: [String: SplitExpense] = [:]
            let expenses: [SplitExpense] = group.expenses.map { e in
                let model = SplitExpense(amount: e.amount, currencyCode: e.currency, paidByMemberID: e.paidBy)
                model.isSettled = e.isSettled
                expenseByID[e.id] = model
                return model
            }
            let shares: [SplitShare] = group.shares.compactMap { s in
                guard let expense = expenseByID[s.expenseId] else { return nil }
                return SplitShare(expenseID: expense.id, memberID: s.member, amount: s.amount)
            }
            let settlements: [SplitSettlement] = group.settlements.map { s in
                let model = SplitSettlement(fromMemberID: s.from, toMemberID: s.to, amount: s.amount, currencyCode: s.currency)
                model.isConfirmed = s.isConfirmed
                return model
            }
            let source = GroupBalanceService.GroupSummarySource(
                expenses: expenses, shares: shares, settlements: settlements,
                simplifyDebts: group.simplifyDebts, singleCurrency: group.singleCurrency)
            sources.append(source)
            me.insert(group.me)

            let balances = GroupBalanceService.calculateBalances(
                expenses: expenses, shares: shares, members: [], settlements: settlements)
            var shown = balances
            if let target = group.singleCurrency, balances.contains(where: { $0.currencyCode != target }) {
                shown = GroupBalanceService.consolidatedBalances(from: balances, targetCurrency: target, converter: converter)
            }
            let debts = GroupBalanceService.shownDebts(source, converter: converter)
            let header = GroupBalanceService.computeGroupHeaderBalance(debts: debts, currentMemberID: group.me)

            perGroup[group.id] = [
                "balances": balances.map { b -> [String: Any] in
                    ["member": b.memberID, "currency": b.currencyCode,
                     "totalPaid": round6(b.totalPaid), "totalOwes": round6(b.totalOwes), "net": round6(b.netBalance)]
                },
                "balancesShown": shown.map { b -> [String: Any] in
                    ["member": b.memberID, "currency": b.currencyCode,
                     "totalPaid": round6(b.totalPaid), "totalOwes": round6(b.totalOwes), "net": round6(b.netBalance)]
                },
                "debts": debtList(debts),
                "header": [
                    "state": headerState(header.state),
                    "owedToMe": header.owedToMe.mapValues(round6),
                    "iOwe": header.iOwe.mapValues(round6),
                ] as [String: Any],
            ] as [String: Any]
        }

        let summary = GroupBalanceService.globalSummary(groups: sources, currentUserMemberIDs: me, converter: converter)
        return [
            "groups": perGroup,
            "global": [
                "owedToMe": summary.totalOwedToMe.mapValues(round6),
                "iOwe": summary.totalIOwe.mapValues(round6),
                "pendingSettlements": Double(summary.pendingSettlements),
            ] as [String: Any],
        ]
    }

    /// Ordenadas por divisa, deudor y acreedor: el orden de la app sale de un diccionario.
    private func debtList(_ debts: [Debt]) -> [[String: Any]] {
        debts
            .sorted { ($0.currencyCode, $0.fromMemberID, $0.toMemberID) < ($1.currencyCode, $1.fromMemberID, $1.toMemberID) }
            .map { ["from": $0.fromMemberID, "to": $0.toMemberID, "amount": round6($0.amount), "currency": $0.currencyCode] }
    }

    private func headerState(_ state: GroupHeaderBalance.State) -> String {
        switch state {
        case .theyOweMe: return "theyOweMe"
        case .iOwe: return "iOwe"
        case .mixed: return "mixed"
        case .settled: return "settled"
        }
    }

    private func round6(_ v: Double) -> Double {
        guard v.isFinite else { return 0 }
        let r = (v * 1_000_000).rounded() / 1_000_000
        return r == 0 ? 0 : r
    }

    private func compare(_ got: Any?, _ want: Any?, path: String) {
        switch (got, want) {
        case (let g as [String: Any], let w as [String: Any]):
            for key in Set(g.keys).union(w.keys).sorted() { compare(g[key], w[key], path: "\(path).\(key)") }
        case (let g as [Any], let w as [Any]):
            guard g.count == w.count else {
                Issue.record("\(path): \(g.count) elementos, el golden tiene \(w.count)")
                return
            }
            for i in g.indices { compare(g[i], w[i], path: "\(path)[\(i)]") }
        case (let g as Double, let w as NSNumber):
            #expect(abs(g - w.doubleValue) <= Self.tolerance, "\(path): la app da \(g), el golden \(w.doubleValue)")
        case (let g as String, let w as String):
            #expect(g == w, "\(path): la app da \(g), el golden \(w)")
        default:
            Issue.record("\(path): la app da \(String(describing: got)), el golden \(String(describing: want))")
        }
    }
}
