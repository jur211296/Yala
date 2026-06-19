//
//  MonetizationDedupLogic.swift
//  Yala
//
//  Pure-logic: cross-type dedup for monetization intents.
//
//  Without this, .presentTrialExpired + .presentTrialOffer (or .presentTrialOffer
//  + .presentMilestoneUpgrade) can stack and surface two paywalls in a row.
//  Trial-expired is the highest-pressure variant; everything else yields to it.
//

import Foundation

enum MonetizationDedupLogic {

    /// `true` → `intent` can join `queued`; `false` → drop the incoming silently.
    /// Apply BEFORE supersession (decisions vs queue).
    static func canEnqueue(_ intent: RouterIntent, given queued: [RouterIntent]) -> Bool {
        switch intent {
        case .presentTrialOffer:
            // Don't show trial offer if expired sheet is queued or onscreen.
            return !queued.contains { if case .presentTrialExpired = $0 { return true }; return false }

        case .presentMilestoneUpgrade:
            // Don't pile a milestone celebration on top of trial expired.
            return !queued.contains { if case .presentTrialExpired = $0 { return true }; return false }

        default:
            return true
        }
    }

    /// Reserved hook for monetization-specific supersession that doesn't
    /// belong in `IntentSupersessionLogic.rules`. Currently empty —
    /// `.presentTrialExpired → .presentTrialOffer` lives in the general
    /// supersession module (single owner avoids double-track of telemetry
    /// when both modules would otherwise produce the same drops).
    static func intentsToSupersede(by intent: RouterIntent, in queued: [RouterIntent]) -> [String] {
        return []
    }
}
