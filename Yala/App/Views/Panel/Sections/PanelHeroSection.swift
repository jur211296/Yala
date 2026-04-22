//
//  PanelHeroSection.swift
//  Yala
//
//  Gating wrapper: renders `HeroMonthView` only once `PanelViewModel` has
//  computed the hero payload (otherwise the skeleton flashes an empty card).
//  Propaga el binding del period picker para que `PanelFilterControlBar`
//  pueda quedarse en chips-only. Decide el destino del upsellCTA según
//  el estado del user: Free → sheet de upgrade; Pro sin consent → alert
//  que activa el consent IA (auto-toggle ON) y dispara la regeneración.
//
//  Intentionally NOT a `PanelSectionKind` — the hero is a permanent header
//  of the Panel, not a thematic section the user can hide.
//

import SwiftUI

struct PanelHeroSection: View {
    @Bindable var viewModel: PanelViewModel
    let sessionState: SessionState
    @Binding var showCustomPeriodPicker: Bool
    @Environment(AppPreferences.self) private var appPreferences

    /// Single source of truth para el destino del upsellCTA — elimina la
    /// combinación imposible "ambos true" de dos booleanos separados.
    private enum UpsellDestination: Identifiable {
        case upgrade
        case consent
        var id: String { String(describing: self) }
    }

    @State private var upsellDestination: UpsellDestination?

    var body: some View {
        if let data = viewModel.heroWidget.data {
            // Touch consent so SwiftUI invalidates this section when the user
            // toggles the AI insights consent in Profile — otherwise the
            // upsellCTA stays stale until the next data refresh.
            let _ = appPreferences.aiInsightsConsentAccepted

            let isPro = FeatureGateService.shared.isProUser
            let hasConsent = appPreferences.aiInsightsConsentAccepted
            let showUpsellCTA = viewModel.heroAISubtitle == nil && (!isPro || !hasConsent)

            HeroMonthView(
                data: data,
                currencyCode: viewModel.defaultCurrencyCode,
                selectedPeriod: sessionState.selectedPeriod,
                customDateRange: sessionState.customDateRange,
                onSelectPeriod: { sessionState.selectedPeriod = $0 },
                onCustomPeriodTapped: { showCustomPeriodPicker = true },
                aiSubtitle: viewModel.heroAISubtitle,
                showProBadge: viewModel.heroAISubtitle != nil,
                showUpsellCTA: showUpsellCTA,
                onUpsellTap: {
                    TelemetryService.track(.panelHeroCTATap)
                    upsellDestination = isPro ? .consent : .upgrade
                }
            )
            .contentShape(Rectangle())
            .onTapGesture {
                sessionState.navigateToDetail(.insights)
            }
            .sheet(isPresented: Binding(
                get: { upsellDestination == .upgrade },
                set: { if !$0 { upsellDestination = nil } }
            )) {
                UpgradePromptSheet(
                    feature: .smartInsightsAI,
                    context: .proFeature,
                    source: "panelHero"
                )
            }
            .alert(
                L10n.AIConsent.insightsTitle,
                isPresented: Binding(
                    get: { upsellDestination == .consent },
                    set: { if !$0 { upsellDestination = nil } }
                )
            ) {
                Button(L10n.AIConsent.accept) {
                    appPreferences.aiInsightsConsentAccepted = true
                    viewModel.retriggerHeroAI()
                }
                Button(L10n.Action.cancel, role: .cancel) {}
            } message: {
                Text(L10n.AIConsent.insightsMessage)
            }
        }
    }
}
