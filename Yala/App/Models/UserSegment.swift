//
//  UserSegment.swift
//  Yala
//
//  Behavioral segmentation of the user. Recalculated on each session.
//  Pure classification logic — no SwiftData dependency.
//

import Foundation

enum UserSegment: String {
    /// onboardingMode == .groupInvite (no personal finance context)
    case invited
    /// Onboarding complete but <5 transactions
    case dormant
    /// 5-30 transactions, avg >7 days between sessions
    case sporadic
    /// >30 transactions, avg <=7 days between sessions
    case active
    /// >100 transactions + uses advanced features (budgets, insights, export)
    case powerUser

    /// Pure classification function — testable without SwiftData context.
    /// - Parameters:
    ///   - onboardingMode: Current onboarding mode
    ///   - totalTransactions: Total personal TransactionItem count
    ///   - avgDaysBetweenSessions: Average days between app sessions (0 = first session)
    ///   - usesAdvancedFeatures: Whether user has budgets, used insights, or exported data
    static func classify(
        onboardingMode: OnboardingMode,
        totalTransactions: Int,
        avgDaysBetweenSessions: Double,
        usesAdvancedFeatures: Bool
    ) -> UserSegment {
        if onboardingMode == .groupInvite {
            return .invited
        }

        if totalTransactions > 100 && usesAdvancedFeatures {
            return .powerUser
        }

        if totalTransactions > 30 && avgDaysBetweenSessions <= 7 {
            return .active
        }

        if totalTransactions >= 5 {
            return .sporadic
        }

        return .dormant
    }
}
