//
//  CategoryImportHelper.swift
//  Yala
//
//  Helpers de categorías y subcategorías para importaciones.
//  Lógica centralizada para crear / reutilizar categorías.
//
//  No modificar la firma pública de este helper sin aprobación explícita.
//

import Foundation
import SwiftData

/// Helper centralizado para resolver o crear categorías y subcategorías
/// durante procesos de importación (CSV u otros).
///
/// Importante:
/// - No realiza `context.save()`. El llamador es responsable de persistir.
/// - Evita duplicados por nombre dentro de la misma categoría.
/// - Todas las categorías/subcategorías creadas desde aquí NO son semilla.
enum CategoryImportHelper {

    // MARK: - Categorías

    /// Devuelve una categoría existente con ese nombre o crea una nueva.
    ///
    /// - Parameters:
    ///   - name: Nombre de la categoría según viene en el CSV.
    ///   - isIncome: Indica si la categoría es de ingresos o de gastos.
    ///   - context: ModelContext de SwiftData.
    /// - Returns: Category resuelta o creada.
    ///
    /// - Note: Busca primero por nombre exacto (ignorando isIncome) para soportar
    ///   categorías "neutrales" como "Otros" que contienen subcategorías de transferencias.
    ///   Esto permite importar transferencias correctamente independiente del signo del monto.
    static func fetchOrCreateCategory(
        named name: String,
        isIncome: Bool,
        in context: ModelContext
    ) throws -> Category {

        // Normalizamos nombre para evitar duplicados triviales por espacios.
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        // Buscamos una categoría ya existente con el mismo nombre (sin filtrar por isIncome).
        // Esto permite que categorías "neutrales" como "Otros" funcionen para transferencias
        // que tienen montos positivos (entrada) y negativos (salida).
        var descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { category in
                category.name == trimmedName
            }
        )
        descriptor.fetchLimit = 1

        let fetchedCategories: [Category]
        do {
            fetchedCategories = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("CategoryImportHelper: Error fetching category by name: \(error)")
            #endif
            fetchedCategories = []
        }
        if let existing = fetchedCategories.first {
            // Si existe, simplemente la reutilizamos.
            return existing
        }

        // Si no existe, creamos una nueva categoría.
        let defaultColorHex = AppConstants.defaultColorHex

        // sortOrder se coloca al final según el máximo actual.
        let allCategoriesDescriptor = FetchDescriptor<Category>()
        let allCategories: [Category]
        do {
            allCategories = try context.fetch(allCategoriesDescriptor)
        } catch {
            #if DEBUG
            print("CategoryImportHelper: Error fetching all categories: \(error)")
            #endif
            allCategories = []
        }
        let nextSortOrder = (allCategories.map { $0.sortOrder }.max() ?? 0) + 1

        let newCategory = Category(
            name: trimmedName,
            colorHex: defaultColorHex,
            isIncome: isIncome,
            isDefaultSeed: false,
            isVisible: true,
            sortOrder: nextSortOrder,
            subcategories: []
        )

        context.insert(newCategory)
        return newCategory
    }

    // MARK: - Subcategorías

    /// Devuelve una subcategoría existente dentro de la categoría padre
    /// o crea una nueva si no existe.
    ///
    /// - Parameters:
    ///   - name: Nombre de la subcategoría desde el CSV.
    ///   - parentCategory: Categoría padre a la que pertenece.
    ///   - isIncome: Naturaleza de ingreso o gasto, alineada con la categoría.
    ///   - context: ModelContext de SwiftData.
    /// - Returns: Subcategory resuelta o creada.
    static func fetchOrCreateSubcategory(
        named name: String,
        in parentCategory: Category,
        isIncome: Bool,
        in context: ModelContext
    ) throws -> Subcategory {

        // Nombre normalizado para evitar duplicados triviales.
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        // Buscamos subcategorías con el mismo nombre y luego filtramos
        // por categoría padre en memoria para evitar problemas con el
        // uso de relaciones dentro de #Predicate.
        let descriptor = FetchDescriptor<Subcategory>(
            predicate: #Predicate { sub in
                sub.name == trimmedName
            }
        )

        let fetched: [Subcategory]
        do {
            fetched = try context.fetch(descriptor)
        } catch {
            #if DEBUG
            print("CategoryImportHelper: Error fetching subcategory by name: \(error)")
            #endif
            fetched = []
        }
        if let existing = fetched.first(where: { $0.category === parentCategory }) {
            // Reutilizamos la subcategoría si ya existe en esta categoría.
            return existing
        }

        // sortOrder dentro de la categoría padre.
        let allSubcategoriesDescriptor = FetchDescriptor<Subcategory>()
        let allSubcategories: [Subcategory]
        do {
            allSubcategories = try context.fetch(allSubcategoriesDescriptor)
        } catch {
            #if DEBUG
            print("CategoryImportHelper: Error fetching all subcategories: \(error)")
            #endif
            allSubcategories = []
        }
        let siblings = allSubcategories.filter { $0.category == parentCategory }
        let nextSortOrder = (siblings.map { $0.sortOrder }.max() ?? -1) + 1

        let newSubcategory = Subcategory(
            name: trimmedName,
            colorHex: nil,  // Hereda del padre (definido en modelo/vista)
            isDefaultSeed: false,
            isVisible: true,
            sortOrder: nextSortOrder,
            natureRawValue: nil,
            category: parentCategory
        )

        context.insert(newSubcategory)
        return newSubcategory
    }
}
