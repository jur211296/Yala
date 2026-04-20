//
//  WidgetType+PanelSection.swift
//  Yala
//
//  Maps every WidgetType to its thematic Panel section.
//

import Foundation

/// Thematic sections of the Panel. Each widget belongs to exactly one.
///
/// `health` is the P20-06 Salud Financiera section. It already appears in the
/// P20-02 config sheet so the user can toggle it, and its render code picks up
/// the persisted state from the sections-hidden list.
enum PanelSectionKind: String, CaseIterable, Hashable {
    case health
    case tendencias
    case distribucion
    case planificacion
    case latestRecords
    case tools

    var localizedTitle: String {
        switch self {
        case .health:        return L10n.Panel.sectionHealth
        case .tendencias:    return L10n.Panel.sectionTendencias
        case .distribucion:  return L10n.Panel.sectionDistribucion
        case .planificacion: return L10n.Panel.sectionPlanificacion
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

    /// True when the section has ≥2 widgets — only these show the per-section
    /// preferences gear in the Panel header (P20-03). Single-widget sections
    /// have nothing to reorder or toggle.
    var hasMultipleWidgets: Bool {
        WidgetType.defaultWidgets(in: self).count >= 2
    }

    /// Toggleable sections shown in the config sheet, in display order.
    static var toggleableSections: [PanelSectionKind] {
        Self.allCases.filter(\.canBeHidden)
    }
}

// MARK: - Identifiable

/// Enables `.sheet(item: $binding)` patterns where the section kind itself
/// identifies which per-section preferences sheet to present (P20-03).
extension PanelSectionKind: Identifiable {
    var id: String { rawValue }
}

extension WidgetType {

    var panelSection: PanelSectionKind {
        switch self {
        case .trend, .cashFlow, .expensesByNeed, .weekdayBar:
            return .tendencias
        case .categoriesPie, .subcategoriesPie, .topSpending, .topSubcategories, .tagsPie:
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
