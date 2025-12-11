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

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .trend: return "Tendencia del saldo"
        case .topSpending: return "Categorías principales"
        case .topSubcategories: return "Subcategorías principales"
        }
    }

    var iconName: String {
        switch self {
        case .trend: return "chart.xyaxis.line"
        case .topSpending: return "chart.pie.fill"
        case .topSubcategories: return "list.bullet.indent"
        }
    }
}

enum WidgetSize: String, Codable, CaseIterable, Identifiable {
    case small = "S"
    case medium = "M"
    case large = "L"

    var id: String { rawValue }
}

struct WidgetConfig: Identifiable, Codable, Equatable {
    let id: UUID
    let type: WidgetType
    var isVisible: Bool
    var size: WidgetSize

    // Helper for locking properties
    var isLocked: Bool {
        return type == .trend
    }

    // Default configs generator
    static func defaultConfigs() -> [WidgetConfig] {
        return [
            WidgetConfig(id: UUID(), type: .trend, isVisible: true, size: .large),
            WidgetConfig(id: UUID(), type: .topSpending, isVisible: true, size: .large),
            WidgetConfig(id: UUID(), type: .topSubcategories, isVisible: true, size: .medium),
        ]
    }
}
