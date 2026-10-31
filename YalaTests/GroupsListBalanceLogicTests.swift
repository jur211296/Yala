//
//  GroupsListBalanceLogicTests.swift
//  YalaTests
//
//  El resumen y las tarjetas de la lista de Grupos (decisión de Jürgen, 2026-10-30): el neto en la moneda principal
//  del aviso morado (signo, cero, una y varias divisas, tasa aproximada) y las filas por persona de cada tarjeta
//  (primero lo que debes, de mayor a menor, como mucho tres y «y N más»).
//

import Foundation
import Testing
@testable import Yala

@Suite("Lista de Grupos · neto en la moneda principal y filas por persona")
@MainActor
struct GroupsListBalanceLogicTests {

    /// 1 USD = 3,40 PEN; cualquier otra divisa, 1:1. Las tasas que no son de PEN a PEN salen con la calidad pedida.
    private struct Conversor: CurrencyConverting {
        var quality: RateQuality = .exact
        private func rate(_ from: String, _ to: String) -> Decimal {
            switch (from, to) {
            case ("USD", "PEN"): Decimal(34) / 10
            case ("PEN", "USD"): 10 / Decimal(34)
            case ("JPY", "PEN"): Decimal(1) / 100
            default: 1
            }
        }
        func convert(_ amount: Decimal, from: String, to: String, on date: Date) -> Decimal { amount * rate(from, to) }
        func convertWithLatestRate(_ amount: Decimal, from: String, to: String) -> Decimal { amount * rate(from, to) }
        func convertChecked(_ amount: Decimal, from: String, to: String, on date: Date)
            -> (amount: Decimal, quality: RateQuality) { (amount * rate(from, to), quality) }
        func convertCheckedWithLatestRate(_ amount: Decimal, from: String, to: String)
            -> (amount: Decimal, quality: RateQuality) { (amount * rate(from, to), quality) }
    }

    private func net(_ owed: [String: Double], _ owe: [String: Double], main: String = "PEN",
                     quality: RateQuality = .exact) -> GroupsListBalanceLogic.Net? {
        GroupsListBalanceLogic.net(owedToMe: owed, iOwe: owe, mainCurrency: main, converter: Conversor(quality: quality))
    }

    // MARK: - Neto

    @Test("Sin nada pendiente no hay aviso")
    func nothingPending_isNil() {
        #expect(net([:], [:]) == nil)
        #expect(net(["PEN": 0.004], ["USD": 0.01]) == nil, "los restos de menos de un céntimo no cuentan")
    }

    @Test("Una divisa: el signo dice quién debe a quién")
    func singleCurrency_sign() throws {
        let owed = try #require(net(["PEN": 50], [:]))
        #expect(owed.direction == .owedToMe)
        #expect(owed.amount == 50)
        #expect(owed.currencyCode == "PEN")
        let owe = try #require(net([:], ["PEN": 20]))
        #expect(owe.direction == .iOwe)
        #expect(owe.amount == 20, "el importe va siempre en positivo")
    }

    @Test("Varias divisas: el caso de las propuestas da S/ 566.81 que debes")
    func severalCurrencies_matchesTheMockups() throws {
        // Debes S/ 11,118.52; te deben $ 3,035.65 + S/ 230.50 → 230.50 + 3,035.65 × 3.4 − 11,118.52 = −566.81.
        let result = try #require(net(["USD": 3035.65, "PEN": 230.50], ["PEN": 11118.52]))
        #expect(result.direction == .iOwe)
        #expect(abs(result.amount - 566.81) < 0.005, "\(result.amount)")
        #expect(result.isEstimate == false)
    }

    @Test("Lo que debes y lo que te deben se compensan: texto neutro")
    func balanced_isEven() throws {
        let result = try #require(net(["USD": 10], ["PEN": 34]))
        #expect(result.direction == .even)
        #expect(result.amount == 0)
        #expect(GroupsListBalanceLogic.netText(result, currencySymbol: "S/", formattedAmount: "S/ 0.00")
                == L10n.Groups.Hero.netEven("S/"))
    }

    @Test("Un solo lado que al convertirlo baja del céntimo no dice «se compensan»: no hay aviso")
    func singleTinySide_isNotEven() {
        #expect(net(["JPY": 0.4], [:]) == nil)
        #expect(net([:], ["JPY": 0.4]) == nil)
    }

    @Test("Una tasa que no es la del día marca el neto como aproximado; la divisa principal no se convierte")
    func estimate_onlyWhenSomethingWasConverted() throws {
        #expect(try #require(net(["USD": 10], [:], quality: .staticFallback)).isEstimate)
        #expect(try #require(net(["PEN": 10], [:], quality: .staticFallback)).isEstimate == false)
    }

    @Test("El texto elige la frase por el signo")
    func text_followsTheDirection() throws {
        let owed = try #require(net(["PEN": 50], [:]))
        let owe = try #require(net([:], ["PEN": 50]))
        #expect(GroupsListBalanceLogic.netText(owed, currencySymbol: "S/", formattedAmount: "S/ 50.00")
                == L10n.Groups.Hero.netOwedToMe("S/", "S/ 50.00"))
        #expect(GroupsListBalanceLogic.netText(owe, currencySymbol: "S/", formattedAmount: "S/ 50.00")
                == L10n.Groups.Hero.netIOwe("S/", "S/ 50.00"))
        #expect(L10n.Groups.Hero.netIOwe("S/", "S/ 50.00") != L10n.Groups.Hero.netOwedToMe("S/", "S/ 50.00"))
    }

    // MARK: - Filas por persona

    private func row(_ name: String, _ amount: Double, _ perspective: GroupsViewModel.Perspective,
                     _ currency: String = "PEN") -> GroupsViewModel.DebtRow {
        GroupsViewModel.DebtRow(id: "\(name)-\(currency)-\(perspective)", counterpartyName: name, amount: amount,
                                currencyCode: currency, perspective: perspective, wasConverted: false)
    }

    @Test("Primero lo que debes, cada lado de mayor a menor")
    func personRows_oweFirstThenByAmount() {
        let rows = GroupsListBalanceLogic.personRows([
            row("Ana", 120, .theyOweMe), row("Diego", 30, .iOwe), row("Beto", 85.5, .theyOweMe), row("Eva", 300, .iOwe),
        ], limit: 10)
        #expect(rows.shown.map(\.counterpartyName) == ["Eva", "Diego", "Ana", "Beto"])
        #expect(rows.hiddenCount == 0)
    }

    @Test("Como mucho tres; el resto cuenta para «y N más»")
    func personRows_capsAtThree() {
        let rows = GroupsListBalanceLogic.personRows([
            row("Diego", 30, .iOwe), row("Ana", 120, .theyOweMe), row("Beto", 85.5, .theyOweMe),
            row("Carla", 40, .theyOweMe), row("Eva", 10, .theyOweMe),
        ])
        #expect(rows.shown.map(\.counterpartyName) == ["Diego", "Ana", "Beto"])
        #expect(rows.hiddenCount == 2)
    }

    @Test("La misma persona en dos divisas sale dos veces; los empates no bailan")
    func personRows_stableTies() {
        let rows = GroupsListBalanceLogic.personRows([
            row("Pía", 10, .theyOweMe, "USD"), row("Pía", 10, .theyOweMe, "PEN"), row("Ana", 10, .theyOweMe),
        ])
        #expect(rows.shown.map { "\($0.counterpartyName) \($0.currencyCode)" } == ["Ana PEN", "Pía PEN", "Pía USD"])
    }

    @Test("Sin deudas, ni filas ni «y N más»")
    func personRows_empty() {
        let rows = GroupsListBalanceLogic.personRows([row("Ana", 0.001, .theyOweMe)])
        #expect(rows.shown.isEmpty)
        #expect(rows.hiddenCount == 0)
    }
}
