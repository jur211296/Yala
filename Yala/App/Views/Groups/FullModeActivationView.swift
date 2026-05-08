//
//  FullModeActivationView.swift
//  Yala
//
//  Wrapper que reusa OnboardingView para activar Yala completo desde el modo
//  `.groupInvite`. El flow es idéntico al onboarding fresh excepto los steps
//  skipeados por prefill (name + currencyName) y categorías skipeadas si el
//  user ya las sembró vía SubcategorySelectorSheet (Approach J, Bug #21).
//

import SwiftData
import SwiftUI

struct FullModeActivationView: View {
    var onComplete: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(SessionState.self) private var sessionState

    @State private var showImportPrompt = false
    @State private var groupExpenseCount = 0
    @State private var prefilledSummary: ICloudAccountSummary?

    var body: some View {
        NavigationStack {
            OnboardingView(
                prefilledData: prefilledSummary,
                onCancelFromStep1: { onComplete() },
                onComplete: { completeFullActivation() }
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Action.cancel) { onComplete() }
                }
            }
        }
        .alert(L10n.Groups.Activate.importPrompt(groupExpenseCount), isPresented: $showImportPrompt) {
            Button(L10n.Groups.Activate.importYes) {
                importGroupHistory()
                onComplete()
            }
            Button(L10n.Groups.Activate.importNo, role: .cancel) {
                onComplete()
            }
        }
        .onAppear {
            cleanupResidualGeneralAccount()
            if prefilledSummary == nil { prefilledSummary = buildPrefilledSummary() }
            TelemetryService.track(.fullModeActivationStarted)
        }
    }

    /// `fetchCount` para Category es <10ms — invocado una vez en `.onAppear`.
    private func buildPrefilledSummary() -> ICloudAccountSummary {
        let categoriesCount = (try? modelContext.fetchCount(
            FetchDescriptor<Category>(predicate: #Predicate { !$0.isSystem })
        )) ?? 0
        return FullModeActivationLogic.buildSummary(
            userName: UserDefaults.standard.string(forKey: AppPreferences.Keys.userName),
            groupCurrency: SplitSyncManager.shared.mostRecentGroup()?.currencyCode,
            defaultCurrency: UserDefaults.standard.string(forKey: AppPreferences.Keys.defaultCurrencyCode),
            userCategoriesCount: categoriesCount
        )
    }

    /// Paranoid safeguard para QA con state acumulado de tests previos.
    /// En producción no hay legacy: groups no estaban en producción según decisión [2026-05-05].
    private func cleanupResidualGeneralAccount() {
        let generalType = AccountType.general.rawValue
        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate {
                $0.type == generalType && !$0.isSystemAccount
            }
        )
        guard let accounts = try? modelContext.fetch(descriptor) else { return }
        for account in accounts where FullModeActivationLogic.shouldDeleteResidualGeneralAccount(
            type: account.type,
            isSystemAccount: account.isSystemAccount,
            hasTransactions: !(account.transactions?.isEmpty ?? true)
        ) {
            modelContext.delete(account)
        }
        try? modelContext.save()
    }

    /// `OnboardingView.completeOnboarding` ya hizo seeds + account + notifs +
    /// `hasCompletedOnboarding=true`. Aquí cambiamos al modo `.completed`,
    /// expandimos el TabBar y, si hay group expenses, ofrecemos importarlas.
    private func completeFullActivation() {
        let sync = PreferenceSyncService.shared
        sync.set(string: OnboardingMode.completed.rawValue, forKey: OnboardingMode.userDefaultsKey)
        sessionState.onboardingMode = .completed

        UserDefaults.standard.set(
            TabBarConfiguration.default.toJSON(),
            forKey: TabBarConfiguration.storageKey
        )
        sessionState.selectedMainTab = .panel

        TelemetryService.track(.onboardingCompleted, parameters: [
            "mode": "fullActivation",
        ])
        TelemetryService.track(.fullModeActivationCompleted, parameters: [
            "fromSegment": UserSegmentService.shared.currentSegment.rawValue,
        ])

        let count = (try? modelContext.fetchCount(FetchDescriptor<SplitExpense>())) ?? 0
        if count > 0 {
            groupExpenseCount = count
            showImportPrompt = true
        } else {
            onComplete()
        }
    }

    private func importGroupHistory() {
        let descriptor = FetchDescriptor<SplitGroup>()
        guard let groups = try? modelContext.fetch(descriptor), !groups.isEmpty else { return }
        do {
            try GroupTransactionBridge.shared.importGroupHistoryAsDrafts(for: groups)
            TelemetryService.track(.groupHistoryImported, parameters: [
                "count": String(groupExpenseCount),
            ])
        } catch {
            #if DEBUG
            print("FullModeActivationView: Import error: \(error)")
            #endif
        }
    }
}
