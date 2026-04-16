//
//  PanelThematicSection.swift
//  Yala
//
//  Single thematic Panel section. Omitted entirely when no widget is visible.
//

import SwiftUI

struct PanelThematicSection: View {
    let kind: PanelSectionKind
    let viewModel: PanelViewModel
    let sessionState: SessionState
    let defaultCurrencyCodeRaw: String
    let showVariations: Bool
    @Binding var showBudgetFavoritesSettings: Bool
    var onPreferences: (() -> Void)? = nil

    var body: some View {
        let widgets = viewModel.activeWidgets(in: kind)
        if !widgets.isEmpty {
            PanelSection(title: kind.localizedTitle, onPreferences: onPreferences) {
                PanelWidgetsGrid(
                    widgets: widgets,
                    viewModel: viewModel,
                    sessionState: sessionState,
                    defaultCurrencyCodeRaw: defaultCurrencyCodeRaw,
                    showVariations: showVariations,
                    showBudgetFavoritesSettings: $showBudgetFavoritesSettings
                )
            }
        }
    }
}
