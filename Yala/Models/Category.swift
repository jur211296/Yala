//
//  Category.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import Foundation
import SwiftData

// MARK: - Category

@Model
final class Category {
    // Campos existentes (CloudKit: defaults required)
    var name: String = ""
    var colorHex: String = "#6366F1"
    var isIncome: Bool = false

    // Campos adicionales para semilla y gestión en Ajustes
    /// Indica si esta categoría proviene de la semilla inicial de Yala
    var isDefaultSeed: Bool = false
    /// Control de visibilidad dentro de la app (para permitir ocultar categorías)
    var isVisible: Bool = true
    /// Orden de presentación en la lista de categorías
    var sortOrder: Int = 0
    /// Nombre del icono SF Symbol (opcional)
    var iconName: String?

    /// Relación 1 -> N con subcategorías
    /// NOTE: Using nullify instead of cascade - manual deletion handles subcategories to avoid SwiftUI @Query conflicts
    @Relationship(deleteRule: .nullify, inverse: \Subcategory.category)
    var subcategories: [Subcategory]

    /// Inverse relationship: transactions linked to this category
    var transactions: [TransactionItem] = []

    /// Inverse relationship: budgets linked to this category (CloudKit requirement)
    var budgets: [Budget]? = []

    init(
        name: String,
        colorHex: String,
        isIncome: Bool,
        isDefaultSeed: Bool = true,
        isVisible: Bool = true,
        sortOrder: Int = 0,
        iconName: String? = nil,
        subcategories: [Subcategory] = []
    ) {
        self.name = name
        self.colorHex = colorHex
        self.isIncome = isIncome
        self.isDefaultSeed = isDefaultSeed
        self.isVisible = isVisible
        self.sortOrder = sortOrder
        self.iconName = iconName
        self.subcategories = subcategories
    }
}
