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

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .trend: return "Tendencias"
        case .topSpending: return "Top categorías"
        case .topSubcategories: return "Top subcategorías"
        case .cashFlow: return "Flujo de efectivo"
        case .categoriesPie: return "Distribución de categorías"
        case .subcategoriesPie: return "Distribución de subcategorías"
        case .latestRecords: return "Últimos registros"
        case .expensesByNature: return "Gastos por naturaleza"
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
        }
    }

    var supportedSizes: [WidgetSize] {
        switch self {
        case .trend: return [.medium, .large]
        case .cashFlow: return [.medium, .large]
        case .topSpending: return [.medium, .large]
        case .topSubcategories: return [.medium, .large]
        case .categoriesPie: return [.large]  // Tamaño único
        case .subcategoriesPie: return [.large]  // Tamaño único
        case .latestRecords: return [.medium]  // Tamaño único
        case .expensesByNature: return [.medium, .large]
        }
    }

    /// Returns custom size name for the widget, or nil if single size
    func displaySizeName(for size: WidgetSize) -> String? {
        switch self {
        case .trend, .cashFlow, .expensesByNature:
            return size == .medium ? "Compacta" : "Ampliada"
        case .topSpending, .topSubcategories:
            return size == .medium ? "Top 3" : "Top 5"
        case .categoriesPie, .subcategoriesPie, .latestRecords:
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
        ]
    }
}
