//
//  WidgetType+PanelSection.swift
//  Yala
//
//  Maps every WidgetType to its thematic Panel section.
//

import Foundation

/// Thematic sections of the Panel. Each widget belongs to exactly one.
enum PanelSectionKind: String, CaseIterable, Hashable {
    case tendencias
    case distribucion
    case planificacion
    case latestRecords
    case tools

    var localizedTitle: String {
        switch self {
        case .tendencias:    return L10n.Panel.sectionTendencias
        case .distribucion:  return L10n.Panel.sectionDistribucion
        case .planificacion: return L10n.Panel.sectionPlanificacion
        case .latestRecords: return L10n.Panel.sectionLatestRecords
        case .tools:         return L10n.Panel.sectionTools
        }
    }
}

extension WidgetType {

    var panelSection: PanelSectionKind {
        switch self {
        case .trend, .cashFlow, .expensesByNeed:
            return .tendencias
        case .categoriesPie, .subcategoriesPie, .topSpending, .topSubcategories:
            return .distribucion
        case .budgets, .scheduledPayments, .groupsSummary:
            return .planificacion
        case .latestRecords:
            return .latestRecords
        case .exchangeRate:
            return .tools
        }
    }

    static func defaultWidgets(in section: PanelSectionKind) -> [WidgetType] {
        WidgetType.allCases.filter { $0.panelSection == section }
    }
}
