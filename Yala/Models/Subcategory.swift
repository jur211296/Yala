//
//  Subcategory.swift
//  Yala
//
//  Created by Yala Refactoring.
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

    /// Relación inversa con la categoría padre (optional for CloudKit compatibility)
    var category: Category?

    /// Relación inversa con budgets (muchos-a-muchos)
    var budgets: [Budget] = []

    /// Inverse relationship: transactions linked to this subcategory
    var transactions: [TransactionItem] = []

    /// Inverse relationship: favorite payments linked to this subcategory
    var favoritePayments: [FavoritePayment] = []

    /// Inverse relationship: scheduled payments linked to this subcategory
    var scheduledPayments: [ScheduledPayment] = []

    init(
        name: String,
        colorHex: String? = nil,
        isDefaultSeed: Bool = true,
        isVisible: Bool = true,
        sortOrder: Int = 0,
        natureRawValue: String? = nil,
        iconName: String? = nil,
        category: Category?
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

}

// MARK: - System Subcategories

extension Subcategory {
    /// System subcategory names that cannot be deleted (all localizations)
    static let systemSubcategoryNames: Set<String> = [
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

// MARK: - CloudKit Compatibility

extension Subcategory {
    /// Safe access to category. CloudKit requires optional relationships,
    /// but semantically a Subcategory always has a Category.
    /// Use this for UI/logic where category is guaranteed to exist.
    var safeCategory: Category {
        guard let cat = category else {
            // This should never happen in normal operation
            assertionFailure("Subcategory '\(name)' has no category")
            // Return a placeholder to avoid crash in production
            return Category(name: "Unknown", colorHex: "#6366F1", isIncome: false)
        }
        return cat
    }
}
