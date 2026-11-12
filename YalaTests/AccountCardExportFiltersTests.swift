//
//  AccountCardExportFiltersTests.swift
//  YalaTests
//
//  Tarjeta con varias divisas, entrega 4 · Paso 0 D4: el filtro de cuentas del asistente de exportación enseña cada
//  tarjeta una vez y no ofrece las cuentas de Grupos; elegir la tarjeta mete sus líneas y el filtro de divisas ofrece las
//  de todas. Los movimientos de Grupos salen con TODO marcado (la copia completa sigue siendo completa) y no al elegir una
//  cuenta concreta.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite(.serialized)
@MainActor
struct AccountCardExportFiltersTests {

    private struct Fixture {
        let viewModel: ExportFiltersStepViewModel
        let card: Account
        let line: Account
        let dollars: Account
        let groups: Account
    }

    private func fixture() throws -> Fixture {
        let context = try makeTestContext()
        let card = Account(name: "Visa QA", currencyCode: "PEN", colorHex: "#3D36B3", iconName: "creditcard.fill", type: "creditCard")
        let line = Account(name: "Visa QA · USD", currencyCode: "USD", colorHex: "#3D36B3", iconName: "creditcard.fill", type: "creditCard")
        line.parentAccountID = card.shortcutID
        let dollars = Account(name: "Dólares QA", currencyCode: "USD", colorHex: "#FF7F11", iconName: "dollarsign.circle.fill", type: "savings")
        let groups = Account(name: "Grupos EUR", currencyCode: "EUR", colorHex: "#888888", iconName: "person.2.fill", type: "bank")
        groups.isSystemAccount = true
        [card, line, dollars, groups].forEach { context.insert($0) }
        try context.save()
        let viewModel = ExportFiltersStepViewModel()
        viewModel.setContext(context)
        return Fixture(viewModel: viewModel, card: card, line: line, dollars: dollars, groups: groups)
    }

    private func ids(_ accounts: [Account]) -> Set<PersistentIdentifier> { Set(accounts.map(\.persistentModelID)) }

    @Test("Ofrece cada tarjeta una vez y ninguna cuenta de Grupos")
    func offersEachCardOnceWithoutSystemAccounts() throws {
        let f = try fixture()
        #expect(f.viewModel.offeredAccounts.map(\.name) == ["Dólares QA", "Visa QA"])
    }

    @Test("La partida marca todo menos Grupos, y lo que exporta incluye Grupos")
    func initialSelectionExportsEverything() throws {
        let f = try fixture()
        let initial = f.viewModel.initialAccountSelection
        #expect(initial == ids([f.card, f.line, f.dollars]))
        #expect(ids(f.viewModel.exportedAccounts(selectedAccounts: initial)) == ids([f.card, f.line, f.dollars, f.groups]))
        #expect(f.viewModel.selectedAccountsText(selectedAccounts: initial) == L10n.Filters.allAccounts)
    }

    @Test("Quitar la tarjeta quita sus líneas, y con una sola cuenta elegida Grupos no sale")
    func togglingTheCardTakesItsLines() throws {
        let f = try fixture()
        let withoutCard = f.viewModel.toggling(f.card, in: f.viewModel.initialAccountSelection)
        #expect(withoutCard == ids([f.dollars]))
        #expect(ids(f.viewModel.exportedAccounts(selectedAccounts: withoutCard)) == ids([f.dollars]))
        #expect(f.viewModel.selectedAccountsText(selectedAccounts: withoutCard) == L10n.Filters.selectedCount(1))

        let onlyCard = f.viewModel.toggling(f.card, in: [])
        #expect(onlyCard == ids([f.card, f.line]))
        #expect(f.viewModel.selectedAccountsText(selectedAccounts: onlyCard) == L10n.Filters.selectedCount(1))
    }

    @Test("Elegir la tarjeta ofrece las divisas de todas sus líneas")
    func cardOffersTheCurrenciesOfAllItsLines() throws {
        let f = try fixture()
        let onlyCard = f.viewModel.toggling(f.card, in: [])
        #expect(f.viewModel.availableCurrencies(selectedAccounts: onlyCard) == CurrencyCode.allCases.filter { [.pen, .usd].contains($0) })
        // Con todo marcado, también la divisa de la cuenta de Grupos (sus movimientos se exportan).
        let all = f.viewModel.availableCurrencies(selectedAccounts: f.viewModel.initialAccountSelection)
        #expect(Set(all) == [.pen, .usd, .eur])
    }

    @Test("Los filtros que llegan al servicio llevan la tarjeta con su línea")
    func exportFiltersCarryTheLines() throws {
        let f = try fixture()
        let filters = f.viewModel.buildExportFilters(
            selectedAccounts: f.viewModel.toggling(f.card, in: []), selectedSubcategories: [], selectedTags: [],
            selectedCurrencies: [], amountCondition: .any, selectedPeriod: .last30Days, customDateRange: nil,
            noteContains: "")
        #expect(ids(filters.selectedAccounts) == ids([f.card, f.line]))
    }

    @Test("Sin ninguna cuenta propia, ofrece las de Grupos como antes y se pueden exportar")
    func onlySystemAccounts_areOffered() throws {
        let context = try makeTestContext()
        let groups = Account(name: "Grupos PEN", currencyCode: "PEN", colorHex: "#888888", iconName: "person.2.fill", type: "bank")
        groups.isSystemAccount = true
        context.insert(groups)
        try context.save()
        let viewModel = ExportFiltersStepViewModel()
        viewModel.setContext(context)
        #expect(viewModel.offeredAccounts.map(\.name) == ["Grupos PEN"])
        let initial = viewModel.initialAccountSelection
        #expect(initial == ids([groups]))
        #expect(ids(viewModel.exportedAccounts(selectedAccounts: initial)) == ids([groups]))
        #expect(viewModel.exportedAccounts(selectedAccounts: []).isEmpty)
    }
}
