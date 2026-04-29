//
//  WidgetInfoContent.swift
//  Yala
//
//  Modelo del payload pedagógico para las sheets informativas de widgets del
//  Panel. Cada `WidgetInfoKind` mapea a su `WidgetType` (para size/visibility
//  prefs) y a su contenido (title + chips + explanation) vía
//  `WidgetInfoContent.content(for:)`.
//
//  Sub-épica: solo los pilotos `cashFlow` y `trend` están implementados en
//  Fase B. El resto de los cases lanzan `fatalError` y se resuelven en el
//  ticket de roll-out.
//

import SwiftUI

enum WidgetInfoKind: String, CaseIterable {
    case trend
    case cashFlow
    case categoriesPie
    case subcategoriesPie
    case tagsPie
    case topCategories
    case topSubcategories
    case budgets
    case scheduledPayments
    case recentRecords
    case exchangeRate
    case expensesByNeed
    case weekdayBar
}

extension WidgetInfoKind {
    /// Mapping inverso a `WidgetType` para resolver size + visibility prefs.
    var widgetType: WidgetType {
        switch self {
        case .trend:             return .trend
        case .cashFlow:          return .cashFlow
        case .categoriesPie:     return .categoriesPie
        case .subcategoriesPie:  return .subcategoriesPie
        case .tagsPie:           return .tagsPie
        case .topCategories:     return .topSpending
        case .topSubcategories:  return .topSubcategories
        case .budgets:           return .budgets
        case .scheduledPayments: return .scheduledPayments
        case .recentRecords:     return .latestRecords
        case .exchangeRate:      return .exchangeRate
        case .expensesByNeed:    return .expensesByNeed
        case .weekdayBar:        return .weekdayBar
        }
    }
}

/// Tag colorido en el header de la sheet pedagógica. La tinta se resuelve
/// contra `YalaTheme` en el chip view (no se almacena `Color` directo aquí
/// porque depende del modo claro/oscuro y del tema activo).
struct InfoChip: Identifiable {
    let id = UUID()
    let label: String
    let tintKey: ChipTint
    let systemImage: String?

    enum ChipTint {
        case income
        case expense
        case accent
        case neutral
    }
}

struct WidgetInfoContent {
    let title: String
    let chips: [InfoChip]
    let explanation: String

    static func content(for kind: WidgetInfoKind) -> WidgetInfoContent {
        switch kind {
        case .trend:
            return WidgetInfoContent(
                title: L10n.Panel.WidgetInfo.Trend.title,
                chips: [
                    InfoChip(label: L10n.Panel.WidgetInfo.Trend.chip1,
                             tintKey: .accent,
                             systemImage: "hand.tap"),
                    InfoChip(label: L10n.Panel.WidgetInfo.Trend.chip2,
                             tintKey: .neutral,
                             systemImage: "calendar"),
                ],
                explanation: L10n.Panel.WidgetInfo.Trend.explanation
            )

        case .cashFlow:
            return WidgetInfoContent(
                title: L10n.Panel.WidgetInfo.CashFlow.title,
                chips: [
                    InfoChip(label: L10n.Panel.WidgetInfo.CashFlow.chip1,
                             tintKey: .income,
                             systemImage: "arrow.up"),
                    InfoChip(label: L10n.Panel.WidgetInfo.CashFlow.chip2,
                             tintKey: .expense,
                             systemImage: "arrow.down"),
                    InfoChip(label: L10n.Panel.WidgetInfo.CashFlow.chip3,
                             tintKey: .neutral,
                             systemImage: "calendar"),
                ],
                explanation: L10n.Panel.WidgetInfo.CashFlow.explanation
            )

        case .categoriesPie, .subcategoriesPie, .tagsPie,
             .topCategories, .topSubcategories,
             .budgets, .scheduledPayments, .recentRecords,
             .exchangeRate, .expensesByNeed, .weekdayBar:
            fatalError("WidgetInfoKind.\(kind) no migrado todavía — ver ticket de roll-out panel-polish-2_widget-info-rollout")
        }
    }
}
