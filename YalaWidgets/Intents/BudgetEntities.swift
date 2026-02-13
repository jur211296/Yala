//
//  BudgetEntities.swift
//  YalaWidgets
//
//  AppEntity and EntityQuery for budget selection in widgets.
//  Reads from WidgetDataService (App Group cache).
//

import AppIntents

// MARK: - Budget App Entity

/// AppEntity representing a budget for widget configuration
struct BudgetAppEntity: AppEntity {
    var id: String
    var name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "widget.entity.budget")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static var defaultQuery = BudgetEntityQuery()
}

// MARK: - Budget Entity Query

/// EntityQuery that reads budgets from the widget data cache
struct BudgetEntityQuery: EntityQuery {

    func entities(for identifiers: [String]) async throws -> [BudgetAppEntity] {
        let allBudgets = WidgetDataService.getBudgets(sortByCritical: false)
        let idSet = Set(identifiers)
        return allBudgets
            .filter { idSet.contains($0.id) }
            .map { BudgetAppEntity(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [BudgetAppEntity] {
        let budgets = WidgetDataService.getBudgets(sortByCritical: true)
        return budgets.map { BudgetAppEntity(id: $0.id, name: $0.name) }
    }

    func defaultResult() async -> BudgetAppEntity? {
        nil
    }
}
