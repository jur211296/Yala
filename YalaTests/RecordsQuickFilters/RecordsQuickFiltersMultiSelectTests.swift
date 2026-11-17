//
//  RecordsQuickFiltersMultiSelectTests.swift
//  YalaTests
//
//  Chips rápidos de Registros, 16-nov (Jürgen, con captura): sin chip de período, varias cuentas y categorías a la vez
//  como en el primer presupuesto del onboarding, y la forma en que eso se escribe en la sesión, que tiene que filtrar
//  igual que «Más filtros» (categoría y subcategoría se cumplen las dos: nunca las dos listas a la vez).
//

import Foundation
@testable import Yala
import Testing

struct RecordsQuickFiltersMultiSelectTests {
    private typealias Logic = RecordsQuickCategorySelectionLogic
    private typealias Entry = RecordsQuickCategorySelectionLogic.Entry<String, String>

    // Comida: delivery, restaurantes, súper · Transporte: taxi, bus · Ocio: cine
    private let food = Entry(id: "comida", subcategories: ["delivery", "restaurantes", "super"])
    private let transport = Entry(id: "transporte", subcategories: ["taxi", "bus"])
    private let fun = Entry(id: "ocio", subcategories: ["cine"])
    private var entries: [Entry] { [food, transport, fun] }

    // MARK: - Cuentas

    @Test func accounts_tappingAddsAndRemoves_severalAtOnce() {
        var shown: Set<String> = []
        shown = RecordsQuickAccountSelectionLogic.toggled("principal", in: shown)
        shown = RecordsQuickAccountSelectionLogic.toggled("ahorros", in: shown)
        #expect(shown == ["principal", "ahorros"])
        shown = RecordsQuickAccountSelectionLogic.toggled("principal", in: shown)
        #expect(shown == ["ahorros"])
    }

    @Test func accounts_chipSaysHowMany() {
        #expect(RecordsQuickChipLabel.accounts(selectedNames: ["Principal", "Ahorros", "Visa"]) == .many(3))
    }

    // MARK: - Categorías

    @Test func tappingTwoCategories_choosesBothWhole_andWritesCategoriesOnly() {
        var expanded: Set<String> = []
        expanded = Logic.togglingCategory(food, in: expanded)
        expanded = Logic.togglingCategory(transport, in: expanded)
        let written = Logic.committed(expanded, entries: entries)
        #expect(written.categories == ["comida", "transporte"])
        #expect(written.subcategories.isEmpty)
    }

    @Test func removingOneSubcategory_writesSubcategoriesOnly_neverBothLists() {
        var expanded = Logic.togglingCategory(food, in: [])
        expanded = Logic.togglingCategory(transport, in: expanded)
        expanded = Logic.togglingSubcategory("delivery", in: expanded)
        let written = Logic.committed(expanded, entries: entries)
        // Las dos listas a la vez no dejarían pasar nada: el taxi no está en «Comida».
        #expect(written.categories.isEmpty)
        #expect(written.subcategories == ["restaurantes", "super", "taxi", "bus"])
    }

    @Test func puttingTheSubcategoryBack_returnsToTheWholeCategory() {
        var expanded = Logic.togglingCategory(food, in: [])
        expanded = Logic.togglingSubcategory("delivery", in: expanded)
        expanded = Logic.togglingSubcategory("delivery", in: expanded)
        let written = Logic.committed(expanded, entries: entries)
        #expect(written.categories == ["comida"])
        #expect(written.subcategories.isEmpty)
    }

    @Test func tappingAChosenTile_removesTheWholeCategory_evenIfHalfChosen() {
        var expanded = Logic.togglingCategory(food, in: [])
        expanded = Logic.togglingSubcategory("delivery", in: expanded)
        #expect(Logic.isChosen(food, in: expanded))
        expanded = Logic.togglingCategory(food, in: expanded)
        #expect(!Logic.isChosen(food, in: expanded))
        #expect(expanded.isEmpty)
        #expect(Logic.committed(expanded, entries: entries).categories.isEmpty)
        #expect(Logic.committed(expanded, entries: entries).subcategories.isEmpty)
    }

    @Test func removingEverySubcategory_unchoosesTheCategory() {
        var expanded = Logic.togglingCategory(transport, in: [])
        expanded = Logic.togglingSubcategory("taxi", in: expanded)
        expanded = Logic.togglingSubcategory("bus", in: expanded)
        #expect(!Logic.isChosen(transport, in: expanded))
        #expect(Logic.committed(expanded, entries: entries).categories.isEmpty)
        #expect(Logic.committed(expanded, entries: entries).subcategories.isEmpty)
    }

    // MARK: - Lo que ya trae la sesión (de «Más filtros», de Distribución…)

    @Test func whatTheSessionHas_opensMarked_andAKeptChoiceWritesTheSame() {
        let fromCategories = Logic.expanded(selectedCategories: ["ocio"], selectedSubcategories: [], entries: entries)
        #expect(fromCategories == ["cine"])
        #expect(Logic.committed(fromCategories, entries: entries).categories == ["ocio"])

        let fromSubcategories = Logic.expanded(
            selectedCategories: [], selectedSubcategories: ["taxi"], entries: entries
        )
        #expect(Logic.isChosen(transport, in: fromSubcategories))
        #expect(Logic.committed(fromSubcategories, entries: entries).subcategories == ["taxi"])
    }

    /// Una subcategoría elegida en «Más filtros» que la hoja rápida no enseña (oculta) no se pierde ni hace pasar la
    /// selección a «categoría entera».
    @Test func aSubcategoryTheSheetDoesNotShow_isKept() {
        let expanded = Logic.expanded(
            selectedCategories: ["ocio"], selectedSubcategories: ["oculta"], entries: entries
        )
        let written = Logic.committed(expanded, entries: entries)
        #expect(written.categories.isEmpty)
        #expect(written.subcategories == ["cine", "oculta"])
    }

    // MARK: - Sin chip de período

    @Test func theBarHasNoPeriodChip() throws {
        let source = try String(contentsOf: Self.repoFile("Yala/App/Views/Records/Components/RecordsQuickFilterBar.swift"),
                                encoding: .utf8)
        #expect(!source.contains("records_quick_date"))
        #expect(!source.contains("choosePeriod"))
        #expect(source.contains("records_quick_account"))
        #expect(source.contains("records_quick_category"))
        #expect(source.contains("records_quick_more"))
    }

    private static func repoFile(_ relative: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent(relative)
    }
}
