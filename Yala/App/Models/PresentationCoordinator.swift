//
//  PresentationCoordinator.swift
//  Yala
//
//  Scaffolding. The orchestrator maps drained RouterIntents to shell
//  presentation state via `PresentationCascadeLogic.decide(...)`. While the
//  shell still uses `@State` flags as the UI source of truth, the
//  coordinator's observable state is unobserved at runtime — the supersession
//  + readiness gates presuppose a single observable presentation state for
//  future cross-consumer dedup and telemetry beyond what supersession rules
//  can express. To wire: inject `.environment(PresentationCoordinator.shared)`
//  in ContentView + replace each `.sheet(isPresented: $showX)` with
//  `coordinator.binding(for: .x)`.
//

import Foundation
import OSLog

@MainActor
@Observable
final class PresentationCoordinator {
    static let shared = PresentationCoordinator()

    // MARK: - Observable State

    private(set) var currentShellPresentation: ShellPresentation = .none
    private(set) var currentPanelPresentation: PanelPresentation = .none

    /// Last time the panel dismissed any sheet — used by cascade cooldown.
    private(set) var lastPanelDismissalDate: Date?

    // MARK: - Internals

    private let logger = Logger(subsystem: "com.yala", category: "PresentationCoordinator")

    private init() {}

    // MARK: - Public API

    /// Ingests a router intent and applies the resulting CascadeDecision.
    /// Called from ContentView/PanelShell drain handlers.
    func ingest(_ intent: RouterIntent, readiness: ShellReadinessState, currentTab: AppTab) {
        let inputs = CascadeInputs(
            currentShell: currentShellPresentation,
            currentPanel: currentPanelPresentation,
            currentTab: currentTab,
            readiness: readiness,
            lastPanelDismissalDate: lastPanelDismissalDate,
            now: Date()
        )
        let decision = PresentationCascadeLogic.decide(intent: intent, inputs: inputs)

        #if DEBUG
        logger.debug("ingest \(intent.id, privacy: .public) → \(String(describing: decision), privacy: .public)")
        #endif

        apply(decision)
    }

    /// Called by the shell when a presentation dismisses (user swipe, sheet
    /// close, modal cancel). Bridges the @State binding setter back to
    /// the coordinator's model.
    func dismiss(_ kind: ShellDismissalKind) {
        switch kind {
        case .shell:
            currentShellPresentation = .none
        case .panel:
            currentPanelPresentation = .none
            lastPanelDismissalDate = Date()
        }
    }

    /// Force-set the shell presentation. Used by handlers that need to seed
    /// presentation state ahead of the binding (e.g. group invite onboarding
    /// where the shell stores `pendingInviteMetadata`).
    func setShell(_ presentation: ShellPresentation) {
        currentShellPresentation = presentation
    }

    /// Force-set the panel presentation. Used by callers that already own
    /// the panel state machine (e.g. legacy PanelSheetState during F7 transition).
    func setPanel(_ presentation: PanelPresentation) {
        currentPanelPresentation = presentation
    }

    /// True when a presentation matching `kindID` is currently displayed.
    /// Callers pass the stable kindID (e.g. `"inboxAlert"`, `"trialOffer"`)
    /// directly — matches the namespace of `ShellPresentation.kindID`.
    func isPresenting(kindID: String) -> Bool {
        currentShellPresentation.kindID == kindID
    }

    // MARK: - Internals

    private func apply(_ decision: CascadeDecision) {
        switch decision {
        case .noop:
            return
        case .present(let shell):
            currentShellPresentation = shell
        case .panel(let panel):
            currentPanelPresentation = panel
        case .switchTab(let tab):
            SessionState.shared.selectMainTab(tab)
        case .combined(let tab, let panel):
            SessionState.shared.selectMainTab(tab)
            currentPanelPresentation = panel
        case .shellAndPanel(let shell, let panel):
            currentShellPresentation = shell
            currentPanelPresentation = panel
        }
    }
}

/// Identifies which level of presentation a dismiss event belongs to.
enum ShellDismissalKind {
    case shell
    case panel
}

