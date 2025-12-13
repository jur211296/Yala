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

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .trend: return "Tendencia del saldo"
        case .topSpending: return "Categorías principales"
        case .topSubcategories: return "Subcategorías principales"
        case .cashFlow: return "Flujo de efectivo"
        }
    }

    var iconName: String {
        switch self {
        case .trend: return "chart.xyaxis.line"
        case .topSpending: return "chart.pie.fill"
        case .topSubcategories: return "list.bullet.indent"
        case .cashFlow: return "arrow.up.arrow.down"
        }
    }
    var supportedSizes: [WidgetSize] {
        switch self {
        case .cashFlow: return [.small, .medium, .large]
        default: return WidgetSize.allCases
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

    var isLocked: Bool = false

    // Default configs generator
    static func defaultConfigs() -> [WidgetConfig] {
        return [
            WidgetConfig(id: UUID(), type: .trend, isVisible: true, size: .large),  // Locked, always large
            WidgetConfig(id: UUID(), type: .cashFlow, isVisible: true, size: .medium),
            WidgetConfig(id: UUID(), type: .topSpending, isVisible: true, size: .medium),
            WidgetConfig(id: UUID(), type: .topSubcategories, isVisible: true, size: .medium),
        ]
    }
}
