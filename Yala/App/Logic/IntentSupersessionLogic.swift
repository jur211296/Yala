//
//  IntentSupersessionLogic.swift
//  Yala
//
//  Pure-logic: declarative rules for cross-intent supersession.
//
//  When `.navigate(.inbox)` arrives, a queued `.showInboxAlert` becomes
//  redundant — both ultimately land the user in the Inbox. Without
//  supersession, both drain (alert first, sheet after) producing the
//  "automatizaciones tardía" bug. This module returns the IDs of queued
//  intents to drop when a given incoming intent arrives.
//
//  Rules are values in `rules: [SupersessionRule]` — extended by adding new
//  entries (never by modifying a switch).
//

import Foundation

struct SupersessionRule {
    /// `true` when this rule applies to the incoming intent.
    let triggers: (RouterIntent) -> Bool
    /// `true` for each queued intent that should be dropped when triggered.
    let dropsExisting: (RouterIntent) -> Bool
    /// `true` if the incoming itself should be dropped (rare; e.g. a self-supersede).
    let dropsIncoming: Bool
    /// Human-readable tag for telemetry/logs.
    let description: String
}

enum IntentSupersessionLogic {

    /// Rule set. Order does not matter — all rules are evaluated.
    /// Active rules (consumed by RouterEntryGate):
    ///   - `.navigate(.inbox)` drops queued `.showInboxAlert`
    ///   - `.presentInboxSheet` drops queued `.showInboxAlert`
    ///     (plus a sibling check in the gate consults `SessionState.isInboxSheetVisible`
    ///     to also drop new `.showInboxAlert` arriving AFTER the sheet opened)
    ///   - `.presentTrialExpired` drops queued `.presentTrialOffer`
    ///   - `.remoteWipe(_)` drops all non-critical (priority < .critical)
    static let rules: [SupersessionRule] = [
        SupersessionRule(
            triggers: { if case .navigate(.inbox) = $0 { return true }; return false },
            dropsExisting: { if case .showInboxAlert = $0 { return true }; return false },
            dropsIncoming: false,
            description: "navigateInbox_supersedes_showInboxAlert"
        ),
        SupersessionRule(
            triggers: { if case .presentInboxSheet = $0 { return true }; return false },
            dropsExisting: { if case .showInboxAlert = $0 { return true }; return false },
            dropsIncoming: false,
            description: "presentInboxSheet_supersedes_showInboxAlert"
        ),
        SupersessionRule(
            triggers: { if case .presentTrialExpired = $0 { return true }; return false },
            dropsExisting: { if case .presentTrialOffer = $0 { return true }; return false },
            dropsIncoming: false,
            description: "presentTrialExpired_supersedes_presentTrialOffer"
        ),
        SupersessionRule(
            triggers: { if case .remoteWipe = $0 { return true }; return false },
            dropsExisting: { $0.priority < RouterIntent.Priority.critical },
            dropsIncoming: false,
            description: "remoteWipe_supersedes_nonCritical"
        ),
    ]

    /// Returns `(dropIDs, acceptIncoming)` for an incoming intent against a
    /// snapshot of the current queue. `acceptIncoming` is `false` only if any
    /// rule sets `dropsIncoming = true`.
    static func decisions(
        queued: [RouterIntent],
        incoming: RouterIntent,
        rules: [SupersessionRule] = IntentSupersessionLogic.rules
    ) -> (dropIDs: Set<String>, acceptIncoming: Bool) {
        var drops: Set<String> = []
        var accept = true
        for rule in rules where rule.triggers(incoming) {
            for existing in queued where rule.dropsExisting(existing) {
                drops.insert(existing.id)
            }
            if rule.dropsIncoming { accept = false }
        }
        return (drops, accept)
    }
}
