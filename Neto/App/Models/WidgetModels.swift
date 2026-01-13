//
//  WidgetModels.swift
//  Neto
//
//  Created by Neto Refactoring.
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
    case expensesByNature = "gastos_por_naturaleza"
    case exchangeRate = "tipo_cambio"

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
        case .expensesByNature: return L10n.WidgetType.expensesByNature
        case .exchangeRate: return L10n.WidgetType.exchangeRate
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
        case .expensesByNature: return "chart.bar.xaxis"
        case .exchangeRate: return "arrow.left.arrow.right"
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
        case .expensesByNature: return [.medium, .large]
        case .exchangeRate: return [.medium]  // Tamaño único
        }
    }

    /// Returns custom size name for the widget, or nil if single size
    func displaySizeName(for size: WidgetSize) -> String? {
        switch self {
        case .cashFlow, .expensesByNature:
            return size == .medium ? L10n.Widget.compact : L10n.Widget.expanded
        case .topSpending, .topSubcategories:
            return size == .medium ? L10n.Widget.top3 : L10n.Widget.top5
        case .trend, .categoriesPie, .subcategoriesPie, .latestRecords, .exchangeRate:
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

    // Default configs generator
    static func defaultConfigs() -> [WidgetConfig] {
        return [
            WidgetConfig(id: UUID(), type: .trend, isVisible: true, size: .medium),
            WidgetConfig(id: UUID(), type: .cashFlow, isVisible: true, size: .medium),
            WidgetConfig(id: UUID(), type: .topSpending, isVisible: false, size: .medium),
            WidgetConfig(id: UUID(), type: .topSubcategories, isVisible: false, size: .medium),
            WidgetConfig(id: UUID(), type: .categoriesPie, isVisible: true, size: .large),
            WidgetConfig(id: UUID(), type: .subcategoriesPie, isVisible: false, size: .large),
            WidgetConfig(id: UUID(), type: .expensesByNature, isVisible: true, size: .medium),
            WidgetConfig(id: UUID(), type: .latestRecords, isVisible: true, size: .medium),
            WidgetConfig(id: UUID(), type: .exchangeRate, isVisible: false, size: .medium),
        ]
    }
}
