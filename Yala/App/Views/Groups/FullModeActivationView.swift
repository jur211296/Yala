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

    @State private var prefilledSummary: ICloudAccountSummary?

    var body: some View {
        OnboardingView(
            prefilledData: prefilledSummary,
            backgroundStyle: .themedPanel,
            mode: .fullActivation,
            onCancel: { onComplete() },
            onComplete: { completeFullActivation() }
        )
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
        do {
            let accounts = try modelContext.fetch(descriptor)
            for account in accounts where FullModeActivationLogic.shouldDeleteResidualGeneralAccount(
                type: account.type,
                isSystemAccount: account.isSystemAccount,
                hasTransactions: !(account.transactions?.isEmpty ?? true)
            ) {
                modelContext.delete(account)
            }
            try modelContext.save()
        } catch {
            // El cleanup es defensivo: un fallo no debe bloquear la activación full.
            #if DEBUG
            print("FullModeActivationView: cleanup de cuenta General residual falló: \(error)")
            #endif
        }
    }

    /// `OnboardingView.completeOnboarding` ya hizo seeds + account + notifs +
    /// `hasCompletedOnboarding=true`. Aquí cambiamos al modo `.completed` y
    /// expandimos el TabBar. Las TX virtuales de gastos pre-existentes ya están
    /// creadas por el bridge automático (modelo M5) — no requiere import.
    private func completeFullActivation() {
        let sync = PreferenceSyncService.shared
        sync.set(string: OnboardingMode.completed.rawValue, forKey: OnboardingMode.userDefaultsKey)
        sessionState.onboardingMode = .completed

        UserDefaults.standard.set(
            TabBarConfiguration.default.toJSON(),
            forKey: TabBarConfiguration.storageKey
        )
        sessionState.selectMainTab(.panel)

        // `.onboardingCompleted` lo dispara `OnboardingView.completeOnboarding`
        // con el `mode` correcto — invariante: un solo fire por flow.
        TelemetryService.track(.fullModeActivationCompleted, parameters: [
            "fromSegment": UserSegmentService.shared.currentSegment.rawValue,
        ])

        onComplete()
    }
}
