//
//  DevSeedBudgets.swift
//  Yala
//
//  Creates 6 budgets linked to subcategories for dev seed data.
//

#if DEBUG
import Foundation
import SwiftData

struct DevSeedBudgets {

    @MainActor
    static func create(
        account: Account,
        subcategoryLookup: [String: Subcategory],
        in context: ModelContext
    ) {
        let budgetDefs: [(name: String, limit: Double, categoryName: String)] = [
            ("Comidas fuera", 1800, L10n.Category.food),
            ("Movilidad", 600, L10n.Category.transport),
            ("Salidas con amigos", 1200, L10n.Category.entertainment),
            ("Cuidado personal", 800, L10n.Category.personal),
            ("Fijos casa", 3200, L10n.Category.housing),
            ("Maia 🐶", 500, L10n.Category.pets),
        ]

        // Group subcategories by category name
        var subcategoriesByCategory: [String: [Subcategory]] = [:]
        for (_, sub) in subcategoryLookup {
            let catName = sub.category?.name ?? ""
            subcategoriesByCategory[catName, default: []].append(sub)
        }

        for def in budgetDefs {
            let subs = subcategoriesByCategory[def.categoryName] ?? []
            let category = subs.first?.category

            let budget = Budget(
                currencyCode: "PEN",
                limitAmount: def.limit,
                category: category,
                name: def.name,
                periodType: "monthly",
                accounts: [account],
                subcategories: subs,
                alertEnabled: true,
                alertThresholds: "50,75,100"
            )
            context.insert(budget)
        }
    }
}
#endif
