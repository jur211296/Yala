//
//  NudgeType.swift
//  Yala
//
//  Contextual nudge types for converting invited/dormant/sporadic users.
//  Pure enum — no runtime dependencies. Testable in isolation.
//

import Foundation

// MARK: - Nudge Type

enum NudgeType: String, CaseIterable {

    // Invited → activate full mode
    case invitedSpendingInsight
    case invitedPostSettlement
    case invitedMonthTwo
    case invitedSocialProof

    // Dormant → re-engagement
    case dormantGroupsAsMain
    case dormantNewExpenses
    case dormantSpendingGap
    case dormantQuickEntry

    // Sporadic → increase frequency
    case sporadicImbalance
    case sporadicBudgetSuggestion
    case sporadicTrendAlert

    // MARK: - Segment Mapping

    var segment: UserSegment {
        switch self {
        case .invitedSpendingInsight, .invitedPostSettlement,
             .invitedMonthTwo, .invitedSocialProof:
            return .invited
        case .dormantGroupsAsMain, .dormantNewExpenses,
             .dormantSpendingGap, .dormantQuickEntry:
            return .dormant
        case .sporadicImbalance, .sporadicBudgetSuggestion,
             .sporadicTrendAlert:
            return .sporadic
        }
    }

    // MARK: - Timing Gate

    /// Minimum weeks since first group join before this nudge can appear.
    var minimumWeek: Int {
        switch self {
        case .dormantGroupsAsMain:          return 0
        case .dormantNewExpenses:           return 1
        case .sporadicImbalance:            return 1
        case .dormantSpendingGap:           return 2
        case .sporadicBudgetSuggestion:     return 2
        case .invitedSpendingInsight:       return 3
        case .dormantQuickEntry:            return 3
        case .invitedPostSettlement:        return 4
        case .invitedMonthTwo:              return 8
        case .invitedSocialProof:           return 8
        case .sporadicTrendAlert:           return 8
        }
    }

    // MARK: - Display

    var icon: String {
        switch self {
        case .invitedSpendingInsight:       return "chart.bar.fill"
        case .invitedPostSettlement:        return "checkmark.circle.fill"
        case .invitedMonthTwo:              return "eye.fill"
        case .invitedSocialProof:           return "person.3.fill"
        case .dormantGroupsAsMain:          return "rectangle.stack.fill"
        case .dormantNewExpenses:           return "bell.badge.fill"
        case .dormantSpendingGap:           return "chart.line.uptrend.xyaxis"
        case .dormantQuickEntry:            return "bolt.fill"
        case .sporadicImbalance:            return "scale.3d"
        case .sporadicBudgetSuggestion:     return "chart.pie.fill"
        case .sporadicTrendAlert:           return "arrow.triangle.2.circlepath"
        }
    }

    var actionType: NudgeAction {
        switch self {
        case .invitedSpendingInsight, .invitedPostSettlement,
             .invitedMonthTwo, .invitedSocialProof:
            return .activateFullMode
        case .dormantGroupsAsMain, .dormantNewExpenses:
            return .openGroupDetail
        case .dormantSpendingGap, .dormantQuickEntry:
            return .openPanel
        case .sporadicImbalance, .sporadicBudgetSuggestion, .sporadicTrendAlert:
            return .dismiss
        }
    }

    // MARK: - Localized Text

    var title: String {
        L10n.Groups.Nudge.title(for: self)
    }

    var ctaLabel: String {
        L10n.Groups.Nudge.cta(for: self)
    }

    /// Message with dynamic placeholders interpolated from context.
    func message(with context: NudgeTriggerContext) -> String {
        L10n.Groups.Nudge.message(for: self, context: context)
    }

    // MARK: - Filtering

    /// Returns nudges targeting a specific segment. Empty for active/powerUser.
    static func nudges(for segment: UserSegment) -> [NudgeType] {
        allCases.filter { $0.segment == segment }
    }
}

// MARK: - Nudge Action

enum NudgeAction {
    case activateFullMode
    case openPanel
    case openGroupDetail
    case dismiss
}

// MARK: - Nudge Trigger Context

/// Pre-fetched data for evaluating nudge triggers. Built by NudgeService, consumed by NudgeTriggerEvaluator.
struct NudgeTriggerContext {
    let totalSharedAmount: Double
    let sharedExpenseCount: Int
    let hasConfirmedSettlement: Bool
    let personalTransactionCount: Int
    let groupMemberCount: Int
    let currentMonthSharedCount: Int
    let monthOverMonthVariation: Double
    let enteredViaGroupNotification: Bool

    static let empty = NudgeTriggerContext(
        totalSharedAmount: 0,
        sharedExpenseCount: 0,
        hasConfirmedSettlement: false,
        personalTransactionCount: 0,
        groupMemberCount: 0,
        currentMonthSharedCount: 0,
        monthOverMonthVariation: 0,
        enteredViaGroupNotification: false
    )
}

// MARK: - Nudge Trigger Evaluator

/// Pure static evaluation of nudge triggers. No SwiftData dependency — testable in isolation.
struct NudgeTriggerEvaluator {

    static func shouldShow(_ nudge: NudgeType, context: NudgeTriggerContext) -> Bool {
        switch nudge {
        // Invited
        case .invitedSpendingInsight:
            return context.totalSharedAmount > 500
        case .invitedPostSettlement:
            return context.hasConfirmedSettlement
        case .invitedMonthTwo:
            return context.sharedExpenseCount > 10
        case .invitedSocialProof:
            return context.groupMemberCount >= 3

        // Dormant
        case .dormantGroupsAsMain:
            return true // Always eligible, gated by minimumWeek
        case .dormantNewExpenses:
            return context.sharedExpenseCount > 0
        case .dormantSpendingGap:
            return context.sharedExpenseCount > 5
        case .dormantQuickEntry:
            return context.enteredViaGroupNotification

        // Sporadic
        case .sporadicImbalance:
            let personal = max(context.personalTransactionCount, 1)
            return context.sharedExpenseCount > personal * 3
        case .sporadicBudgetSuggestion:
            return context.currentMonthSharedCount > 10
        case .sporadicTrendAlert:
            return context.monthOverMonthVariation > 0.4
        }
    }
}
