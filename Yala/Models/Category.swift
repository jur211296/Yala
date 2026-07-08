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

    /// True para categorías sistema (`Grupos`, `Cobros de grupos`).
    /// CloudKit: must have default value. No editables, no eliminables, sus subcategorías excluidas de pickers manuales.
    var isSystem: Bool = false

    /// Relación 1 -> N con subcategorías - CloudKit: must be optional
    /// NOTE: Using nullify instead of cascade - manual deletion handles subcategories to avoid SwiftUI @Query conflicts
    @Relationship(deleteRule: .nullify, inverse: \Subcategory.category)
    var subcategories: [Subcategory]?

    /// Inverse relationship: transactions linked to this category - CloudKit: must be optional
    @Relationship(deleteRule: .nullify)
    var transactions: [TransactionItem]?

    /// Inverse relationship: budgets linked to this category - CloudKit: must be optional
    @Relationship(deleteRule: .nullify)
    var budgets: [Budget]?

    /// Inverse relationship: cash flow lines linked to this category - CloudKit: must be optional
    @Relationship(deleteRule: .nullify)
    var cashFlowLines: [CashFlowLine]?

    // MARK: - Sync Identity (Modo Nube, I2)
    /// Identidad estable de sync. Opcional sin default (gotcha de UUID colapsado — ver
    /// `TransactionItem.syncID`). Poblado por `SyncIdentityService`.
    @Attribute(.preserveValueOnDeletion) var syncID: UUID?

    init(
        name: String,
        colorHex: String,
        isIncome: Bool,
        isDefaultSeed: Bool = true,
        isVisible: Bool = true,
        sortOrder: Int = 0,
        iconName: String? = nil,
        isSystem: Bool = false,
        subcategories: [Subcategory] = []
    ) {
        self.name = name
        self.colorHex = colorHex
        self.isIncome = isIncome
        self.isDefaultSeed = isDefaultSeed
        self.isVisible = isVisible
        self.sortOrder = sortOrder
        self.iconName = iconName
        self.isSystem = isSystem
        self.subcategories = subcategories
    }
}

// MARK: - LLM Context

extension [Category] {
    /// Visible category → subcategory tree labels for LLM context.
    /// Example: `["Vehículo (Combustible, Seguro)", "Alimentación (Restaurantes, Delivery)"]`
    func visibleCategoryTreeLabels() -> [String] {
        filter(\.isVisible).map { cat in
            let subs = (cat.subcategories ?? []).filter(\.isVisible).map(\.name)
            return subs.isEmpty ? cat.name : "\(cat.name) (\(subs.joined(separator: ", ")))"
        }
    }
}
