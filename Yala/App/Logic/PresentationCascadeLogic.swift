//
//  PresentationCascadeLogic.swift
//  Yala
//
//  Pure-logic: maps a drained RouterIntent into a CascadeDecision describing
//  what the PresentationCoordinator should do. Encapsulates the cross-consumer
//  cascade declaratively: e.g. `.navigate(.inbox)` returns
//  `.combined(tab: .panel, panel: .inboxSheet)` instead of the mainTab handler
//  enqueueing a follow-up intent.
//

import Foundation

/// Output of the cascade decision. Coordinator consumes this and mutates
/// state + SessionState.selectMainTab + side effects accordingly.
enum CascadeDecision: Equatable {
    /// Nothing to do (e.g. intent already represented by current presentation,
    /// or the shell isn't ready). Intent stays "consumed" but no UI changes.
    case noop

    /// Mutate the shell-level presentation only.
    case present(ShellPresentation)

    /// Mutate the panel-level presentation only.
    case panel(PanelPresentation)

    /// Switch the main tab (no modal). Used by `.navigate(.statistics)` etc.
    case switchTab(AppTab)

    /// Switch tab AND mutate panel presentation atomically. Used by
    /// `.navigate(.inbox)` → switch to Panel + open Inbox sheet.
    case combined(tab: AppTab, panel: PanelPresentation)

    /// Mutate both shell and panel (e.g. a shell alert that also affects panel).
    /// Rare; kept for future extensions.
    case shellAndPanel(shell: ShellPresentation, panel: PanelPresentation)
}

/// Subset of inputs the cascade needs. Built by PresentationCoordinator from
/// its observable state + readiness + dismissal tracking.
struct CascadeInputs {
    let currentShell: ShellPresentation
    let currentPanel: PanelPresentation
    let currentTab: AppTab
    let readiness: ShellReadinessState
    /// When the last panel sheet was dismissed (any sheet). Used to gate
    /// re-presentation within ~500ms (prevents "user closes, app reopens").
    let lastPanelDismissalDate: Date?
    let now: Date
}

enum PresentationCascadeLogic {

    /// Re-presentation cooldown after a panel dismiss (seconds).
    static let panelDismissCooldownSeconds: TimeInterval = 0.5

    /// Maps a drained intent into the decision the coordinator should apply.
    /// Pure — no globals, no side effects, no actor.
    static func decide(
        intent: RouterIntent,
        inputs: CascadeInputs
    ) -> CascadeDecision {

        // Hard block: shell not ready → never drain modals.
        // (RouterEntryGate would normally prevent this from reaching us, but
        // defence-in-depth — cascade is called from coordinator.ingest.)
        if ContentViewReadinessLogic.isReady(state: inputs.readiness) == false {
            return .noop
        }

        switch intent {

        // MARK: Shell presentations (single source of truth = ShellPresentation)
        case .showInboxAlert(let notif):
            return .present(.inboxAlert(notif))
        case .presentTrialOffer:
            return .present(.trialOffer)
        case .presentTrialExpired:
            return .present(.trialExpired)
        case .presentMilestoneUpgrade(let n):
            return .present(.milestoneUpgrade(n))
        case .presentWhatsNew(let features, let version):
            return .present(.whatsNew(features: features, version: version))
        case .presentDowngradeResolution:
            return .present(.downgradeResolution)
        case .presentGroupInviteOnboarding(let invite):
            return .present(.groupInviteOnboarding(invite))
        case .presentGroupReconnect(let invite):
            return .present(.groupReconnect(invite))
        case .offerRestoreBeforeInvite(let invite):
            return .present(.offerRestoreBeforeInvite(invite))
        case .showInviteError(let msg):
            return .present(.inviteError(msg))
        case .showGroupSyncError(let msg):
            return .present(.groupSyncError(msg))
        case .presentFullModeActivation:
            return .present(.fullModeActivation)
        case .iCloudMismatch:
            return .present(.iCloudMismatch)
        case .remoteWipe(let skip):
            return .present(.remoteWipe(skipOnboarding: skip))
        case .remoteOnboardingCompleted:
            return .present(.remoteOnboardingCompleted)

        // MARK: Panel presentations
        case .presentInboxSheet:
            return panelDecision(.inboxSheet, inputs: inputs)
        case .presentSharedImage(let url):
            return panelDecision(.sharedImage(url), inputs: inputs)
        case .presentNewTransaction:
            return panelDecision(.newTransaction, inputs: inputs)
        case .presentNewTransactionFromChatDraft(let prefill):
            return panelDecision(.newTransactionFromChatDraft(prefill), inputs: inputs)
        case .presentVoiceEntry:
            return panelDecision(.voiceEntry, inputs: inputs)
        case .presentImageEntry:
            return panelDecision(.imageEntry, inputs: inputs)
        case .presentUpgradeSheet(let feature):
            return panelDecision(.upgradeSheet(feature), inputs: inputs)
        case .requestAIConsent(let input):
            return panelDecision(.aiConsent(input), inputs: inputs)

        // MARK: Tab navigation
        case .navigate(let dest):
            return navigateDecision(dest, inputs: inputs)

        // MARK: Out-of-coordinator scope (handled by other consumers)
        case .autoOpenBudgetEditor, .autoOpenScheduledEditor,
             .requestAppStoreReview:
            // .planning consumer handles autoOpen* via peek-first.
            // .requestAppStoreReview is a side-effect (no presentation).
            return .noop
        }
    }

    // MARK: - Private helpers

    /// Panel-level presentations need extra care: if the panel is currently
    /// showing something else, or if the user just dismissed a sheet, we
    /// return `.noop` (intent stays consumed — coordinator drops it).
    private static func panelDecision(
        _ target: PanelPresentation,
        inputs: CascadeInputs
    ) -> CascadeDecision {
        // Cooldown: ignore re-presentation right after a dismiss.
        if let last = inputs.lastPanelDismissalDate,
           inputs.now.timeIntervalSince(last) < panelDismissCooldownSeconds {
            return .noop
        }
        // Already showing same thing → noop.
        if inputs.currentPanel == target { return .noop }
        // Different sheet open → noop (gate / readiness should've blocked).
        if inputs.currentPanel != .none { return .noop }
        // Off the Panel tab → switch tab AND present.
        if inputs.currentTab != .panel {
            return .combined(tab: .panel, panel: target)
        }
        return .panel(target)
    }

    /// `.navigate(dest)` maps to either a tab switch, a panel cascade, or both.
    private static func navigateDecision(
        _ dest: DeepLinkDestination,
        inputs: CascadeInputs
    ) -> CascadeDecision {
        switch dest {
        case .panel:
            return .switchTab(.panel)
        case .statistics, .records, .categories:
            return .switchTab(.statistics)
        case .planning, .budgets, .scheduledPayments:
            return .switchTab(.planning)
        case .recordsStandalone:
            return .switchTab(.records)
        case .groups, .groupDetail:
            return .switchTab(.groups)
        case .inbox:
            // The cascade. Replaces the legacy enqueue(.presentInboxSheet) chain.
            return .combined(tab: .panel, panel: .inboxSheet)
        }
    }
}
