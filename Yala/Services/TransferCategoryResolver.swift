//
//  TransferCategoryResolver.swift
//  Yala
//
//  Las subcategorías «Transferencia entre cuentas» de las dos patas de una transferencia: la de salida en una categoría
//  de gasto y la de entrada en una de ingreso, creadas si no existen. Las usaban solo el formulario de Nuevo registro;
//  desde Grupos B (card 2) también el puente, que apunta las recargas de tu parte como un par de transferencia. Un solo
//  sitio para que las dos fuentes no creen subcategorías distintas.
//

import Foundation
import SwiftData

enum TransferCategoryResolver {

    /// Los nombres de la subcategoría de transferencia en los 16 idiomas (`Subcategory.transferNames`). Antes se
    /// buscaba solo el del idioma ACTUAL, y al cambiar de idioma cada transferencia nueva creaba otra subcategoría.
    private static let knownNames: [String] = Array(Subcategory.transferNames)

    /// Entre las que existen, la del idioma actual si la hay; si no, la de nombre más estable (orden alfabético),
    /// para que dos llamadas seguidas devuelvan la misma.
    static func preferred(_ candidates: [Subcategory], currentName: String) -> Subcategory? {
        if let current = candidates.first(where: { $0.name == currentName }) {
            return current
        }
        return candidates.min { $0.name < $1.name }
    }

    /// La subcategoría de la pata de SALIDA (categoría de gasto).
    static func outflow(context: ModelContext) throws -> Subcategory {
        let subcategoryName = L10n.Transfer.categoryName
        let knownNames = Self.knownNames

        // La de transferencia puede existir con el nombre de CUALQUIER idioma: si el usuario cambió de idioma, se
        // reutiliza la que ya tiene en vez de crear otra con el nombre nuevo.
        let descriptor = FetchDescriptor<Subcategory>(
            predicate: #Predicate { knownNames.contains($0.name) && $0.category?.isIncome == false }
        )

        let fetchedSubcategories: [Subcategory]
        do {
            fetchedSubcategories = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("[TransferCategoryResolver] Error fetching transfer subcategory: \(error)")
            #endif
            fetchedSubcategories = []
        }
        if let existing = preferred(fetchedSubcategories, currentName: subcategoryName) {
            return existing
        }

        // Find first expense category
        let catDescriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.isIncome == false },
            sortBy: [SortDescriptor(\.sortOrder)]
        )

        let fetchedExpenseCategories: [Category]
        do {
            fetchedExpenseCategories = try context.fetch(catDescriptor)
        } catch {
            #if DEBUG
            print("[TransferCategoryResolver] Error fetching expense categories: \(error)")
            #endif
            fetchedExpenseCategories = []
        }

        let category: Category
        if let existingCat = fetchedExpenseCategories.first {
            category = existingCat
        } else {
            // Fallback: create expense category if somehow missing
            category = Category(
                name: L10n.Category.other,
                colorHex: "#64748B",
                isIncome: false
            )
            context.insert(category)
        }

        // Create subcategory within "Otros"
        let subcategory = Subcategory(
            name: subcategoryName,
            colorHex: nil,
            natureRawValue: SubcategoryNeed.unclassified.rawValue,
            iconName: "arrow.left.arrow.right",
            category: category
        )
        context.insert(subcategory)

        return subcategory
    }

    /// Ensures the income transfer subcategory exists for incoming transfers
    static func inflow(context: ModelContext) throws -> Subcategory {
        let subcategoryName = L10n.Transfer.categoryName
        let knownNames = Self.knownNames

        // Igual que en la de salida: cualquier idioma vale.
        let descriptor = FetchDescriptor<Subcategory>(
            predicate: #Predicate { knownNames.contains($0.name) && $0.category?.isIncome == true }
        )

        let fetchedIncomeSubcategories: [Subcategory]
        do {
            fetchedIncomeSubcategories = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("[TransferCategoryResolver] Error fetching income transfer subcategory: \(error)")
            #endif
            fetchedIncomeSubcategories = []
        }
        if let existing = preferred(fetchedIncomeSubcategories, currentName: subcategoryName) {
            return existing
        }

        // Find first income category
        let catDescriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.isIncome == true },
            sortBy: [SortDescriptor(\.sortOrder)]
        )

        let fetchedIncomeCategories: [Category]
        do {
            fetchedIncomeCategories = try context.fetch(catDescriptor)
        } catch {
            #if DEBUG
            print("[TransferCategoryResolver] Error fetching income categories: \(error)")
            #endif
            fetchedIncomeCategories = []
        }

        let category: Category
        if let existingCat = fetchedIncomeCategories.first {
            category = existingCat
        } else {
            // Fallback: create income category if somehow missing
            category = Category(
                name: L10n.Category.incomeCategory,
                colorHex: "#14B8A6",
                isIncome: true
            )
            context.insert(category)
        }

        // Create subcategory within "Ingresos"
        let subcategory = Subcategory(
            name: subcategoryName,
            colorHex: nil,
            natureRawValue: SubcategoryNeed.unclassified.rawValue,
            iconName: "arrow.left.arrow.right",
            category: category
        )
        context.insert(subcategory)

        return subcategory
    }
}
