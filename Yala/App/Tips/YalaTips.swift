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

// MARK: - Grupo D: Tour de Settings

/// UX 2.2 · L5-9 (opción A): tres pasos, lo que una persona nueva necesita saber dónde está —dónde se corrige el
/// saldo, dónde se personaliza y dónde están los tutoriales—. Antes eran nueve que leían el nombre de cada fila.
enum SettingsTourSteps {
    static let steps: [CoachMarkStep] = [
        CoachMarkStep(
            id: "settingsAccounts",
            title: L10n.TipKit.settingsAccounts,
            message: L10n.TipKit.settingsAccountsMessage
        ),
        CoachMarkStep(
            id: "settingsPersonalization",
            title: L10n.TipKit.settingsPersonalization,
            message: L10n.TipKit.settingsPersonalizationMessage
        ),
        CoachMarkStep(
            id: "settingsTutorials",
            title: L10n.TipKit.settingsTutorials,
            message: L10n.TipKit.settingsTutorialsMessage
        )
    ]
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

// MARK: - Grupo G: Pro Tour (post-subscription)

enum ProTourSteps {
    /// Phase 1: ProfileView — icons, themes. (Exportar salió del tour el 2026-10-12: ya no es Pro.)
    static let profileSteps: [CoachMarkStep] = [
        CoachMarkStep(
            id: "settingsAppIcon",
            title: L10n.TipKit.proPremiumIconsTitle,
            message: L10n.TipKit.proPremiumIconsMessage,
            spotlightPadding: DS.Spacing.xs
        ),
        CoachMarkStep(
            id: "settingsTheme",
            title: L10n.TipKit.proProThemesTitle,
            message: L10n.TipKit.proProThemesMessage,
            spotlightPadding: DS.Spacing.xs
        ),
    ]

    /// Phase 2: PanelView — la fila de acciones de arriba (UX 2.2 · L5-12, opción A): un paso sobre «Voz» y «Foto» y
    /// otro sobre «IA». Antes señalaba un «+» flotante que solo salía durante el tour y que el Panel de verdad no tiene
    /// arriba. Sin la píldora de IA (el usuario la escondió), su paso no se monta: apuntaría a una vista que no existe.
    static func panelSteps(includesAssistant: Bool) -> [CoachMarkStep] {
        var steps = [
            CoachMarkStep(
                id: panelVoiceImageAnchor,
                title: L10n.TipKit.proQuickEntryTitle,
                message: L10n.TipKit.proQuickEntryMessage
            ),
        ]
        if includesAssistant {
            steps.append(CoachMarkStep(
                id: panelAssistantAnchor,
                title: L10n.TipKit.proChatFabTitle,
                message: L10n.TipKit.proQuickAIMessage
            ))
        }
        return steps
    }

    /// Los anclas de la fila de acciones del Panel (`PanelQuickActionsRow`).
    static let panelVoiceImageAnchor = "proQuickVoiceImage"
    static let panelAssistantAnchor = "proQuickAI"

    /// Phase 3: InsightsTabView — AI summary button
    static let insightsSteps: [CoachMarkStep] = [
        CoachMarkStep(
            id: "proAiSummary",
            title: L10n.TipKit.proAiSummaryTitle,
            message: L10n.TipKit.proAiSummaryMessage
        ),
    ]

    /// Standalone (not Pro Tour): TrendChartView — "Today FX" hint.
    /// 1 step independiente, mostrado primera vez en multi-currency.
    /// La persistencia vive en `AppPreferences.hasSeenTodayFXCoachMark`,
    /// no en `ProTourManager`. El enum se reutiliza por convención visual.
    static let todayFXSteps: [CoachMarkStep] = [
        CoachMarkStep(
            id: "todayFXHint",
            title: L10n.Panel.LiveAnchorEducation.coachTitle,
            message: L10n.Panel.LiveAnchorEducation.coachMessage
        ),
    ]
}

// MARK: - TipKit Tip (standalone)

struct ComparisonTip: Tip {
    @Parameter
    static var hasVisitedStatistics: Bool = false

    var title: Text { Text(L10n.TipKit.comparison) }
    var message: Text? { Text(L10n.TipKit.comparisonMessage) }

    var rules: [Rule] {
        [#Rule(Self.$hasVisitedStatistics) { $0 == true }]
    }
}

struct AIChartsProTip: Tip {
    @Parameter
    static var hasSeenCharts: Bool = false

    var title: Text { Text(L10n.TipKit.aiChartsPro) }
    var message: Text? { Text(L10n.TipKit.aiChartsProMessage) }

    var rules: [Rule] {
        [#Rule(Self.$hasSeenCharts) { $0 == true }]
    }
}

struct AIChartsFreeUpsellTip: Tip {
    @Parameter
    static var hasSeenCharts: Bool = false

    var title: Text { Text(L10n.TipKit.aiChartsFree) }
    var message: Text? { Text(L10n.TipKit.aiChartsFreeMessage) }

    var rules: [Rule] {
        [#Rule(Self.$hasSeenCharts) { $0 == true }]
    }
}
