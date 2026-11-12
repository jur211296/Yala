//
//  GroupsListBalanceLogicTests.swift
//  YalaTests
//
//  El resumen y las tarjetas de la lista de Grupos: el neto en la moneda principal de la cifra grande (signo, cero, una
//  y varias divisas, tasa aproximada), la barra y las líneas por divisa de cada lado (propuesta 2 de Jürgen,
//  2026-11-03: como mucho tres líneas) y las filas por persona de cada tarjeta (2026-10-30).
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
        #expect(GroupsListBalanceLogic.netCaption(result.direction, currencySymbol: "S/") == L10n.Groups.Hero.netEven("S/"))
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

    @Test("El rótulo de la cifra grande elige la frase por el signo")
    func caption_followsTheDirection() throws {
        let owed = try #require(net(["PEN": 50], [:]))
        let owe = try #require(net([:], ["PEN": 50]))
        #expect(GroupsListBalanceLogic.netCaption(owed.direction, currencySymbol: "S/")
                == L10n.Groups.Hero.netOwedToMe("S/"))
        #expect(GroupsListBalanceLogic.netCaption(owe.direction, currencySymbol: "S/") == L10n.Groups.Hero.netIOwe("S/"))
        #expect(L10n.Groups.Hero.netIOwe("S/") != L10n.Groups.Hero.netOwedToMe("S/"))
        #expect(L10n.Groups.Hero.netIOwe("S/").contains("S/"), "el rótulo nombra la moneda principal")
    }

    // MARK: - Barra y líneas por divisa

    @Test("Cada lado se pasa a la moneda principal; la barra reparte por lo que pesa cada uno")
    func totals_andShare() throws {
        let c = Conversor()
        #expect(abs(GroupsListBalanceLogic.total(["USD": 10, "PEN": 6], mainCurrency: "PEN", converter: c) - 40) < 0.001)
        #expect(GroupsListBalanceLogic.total([:], mainCurrency: "PEN", converter: c) == 0)
        #expect(GroupsListBalanceLogic.total(["PEN": 0.004], mainCurrency: "PEN", converter: c) == 0,
                "los restos de menos de un céntimo no pesan")
        let share = try #require(GroupsListBalanceLogic.oweShare(iOweInMain: 30, owedInMain: 10))
        #expect(abs(share - 0.75) < 0.0001)
        #expect(GroupsListBalanceLogic.oweShare(iOweInMain: 0, owedInMain: 10) == 0)
        #expect(GroupsListBalanceLogic.oweShare(iOweInMain: 5, owedInMain: 0) == 1)
        #expect(GroupsListBalanceLogic.oweShare(iOweInMain: 0, owedInMain: 0) == nil, "sin nada, no hay barra")
    }

    @Test("Hasta tres divisas salen todas, de mayor a menor en la moneda principal")
    func sideLines_upToThree() {
        let c = Conversor()
        // $ 10 = S/ 34 pesa más que S/ 20 aunque el número sea menor.
        let lines = GroupsListBalanceLogic.sideLines(["PEN": 20, "USD": 10, "EUR": 5], mainCurrency: "PEN", converter: c)
        #expect(lines.shown.map(\.currencyCode) == ["USD", "PEN", "EUR"])
        #expect(lines.hiddenCount == 0)
    }

    @Test("Con cuatro o más divisas: las dos mayores y «y N más» como tercera línea")
    func sideLines_capsAtThreeLines() {
        let c = Conversor()
        let four = GroupsListBalanceLogic.sideLines(["PEN": 20, "USD": 10, "EUR": 5, "MXN": 1], mainCurrency: "PEN",
                                                   converter: c)
        #expect(four.shown.map(\.currencyCode) == ["USD", "PEN"])
        #expect(four.hiddenCount == 2)
        let five = GroupsListBalanceLogic.sideLines(["PEN": 20, "USD": 10, "EUR": 5, "MXN": 1, "COP": 2],
                                                   mainCurrency: "PEN", converter: c)
        #expect(five.shown.count + (five.hiddenCount > 0 ? 1 : 0) == 3, "nunca más de tres líneas")
        #expect(five.hiddenCount == 3)
    }

    @Test("Un lado vacío no tiene líneas; los empates no bailan")
    func sideLines_emptyAndTies() {
        let c = Conversor()
        #expect(GroupsListBalanceLogic.sideLines([:], mainCurrency: "PEN", converter: c).shown.isEmpty)
        let ties = GroupsListBalanceLogic.sideLines(["EUR": 5, "CHF": 5], mainCurrency: "PEN", converter: c)
        #expect(ties.shown.map(\.currencyCode) == ["CHF", "EUR"])
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
