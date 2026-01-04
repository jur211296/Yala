//
//  Category.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import Foundation
import SwiftData

// MARK: - Category

@Model
final class Category {
    // Campos existentes
    var name: String
    var colorHex: String
    var isIncome: Bool

    // Campos adicionales para FIN-18 y gestión en Ajustes
    /// Indica si esta categoría proviene de la semilla inicial de Neto
    var isDefaultSeed: Bool
    /// Control de visibilidad dentro de la app (para permitir ocultar categorías)
    var isVisible: Bool
    /// Orden de presentación en la lista de categorías
    var sortOrder: Int
    /// Nombre del icono SF Symbol (opcional)
    var iconName: String?

    /// Relación 1 -> N con subcategorías
    var subcategories: [Subcategory]

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
