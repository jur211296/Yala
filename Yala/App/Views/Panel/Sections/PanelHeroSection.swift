//
//  PanelHeroSection.swift
//  Yala
//
//  Gating wrapper: renders `HeroMonthView` only once `PanelViewModel` has
//  computed the hero payload (otherwise the skeleton flashes an empty card).
//  Propaga el binding del period picker para que `PanelFilterControlBar`
//  pueda quedarse en chips-only. La frase motivacional y el upsellCTA viven
//  en `PanelPanoramaSection` (subtítulo de "Tus finanzas" colapsado).
//
//  Intentionally NOT a `PanelSectionKind` — the hero is a permanent header
//  of the Panel, not a thematic section the user can hide.
//

import SwiftUI

struct PanelHeroSection: View {
    @Bindable var viewModel: PanelViewModel
    let sessionState: SessionState
    @Binding var showCustomPeriodPicker: Bool

    var body: some View {
        if let data = viewModel.heroWidget.data {
            HeroMonthView(
                data: data,
                currencyCode: viewModel.defaultCurrencyCode,
                selectedPeriod: sessionState.selectedPeriod,
                customDateRange: sessionState.customDateRange,
                onSelectPeriod: { sessionState.selectedPeriod = $0 },
                onCustomPeriodTapped: { showCustomPeriodPicker = true },
                periodSummary: viewModel.heroPeriodWidget
            )
            .contentShape(Rectangle())
            .onTapGesture {
                sessionState.navigateToDetail(.insights)
            }
        }
    }
}
