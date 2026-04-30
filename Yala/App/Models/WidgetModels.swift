//
//  WidgetModels.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import Foundation

enum WidgetType: String, Codable, CaseIterable, Identifiable {
    case trend = "tendencia_saldo"
    case topSpending = "categorias_principales"
    case topSubcategories = "subcategorias_principales"
    case cashFlow = "flujo_efectivo"
    case categoriesPie = "categorias_torta"
    case subcategoriesPie = "subcategorias_torta"
    case latestRecords = "ultimos_registros"
    case expensesByNeed = "gastos_por_naturaleza"
    case exchangeRate = "tipo_cambio"
    case budgets = "presupuestos"
    case scheduledPayments = "pagos_planificados"
    case weekdayBar = "gasto_por_dia"
    case tagsPie = "distribucion_por_etiquetas"

    // `"resumen_grupos"` persisted in v1.x prefs is dropped by
    // `buildOrderedRawWidgets` self-healing (removed in P20-11).

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .trend: return L10n.WidgetType.trend
        case .topSpending: return L10n.WidgetType.topSpending
        case .topSubcategories: return L10n.WidgetType.topSubcategories
        case .cashFlow: return L10n.WidgetType.cashFlow
        case .categoriesPie: return L10n.WidgetType.categoriesPie
        case .subcategoriesPie: return L10n.WidgetType.subcategoriesPie
        case .latestRecords: return L10n.WidgetType.latestRecords
        case .expensesByNeed: return L10n.WidgetType.expensesByNeed
        case .exchangeRate: return L10n.WidgetType.exchangeRate
        case .budgets: return L10n.WidgetType.budgets
        case .scheduledPayments: return L10n.WidgetType.scheduledPayments
        case .weekdayBar: return L10n.WidgetType.weekdayBar
        case .tagsPie: return L10n.WidgetType.expensesByTag
        }
    }

    var iconName: String {
        switch self {
        case .trend: return "chart.xyaxis.line"
        case .topSpending: return "chart.pie.fill"
        case .topSubcategories: return "list.bullet.indent"
        case .cashFlow: return "arrow.up.arrow.down"
        case .categoriesPie: return "chart.pie"
        case .subcategoriesPie: return "chart.pie"
        case .latestRecords: return "list.bullet.rectangle"
        case .expensesByNeed: return "chart.bar.xaxis"
        case .exchangeRate: return "arrow.left.arrow.right"
        case .budgets: return "chart.pie.fill"
        case .scheduledPayments: return "calendar.badge.clock"
        case .weekdayBar: return "calendar.day.timeline.left"
        case .tagsPie: return "tag.fill"
        }
    }

    var supportedSizes: [WidgetSize] {
        switch self {
        case .trend: return [.small, .large]  // PP2-06c
        case .cashFlow: return [.small, .medium, .large]  // PP2-06c
        case .topSpending: return [.small, .medium, .large]  // PP2-05 piloto
        case .topSubcategories: return [.small, .medium, .large]  // PP2-06
        case .categoriesPie: return [.small, .large]  // PP2-05 piloto
        case .subcategoriesPie: return [.small, .large]  // PP2-06
        case .latestRecords: return [.medium]  // Tamaño único
        case .expensesByNeed: return [.small, .medium, .large]  // PP2-06c
        case .exchangeRate: return [.medium]  // Tamaño único
        case .budgets: return [.small, .medium, .large]  // PP2-06b
        case .scheduledPayments: return [.small, .medium]  // PP2-06b
        case .weekdayBar: return [.small, .large]  // PP2-06c
        case .tagsPie: return [.small, .large]  // PP2-06
        }
    }

}

enum WidgetSize: String, Codable, CaseIterable, Identifiable {
    case small = "S"
    case medium = "M"
    case large = "L"

    var id: String { rawValue }

    /// PP2-05: altura TOTAL del card (incluyendo padding del `.solidCard`) para widgets `.small`.
    /// Garantiza matching visual exacto en half-pair aunque los widgets usen distinto padding de card.
    static let smallHeight: CGFloat = 192
}

struct WidgetConfig: Identifiable, Codable, Equatable {
    let id: UUID
    let type: WidgetType
    var isVisible: Bool
    var size: WidgetSize

    var isLocked: Bool = false

    static func defaultConfigs() -> [WidgetConfig] {
        // Visibility real vive en `AppPreferences.panel<Section>Hidden`
        // (P20-03 SSOT); los `isVisible` aquí son solo fallback silencioso
        // durante bootstrap antes de inyectar AppPreferences.
        return [
            WidgetConfig(id: UUID(), type: .trend, isVisible: true, size: .small),
            WidgetConfig(id: UUID(), type: .cashFlow, isVisible: true, size: .medium),
            WidgetConfig(id: UUID(), type: .categoriesPie, isVisible: true, size: .small),
            WidgetConfig(id: UUID(), type: .subcategoriesPie, isVisible: true, size: .small),
            WidgetConfig(id: UUID(), type: .topSpending, isVisible: false, size: .medium),
            WidgetConfig(id: UUID(), type: .topSubcategories, isVisible: false, size: .medium),
            WidgetConfig(id: UUID(), type: .expensesByNeed, isVisible: true, size: .medium),
            WidgetConfig(id: UUID(), type: .latestRecords, isVisible: true, size: .medium),
            WidgetConfig(id: UUID(), type: .budgets, isVisible: true, size: .small),
            WidgetConfig(id: UUID(), type: .scheduledPayments, isVisible: true, size: .small),
            WidgetConfig(id: UUID(), type: .exchangeRate, isVisible: false, size: .medium),
            WidgetConfig(id: UUID(), type: .weekdayBar, isVisible: true, size: .small),
            WidgetConfig(id: UUID(), type: .tagsPie, isVisible: false, size: .small),
        ]
    }
}

// MARK: - Scheduled Payments Widget Enums

/// Filter for scheduled payments widget
enum ScheduledPaymentsWidgetFilter: String, CaseIterable, Identifiable {
    case all
    case recurring
    case subscriptions

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .all: return "list.bullet"
        case .recurring: return "arrow.trianglehead.2.clockwise.rotate.90"
        case .subscriptions: return "creditcard.and.123"
        }
    }

    /// Maps to PaymentCategory rawValue for filtering
    var paymentCategoryFilter: String? {
        switch self {
        case .all: return nil
        case .recurring: return "recurring"
        case .subscriptions: return "subscription"
        }
    }
}
