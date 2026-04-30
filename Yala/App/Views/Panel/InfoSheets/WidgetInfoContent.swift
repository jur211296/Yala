//
//  WidgetInfoContent.swift
//  Yala
//
//  Modelo del payload pedagógico de las sheets de widgets del Panel.
//  Solo los pilotos `cashFlow` y `trend` están implementados (Fase B); el
//  resto lanza `fatalError` hasta el ticket de roll-out.
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
    let label: String
    let tintKey: ChipTint
    let systemImage: String?

    /// Identidad estable derivada del label — evita que `ForEach` recree
    /// la vista del chip en cada render del padre.
    var id: String { label }

    enum ChipTint {
        case income
        case expense
        case accent
        case neutral
    }
}

struct InfoSection: Identifiable {
    let question: String
    let answer: String

    /// Identidad estable derivada de la pregunta — evita que `ForEach`
    /// recree la fila en cada render del padre.
    var id: String { question }
}

struct WidgetInfoContent {
    let title: String
    /// Resuelve los chips descriptores para un `WidgetSize`. El chip
    /// "Interactiva" solo se muestra cuando el size soporta scrubbing u
    /// otros gestos en la gráfica.
    let chips: (WidgetSize) -> [InfoChip]
    /// Resuelve las secciones Q&A para un `WidgetSize`. Cada widget puede
    /// tener un set distinto según la interactividad real del layout (small
    /// suele ser solo descriptivo; large suele incluir explicación de
    /// interacción).
    let sections: (WidgetSize) -> [InfoSection]

    static func content(for kind: WidgetInfoKind) -> WidgetInfoContent {
        switch kind {
        case .trend:
            let interactiveChip = InfoChip(label: L10n.Panel.WidgetInfo.Trend.chip1,
                                           tintKey: .accent,
                                           systemImage: "hand.tap")
            let periodChip = InfoChip(label: L10n.Panel.WidgetInfo.Trend.chip2,
                                      tintKey: .neutral,
                                      systemImage: "calendar")
            return WidgetInfoContent(
                title: L10n.Panel.WidgetInfo.Trend.title,
                chips: { size in
                    switch size {
                    case .small:           return [periodChip]
                    case .medium, .large:  return [interactiveChip, periodChip]
                    }
                },
                sections: { size in
                    switch size {
                    case .small:
                        return [
                            InfoSection(
                                question: L10n.Panel.WidgetInfo.Trend.smallWhatQ,
                                answer: L10n.Panel.WidgetInfo.Trend.smallWhatA
                            ),
                        ]
                    case .medium, .large:
                        return [
                            InfoSection(
                                question: L10n.Panel.WidgetInfo.Trend.largeWhatQ,
                                answer: L10n.Panel.WidgetInfo.Trend.largeWhatA
                            ),
                            InfoSection(
                                question: L10n.Panel.WidgetInfo.Trend.largeHowQ,
                                answer: L10n.Panel.WidgetInfo.Trend.largeHowA
                            ),
                        ]
                    }
                }
            )

        case .cashFlow:
            let incomeChip = InfoChip(label: L10n.Panel.WidgetInfo.CashFlow.chip1,
                                      tintKey: .income,
                                      systemImage: "arrow.up")
            let expenseChip = InfoChip(label: L10n.Panel.WidgetInfo.CashFlow.chip2,
                                       tintKey: .expense,
                                       systemImage: "arrow.down")
            let periodChip = InfoChip(label: L10n.Panel.WidgetInfo.CashFlow.chip3,
                                      tintKey: .neutral,
                                      systemImage: "calendar")
            let interactiveChip = InfoChip(label: L10n.Panel.WidgetInfo.CashFlow.chip4,
                                           tintKey: .accent,
                                           systemImage: "hand.tap")
            return WidgetInfoContent(
                title: L10n.Panel.WidgetInfo.CashFlow.title,
                chips: { size in
                    switch size {
                    case .small, .medium:
                        return [incomeChip, expenseChip, periodChip]
                    case .large:
                        return [incomeChip, expenseChip, periodChip, interactiveChip]
                    }
                },
                sections: { size in
                    switch size {
                    case .small:
                        return [
                            InfoSection(
                                question: L10n.Panel.WidgetInfo.CashFlow.smallWhatQ,
                                answer: L10n.Panel.WidgetInfo.CashFlow.smallWhatA
                            ),
                            InfoSection(
                                question: L10n.Panel.WidgetInfo.CashFlow.balanceQ,
                                answer: L10n.Panel.WidgetInfo.CashFlow.balanceA
                            ),
                        ]
                    case .medium:
                        return [
                            InfoSection(
                                question: L10n.Panel.WidgetInfo.CashFlow.mediumWhatQ,
                                answer: L10n.Panel.WidgetInfo.CashFlow.mediumWhatA
                            ),
                            InfoSection(
                                question: L10n.Panel.WidgetInfo.CashFlow.balanceQ,
                                answer: L10n.Panel.WidgetInfo.CashFlow.balanceA
                            ),
                        ]
                    case .large:
                        return [
                            InfoSection(
                                question: L10n.Panel.WidgetInfo.CashFlow.largeWhatQ,
                                answer: L10n.Panel.WidgetInfo.CashFlow.largeWhatA
                            ),
                            InfoSection(
                                question: L10n.Panel.WidgetInfo.CashFlow.largeHowQ,
                                answer: L10n.Panel.WidgetInfo.CashFlow.largeHowA
                            ),
                            InfoSection(
                                question: L10n.Panel.WidgetInfo.CashFlow.balanceQ,
                                answer: L10n.Panel.WidgetInfo.CashFlow.balanceA
                            ),
                        ]
                    }
                }
            )

        case .categoriesPie, .subcategoriesPie, .tagsPie,
             .topCategories, .topSubcategories,
             .budgets, .scheduledPayments, .recentRecords,
             .exchangeRate, .expensesByNeed, .weekdayBar:
            fatalError("WidgetInfoKind.\(kind) no migrado todavía — ver ticket de roll-out panel-polish-2_widget-info-rollout")
        }
    }
}
