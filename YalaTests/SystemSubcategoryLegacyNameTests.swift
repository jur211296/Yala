//
//  SystemSubcategoryLegacyNameTests.swift
//  YalaTests
//
//  bxds · pt-PT: los dos saldos iniciales de Grupos decían «você» (trato de Brasil). La subcategoría se guarda con el
//  texto del idioma y el seed la busca por nombre, así que cambiar el texto sin más le sembraba una segunda a quien ya
//  la tenía. `SystemSubcategoryNameLogic` acepta el nombre viejo (molde de «Sin asignar», lote 12.4).
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@MainActor
@Suite("bxds — nombre viejo de las subcategorías de sistema", .serialized)
struct SystemSubcategoryLegacyNameTests {

    private static let oldOwed = "Saldo inicial (devem a você)"
    private static let oldDebt = "Saldo inicial (você deve)"

    private func ptPTValue(_ key: String) -> String? {
        guard let path = Bundle.main.path(forResource: "pt-PT", ofType: "lproj"),
              let bundle = Bundle(path: path) else { return nil }
        let value = bundle.localizedString(forKey: key, value: "__MISSING__", table: nil)
        return value == "__MISSING__" ? nil : value
    }

    // MARK: - El texto

    @Test func ptPT_openingBalances_noLongerSayVoce() throws {
        for key in ["subcategory.system.openingBalanceOwed", "subcategory.system.openingBalanceDebt"] {
            let value = try #require(ptPTValue(key), "pt-PT no trae \(key)")
            #expect(!value.lowercased().contains("você"), "\(key) sigue en trato de Brasil: \(value)")
        }
        #expect(ptPTValue("subcategory.system.openingBalanceOwed") == "Saldo inicial (devem-te)")
        #expect(ptPTValue("subcategory.system.openingBalanceDebt") == "Saldo inicial (deves)")
    }

    // MARK: - El emparejamiento

    @Test func matches_acceptsTheCurrentAndTheOldName_forItsRoleOnly() {
        let owed = GroupBridgeSystemRole.subcategoryOpeningBalanceOwed
        let debt = GroupBridgeSystemRole.subcategoryOpeningBalanceDebt
        #expect(SystemSubcategoryNameLogic.matches("Saldo inicial (devem-te)", role: owed, current: "Saldo inicial (devem-te)"))
        #expect(SystemSubcategoryNameLogic.matches(Self.oldOwed, role: owed, current: "Saldo inicial (devem-te)"))
        #expect(SystemSubcategoryNameLogic.matches(Self.oldDebt, role: debt, current: "Saldo inicial (deves)"))
        // El viejo de un rol no casa con el otro: serían dos subcategorías fundidas en una.
        #expect(!SystemSubcategoryNameLogic.matches(Self.oldOwed, role: debt, current: "Saldo inicial (deves)"))
        #expect(!SystemSubcategoryNameLogic.matches("Otra", role: owed, current: "Saldo inicial (devem-te)"))
    }

    @Test func legacyNames_byLocalizationKey_onlyForSubcategoryKeys() {
        #expect(SystemSubcategoryNameLogic.legacyNames(forLocalizationKey: "subcategory.system.openingBalanceOwed") == [Self.oldOwed])
        #expect(SystemSubcategoryNameLogic.legacyNames(forLocalizationKey: "subcategory.system.openingBalanceDebt") == [Self.oldDebt])
        #expect(SystemSubcategoryNameLogic.legacyNames(forLocalizationKey: "subcategory.system.loanToGroups").isEmpty)
        #expect(SystemSubcategoryNameLogic.legacyNames(forLocalizationKey: "category.system.openingBalanceOwed").isEmpty)
    }

    // MARK: - El seed no duplica

    private func seedStore(subcategoryName: String) throws -> (ModelContext, Yala.Category, UserDefaults) {
        let context = try makeTestContext()
        let def = try #require(systemGroupCategoryDefinitions().first { $0.role == GroupBridgeSystemRole.categoryGroupCollections })
        let category = Yala.Category(name: def.name, colorHex: def.colorHex, isIncome: def.isIncome,
                                isDefaultSeed: true, iconName: def.iconName, isSystem: true)
        context.insert(category)
        let sub = Subcategory(name: subcategoryName, isDefaultSeed: true, isSystem: true, category: category)
        context.insert(sub)
        try context.save()
        let suite = "bxds-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        return (context, category, defaults)
    }

    @Test func seed_adoptsTheOldName_insteadOfSowingASecond() throws {
        let (context, category, defaults) = try seedStore(subcategoryName: Self.oldOwed)
        seedSystemGroupCategoriesIfNeeded(in: context, defaults: defaults)

        // Oráculo propio, sin `SystemSubcategoryNameLogic`: si el test contara con la función que prueba, un mutante en
        // ella le cambiaría también la cuenta.
        let names: Set<String> = [L10n.Subcategory.System.openingBalanceOwed, Self.oldOwed]
        let openingOwed = (category.subcategories ?? []).filter { names.contains($0.name) }
        #expect(openingOwed.count == 1, "Sembró una segunda «Saldo inicial (me deben)»: \(openingOwed.map(\.name))")
        #expect(openingOwed.first?.name == Self.oldOwed, "No se renombra lo guardado")
    }

    /// Control: con un nombre que no es de la subcategoría, el seed sí crea la suya. Sin este, el test de arriba
    /// pasaría también con un seed que no sembrara nada.
    @Test func seed_control_sowsItWhenNothingMatches() throws {
        let (context, category, defaults) = try seedStore(subcategoryName: "Otra")
        seedSystemGroupCategoriesIfNeeded(in: context, defaults: defaults)

        let names = (category.subcategories ?? []).map(\.name)
        #expect(names.contains(L10n.Subcategory.System.openingBalanceOwed), "No sembró la subcategoría: \(names)")
    }
}
