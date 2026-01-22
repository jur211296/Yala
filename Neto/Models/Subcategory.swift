//
//  Subcategory.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import Foundation
import SwiftData

// MARK: - Subcategory

@Model
final class Subcategory {
    var name: String
    var colorHex: String?

    /// Indica si esta subcategoría proviene de la semilla inicial
    var isDefaultSeed: Bool
    /// Control de visibilidad dentro de la app
    var isVisible: Bool
    /// Orden de presentación dentro de su categoría
    var sortOrder: Int
    /// Campo reservado para futura "naturaleza" (Necesario / Deseable / etc.)
    var natureRawValue: String?
    /// Nombre del icono SF Symbol (opcional)
    var iconName: String?

    /// Relación inversa con la categoría padre
    var category: Category

    /// Relación inversa con budgets (muchos-a-muchos)
    var budgets: [Budget] = []

    init(
        name: String,
        colorHex: String? = nil,
        isDefaultSeed: Bool = true,
        isVisible: Bool = true,
        sortOrder: Int = 0,
        natureRawValue: String? = nil,
        iconName: String? = nil,
        category: Category
    ) {
        self.name = name
        self.colorHex = colorHex
        self.isDefaultSeed = isDefaultSeed
        self.isVisible = isVisible
        self.sortOrder = sortOrder
        self.natureRawValue = natureRawValue
        self.iconName = iconName
        self.category = category
    }

    // MARK: - System Subcategories

    /// System subcategory names that cannot be deleted (all localizations)
    private static let systemSubcategoryNames: Set<String> = [
        // Balance adjustments (Spanish seed name)
        "Ajustes de saldo",
        // Transfers (Spanish seed name + all localizations)
        "Transferencia entre cuentas",
        "Transfer between accounts",
        "Überweisung zwischen Konten",
        "Virement entre comptes",
        "Trasferimento tra conti",
        "Transferencia entre contas",
    ]

    /// Whether this subcategory is a system subcategory that cannot be deleted
    var isSystemSubcategory: Bool {
        Self.systemSubcategoryNames.contains(name)
    }
}
