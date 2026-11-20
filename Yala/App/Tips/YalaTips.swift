//
//  YalaTips.swift
//  Yala
//
//  Coach mark step definitions (Groups D-G) and TipKit tips.
//

import SwiftUI
import TipKit

// MARK: - View + Optional Tip (for TipGroup casts)

extension View {
    @ViewBuilder
    func optionalPopoverTip<T: Tip>(_ tip: T?, arrowEdge: Edge = .top) -> some View {
        if let tip {
            self.popoverTip(tip, arrowEdge: arrowEdge)
        } else {
            self
        }
    }
}

// MARK: - Grupo E: Cash Flow Setup Tour

enum CashFlowSetupTourSteps {
    static let steps: [CoachMarkStep] = [
        CoachMarkStep(
            id: "cfSetupBanner",
            title: L10n.TipKit.cfSetupBanner,
            message: L10n.TipKit.cfSetupBannerMessage
        ),
        CoachMarkStep(
            id: "cfSetupLine",
            title: L10n.TipKit.cfSetupLine,
            message: L10n.TipKit.cfSetupLineMessage
        ),
        CoachMarkStep(
            id: "cfSetupStarting",
            title: L10n.TipKit.cfSetupStarting,
            message: L10n.TipKit.cfSetupStartingMessage
        ),
        CoachMarkStep(
            id: "cfSetupCreate",
            title: L10n.TipKit.cfSetupCreate,
            message: L10n.TipKit.cfSetupCreateMessage
        )
    ]
}

// MARK: - Grupo F: Cash Flow Table Tour

enum CashFlowTableTourSteps {
    static let steps: [CoachMarkStep] = [
        CoachMarkStep(
            id: "cfTableCell",
            title: L10n.TipKit.cfTableCell,
            message: L10n.TipKit.cfTableCellMessage
        ),
        CoachMarkStep(
            id: "cfTableAvailable",
            title: L10n.TipKit.cfTableAvailable,
            message: L10n.TipKit.cfTableAvailableMessage
        ),
        CoachMarkStep(
            id: "cfTableAdd",
            title: L10n.TipKit.cfTableAdd,
            message: L10n.TipKit.cfTableAddMessage
        )
    ]
}

// MARK: - Grupo G: «Hoy» del tipo de cambio

/// Quedó solo la guía de «Hoy ⓘ»: el tour Pro (fases de Ajustes, Panel y Estadísticas) se retiró con la opción B de
/// Jürgen del 20-nov-2026; lo de Pro se enseña en «¡Listo! Tienes Pro» (`ProTryNowSection`).
enum ProTourSteps {
    /// Standalone (not Pro Tour): TrendChartView — "Today FX" hint.
    /// 1 step independiente, mostrado primera vez en multi-currency.
    /// El ancla de la píldora «Hoy ⓘ» de la tendencia (`TrendChartView`). El Panel sube hasta ella al sacar la guía
    /// (card 3f57: tras reabrir quedaba bajo la barra de pestañas y la guía se pintaba encima de la barra).
    static let todayFXAnchor = "todayFXHint"
    /// La persistencia vive en `AppPreferences.hasSeenTodayFXCoachMark`.
    static let todayFXSteps: [CoachMarkStep] = [
        CoachMarkStep(
            id: todayFXAnchor,
            title: L10n.Panel.LiveAnchorEducation.coachTitle,
            message: L10n.Panel.LiveAnchorEducation.coachMessage
        ),
    ]
}

// MARK: - TipKit Tip (standalone)

/// Panel progresivo (acuerdo de Jürgen del 19-nov-2026): con Primeros pasos a medias no sale ningún consejo de TipKit.
/// Cada consejo lleva la regla; el Panel la mueve al cambiar el mazo (`PrimerosPasosPanelGateObserver`).
enum PrimerosPasosTipGate {
    @Parameter
    static var primerosPasosShown: Bool = false

    static func update(primerosPasosShown shown: Bool) {
        guard primerosPasosShown != shown else { return }
        primerosPasosShown = shown
    }
}

struct ComparisonTip: Tip {
    @Parameter
    static var hasVisitedStatistics: Bool = false

    var title: Text { Text(L10n.TipKit.comparison) }
    var message: Text? { Text(L10n.TipKit.comparisonMessage) }

    var rules: [Rule] {
        [#Rule(Self.$hasVisitedStatistics) { $0 == true },
         #Rule(PrimerosPasosTipGate.$primerosPasosShown) { $0 == false }]
    }
}

struct AIChartsProTip: Tip {
    @Parameter
    static var hasSeenCharts: Bool = false

    var title: Text { Text(L10n.TipKit.aiChartsPro) }
    var message: Text? { Text(L10n.TipKit.aiChartsProMessage) }

    var rules: [Rule] {
        [#Rule(Self.$hasSeenCharts) { $0 == true },
         #Rule(PrimerosPasosTipGate.$primerosPasosShown) { $0 == false }]
    }
}

struct AIChartsFreeUpsellTip: Tip {
    @Parameter
    static var hasSeenCharts: Bool = false

    var title: Text { Text(L10n.TipKit.aiChartsFree) }
    var message: Text? { Text(L10n.TipKit.aiChartsFreeMessage) }

    var rules: [Rule] {
        [#Rule(Self.$hasSeenCharts) { $0 == true },
         #Rule(PrimerosPasosTipGate.$primerosPasosShown) { $0 == false }]
    }
}
