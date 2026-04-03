//
//  YalaTips.swift
//  Yala
//
//  Coach mark step definitions (Groups A/B) and TipKit tips (Group C).
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

// MARK: - Coach Mark Steps (Groups A & B)

enum PanelTourSteps {
    static func steps(isProUser: Bool) -> [CoachMarkStep] {
        var result = [
            CoachMarkStep(
                id: "accounts",
                title: L10n.TipKit.accounts,
                message: L10n.TipKit.accountsMessage
            ),
            CoachMarkStep(
                id: "widgets",
                title: L10n.TipKit.widgets,
                message: L10n.TipKit.widgetsMessage,
                spotlightPadding: DS.Spacing.xs
            ),
            CoachMarkStep(
                id: "widgetPreferences",
                title: L10n.TipKit.widgetPreferences,
                message: L10n.TipKit.widgetPreferencesMessage,
                spotlightPadding: DS.Spacing.md
            ),
            CoachMarkStep(
                id: "fab",
                title: L10n.TipKit.fab,
                message: isProUser ? L10n.TipKit.fabProMessage : L10n.TipKit.fabFreeMessage
            ),
            CoachMarkStep(
                id: "profile",
                title: L10n.TipKit.profile,
                message: L10n.TipKit.profileMessage,
                spotlightPadding: DS.Spacing.xs
            ),
        ]

        // Contextual guide step — only if the panel guide hasn't been dismissed yet
        if !UserDefaults.standard.bool(forKey: "guide.panel.dismissed") {
            result.append(CoachMarkStep(
                id: "contextualGuide",
                title: L10n.TipKit.contextualGuide,
                message: L10n.TipKit.contextualGuideMessage,
                spotlightPadding: DS.Spacing.xs
            ))
        }

        // Setup checklist step — always shown
        result.append(CoachMarkStep(
            id: "setupChecklist",
            title: L10n.TipKit.setupChecklist,
            message: L10n.TipKit.setupChecklistMessage,
            spotlightPadding: DS.Spacing.xs
        ))

        return result
    }
}

enum RegistroTourSteps {
    static let steps: [CoachMarkStep] = [
        CoachMarkStep(
            id: "transactionTypes",
            title: L10n.TipKit.transactionTypes,
            message: L10n.TipKit.transactionTypesMessage
        ),
        CoachMarkStep(
            id: "favoritePayments",
            title: L10n.TipKit.favoritePayments,
            message: L10n.TipKit.favoritePaymentsMessage,
            spotlightPadding: DS.Spacing.xs
        ),
        CoachMarkStep(
            id: "quickActions",
            title: L10n.TipKit.quickActions,
            message: L10n.TipKit.quickActionsMessage
        )
    ]
}

// MARK: - Grupo C: Interactivity Tour (coach marks)

enum InteractivityTourSteps {
    static let steps: [CoachMarkStep] = [
        CoachMarkStep(
            id: "filterAccount",
            title: L10n.TipKit.filterAccount,
            message: L10n.TipKit.filterAccountMessage
        ),
        CoachMarkStep(
            id: "interactiveWidgets",
            title: L10n.TipKit.interactiveWidgets,
            message: L10n.TipKit.interactiveWidgetsMessage,
            spotlightPadding: DS.Spacing.xs
        )
    ]
}

// MARK: - Grupo D: Tour de Settings

enum SettingsTourSteps {
    static let steps: [CoachMarkStep] = [
        CoachMarkStep(
            id: "settingsAccounts",
            title: L10n.TipKit.settingsAccounts,
            message: L10n.TipKit.settingsAccountsMessage
        ),
        CoachMarkStep(
            id: "settingsCategories",
            title: L10n.TipKit.settingsCategories,
            message: L10n.TipKit.settingsCategoriesMessage
        ),
        CoachMarkStep(
            id: "settingsTags",
            title: L10n.TipKit.settingsTags,
            message: L10n.TipKit.settingsTagsMessage
        ),
        CoachMarkStep(
            id: "settingsBudgets",
            title: L10n.TipKit.settingsBudgets,
            message: L10n.TipKit.settingsBudgetsMessage
        ),
        CoachMarkStep(
            id: "settingsPlanned",
            title: L10n.TipKit.settingsPlanned,
            message: L10n.TipKit.settingsPlannedMessage
        ),
        CoachMarkStep(
            id: "settingsPersonalization",
            title: L10n.TipKit.settingsPersonalization,
            message: L10n.TipKit.settingsPersonalizationMessage
        ),
        CoachMarkStep(
            id: "settingsAppIcon",
            title: L10n.TipKit.settingsAppIcon,
            message: L10n.TipKit.settingsAppIconMessage
        ),
        CoachMarkStep(
            id: "settingsTheme",
            title: L10n.TipKit.settingsTheme,
            message: L10n.TipKit.settingsThemeMessage
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
    /// Phase 1: ProfileView — toggles, export, icons, themes
    static let profileSteps: [CoachMarkStep] = [
        CoachMarkStep(
            id: "proVoiceInput",
            title: L10n.TipKit.proVoiceInputTitle,
            message: L10n.TipKit.proVoiceInputMessage,
            spotlightPadding: DS.Spacing.xs
        ),
        CoachMarkStep(
            id: "proImageInput",
            title: L10n.TipKit.proImageInputTitle,
            message: L10n.TipKit.proImageInputMessage,
            spotlightPadding: DS.Spacing.xs
        ),
        CoachMarkStep(
            id: "proSmartInsights",
            title: L10n.TipKit.proSmartInsightsTitle,
            message: L10n.TipKit.proSmartInsightsMessage,
            spotlightPadding: DS.Spacing.xs
        ),
        CoachMarkStep(
            id: "proExportExtended",
            title: L10n.TipKit.proExportExtendedTitle,
            message: L10n.TipKit.proExportExtendedMessage,
            spotlightPadding: DS.Spacing.xs
        ),
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

    /// Phase 2: PanelView — FAB with voice/image options + chat assistant
    static let panelSteps: [CoachMarkStep] = [
        CoachMarkStep(
            id: "fab",
            title: L10n.TipKit.proFabTitle,
            message: L10n.TipKit.proFabMessage
        ),
        CoachMarkStep(
            id: "proChatFab",
            title: L10n.TipKit.proChatFabTitle,
            message: L10n.TipKit.proChatFabMessage
        ),
    ]

    /// Phase 3: InsightsTabView — AI summary button
    static let insightsSteps: [CoachMarkStep] = [
        CoachMarkStep(
            id: "proAiSummary",
            title: L10n.TipKit.proAiSummaryTitle,
            message: L10n.TipKit.proAiSummaryMessage
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
