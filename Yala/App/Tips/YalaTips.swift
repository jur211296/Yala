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
        [
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
            )
        ]
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
            id: "settingsTutorials",
            title: L10n.TipKit.settingsTutorials,
            message: L10n.TipKit.settingsTutorialsMessage
        )
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
