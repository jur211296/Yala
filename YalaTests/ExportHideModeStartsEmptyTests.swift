//
//  ExportHideModeStartsEmptyTests.swift
//  YalaTests
//
//  Card k4iz (opción A de Jürgen, 2026-10-30): el asistente de Exportar arranca con todo marcado y en «Ocultar» lo
//  marcado DESAPARECE, así que elegir «Ocultar» sin tocar nada daba «Ninguno con estos filtros». Al pasar a «Ocultar» se
//  vacía lo marcado: sin tocar nada se exporta todo, y lo que se marque después es lo que se quita.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite(.serialized)
@MainActor
struct ExportHideModeStartsEmptyTests {

    typealias Logic = ExportRecordsLogic

    // MARK: - La lógica del cambio de modo

    @Test func switchingToHide_marksNothing_andBack_marksEverything() {
        let all: Set<Int> = [1, 2, 3]
        #expect(Logic.marks(afterSwitchingToHide: true, all: all).isEmpty)
        #expect(Logic.marks(afterSwitchingToHide: false, all: all) == all)
    }

    @Test func hideMode_withNothingMarked_canExport() {
        #expect(Logic.hasAccountsToExport(markedAccounts: 0, isExcludeMode: true))
        #expect(!Logic.hasAccountsToExport(markedAccounts: 0, isExcludeMode: false))
        #expect(Logic.hasAccountsToExport(markedAccounts: 2, isExcludeMode: false))
    }

    @Test func allMarked_collapsesOnlyWhenShowing() {
        #expect(Logic.effectiveMarks(["a", "b"], allCount: 2, isExcludeMode: false).isEmpty, "Todas = sin filtro.")
        #expect(Logic.effectiveMarks(["a", "b"], allCount: 2, isExcludeMode: true) == ["a", "b"], "Todas = ocultar todas.")
        #expect(Logic.effectiveMarks(["a"], allCount: 2, isExcludeMode: false) == ["a"])
        #expect(Logic.effectiveMarks([String](), allCount: 2, isExcludeMode: true).isEmpty)
    }

    @Test func statusSaysNone_onlyInHideModeWithNothingMarked() {
        #expect(Logic.showsNoneMarked(marked: 0, isExcludeMode: true))
        #expect(!Logic.showsNoneMarked(marked: 0, isExcludeMode: false))
        #expect(!Logic.showsNoneMarked(marked: 1, isExcludeMode: true))
    }

    /// En «Ocultar», nada marcado no recorta; todo marcado, sí.
    @Test func activeFilters_inHideMode_countWhatIsMarked() {
        func active(accounts: Int, needs: Int) -> [Logic.ActiveFilter] {
            Logic.activeFilters(
                markedAccounts: accounts, offeredAccounts: 2,
                selectedSubcategories: 0, visibleSubcategories: 10,
                selectedTags: 0, allTags: 2,
                selectedNeeds: needs, allNeeds: 4,
                selectedCurrencies: [], availableCurrencies: 2,
                amountIsActive: false, note: "", isExcludeMode: true)
        }
        #expect(active(accounts: 0, needs: 0) == [.hidingSelected])
        #expect(active(accounts: 2, needs: 4) == [.accounts(2), .needs(4), .hidingSelected])
    }

    // MARK: - Lo que sale

    private struct Fixture {
        let viewModel: ExportFiltersStepViewModel
        let soles: Account
        let dollars: Account
        let transactions: [TransactionItem]
    }

    private func fixture() throws -> Fixture {
        let context = try makeTestContext()
        let soles = Account(name: "Soles QA", currencyCode: "PEN", colorHex: "#3D36B3", iconName: "banknote", type: "bank")
        let dollars = Account(name: "Dólares QA", currencyCode: "USD", colorHex: "#FF7F11", iconName: "dollarsign.circle.fill", type: "savings")
        [soles, dollars].forEach { context.insert($0) }
        let lunch = TransactionItem(date: .now, amount: -20, currencyCode: "PEN")
        lunch.account = soles
        lunch.needOverride = SubcategoryNeed.essential.rawValue
        let cinema = TransactionItem(date: .now, amount: -15, currencyCode: "PEN")
        cinema.account = soles
        cinema.needOverride = SubcategoryNeed.optional.rawValue
        let savings = TransactionItem(date: .now, amount: 100, currencyCode: "USD")
        savings.account = dollars
        [lunch, cinema, savings].forEach { context.insert($0) }
        try context.save()
        let viewModel = ExportFiltersStepViewModel()
        viewModel.setContext(context)
        return Fixture(viewModel: viewModel, soles: soles, dollars: dollars, transactions: [lunch, cinema, savings])
    }

    /// Los filtros que arma el asistente, con la regla de necesidades de la vista.
    private func exported(
        _ f: Fixture, accounts: Set<PersistentIdentifier>, needs: Set<SubcategoryNeed>,
        currencies: Set<CurrencyCode>, hiding: Bool
    ) -> [TransactionItem] {
        var filters = f.viewModel.buildExportFilters(
            selectedAccounts: accounts, selectedSubcategories: [], selectedTags: [],
            selectedCurrencies: currencies, amountCondition: .any, selectedPeriod: .allTime,
            customDateRange: nil, noteContains: "", isExcludeMode: hiding)
        filters.selectedNeeds = Logic.effectiveMarks(
            SubcategoryNeed.allCases.filter { needs.contains($0) },
            allCount: SubcategoryNeed.allCases.count, isExcludeMode: hiding)
        return TransactionsExportService.applyInMemoryFilters(f.transactions, filters: filters)
    }

    /// El escenario del ticket: lo que viene marcado, en «Ocultar», no exporta nada. Control: sin él, el caso de abajo no
    /// probaría nada.
    @Test func hideMode_withTheOpeningMarks_exportsNothing() throws {
        let f = try fixture()
        let accounts = f.viewModel.initialAccountSelection
        let out = exported(f, accounts: accounts, needs: Set(SubcategoryNeed.allCases),
                           currencies: Set(f.viewModel.availableCurrencies(selectedAccounts: accounts)), hiding: true)
        #expect(out.isEmpty)
    }

    @Test func hideMode_untouched_exportsEverything() throws {
        let f = try fixture()
        let empty: Set<PersistentIdentifier> = Logic.marks(afterSwitchingToHide: true, all: f.viewModel.initialAccountSelection)
        let out = exported(f, accounts: empty,
                           needs: Logic.marks(afterSwitchingToHide: true, all: Set(SubcategoryNeed.allCases)),
                           currencies: Logic.marks(afterSwitchingToHide: true, all: Set(CurrencyCode.allCases)), hiding: true)
        #expect(out.count == f.transactions.count)
    }

    @Test func hideMode_whatYouMarkAfterwards_isWhatGoes() throws {
        let f = try fixture()
        let onlyDollars = exported(f, accounts: [f.soles.persistentModelID], needs: [], currencies: [], hiding: true)
        #expect(onlyDollars.map(\.amount) == [100])

        let withoutOptional = exported(f, accounts: [], needs: [.optional], currencies: [], hiding: true)
        #expect(withoutOptional.count == 2)

        let allNeedsHidden = exported(f, accounts: [], needs: Set(SubcategoryNeed.allCases), currencies: [], hiding: true)
        #expect(allNeedsHidden.isEmpty, "Ocultar todas las necesidades oculta todo, no deja de filtrar.")
    }

    /// Lo que se ofrece en «Ocultar» con nada oculto: las monedas de las cuentas, no las 54.
    @Test func hideMode_untouched_offersTheCurrenciesOfTheAccounts() throws {
        let f = try fixture()
        #expect(f.viewModel.currenciesLeftInView(hiding: []) == CurrencyCode.allCases.filter { [.pen, .usd].contains($0) })
    }
}
