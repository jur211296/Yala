//
//  ProTourManager.swift
//  Yala
//
//  Coordinates the 3-phase Pro Tour that activates after subscription/trial.
//  Phase 1: ProfileView (toggles, export, icons, themes)
//  Phase 2: PanelView (FAB)
//  Phase 3: InsightsTabView (AI summary button)
//

import SwiftUI

@MainActor @Observable
final class ProTourManager {

    // MARK: - Phase

    enum Phase: Int {
        case idle = 0
        case profile = 1
        case panel = 2
        case insights = 3
        case done = 4
    }

    // MARK: - State

    private(set) var currentPhase: Phase {
        didSet { UserDefaults.standard.set(currentPhase.rawValue, forKey: Self.phaseKey) }
    }

    private(set) var hasCompleted: Bool {
        didSet { UserDefaults.standard.set(hasCompleted, forKey: Self.completedKey) }
    }

    private(set) var triggered: Bool {
        didSet { UserDefaults.standard.set(triggered, forKey: Self.triggeredKey) }
    }

    // MARK: - Keys

    private static let completedKey = "hasCompletedProTour"
    private static let phaseKey = "proTourPendingPhase"
    private static let triggeredKey = "proTourTriggered"

    // MARK: - Singleton

    static let shared = ProTourManager()

    // MARK: - Init

    private init() {
        let defaults = UserDefaults.standard
        self.hasCompleted = defaults.bool(forKey: Self.completedKey)
        self.triggered = defaults.bool(forKey: Self.triggeredKey)
        self.currentPhase = Phase(rawValue: defaults.integer(forKey: Self.phaseKey)) ?? .idle
    }

    // MARK: - Actions

    /// Triggers the tour if all pre-requisites are met.
    /// Call from SubscriptionSuccessView onDismiss.
    func triggerIfEligible() {
        guard !hasCompleted,
              !triggered,
              UserDefaults.standard.bool(forKey: "hasSeenSettingsTour"),
              FeatureGateService.shared.isProUser else { return }

        #if DEBUG
        print("ProTourManager: Tour triggered — starting at profile phase")
        #endif

        triggered = true
        currentPhase = .profile
    }

    /// Advances to the next phase after the current one completes.
    func advancePhase() {
        switch currentPhase {
        case .idle:
            break
        case .profile:
            #if DEBUG
            print("ProTourManager: Phase 1 (profile) completed — advancing to panel")
            #endif
            currentPhase = .panel
        case .panel:
            #if DEBUG
            print("ProTourManager: Phase 2 (panel) completed — advancing to insights")
            #endif
            currentPhase = .insights
        case .insights:
            #if DEBUG
            print("ProTourManager: Phase 3 (insights) completed — tour done")
            #endif
            markCompleted()
        case .done:
            break
        }
    }

    /// Marks the tour as fully completed.
    func markCompleted() {
        currentPhase = .done
        hasCompleted = true
    }

    /// Marks the tour as completed when user dismisses mid-tour (don't insist).
    func skipTour() {
        #if DEBUG
        print("ProTourManager: Tour skipped at phase \(currentPhase)")
        #endif
        currentPhase = .done
        hasCompleted = true
    }

    /// Resets all state — called by DataWipeService.
    func reset() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Self.completedKey)
        defaults.removeObject(forKey: Self.phaseKey)
        defaults.removeObject(forKey: Self.triggeredKey)
        hasCompleted = false
        triggered = false
        currentPhase = .idle
    }
}
