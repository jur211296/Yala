//
//  TransferCategoryResolverLanguageTests.swift
//  YalaTests
//
//  Card osak (lote 2.3 · UI): al cambiar de idioma, una transferencia nueva creaba otra subcategoría de transferencia,
//  porque `TransferCategoryResolver` buscaba solo el nombre del idioma ACTUAL. Ahora reutiliza la que exista con el
//  nombre de cualquiera de los 16 idiomas.
//

import Foundation
import SwiftData
import Testing

@testable import Yala

@Suite("La subcategoría de transferencia se reutiliza aunque cambie el idioma", .serialized)
@MainActor
struct TransferCategoryResolverLanguageTests {

    /// Un nombre de transferencia de OTRO idioma que el que corre el test.
    private func otherLanguageName() throws -> String {
        let current = L10n.Transfer.categoryName
        return try #require(Subcategory.transferNames.sorted().first { $0 != current })
    }

    private func transferSubcategories(isIncome: Bool, in context: ModelContext) throws -> [Subcategory] {
        try context.fetch(FetchDescriptor<Subcategory>()).filter {
            $0.category?.isIncome == isIncome && Subcategory.transferNames.contains($0.name)
        }
    }

    private func seed(name: String, isIncome: Bool, in context: ModelContext) throws -> Subcategory {
        let category = Category(name: isIncome ? "Ingresos" : "Otros", colorHex: "#64748B", isIncome: isIncome)
        context.insert(category)
        let subcategory = Subcategory(
            name: name, colorHex: nil, natureRawValue: SubcategoryNeed.unclassified.rawValue,
            iconName: "arrow.left.arrow.right", category: category)
        context.insert(subcategory)
        try context.save()
        return subcategory
    }

    @Test("Salida: la creada en otro idioma se reutiliza y no aparece otra")
    func outflow_reusesTheOneInAnotherLanguage() throws {
        let context = try makeTestContext()
        let existing = try seed(name: try otherLanguageName(), isIncome: false, in: context)

        let resolved = try TransferCategoryResolver.outflow(context: context)

        #expect(resolved.persistentModelID == existing.persistentModelID)
        #expect(try transferSubcategories(isIncome: false, in: context).count == 1)
    }

    @Test("Entrada: igual, en la categoría de ingresos")
    func inflow_reusesTheOneInAnotherLanguage() throws {
        let context = try makeTestContext()
        let existing = try seed(name: try otherLanguageName(), isIncome: true, in: context)

        let resolved = try TransferCategoryResolver.inflow(context: context)

        #expect(resolved.persistentModelID == existing.persistentModelID)
        #expect(try transferSubcategories(isIncome: true, in: context).count == 1)
    }

    @Test("Si ya hay dos, gana la del idioma actual")
    func preferred_picksTheCurrentLanguage() throws {
        let current = L10n.Transfer.categoryName
        let other = Subcategory(name: try otherLanguageName(), category: nil)
        let mine = Subcategory(name: current, category: nil)

        #expect(TransferCategoryResolver.preferred([other, mine], currentName: current) === mine)
        #expect(TransferCategoryResolver.preferred([other], currentName: current) === other)
        #expect(TransferCategoryResolver.preferred([], currentName: current) == nil)
    }
}
