//
//  PanelHeroSection.swift
//  Yala
//
//  Gating wrapper: renders `HeroMonthView` only once `PanelViewModel` has
//  computed the hero payload (otherwise the skeleton flashes an empty card).
//  Owns the presentation state for the KPI preferences sheet (P20-04b).
//
//  Intentionally NOT a `PanelSectionKind` — the hero is a permanent header
//  of the Panel, not a thematic section the user can hide.
//

import SwiftUI

struct PanelHeroSection: View {
    @Bindable var viewModel: PanelViewModel
    @Environment(AppPreferences.self) private var appPreferences

    @State private var showingKPIPrefs = false
    /// Sheet del upsell cuando un usuario Free tapea el CTA "Personalízalo con IA".
    @State private var showingUpgrade = false

    var body: some View {
        // Observation fix: the VM's `activeHeroKPIs()` reads from
        // `appPreferences.panelHeroKPIs*` but the VM itself is not an
        // @Observable dependency of those. Touching them here registers this
        // section as an observer so SwiftUI invalidates it after the KPI
        // sheet flushes its drafts. Same pattern that `HeroMonthView` uses
        // for the formatter prefs.
        let _ = appPreferences.panelHeroKPIsOrder
        let _ = appPreferences.panelHeroKPIsHidden
        let _ = appPreferences.panelHeroKPIsCustomized

        if let data = viewModel.heroWidget.data {
            HeroMonthView(
                data: data,
                currencyCode: viewModel.defaultCurrencyCode,
                activeKPIs: viewModel.activeHeroKPIs(),
                onEditTapped: { showingKPIPrefs = true },
                aiSubtitle: viewModel.heroAISubtitle,
                showProBadge: viewModel.heroAISubtitle != nil,
                showUpsellCTA: !FeatureGateService.shared.isProUser,
                onUpsellTap: {
                    TelemetryService.track(.panelHeroCTATap)
                    showingUpgrade = true
                }
            )
            .sheet(isPresented: $showingKPIPrefs) {
                HeroKPIPreferencesSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showingUpgrade) {
                UpgradePromptSheet(
                    feature: .smartInsightsAI,
                    context: .proFeature,
                    source: "panelHero"
                )
            }
        }
    }
}
