//
//  CuentasCategoriasNecesariasLote09Tests.swift
//  YalaTests
//
//  Lote 09 de las mejoras necesarias 2.3 (zona 39: cuentas, categorías, etiquetas y divisas). La lógica de cada punto;
//  lo que se ve está en `CuentasCategoriasNecesariasLote09UITests`.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("Lote 09 de mejoras 2.3 · cuentas, categorías, etiquetas y divisas", .serialized)
struct CuentasCategoriasNecesariasLote09Tests {

    // MARK: - Punto 1 · Tipo de cambio sin secundarias

    @Test func exchangeRates_withoutSecondaryCurrencies_hasNoRow() {
        #expect(ExchangeRatesSectionLogic.inlineCurrencies(secondary: []).isEmpty)
    }

    @Test func exchangeRates_withSecondaryCurrencies_listsExactlyThose() {
        // Control: con secundarias elegidas salen esas, y solo esas.
        let shown = ExchangeRatesSectionLogic.inlineCurrencies(secondary: [.usd, .eur])
        #expect(Set(shown) == [.usd, .eur])
        #expect(shown.count == 2)
    }

    // MARK: - Punto 2 · El saldo de la lista sigue la preferencia código / símbolo

    private func balanceShown(displayFormat: CurrencyDisplayFormat) throws -> String {
        let context = try makeTestContext()
        let account = makeTestAccount(context: context, name: "Ahorros", currencyCode: "PEN")
        let item = TransactionItem(
            date: aMomentAgoToday(), amount: 2000, currencyCode: "PEN", note: "",
            category: nil, subcategory: nil, account: account, tags: [], amountInPreferredCurrency: 2000,
            preferredCurrencyCode: "PEN", tagIDs: nil
        )
        context.insert(item)
        try context.save()

        let vm = AccountsSettingsListViewModel()
        vm.setContext(context)
        return vm.formattedBalance(for: account, displayFormat: displayFormat)
    }

    @Test func accountsList_withSymbolPreference_writesTheSymbol() throws {
        let shown = try balanceShown(displayFormat: .symbol)
        #expect(shown.hasPrefix("S/ "), "Salía «\(shown)».")
        #expect(!shown.contains("PEN"))
    }

    @Test func accountsList_withCodePreference_writesTheCode() throws {
        // Control: quien eligió «código» en Personalización lo sigue viendo.
        let shown = try balanceShown(displayFormat: .code)
        #expect(shown.hasPrefix("PEN "), "Salía «\(shown)».")
    }

    // MARK: - Punto 3 · La categoría nueva que no se guardó

    /// Lo que deja en disco el «+» de Categorías si la app se cierra tras guardar la primera subcategoría: la categoría
    /// SIN nombre (el nombre solo se escribe al guardarla) con su subcategoría.
    private func persistAbandonedDraft(in context: ModelContext) throws -> YalaCategory {
        let draft = YalaCategory(name: "", colorHex: "#6366F1", isIncome: false, isDefaultSeed: false)
        context.insert(draft)
        let sub = Subcategory(name: "QA Sub", isDefaultSeed: false, category: draft)
        context.insert(sub)
        try context.save()
        return draft
    }

    private func categoryNames(in context: ModelContext) throws -> [String] {
        try context.fetch(FetchDescriptor<YalaCategory>()).map(\.name)
    }

    @Test func abandonedDraft_withTheMarkArmed_isRemovedWithItsSubcategories() throws {
        let context = try makeTestContext()
        let defaults = makeIsolatedDefaults()
        _ = makeTestCategory(context: context, name: "Alimentación")
        _ = try persistAbandonedDraft(in: context)
        NewCategoryDraftMark.arm(defaults: defaults)

        let removed = NewCategoryDraftMark.sweepIfArmed(in: context, defaults: defaults)

        #expect(removed == 1)
        #expect(try categoryNames(in: context) == ["Alimentación"])
        #expect(try context.fetch(FetchDescriptor<Subcategory>()).isEmpty, "La subcategoría del borrador se quedó huérfana.")
        #expect(!NewCategoryDraftMark.isArmed(defaults: defaults))
    }

    @Test func withoutTheMark_nothingIsTouched() throws {
        // Control: sin la marca de este teléfono no se mira nada, aunque haya una categoría sin nombre.
        let context = try makeTestContext()
        let defaults = makeIsolatedDefaults()
        _ = try persistAbandonedDraft(in: context)

        #expect(NewCategoryDraftMark.sweepIfArmed(in: context, defaults: defaults) == 0)
        #expect(try categoryNames(in: context) == [""])
    }

    @Test func draftWithRecords_staysEvenWithTheMark() throws {
        // Lo que tiene registros no se borra por una marca: es de la persona.
        let context = try makeTestContext()
        let defaults = makeIsolatedDefaults()
        let draft = try persistAbandonedDraft(in: context)
        let account = makeTestAccount(context: context)
        let item = TransactionItem(
            date: aMomentAgoToday(), amount: -10, currencyCode: "PEN", note: "",
            category: draft, subcategory: draft.subcategories?.first, account: account, tags: [],
            amountInPreferredCurrency: -10, preferredCurrencyCode: "PEN", tagIDs: nil
        )
        context.insert(item)
        try context.save()
        NewCategoryDraftMark.arm(defaults: defaults)

        #expect(NewCategoryDraftMark.sweepIfArmed(in: context, defaults: defaults) == 0)
        #expect(try categoryNames(in: context) == [""])
        #expect(!NewCategoryDraftMark.isArmed(defaults: defaults))
    }

    @Test func isAbandonedDraft_onlyNamelessUserCategoriesWithoutData() {
        #expect(NewCategoryDraftMark.isAbandonedDraft(name: "  ", isSystem: false, isDefaultSeed: false, hasLinkedData: false))
        #expect(!NewCategoryDraftMark.isAbandonedDraft(name: "Viaje", isSystem: false, isDefaultSeed: false, hasLinkedData: false))
        #expect(!NewCategoryDraftMark.isAbandonedDraft(name: "", isSystem: true, isDefaultSeed: false, hasLinkedData: false))
        #expect(!NewCategoryDraftMark.isAbandonedDraft(name: "", isSystem: false, isDefaultSeed: true, hasLinkedData: false))
        #expect(!NewCategoryDraftMark.isAbandonedDraft(name: "", isSystem: false, isDefaultSeed: false, hasLinkedData: true))
    }

    /// El cableado: el «+» arma la marca, guardar y descartar la retiran, y la lista y el arranque barren. Sin una de las
    /// cuatro, el borrador se queda (lo cubre de punta a punta el XCUITest del punto 3).
    @Test func wiring_armClearAndSweep() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        func source(_ path: String) throws -> String {
            try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
        }
        let list = try source("Yala/App/ViewModels/CategoriesSettingsListViewModel.swift")
        let create = try #require(list.range(of: "func createAndOpenNewCategory()"))
        #expect(list[create.lowerBound...].contains("NewCategoryDraftMark.arm()"))
        let setContext = try #require(list.range(of: "func setContext("))
        let loadCall = try #require(list.range(of: "loadCategories()", range: setContext.upperBound..<list.endIndex))
        #expect(list[setContext.upperBound..<loadCall.lowerBound].contains("NewCategoryDraftMark.sweepIfArmed(in: context)"))

        let detail = try source("Yala/App/ViewModels/CategoryDetailViewModel.swift")
        #expect(detail.components(separatedBy: "NewCategoryDraftMark.clear()").count == 3, "Guardar y descartar retiran la marca.")

        let boot = try source("Yala/App/AppBootstrapper.swift")
        #expect(boot.contains("NewCategoryDraftMark.sweepIfArmed(in: context)"))
    }

    // MARK: - Punto 4 · El formulario de etiqueta

    @Test func tagName_captionAppearsNearTheLimitAndAtIt() {
        #expect(TagNameLimit.caption(forLength: 0) == nil)
        #expect(TagNameLimit.caption(forLength: 14) == nil)
        #expect(TagNameLimit.caption(forLength: 15) == .count(15))
        #expect(TagNameLimit.caption(forLength: 19) == .count(19))
        #expect(TagNameLimit.caption(forLength: 20) == .limitReached)
        #expect(TagNameLimit.maxLength == 20)
    }

    @Test func everyPaletteColor_hasAName() {
        // Un color nuevo en la paleta sin su caso en `TagPaletteColor` saldría como «Color propio».
        for hex in Tag.defaultColors {
            #expect(TagPaletteColor(hex: hex) != nil, "\(hex) no tiene nombre.")
        }
        #expect(TagPaletteColor.allCases.count == Tag.defaultColors.count)
        #expect(TagPaletteColor(hex: "#ff9f0a") == .orange, "El hex guardado puede venir en minúsculas.")
        #expect(TagPaletteColor(hex: "#123456") == nil)
    }

    @Test func colorNames_areWordsNotCodes() {
        for color in TagPaletteColor.allCases {
            let name = L10n.Tag.colorName(hex: color.rawValue)
            #expect(!name.contains("#") && !name.hasPrefix("tag."), "\(color) se lee «\(name)».")
        }
        #expect(!L10n.Tag.colorName(hex: "#123456").contains("#"))
        #expect(Set(TagPaletteColor.allCases.map { L10n.Tag.colorName(hex: $0.rawValue) }).count == TagPaletteColor.allCases.count,
                "Dos colores se llaman igual.")
    }

    @Test func tagForm_hasUnsavedChanges_onlyWhenSomethingChanged() {
        let vm = TagFormViewModel()
        #expect(!vm.hasUnsavedChanges)
        vm.name = "   "
        #expect(!vm.hasUnsavedChanges, "Solo espacios no se guardaría: no hay nada que perder.")
        vm.name = "Viaje"
        #expect(vm.hasUnsavedChanges)
        vm.name = ""
        vm.isActive.toggle()
        #expect(vm.hasUnsavedChanges)
    }

    @Test func tagForm_editingWithoutChanges_closesWithoutAsking() {
        let tag = Tag(name: "Viaje", colorHex: "#ff9f0a", iconName: "airplane", isActive: true)
        let vm = TagFormViewModel(tagToEdit: tag)
        #expect(!vm.hasUnsavedChanges)
        vm.selectedColorHex = "#FF9F0A"
        #expect(!vm.hasUnsavedChanges, "El mismo color en otras mayúsculas no es un cambio.")
        vm.selectedColorHex = TagPaletteColor.green.rawValue
        #expect(vm.hasUnsavedChanges)
    }
}
