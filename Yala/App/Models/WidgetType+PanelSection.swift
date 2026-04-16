//
//  WidgetType+PanelSection.swift
//  Yala
//
//  Maps every WidgetType to its thematic Panel section.
//

import Foundation

/// Thematic sections of the Panel. Each widget belongs to exactly one.
///
/// `health` and `paraTi` are reserved for P20-06 (Financial Score) and P20-10
/// (Para ti). They already appear in the P20-02 config sheet so the user can
/// toggle them; the corresponding render code arrives later in the epic and
/// will pick up the persisted state without further changes.
enum PanelSectionKind: String, CaseIterable, Hashable {
    case health
    case tendencias
    case distribucion
    case planificacion
    case paraTi
    case latestRecords
    case tools

    var localizedTitle: String {
        switch self {
        case .health:        return L10n.Panel.sectionHealth
        case .tendencias:    return L10n.Panel.sectionTendencias
        case .distribucion:  return L10n.Panel.sectionDistribucion
        case .planificacion: return L10n.Panel.sectionPlanificacion
        case .paraTi:        return L10n.Panel.sectionParaTi
        case .latestRecords: return L10n.Panel.sectionLatestRecords
        case .tools:         return L10n.Panel.sectionTools
        }
    }

    /// SF Symbol used in the sections-config sheet.
    var iconName: String {
        switch self {
        case .health:        return "heart.text.square"
        case .tendencias:    return "chart.line.uptrend.xyaxis"
        case .distribucion:  return "chart.pie"
        case .planificacion: return "calendar"
        case .paraTi:        return "sparkles"
        case .latestRecords: return "list.bullet.rectangle"
        case .tools:         return "wrench.and.screwdriver"
        }
    }

    /// Sections the user can hide from the config sheet. `latestRecords` is the
    /// Panel's primary CTA and stays visible at all times.
    var canBeHidden: Bool {
        switch self {
        case .latestRecords: return false
        default:             return true
        }
    }

    /// Toggleable sections shown in the config sheet, in display order.
    static var toggleableSections: [PanelSectionKind] {
        Self.allCases.filter(\.canBeHidden)
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
