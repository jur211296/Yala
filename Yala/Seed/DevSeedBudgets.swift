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
            (L10n.DevSeed.budgetEatingOut, 1800, L10n.Category.food),
            (L10n.DevSeed.budgetMobility, 600, L10n.Category.transport),
            (L10n.DevSeed.budgetFriendsOutings, 1200, L10n.Category.entertainment),
            (L10n.DevSeed.budgetPersonalCare, 800, L10n.Category.personal),
            (L10n.DevSeed.budgetHomeEssentials, 3200, L10n.Category.housing),
            (L10n.DevSeed.budgetPet, 500, L10n.Category.pets),
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
