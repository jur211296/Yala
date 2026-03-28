//
//  SetupChecklistManagerTests.swift
//  YalaTests
//
//  Unit tests for SetupChecklistManager — setup checklist logic for new users.
//

import Foundation
import Testing

@testable import Yala

struct SetupChecklistManagerTests {

    // MARK: - Helpers

    /// Creates a fresh manager with all UserDefaults keys cleared.
    @MainActor
    private func freshManager() -> SetupChecklistManager {
        let defaults = UserDefaults.standard
        for step in SetupStepID.allCases {
            defaults.removeObject(forKey: step.storageKey)
        }
        defaults.removeObject(forKey: "setup.collapsed")
        defaults.removeObject(forKey: "setup.collapsedAtSession")
        defaults.removeObject(forKey: "setup.completedAll")
        defaults.removeObject(forKey: "setup.completedAllDate")
        defaults.removeObject(forKey: "setup.completedDismissed")
        defaults.synchronize()

        let manager = SetupChecklistManager.shared
        manager.resetAll()
        // Ensure shouldShow works (requires isNewInstall flag)
        manager.markAsNewInstall()
        return manager
    }

    // MARK: - Initial State

    @MainActor @Test func initialState_allStepsPending() {
        let manager = freshManager()
        #expect(manager.completedCount == 0)
        #expect(manager.totalCount == 7)
        #expect(manager.isAllComplete == false)
        #expect(manager.shouldShow == true)
        #expect(manager.isCollapsed == false)
        #expect(manager.progress == 0.0)
    }

    @MainActor @Test func initialState_hasCurrentStep() {
        let manager = freshManager()
        #expect(manager.currentStep != nil)
        #expect(manager.currentStep?.id == .exploreSettings)
    }

    @MainActor @Test func initialState_stepsInOrder() {
        let manager = freshManager()
        let ids = manager.steps.map { $0.id }
        #expect(ids == SetupStepID.allCases)
    }

    // MARK: - Step Completion

    @MainActor @Test func markCompleted_incrementsCount() {
        let manager = freshManager()
        manager.markCompleted(.firstExpense)
        #expect(manager.completedCount == 1)
        #expect(manager.steps.first { $0.id == .firstExpense }?.isCompleted == true)
    }

    @MainActor @Test func markCompleted_idempotent() {
        let manager = freshManager()
        manager.markCompleted(.firstExpense)
        manager.markCompleted(.firstExpense)
        #expect(manager.completedCount == 1)
    }

    @MainActor @Test func markCompleted_advancesCurrentStep() {
        let manager = freshManager()
        manager.markCompleted(.exploreSettings)
        #expect(manager.currentStep?.id == .firstExpense)
    }

    @MainActor @Test func markCompleted_progressUpdates() {
        let manager = freshManager()
        manager.markCompleted(.firstExpense)
        manager.markCompleted(.firstBudget)
        #expect(manager.progress == 2.0 / 7.0)
    }

    // MARK: - All Complete

    @MainActor @Test func allComplete_triggersCompletion() {
        let manager = freshManager()
        for step in SetupStepID.allCases {
            manager.markCompleted(step)
        }
        #expect(manager.isAllComplete == true)
        #expect(manager.completedCount == 7)
        #expect(manager.completedAllDate != nil)
        #expect(manager.currentStep == nil)
        #expect(manager.progress == 1.0)
    }

    @MainActor @Test func allComplete_shouldShowTrue_withinExpiration() {
        let manager = freshManager()
        for step in SetupStepID.allCases {
            manager.markCompleted(step)
        }
        #expect(manager.shouldShow == true)
    }

    // MARK: - Discover Features Locked

    @MainActor @Test func discoverFeatures_lockedUntilOthersComplete() {
        let manager = freshManager()
        let discoverStep = manager.steps.first { $0.id == .discoverFeatures }
        #expect(discoverStep?.isLocked == true)

        // Complete all except discoverFeatures
        for step in SetupStepID.allCases where step != .discoverFeatures {
            manager.markCompleted(step)
        }
        let discoverStepAfter = manager.steps.first { $0.id == .discoverFeatures }
        #expect(discoverStepAfter?.isLocked == false)
    }

    // MARK: - Auto Detect

    @MainActor @Test func autoDetect_transactions_completesStep() {
        let manager = freshManager()
        manager.autoDetect(transactionCount: 5, budgetCount: 0, scheduledCount: 0)
        #expect(manager.steps.first { $0.id == .firstExpense }?.isCompleted == true)
    }

    @MainActor @Test func autoDetect_budgets_completesStep() {
        let manager = freshManager()
        manager.autoDetect(transactionCount: 0, budgetCount: 2, scheduledCount: 0)
        #expect(manager.steps.first { $0.id == .firstBudget }?.isCompleted == true)
    }

    @MainActor @Test func autoDetect_scheduled_completesStep() {
        let manager = freshManager()
        manager.autoDetect(transactionCount: 0, budgetCount: 0, scheduledCount: 1)
        #expect(manager.steps.first { $0.id == .scheduledPayment }?.isCompleted == true)
    }

    @MainActor @Test func autoDetect_all_completesMultiple() {
        let manager = freshManager()
        manager.autoDetect(transactionCount: 3, budgetCount: 1, scheduledCount: 2)
        #expect(manager.completedCount == 3)
    }

    // MARK: - Collapse / Re-expand

    @MainActor @Test func toggleCollapsed_togglesState() {
        let manager = freshManager()
        #expect(manager.isCollapsed == false)
        manager.toggleCollapsed()
        #expect(manager.isCollapsed == true)
        manager.toggleCollapsed()
        #expect(manager.isCollapsed == false)
    }

    @MainActor @Test func collapseForTour_doesNotPersist() {
        let manager = freshManager()
        manager.collapseForTour()
        #expect(manager.isCollapsed == true)
        // Not persisted — UserDefaults should still be false
        #expect(UserDefaults.standard.bool(forKey: "setup.collapsed") == false)
    }

    @MainActor @Test func expandAfterTour_restores() {
        let manager = freshManager()
        manager.collapseForTour()
        manager.expandAfterTour()
        #expect(manager.isCollapsed == false)
    }

    @MainActor @Test func reExpand_afterIntervalSessions() {
        let manager = freshManager()
        UserDefaults.standard.set(10, forKey: "pro.upsell.sessionCount")
        manager.toggleCollapsed()
        #expect(manager.isCollapsed == true)

        UserDefaults.standard.set(12, forKey: "pro.upsell.sessionCount")
        manager.checkReExpand()
        #expect(manager.isCollapsed == true)

        UserDefaults.standard.set(13, forKey: "pro.upsell.sessionCount")
        manager.checkReExpand()
        #expect(manager.isCollapsed == false)
    }

    // MARK: - Reset

    @MainActor @Test func resetAll_clearsEverything() {
        let manager = freshManager()
        manager.markCompleted(.firstExpense)
        manager.markCompleted(.firstBudget)
        manager.toggleCollapsed()

        manager.resetAll()

        #expect(manager.completedCount == 0)
        #expect(manager.isCollapsed == false)
        #expect(manager.isAllComplete == false)
        #expect(manager.completedAllDate == nil)
    }

    // MARK: - SetupStepID Properties

    @Test func stepID_hasPracticeCleanup() {
        #expect(SetupStepID.firstExpense.hasPracticeCleanup == true)
        #expect(SetupStepID.firstBudget.hasPracticeCleanup == true)
        #expect(SetupStepID.scheduledPayment.hasPracticeCleanup == true)
        #expect(SetupStepID.tryVoiceInput.hasPracticeCleanup == true)
        #expect(SetupStepID.tryImageInput.hasPracticeCleanup == true)
        #expect(SetupStepID.exploreSettings.hasPracticeCleanup == false)
        #expect(SetupStepID.discoverFeatures.hasPracticeCleanup == false)
    }

    // MARK: - Voice/Image Trial Steps

    @MainActor @Test func discoverFeatures_lockedUntilTrialStepsComplete() {
        let manager = freshManager()
        // Complete original steps except discoverFeatures and trial steps
        manager.markCompleted(.exploreSettings)
        manager.markCompleted(.firstExpense)
        manager.markCompleted(.firstBudget)
        manager.markCompleted(.scheduledPayment)

        // Still locked — trial steps not complete
        let discoverStep = manager.steps.first { $0.id == .discoverFeatures }
        #expect(discoverStep?.isLocked == true)

        // Complete trial steps
        manager.markCompleted(.tryVoiceInput)
        manager.markCompleted(.tryImageInput)

        let discoverStepAfter = manager.steps.first { $0.id == .discoverFeatures }
        #expect(discoverStepAfter?.isLocked == false)
    }

    @MainActor @Test func stepsOrder_trialBeforeDiscover() {
        let manager = freshManager()
        let ids = manager.steps.map { $0.id }
        guard let voiceIdx = ids.firstIndex(of: .tryVoiceInput),
              let imageIdx = ids.firstIndex(of: .tryImageInput),
              let discoverIdx = ids.firstIndex(of: .discoverFeatures) else {
            Issue.record("Missing trial or discover steps")
            return
        }
        #expect(voiceIdx < discoverIdx)
        #expect(imageIdx < discoverIdx)
        #expect(voiceIdx < imageIdx)
    }

    @Test func stepID_allHaveIcons() {
        for step in SetupStepID.allCases {
            #expect(!step.icon.isEmpty)
        }
    }

    @Test func stepID_allHaveStorageKeys() {
        for step in SetupStepID.allCases {
            #expect(step.storageKey.hasPrefix("setup.step."))
            #expect(step.storageKey.hasSuffix(".completed"))
        }
    }
}
