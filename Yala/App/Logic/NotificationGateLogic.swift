//
//  NotificationGateLogic.swift
//  Yala
//
//  Pure-logic: when a push/local notification tap arrives, should the resulting
//  RouterIntent enqueue immediately or be deferred to the DeferredIntentBuffer?
//
//  Tapping a notification mid-onboarding, or before AppBootstrapper.isInitialized
//  would otherwise drop the intent into a queue that drains "later" — landing the
//  user on a tab they didn't choose.
//

import Foundation

enum NotificationGateLogic {

    /// `true` → enqueue right now via AppRouter.
    /// `false` → persist in DeferredIntentBuffer; will drain on next ready window.
    static func shouldEnqueueNow(
        hasCompletedOnboarding: Bool,
        isBootstrapInitialized: Bool
    ) -> Bool {
        guard isBootstrapInitialized else { return false }
        guard hasCompletedOnboarding else { return false }
        return true
    }

    /// Diagnostic reason when `shouldEnqueueNow` returns false. Nil when allowed.
    static func deferralReason(
        hasCompletedOnboarding: Bool,
        isBootstrapInitialized: Bool
    ) -> String? {
        if !isBootstrapInitialized { return "bootstrapPending" }
        if !hasCompletedOnboarding { return "onboardingIncomplete" }
        return nil
    }
}
