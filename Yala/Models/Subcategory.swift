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
    // CloudKit: defaults required
    var name: String = ""
    var colorHex: String?

    /// Stable identifier for App Intents (Siri/Shortcuts). Unaffected by name/category renames.
    /// CloudKit: must have default value, no `@Attribute(.unique)`. Migration: legacy entities
    /// receive a UUID at first save via AppBootstrapper.persistAppEntityShortcutIDsIfNeeded.
    var shortcutID: UUID = UUID()

    /// Indica si esta subcategoría proviene de la semilla inicial
    var isDefaultSeed: Bool = false
    /// Control de visibilidad dentro de la app
    var isVisible: Bool = true
    /// Orden de presentación dentro de su categoría
    var sortOrder: Int = 0
    /// Campo reservado para futura "naturaleza" (Necesario / Deseable / etc.)
    var natureRawValue: String?
    /// Nombre del icono SF Symbol (opcional)
    var iconName: String?

    /// True para subcategorías sistema persistentes (creadas por seed para flujos como bridge de grupos).
    /// CloudKit: must have default value. Excluidas de pickers manuales, presupuestos y "Top categorías".
    /// NOTA: coexiste con `isSystemSubcategory` (computed legacy basado en nombre para "Ajuste de saldo"/"Transferencia").
    /// Usar `isAnySystem` cuando se quiera filtrar AMBOS tipos de subcategoría sistema.
    var isSystem: Bool = false

    /// Relación inversa con la categoría padre (optional for CloudKit compatibility)
    @Relationship(deleteRule: .nullify)
    var category: Category?

    /// Relación inversa con budgets (muchos-a-muchos) - CloudKit: must be optional
    @Relationship(deleteRule: .nullify)
    var budgets: [Budget]?

    /// Inverse relationship: transactions linked to this subcategory - CloudKit: must be optional
    @Relationship(deleteRule: .nullify)
    var transactions: [TransactionItem]?

    /// Inverse relationship: favorite payments linked to this subcategory - CloudKit: must be optional
    @Relationship(deleteRule: .nullify)
    var favoritePayments: [FavoritePayment]?

    /// Inverse relationship: scheduled payments linked to this subcategory - CloudKit: must be optional
    @Relationship(deleteRule: .nullify)
    var scheduledPayments: [ScheduledPayment]?

    /// Inverse relationship: inbox drafts linked to this subcategory - CloudKit: must be optional
    @Relationship(deleteRule: .nullify)
    var inboxDrafts: [InboxDraft]?

    /// Inverse relationship: merchant memories linked to this subcategory - CloudKit: must be optional
    @Relationship(deleteRule: .nullify)
    var merchantMemories: [MerchantMemory]?

    /// Inverse relationship: cash flow lines linked to this subcategory - CloudKit: must be optional
    @Relationship(deleteRule: .nullify)
    var cashFlowLines: [CashFlowLine]?

    init(
        name: String,
        colorHex: String? = nil,
        isDefaultSeed: Bool = true,
        isVisible: Bool = true,
        sortOrder: Int = 0,
        natureRawValue: String? = nil,
        iconName: String? = nil,
        isSystem: Bool = false,
        category: Category?
    ) {
        self.name = name
        self.colorHex = colorHex
        self.isDefaultSeed = isDefaultSeed
        self.isVisible = isVisible
        self.sortOrder = sortOrder
        self.natureRawValue = natureRawValue
        self.iconName = iconName
        self.isSystem = isSystem
        self.category = category
    }

}

// MARK: - System Subcategories

extension Subcategory {
    /// Balance adjustment subcategory names (all localizations)
    static let balanceAdjustmentNames: Set<String> = [
        "Ajustes de saldo",
        "Balance adjustments", "Balance adjustment",
        "Saldoanpassungen", "Saldoanpassung",
        "Ajustements de solde", "Ajustement de solde",
        "Rettifiche del saldo", "Aggiustamento saldo",
        "Ajuste de saldo",
    ]

    /// Transfer subcategory names (all localizations)
    static let transferNames: Set<String> = [
        "Transferencia entre cuentas",
        "Transfer between accounts",
        "Überweisung zwischen Konten",
        "Virement entre comptes",
        "Trasferimento tra conti",
        "Transferencia entre contas",
    ]

    /// System subcategory names that cannot be deleted (all localizations)
    static let systemSubcategoryNames: Set<String> = balanceAdjustmentNames.union(transferNames)

    /// Whether this subcategory is a system subcategory that cannot be deleted
    var isSystemSubcategory: Bool {
        Self.systemSubcategoryNames.contains(name)
    }

    /// True si es subcategoría sistema legacy (computed por nombre) O nuevo flag persistente `isSystem`.
    /// Usar este helper en filtros UI/stats que deben ocultar TODA subcat sistema.
    var isAnySystem: Bool {
        isSystemSubcategory || isSystem
    }
}

// MARK: - CloudKit Compatibility

extension Subcategory {
    /// Safe access to category. CloudKit requires optional relationships,
    /// but semantically a Subcategory always has a Category.
    /// Use this for UI/logic where category is guaranteed to exist.
    /// Cached placeholder to avoid creating new Category objects on each access.
    private static let placeholderCategory = Category(name: "Unknown", colorHex: "#6366F1", isIncome: false)

    var safeCategory: Category {
        guard let cat = category else {
            #if DEBUG
            print("Subcategory: Warning: '\(name)' has no category — returning placeholder")
            #endif
            return Self.placeholderCategory
        }
        return cat
    }
}
