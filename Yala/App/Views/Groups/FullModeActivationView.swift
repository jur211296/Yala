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
    /// D1: al activar Yala completo desde «Solo mis grupos» hay que resetear el foco de la shell
    /// (si no, `usageFocus == .groupsOnly` residual mantendría la app reducida pese al onboarding).
    @Environment(AppPreferences.self) private var appPreferences

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
        }
    }

    /// `fetchCount` para Category es <10ms — invocado una vez en `.onAppear`.
    private func buildPrefilledSummary() -> ICloudAccountSummary {
        let categoriesCount: Int
        do {
            categoriesCount = try modelContext.fetchCount(
                FetchDescriptor<Category>(predicate: #Predicate { !$0.isSystem })
            )
        } catch {
            #if DEBUG
            print("FullModeActivationView: category fetchCount failed: \(error)")
            #endif
            categoriesCount = 0
        }
        return FullModeActivationLogic.buildSummary(
            userName: SessionDefaults.current.string(forKey: AppPreferences.Keys.userName),
            groupCurrency: GroupService.shared.mostRecentGroup()?.currencyCode,
            defaultCurrency: SessionDefaults.current.string(forKey: AppPreferences.Keys.defaultCurrencyCode),
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
        // M1 · frontera de cuenta. Este `set` escribe la key del modo por `PreferenceSyncService`
        // —que en `.localOnly` (sesión secundaria) sigue escribiendo el ESPEJO LOCAL, o sea el
        // `SessionDefaults.current` del DUEÑO— así que el guard de `OnboardingMode.setCurrent` no lo
        // cubre: va aquí, en el escritor. `.completed` es rank 2 y el merge es never-downgrade ⇒
        // escribirlo desde la sesión de la invitada deja al dueño una shell escalada que su
        // `.groupInvite` del iKV ya no puede recuperar, y el wipe de salida no repone la key.
        // La activación SÍ ocurre en memoria: la invitada ve su shell completa durante su sesión.
        if !SecondarySessionStore.isActive() {
            sync.set(string: OnboardingMode.completed.rawValue, forKey: OnboardingMode.userDefaultsKey)
        }
        sessionState.onboardingMode = .completed

        // D1: des-reducir la shell. DEBE ir ANTES de `selectMainTab(.panel)` — `effectiveShellMode`
        // es `.groupsFocused` mientras `usageFocus == .groupsOnly` (independiente de onboardingMode),
        // así que el guard GC-08 rechazaría `.panel` si el reset viniera después. No-op para
        // group-invite (usageFocus ya `.full`, guard del didSet).
        appPreferences.usageFocus = .full

        SessionDefaults.current.set(
            TabBarConfiguration.default.toJSON(),
            forKey: TabBarConfiguration.storageKey
        )
        sessionState.selectMainTab(.panel)

        onComplete()
    }
}
