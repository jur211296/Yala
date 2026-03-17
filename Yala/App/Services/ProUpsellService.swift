//
//  ProUpsellService.swift
//  Yala
//
//  Central service for proactive upsell decisions with frequency capping.
//

import Foundation

@MainActor @Observable
final class ProUpsellService {

    static let shared = ProUpsellService()
    private init() {}

    // MARK: - In-Memory State

    private var shownThisSession = false

    // MARK: - UserDefaults Keys

    private let lastShownDateKey = "pro.upsell.lastShownDate"
    private let dismissCountKey = "pro.upsell.dismissCount"
    private let monthlyShownCountKey = "pro.upsell.monthlyShownCount"
    private let monthlyResetDateKey = "pro.upsell.monthlyResetDate"
    private let sessionCountKey = "pro.upsell.sessionCount"
    private let wasInTrialKey = "pro.trial.wasInTrial"
    private let trialExpiredSheetShownKey = "pro.trial.expiredSheetShown"
    private let lastMilestoneShownKey = "pro.milestone.lastShown"

    // MARK: - Milestones

    private let milestones = [10, 50, 100]

    // MARK: - Public API

    /// Whether a periodic upgrade banner should appear for Free users.
    func shouldShowPeriodicBanner() -> Bool {
        guard !FeatureGateService.shared.isProUser else { return false }
        guard !StoreKitManager.shared.isInTrial else { return false }
        guard !shownThisSession else { return false }
        guard !isVoluntaryChurn else { return false }

        // Monthly cap: max 4
        resetMonthlyCountIfNeeded()
        guard UserDefaults.standard.integer(forKey: monthlyShownCountKey) < 4 else { return false }

        // Cooldown: 5 days base + 2 per dismiss
        let dismissCount = UserDefaults.standard.integer(forKey: dismissCountKey)
        let cooldownDays = 5 + (dismissCount * 2)
        if let lastShown = UserDefaults.standard.object(forKey: lastShownDateKey) as? Date {
            let daysSince = Calendar.current.dateComponents([.day], from: lastShown, to: .now).day ?? 0
            guard daysSince >= cooldownDays else { return false }
        }

        return true
    }

    /// Whether the trial-expired sheet should appear (once per lifetime).
    func shouldShowTrialExpiredSheet() -> Bool {
        guard !FeatureGateService.shared.isProUser else { return false }
        guard UserDefaults.standard.bool(forKey: wasInTrialKey) else { return false }
        guard !UserDefaults.standard.bool(forKey: trialExpiredSheetShownKey) else { return false }
        return true
    }

    /// Whether a milestone upgrade sheet should appear for this transaction count.
    func shouldShowMilestone(transactionCount: Int) -> Bool {
        guard !FeatureGateService.shared.isProUser else { return false }
        guard !shownThisSession else { return false }
        let lastShown = UserDefaults.standard.integer(forKey: lastMilestoneShownKey)
        return milestones.contains(transactionCount) && transactionCount > lastShown
    }

    /// Next milestone that hasn't been shown yet.
    var nextMilestone: Int? {
        let lastShown = UserDefaults.standard.integer(forKey: lastMilestoneShownKey)
        return milestones.first { $0 > lastShown }
    }

    /// Computes the next milestone for a given transaction count.
    func nextMilestone(for transactionCount: Int) -> Int? {
        let lastShown = UserDefaults.standard.integer(forKey: lastMilestoneShownKey)
        return milestones.first { $0 > lastShown && $0 == transactionCount }
    }

    // MARK: - Recording

    func recordShown(source: String) {
        shownThisSession = true
        UserDefaults.standard.set(Date.now, forKey: lastShownDateKey)
        resetMonthlyCountIfNeeded()
        let count = UserDefaults.standard.integer(forKey: monthlyShownCountKey) + 1
        UserDefaults.standard.set(count, forKey: monthlyShownCountKey)
    }

    func recordDismissed() {
        let count = UserDefaults.standard.integer(forKey: dismissCountKey) + 1
        UserDefaults.standard.set(count, forKey: dismissCountKey)
    }

    func recordTrialStarted() {
        UserDefaults.standard.set(true, forKey: wasInTrialKey)
    }

    func incrementSessionCount() {
        let count = UserDefaults.standard.integer(forKey: sessionCountKey) + 1
        UserDefaults.standard.set(count, forKey: sessionCountKey)
    }

    func markTrialExpiredSheetShown() {
        UserDefaults.standard.set(true, forKey: trialExpiredSheetShownKey)
    }

    func markMilestoneShown(_ milestone: Int) {
        UserDefaults.standard.set(milestone, forKey: lastMilestoneShownKey)
        shownThisSession = true
    }

    // MARK: - Private

    /// Voluntary churn: was Pro, no longer Pro, and never had trial
    private var isVoluntaryChurn: Bool {
        StoreKitManager.shared.wasProUser
            && !StoreKitManager.shared.isProUser
            && !UserDefaults.standard.bool(forKey: wasInTrialKey)
    }

    private func resetMonthlyCountIfNeeded() {
        let calendar = Calendar.current
        if let resetDate = UserDefaults.standard.object(forKey: monthlyResetDateKey) as? Date {
            if !calendar.isDate(resetDate, equalTo: .now, toGranularity: .month) {
                UserDefaults.standard.set(0, forKey: monthlyShownCountKey)
                UserDefaults.standard.set(Date.now, forKey: monthlyResetDateKey)
            }
        } else {
            UserDefaults.standard.set(Date.now, forKey: monthlyResetDateKey)
        }
    }
}
