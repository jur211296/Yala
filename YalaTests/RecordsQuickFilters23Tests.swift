//
//  RecordsQuickFilters23Tests.swift
//  YalaTests
//
//  Revisión 2.3, decisiones 15 y 16: el resumen de Categorías nombra el grupo elegido (no «Delivery +3»), la banda de
//  filtros cuenta lo que pinta y trae «Quitar todo» con un solo filtro, y «Borrar filtros» deja de existir en pantalla.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite(.serialized)
struct RecordsQuickFilters23Tests {

    // MARK: - Resumen de Categorías (punto 3)

    /// Elegir Alimentación entera decía «Delivery +3» (la primera subcategoría y el resto). Ahora dice «Alimentación».
    @MainActor @Test func wholeCategoryChosen_summaryNamesTheCategory() throws {
        let ctx = try makeTestContext()
        let food = makeTestCategory(context: ctx, name: "Alimentación")
        let subs = ["Delivery", "Restaurantes", "Suplementos", "Supermercados"].map {
            makeTestSubcategory(context: ctx, name: $0, category: food)
        }
        let transport = makeTestCategory(context: ctx, name: "Transporte")
        _ = makeTestSubcategory(context: ctx, name: "Taxi", category: transport)
        try ctx.save()

        let vm = RecordsFiltersViewModel()
        vm.setContext(ctx)

        let text = vm.selectedCategoriesText(selectedSubcategories: Set(subs.map(\.persistentModelID)))
        #expect(text == "Alimentación")
    }

    /// Una subcategoría suelta sigue diciendo su nombre, y dos grupos dicen el primero y «+1».
    @MainActor @Test func partialAndTwoGroups_summaryNamesWhatWasChosen() throws {
        let ctx = try makeTestContext()
        let food = makeTestCategory(context: ctx, name: "Alimentación")
        let delivery = makeTestSubcategory(context: ctx, name: "Delivery", category: food)
        let restaurants = makeTestSubcategory(context: ctx, name: "Restaurantes", category: food)
        let transport = makeTestCategory(context: ctx, name: "Transporte")
        let taxi = makeTestSubcategory(context: ctx, name: "Taxi", category: transport)
        // Algo sin elegir: con todo elegido, el resumen dice «Todas las categorías».
        _ = makeTestSubcategory(context: ctx, name: "Luz", category: makeTestCategory(context: ctx, name: "Hogar"))
        try ctx.save()

        let vm = RecordsFiltersViewModel()
        vm.setContext(ctx)

        #expect(vm.selectedCategoriesText(selectedSubcategories: [restaurants.persistentModelID]) == "Restaurantes")
        let names = vm.selectedCategoriesText(
            selectedSubcategories: [delivery.persistentModelID, restaurants.persistentModelID, taxi.persistentModelID]
        )
        let firstChosen = vm.allCategories.first { $0.name != "Hogar" }?.name ?? ""
        #expect(names == "\(firstChosen) +1")
    }

    @Test func summaryLogic_groupsAndOrder() {
        let entries: [CategoryFilterSummaryLogic.CategoryEntry<Int>] = [
            .init(name: "Alimentación", subcategories: [(1, "Delivery"), (2, "Restaurantes")]),
            .init(name: "Transporte", subcategories: [(3, "Taxi"), (4, "Bus")]),
            .init(name: "Vacía", subcategories: []),
        ]
        #expect(CategoryFilterSummaryLogic.names(selected: [1, 2], categories: entries) == ["Alimentación"])
        #expect(CategoryFilterSummaryLogic.names(selected: [4, 2], categories: entries) == ["Restaurantes", "Bus"])
        #expect(CategoryFilterSummaryLogic.names(selected: [], categories: entries).isEmpty)
        #expect(CategoryFilterSummaryLogic.text(names: ["A"]) == "A")
        #expect(CategoryFilterSummaryLogic.text(names: ["A", "B", "C"]) == "A +2")
        #expect(CategoryFilterSummaryLogic.text(names: []) == nil)
    }

    // MARK: - Buscador (punto 1, F3)

    @Test func search_ignoresAccentsAndCase() {
        #expect(CategorySearchLogic.matches("Alimentación", query: "alimentacion"))
        #expect(CategorySearchLogic.matches("Restaurantes", query: "REST"))
        #expect(CategorySearchLogic.matches("Taxi", query: "  "))
        #expect(!CategorySearchLogic.matches("Taxi", query: "rest"))
    }

    // MARK: - Chips rápidos (punto 1, F2)

    @Test func quickChipLabels() {
        #expect(RecordsQuickChipLabel.accounts(selectedNames: []) == .placeholder)
        #expect(RecordsQuickChipLabel.accounts(selectedNames: ["Cuenta Principal"]) == .one("Cuenta Principal"))
        #expect(RecordsQuickChipLabel.accounts(selectedNames: ["A", "B"]) == .many(2))
        #expect(RecordsQuickChipLabel.categories(names: ["Alimentación"]) == .one("Alimentación"))
        #expect(!RecordsQuickChipLabel.categories(names: []).isActive)
    }

    // MARK: - Banda (punto 4, L1)

    @Test func band_countsWhatItPaints() {
        // Panel, Estadísticas, Informes: todo.
        #expect(FilterBandLogic.bandFilterCount(
            userFilterCount: 3, hidesQuickDimensions: false,
            hasIncludedAccounts: true, hasIncludedCategoriesOrSubcategories: true
        ) == 3)
        // Registros con chips: la cuenta y la categoría elegidas las dicen los chips.
        #expect(FilterBandLogic.bandFilterCount(
            userFilterCount: 3, hidesQuickDimensions: true,
            hasIncludedAccounts: true, hasIncludedCategoriesOrSubcategories: true
        ) == 1)
        #expect(FilterBandLogic.bandFilterCount(
            userFilterCount: 1, hidesQuickDimensions: true,
            hasIncludedAccounts: true, hasIncludedCategoriesOrSubcategories: false
        ) == 0)
    }

    /// Antes la ✕ de «borrar todo» solo salía con dos filtros o más.
    @Test func band_removeAllWithASingleFilter() {
        #expect(FilterBandLogic.showsRemoveAll(bandFilterCount: 1))
        #expect(!FilterBandLogic.showsRemoveAll(bandFilterCount: 0))
    }

    /// La ✕ de cada cápsula mide 44 pt de toque (antes, el glifo de 11 pt).
    @Test func chipClose_hasAppleMinimumHitArea() {
        #expect(FilterChipView.closeHitSize >= 44)
    }

    // MARK: - Un solo nombre para limpiar (punto 5)

    /// «Borrar filtros» (`action.clearAll`) ya no se pinta en ninguna vista: la banda dice «Quitar todo» y la hoja y el
    /// vacío, «Limpiar filtros».
    @Test func noViewSaysBorrarFiltros() throws {
        let views = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Yala/App/Views")
        let files = FileManager.default.enumerator(at: views, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" } ?? []
        #expect(!files.isEmpty)
        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8)
            #expect(!source.contains("L10n.Action.clearAll"), "\(file.lastPathComponent) aún dice «Borrar filtros»")
        }
    }

    /// «Limpiar filtros» de la hoja va en la cabecera, aplica y cierra; ya no hay botón al fondo que solo vacía.
    @Test func clearFilters_livesInTheSheetHeader() throws {
        let file = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Yala/App/Views/Records/RecordsFiltersView.swift")
        let source = try String(contentsOf: file, encoding: .utf8)
        #expect(source.contains("\"filters_clear_button\""))
        #expect(source.contains("clearApplyAndClose()"))
        let occurrences = source.components(separatedBy: "Text(L10n.Filters.clearFilters)").count - 1
        #expect(occurrences == 0, "el botón del fondo de la hoja sigue ahí")
    }
}
