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
        }
    }

    var supportedSizes: [WidgetSize] {
        switch self {
        case .trend: return [.medium]  // Tamaño único (compacta)
        case .cashFlow: return [.medium, .large]
        case .topSpending: return [.medium, .large]
        case .topSubcategories: return [.medium, .large]
        case .categoriesPie: return [.large]  // Tamaño único
        case .subcategoriesPie: return [.large]  // Tamaño único
        case .latestRecords: return [.medium]  // Tamaño único
        case .expensesByNeed: return [.medium, .large]
        case .exchangeRate: return [.medium]  // Tamaño único
        case .budgets: return [.medium, .large]  // Top 3 / Top 5
        case .scheduledPayments: return [.medium]  // Single size, mode selected in preferences
        }
    }

    /// Returns custom size name for the widget, or nil if single size
    func displaySizeName(for size: WidgetSize) -> String? {
        switch self {
        case .cashFlow, .expensesByNeed:
            return size == .medium ? L10n.Widget.compact : L10n.Widget.expanded
        case .topSpending, .topSubcategories, .budgets:
            return size == .medium ? L10n.Widget.top3 : L10n.Widget.top5
        case .trend, .categoriesPie, .subcategoriesPie, .latestRecords, .exchangeRate, .scheduledPayments:
            return nil  // Single size, no name needed
        }
    }
}

enum WidgetSize: String, Codable, CaseIterable, Identifiable {
    case medium = "M"
    case large = "L"

    var id: String { rawValue }
}

struct WidgetConfig: Identifiable, Codable, Equatable {
    let id: UUID
    let type: WidgetType
    var isVisible: Bool
    var size: WidgetSize

    var isLocked: Bool = false

    /// Mode for scheduled payments widget (only used when type == .scheduledPayments)
    var scheduledPaymentsMode: ScheduledPaymentsWidgetMode = .summary

    // Default configs generator
    // Order: Tendencias, Flujo, Dist.Cat, Dist.Subcat, TopCat, TopSubcat, Naturaleza, Registros, Presupuestos, Pagos, Cambio
    // Defaults visible: trend, cashFlow, categoriesPie, topSubcategories, latestRecords
    static func defaultConfigs() -> [WidgetConfig] {
        return [
            WidgetConfig(id: UUID(), type: .trend, isVisible: true, size: .medium),
            WidgetConfig(id: UUID(), type: .cashFlow, isVisible: true, size: .medium),
            WidgetConfig(id: UUID(), type: .categoriesPie, isVisible: true, size: .large),
            WidgetConfig(id: UUID(), type: .subcategoriesPie, isVisible: false, size: .large),
            WidgetConfig(id: UUID(), type: .topSpending, isVisible: false, size: .medium),
            WidgetConfig(id: UUID(), type: .topSubcategories, isVisible: true, size: .medium),
            WidgetConfig(id: UUID(), type: .expensesByNeed, isVisible: false, size: .medium),
            WidgetConfig(id: UUID(), type: .latestRecords, isVisible: true, size: .medium),
            WidgetConfig(id: UUID(), type: .budgets, isVisible: false, size: .medium),
            WidgetConfig(id: UUID(), type: .scheduledPayments, isVisible: false, size: .medium),
            WidgetConfig(id: UUID(), type: .exchangeRate, isVisible: false, size: .medium),
        ]
    }
}

// MARK: - Scheduled Payments Widget Enums

/// View mode for scheduled payments widget (selected in preferences)
enum ScheduledPaymentsWidgetMode: String, Codable, CaseIterable, Identifiable {
    case summary
    case list
    case calendar

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .summary: return "square.text.square"
        case .list: return "list.bullet"
        case .calendar: return "calendar"
        }
    }

    var displayName: String {
        switch self {
        case .summary: return L10n.Widget.summary
        case .list: return L10n.Widget.list
        case .calendar: return L10n.Widget.calendar
        }
    }
}

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
