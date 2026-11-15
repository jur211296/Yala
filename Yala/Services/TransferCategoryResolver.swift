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

    /// Entre las que existen, la del idioma actual si la hay; si no, la de nombre más estable (orden alfabético, y el
    /// `shortcutID` para desempatar), para que dos llamadas seguidas devuelvan la misma.
    static func preferred(_ candidates: [Subcategory], currentName: String) -> Subcategory? {
        if let current = candidates.filter({ $0.name == currentName })
            .min(by: { $0.shortcutID.uuidString < $1.shortcutID.uuidString }) {
            return current
        }
        return candidates.min { lhs, rhs in
            lhs.name != rhs.name ? lhs.name < rhs.name : lhs.shortcutID.uuidString < rhs.shortcutID.uuidString
        }
    }

    /// Las subcategorías de transferencia de una naturaleza, por su PAPEL (`systemRole == .transfer`), nunca por el
    /// nombre: así sirve la de cualquier idioma (si el usuario cambió de idioma se reutiliza la que ya tiene) y una
    /// subcategoría del usuario con el mismo nombre no recibe transferencias. El papel es calculado, así que se filtra
    /// en memoria; son pocas filas.
    static func transferSubcategories(isIncome: Bool, context: ModelContext) -> [Subcategory] {
        let descriptor = FetchDescriptor<Subcategory>(
            predicate: #Predicate { $0.category?.isIncome == isIncome }
        )
        do {
            return try context.fetch(descriptor).filter { $0.systemRole == .transfer }
        } catch {
            #if DEBUG
            print("[TransferCategoryResolver] Error fetching transfer subcategory: \(error)")
            #endif
            return []
        }
    }

    /// La subcategoría de la pata de SALIDA (categoría de gasto).
    static func outflow(context: ModelContext) throws -> Subcategory {
        let subcategoryName = L10n.Transfer.categoryName
        if let existing = preferred(transferSubcategories(isIncome: false, context: context), currentName: subcategoryName) {
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
            systemRole: .transfer,
            category: category
        )
        context.insert(subcategory)

        return subcategory
    }

    /// Ensures the income transfer subcategory exists for incoming transfers
    static func inflow(context: ModelContext) throws -> Subcategory {
        let subcategoryName = L10n.Transfer.categoryName
        if let existing = preferred(transferSubcategories(isIncome: true, context: context), currentName: subcategoryName) {
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
            systemRole: .transfer,
            category: category
        )
        context.insert(subcategory)

        return subcategory
    }
}
