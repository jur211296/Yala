//
//  SetupChecklistManager.swift
//  Yala
//
//  Manages the "Configura tu Yala" setup checklist for new users.
//  Tracks progress through 8 guided steps, auto-detects already completed ones,
//  and controls card visibility (expanded/collapsed/completed/expired).
//

import Foundation

@MainActor
@Observable
final class SetupChecklistManager {

    // MARK: - Singleton

    static let shared = SetupChecklistManager()

    // MARK: - Storage Keys

    private enum Keys {
        static let collapsed = "setup.collapsed"
        static let collapsedAtSession = "setup.collapsedAtSession"
        static let completedAll = "setup.completedAll"
        static let completedAllDate = "setup.completedAllDate"
        static let completedDismissed = "setup.completedDismissed"
        static let isNewInstall = "setup.isNewInstall"
        // Step keys: SetupStepID.storageKey ("setup.step.N.completed")
    }

    // MARK: - Constants

    /// Sessions between re-expand attempts when collapsed.
    private let reExpandInterval = 3
    /// Days after 8/8 completion before the card disappears.
    private let expirationDays = 3

    // MARK: - Observable State

    /// Completion state for each step.
    private(set) var stepCompleted: [SetupStepID: Bool] = [:]

    /// Whether the user has collapsed the card.
    private(set) var isCollapsed: Bool = false

    /// Whether all 8 steps are completed.
    private(set) var isAllComplete: Bool = false

    /// Date when all steps were completed (nil if not yet).
    private(set) var completedAllDate: Date?

    /// Whether the user manually dismissed the completed banner.
    private(set) var isCompletedDismissed: Bool = false

    // MARK: - Computed

    /// Number of completed steps.
    var completedCount: Int {
        stepCompleted.values.count(where: { $0 })
    }

    /// Total number of steps.
    var totalCount: Int {
        SetupStepID.allCases.count
    }

    /// Progress fraction (0.0 to 1.0).
    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    /// Whether all steps except "discoverFeatures" are completed.
    private var otherStepsComplete: Bool {
        SetupStepID.allCases
            .filter { $0 != .discoverFeatures }
            .allSatisfy { stepCompleted[$0] == true }
    }

    /// All steps with their current state, in order.
    var steps: [SetupStep] {
        let othersComplete = otherStepsComplete
        return SetupStepID.allCases.map { id in
            let isLocked = (id == .discoverFeatures) && !othersComplete
            return SetupStep(id: id, isCompleted: stepCompleted[id] ?? false, isLocked: isLocked)
        }
    }

    /// First incomplete step (the "current" one to highlight).
    var currentStep: SetupStep? {
        steps.first { !$0.isCompleted && !$0.isLocked }
    }

    /// Whether the checklist card should be visible.
    /// Hidden for: existing users (pre-v1.2), or after all complete + expirationDays passed.
    var shouldShow: Bool {
        if isExistingUser { return false }
        if isCompletedDismissed { return false }

        if let date = completedAllDate {
            let daysSinceComplete = Calendar.current.dateComponents(
                [.day], from: date, to: .now
            ).day ?? 0
            return daysSinceComplete < expirationDays
        }
        return true
    }

    /// Whether this user existed before the checklist feature was introduced.
    /// True if they had a lastSeenAppVersion set (meaning they used a previous version).
    private var isExistingUser: Bool {
        // "setup.isNewInstall" is set during onboarding in v1.2+.
        // If it's not set, the user installed before this feature existed.
        !UserDefaults.standard.bool(forKey: Keys.isNewInstall)
    }

    /// Whether the completion celebration should show (just completed 8/8).
    var shouldShowCelebration: Bool {
        guard isAllComplete, let date = completedAllDate else { return false }
        // Show celebration only within the first 5 seconds of completion
        return Date.now.timeIntervalSince(date) < 5
    }

    /// Pending practice cleanup item (set by editors, consumed by PanelView).
    var pendingPracticeCleanup: PracticeCleanupItem?

    // MARK: - Init

    private init() {
        loadState()
    }

    // MARK: - Public Methods

    /// Mark a step as completed, optionally with a practice item for cleanup.
    func markCompleted(_ step: SetupStepID, practiceItem: PracticeCleanupItem? = nil) {
        guard stepCompleted[step] != true else { return }

        if let item = practiceItem {
            pendingPracticeCleanup = item
        }

        stepCompleted[step] = true
        UserDefaults.standard.set(true, forKey: step.storageKey)

        #if DEBUG
        print("SetupChecklist: Step \(step.rawValue) completed (\(completedCount)/\(totalCount))")
        #endif

        checkAllComplete()
    }

    /// Mark this as a new install (called during onboarding completion in v1.2+).
    /// Existing users who update won't have this flag set, so the checklist won't show for them.
    func markAsNewInstall() {
        UserDefaults.standard.set(true, forKey: Keys.isNewInstall)
    }

    /// Auto-detect steps already completed based on existing data.
    func autoDetect(transactionCount: Int, budgetCount: Int, scheduledCount: Int) {
        if transactionCount > 0 { markCompleted(.firstExpense) }
        if budgetCount > 0 { markCompleted(.firstBudget) }
        if scheduledCount > 0 { markCompleted(.scheduledPayment) }
    }

    /// Temporarily collapse for the panel tour (does NOT persist to UserDefaults).
    func collapseForTour() { isCollapsed = true }

    /// Re-expand after the panel tour completes (does NOT persist).
    func expandAfterTour() { isCollapsed = false }

    /// Toggle collapsed state.
    func toggleCollapsed() {
        isCollapsed.toggle()
        UserDefaults.standard.set(isCollapsed, forKey: Keys.collapsed)

        if isCollapsed {
            let sessionCount = UserDefaults.standard.integer(forKey: "pro.upsell.sessionCount")
            UserDefaults.standard.set(sessionCount, forKey: Keys.collapsedAtSession)
        }
    }

    /// Dismiss the completed banner permanently.
    func dismissCompleted() {
        UserDefaults.standard.set(true, forKey: Keys.completedDismissed)
        isCompletedDismissed = true
    }

    /// Check if the card should re-expand (called on panel appear).
    func checkReExpand() {
        guard isCollapsed, !isAllComplete else { return }

        let collapsedAt = UserDefaults.standard.integer(forKey: Keys.collapsedAtSession)
        let currentSession = UserDefaults.standard.integer(forKey: "pro.upsell.sessionCount")

        if currentSession - collapsedAt >= reExpandInterval {
            isCollapsed = false
            UserDefaults.standard.set(false, forKey: Keys.collapsed)
        }
    }

    /// Reset all checklist state (for DataWipeService).
    func resetAll() {
        let defaults = UserDefaults.standard
        for step in SetupStepID.allCases {
            defaults.removeObject(forKey: step.storageKey)
        }
        defaults.removeObject(forKey: Keys.collapsed)
        defaults.removeObject(forKey: Keys.collapsedAtSession)
        defaults.removeObject(forKey: Keys.completedAll)
        defaults.removeObject(forKey: Keys.completedAllDate)
        defaults.removeObject(forKey: Keys.completedDismissed)
        // Keep isNewInstall — a new install remains new after wipe

        stepCompleted = [:]
        isCollapsed = false
        isAllComplete = false
        isCompletedDismissed = false
        completedAllDate = nil
    }

    // MARK: - Private

    private func loadState() {
        let defaults = UserDefaults.standard

        for step in SetupStepID.allCases {
            stepCompleted[step] = defaults.bool(forKey: step.storageKey)
        }

        isCollapsed = defaults.bool(forKey: Keys.collapsed)
        isAllComplete = defaults.bool(forKey: Keys.completedAll)
        isCompletedDismissed = defaults.bool(forKey: Keys.completedDismissed)

        let timestamp = defaults.double(forKey: Keys.completedAllDate)
        if timestamp > 0 {
            completedAllDate = Date(timeIntervalSince1970: timestamp)
        }
    }

    private func checkAllComplete() {
        guard !isAllComplete else { return }

        let allDone = SetupStepID.allCases.allSatisfy { stepCompleted[$0] == true }
        if allDone {
            isAllComplete = true
            completedAllDate = .now
            isCollapsed = false

            UserDefaults.standard.set(true, forKey: Keys.completedAll)
            UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: Keys.completedAllDate)

            #if DEBUG
            print("SetupChecklist: All steps completed! 🎉")
            #endif
        }
    }
}
