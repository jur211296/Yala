//
//  ScheduledPaymentEntities.swift
//  YalaWidgets
//
//  AppEntity and EntityQuery for scheduled payment selection in widgets.
//  Reads from WidgetDataService (App Group cache).
//

import AppIntents

// MARK: - Scheduled Payment App Entity

/// AppEntity representing a scheduled payment for widget configuration
struct ScheduledPaymentAppEntity: AppEntity {
    var id: String
    var name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "widget.entity.payment")
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    static var defaultQuery = ScheduledPaymentEntityQuery()
}

// MARK: - Scheduled Payment Entity Query

/// EntityQuery that reads scheduled payments from the widget data cache
struct ScheduledPaymentEntityQuery: EntityQuery {

    func entities(for identifiers: [String]) async throws -> [ScheduledPaymentAppEntity] {
        let allPayments = WidgetDataService.getScheduledPayments(filter: .all, limit: 100)
        let idSet = Set(identifiers)
        return allPayments
            .filter { idSet.contains($0.id) }
            .map { ScheduledPaymentAppEntity(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [ScheduledPaymentAppEntity] {
        let payments = WidgetDataService.getScheduledPayments(filter: .all, limit: 100)
        return payments.map { ScheduledPaymentAppEntity(id: $0.id, name: $0.name) }
    }

    func defaultResult() async -> ScheduledPaymentAppEntity? {
        nil
    }
}
