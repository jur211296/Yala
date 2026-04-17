//
//  PanelHeroSection.swift
//  Yala
//
//  Gating wrapper: renders `HeroMonthView` only once `PanelViewModel` has
//  computed the hero payload (otherwise the skeleton flashes an empty card).
//  Intentionally NOT a `PanelSectionKind` — the hero is a permanent header
//  of the Panel, not a thematic section the user can hide.
//

import SwiftUI

struct PanelHeroSection: View {
    let viewModel: PanelViewModel

    var body: some View {
        if let data = viewModel.heroWidget.data {
            HeroMonthView(data: data, currencyCode: viewModel.defaultCurrencyCode)
        }
    }
}
