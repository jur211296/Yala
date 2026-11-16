//
//  PanelMoneyFigureTests.swift
//  YalaTests
//
//  Encargo del 2026-11-16 («el saldo en grande, tu dinero en chico»). Las dos cifras del hero del Panel:
//  - «Tu saldo hoy»: todas las cuentas, tarjetas incluidas, con su signo.
//  - «Tu dinero hoy»: lo mismo sin las cuentas que no cuentan como dinero (por defecto, las tarjetas de crédito).
//  Los casos que pidió el encargo: saldo positivo, saldo negativo con tarjeta, cuenta excluida, valores por defecto por
//  tipo de cuenta y varias monedas. El fixture lleva siempre una tarjeta: sin ella las dos cifras coinciden y ningún caso
//  distinguiría la regla buena de la mala.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Panel · «Tu saldo hoy» y «Tu dinero hoy»")
struct PanelMoneyFigureTests {

    // MARK: - Fixture

    private func account(_ name: String, _ type: AccountType, currency: String = "PEN", exclude: Bool = false) -> Account {
        Account(
            name: name, currencyCode: currency, colorHex: "#6366F1", iconName: "creditcard",
            type: type.rawValue, excludeFromStatistics: exclude
        )
    }

    private func movement(_ amount: Double, _ account: Account, daysAgo: Int = 1) -> TransactionItem {
        TransactionItem(
            date: Date.now.addingTimeInterval(TimeInterval(-86_400 * daysAgo)),
            amount: amount, currencyCode: account.currencyCode, note: "",
            account: account, tags: [],
            amountInPreferredCurrency: amount, preferredCurrencyCode: account.currencyCode
        )
    }

    private func ids(_ accounts: [Account]) -> Set<PersistentIdentifier> {
        Set(accounts.map(\.persistentModelID))
    }

    /// El saldo grande, con el mismo cálculo que usa el Panel (`LiveBalanceCalculator`).
    private func balance(_ accounts: [Account], _ movements: [TransactionItem], converter: MockCurrencyConverter = .init()) -> Double {
        let breakdown = LiveBalanceCalculator.liveBalanceBreakdown(
            accounts: accounts, transactions: movements, preferredCurrencyCode: "PEN", converter: converter
        )
        return (breakdown.convertedTotal as NSDecimalNumber).doubleValue
    }

    private func money(
        _ accounts: [Account], _ movements: [TransactionItem], overrides: [UUID: Bool] = [:],
        total: Set<PersistentIdentifier>? = nil, converter: MockCurrencyConverter = .init()
    ) -> Double {
        let breakdown = PanelMoneyScopeLogic.moneyBreakdown(
            accounts: accounts, totalAccountIDs: total ?? ids(accounts), overrides: overrides,
            transactions: movements, preferredCurrencyCode: "PEN", converter: converter
        )
        return (breakdown.convertedTotal as NSDecimalNumber).doubleValue
    }

    // MARK: - Saldo positivo

    @Test("Saldo positivo: la grande resta la tarjeta y la chica no la cuenta")
    func positiveBalance() {
        let savings = account("Ahorros", .savings)
        let card = account("Visa", .creditCard)
        let movements = [movement(2_000, savings), movement(-300, card)]

        #expect(balance([savings, card], movements) == 1_700)
        #expect(money([savings, card], movements) == 2_000)
        #expect(PanelHeroFigureLogic.bigFigureValue(totalBalance: 1_700) == 1_700)
    }

    // MARK: - Saldo negativo con tarjeta

    @Test("Saldo negativo: la cifra grande sale con su signo, sin rótulo de deuda, y la chica sigue en positivo")
    func negativeBalanceWithCard() {
        let cash = account("Efectivo", .cash)
        let card = account("Visa", .creditCard)
        let movements = [movement(400, cash), movement(-1_250, card)]

        let total = balance([cash, card], movements)
        #expect(total == -850)
        // La cifra grande es el saldo tal cual: con el menos delante. Antes salía sin signo y con «Debes hoy».
        #expect(PanelHeroFigureLogic.bigFigureValue(totalBalance: total) == -850)
        #expect(money([cash, card], movements) == 400)
    }

    // MARK: - Cuenta excluida

    @Test("Una cuenta que la persona apaga sale de «Tu dinero hoy» y no del saldo")
    func excludedAccount() {
        let checking = account("Corriente", .checking)
        let savings = account("Ahorros", .savings)
        let movements = [movement(1_000, checking), movement(5_000, savings)]
        let overrides = [savings.shortcutID: false]

        #expect(balance([checking, savings], movements) == 6_000)
        #expect(money([checking, savings], movements, overrides: overrides) == 1_000)
        #expect(PanelMoneyScopeLogic.showsMoneyLine([checking, savings], totalAccountIDs: ids([checking, savings]), overrides: overrides))
    }

    @Test("Una tarjeta que la persona enciende suma también en «Tu dinero hoy»")
    func cardTurnedOn() {
        let savings = account("Ahorros", .savings)
        let card = account("Visa", .creditCard)
        let movements = [movement(2_000, savings), movement(-300, card)]
        let overrides = [card.shortcutID: true]

        #expect(money([savings, card], movements, overrides: overrides) == 1_700)
        #expect(!PanelMoneyScopeLogic.showsMoneyLine([savings, card], totalAccountIDs: ids([savings, card]), overrides: overrides),
                "Con todo encendido las dos cifras son la misma: la línea chica no se pinta.")
    }

    @Test("Excluida de las estadísticas o fuera del filtro de cuentas, no suma en ninguna de las dos")
    func outsideTheBalance() {
        let savings = account("Ahorros", .savings)
        let hidden = account("Oculta", .savings, exclude: true)
        let card = account("Visa", .creditCard)
        let movements = [movement(2_000, savings), movement(9_000, hidden), movement(-300, card)]

        // `sumsInBalance` deja fuera la excluida aunque su tipo cuente.
        #expect(money([savings, hidden, card], movements) == 2_000)
        // Con el Panel filtrado a la tarjeta, «Tu dinero hoy» se queda en 0: no se escapa a las otras cuentas.
        #expect(money([savings, hidden, card], movements, total: ids([card])) == 0)
    }

    @Test("Sin tarjetas, la línea chica no sale: repetiría la cifra grande")
    func noCardNoLine() {
        let savings = account("Ahorros", .savings)
        let cash = account("Efectivo", .cash)
        #expect(!PanelMoneyScopeLogic.showsMoneyLine([savings, cash], totalAccountIDs: ids([savings, cash]), overrides: [:]))
        // Una tarjeta fuera del saldo grande (filtrada) tampoco la enciende.
        let card = account("Visa", .creditCard)
        #expect(!PanelMoneyScopeLogic.showsMoneyLine([savings, card], totalAccountIDs: ids([savings]), overrides: [:]))
        #expect(PanelMoneyScopeLogic.showsMoneyLine([savings, card], totalAccountIDs: ids([savings, card]), overrides: [:]))
    }

    // MARK: - Varias monedas

    @Test("Varias monedas: cada saldo pasa a la moneda principal al cambio de hoy, también en la cifra chica")
    func severalCurrencies() {
        let soles = account("Ahorros", .savings, currency: "PEN")
        let dollars = account("Dólares", .savings, currency: "USD")
        let card = account("Visa USD", .creditCard, currency: "USD")
        let movements = [movement(1_000, soles), movement(200, dollars), movement(-50, card)]
        var converter = MockCurrencyConverter()
        converter.fixedRate = 3.75

        // Saldo: 1.000 + (200 − 50) × 3,75 = 1.562,50. Dinero: 1.000 + 200 × 3,75 = 1.750.
        #expect(balance([soles, dollars, card], movements, converter: converter) == 1_562.5)
        #expect(money([soles, dollars, card], movements, converter: converter) == 1_750)
    }

    @Test("La línea en dólares de una tarjeta sigue a su tarjeta")
    func cardLineFollowsItsCard() {
        let savings = account("Ahorros", .savings)
        let card = account("Visa", .creditCard)
        let line = account("Visa · USD", .creditCard, currency: "USD")
        line.parentAccountID = card.shortcutID
        let movements = [movement(2_000, savings), movement(-100, card), movement(-20, line)]
        var converter = MockCurrencyConverter()
        converter.fixedRate = 4

        #expect(money([savings, card, line], movements, converter: converter) == 2_000)
        // Encender la tarjeta enciende también su línea: el ajuste es de la tarjeta.
        let on = [card.shortcutID: true]
        #expect(money([savings, card, line], movements, overrides: on, converter: converter) == 2_000 - 100 - 80)
        // La lista de interruptores no enseña la línea.
        let switchable = PanelMoneyScopeLogic.switchableAccounts([savings, card, line])
        #expect(switchable.map(\.name) == ["Ahorros", "Visa"])
    }

    @Test("Un movimiento con fecha futura no entra en ninguna de las dos cifras")
    func futureMovementsStayOut() {
        let savings = account("Ahorros", .savings)
        let card = account("Visa", .creditCard)
        let movements = [movement(2_000, savings), movement(500, savings, daysAgo: -3), movement(-300, card)]
        #expect(balance([savings, card], movements) == 1_700)
        #expect(money([savings, card], movements) == 2_000)
    }
}
