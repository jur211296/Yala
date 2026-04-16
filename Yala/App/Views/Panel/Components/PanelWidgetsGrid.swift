//
//  PanelWidgetsGrid.swift
//  Yala
//
//  Renders a collection of `WidgetConfig` as rows (iPhone full-width / iPad pairs).
//

import SwiftUI

struct PanelWidgetsGrid: View {
    let widgets: [WidgetConfig]
    let viewModel: PanelViewModel
    let sessionState: SessionState
    let defaultCurrencyCodeRaw: String
    let showVariations: Bool
    @Binding var showBudgetFavoritesSettings: Bool

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let rows = WidgetConfigManager.makeLayoutRows(
            for: widgets,
            columns: DS.Adaptive.columns(sizeClass)
        )
        // LazyVStack crashes on tab switch within the Panel ScrollView.
        VStack(spacing: DS.Spacing.lg) {
            ForEach(rows) { row in
                rowView(for: row)
            }
        }
    }

    @ViewBuilder
    private func rowView(for row: WidgetConfigManager.WidgetRow) -> some View {
        switch row.type {
        case .fullWidth(let config):
            widgetView(for: config).clipped()
        case .halfWidthPair(let left, let right):
            HStack(alignment: .top, spacing: DS.Spacing.lg) {
                widgetView(for: left)
                    .frame(maxWidth: .infinity)
                    .clipped()

                if let right {
                    widgetView(for: right)
                        .frame(maxWidth: .infinity)
                        .clipped()
                } else {
                    Color.clear.frame(maxWidth: .infinity)
                }
            }
        }
    }

    @ViewBuilder
    private func widgetView(for config: WidgetConfig) -> some View {
        let preferredCurrency = CurrencyCode(rawValue: defaultCurrencyCodeRaw) ?? .pen
        PanelWidgetRouter(
            config: config,
            viewModel: viewModel,
            sessionState: sessionState,
            currencyCode: preferredCurrency.rawValue,
            showVariations: showVariations,
            reduceMotion: reduceMotion,
            showBudgetFavoritesSettings: $showBudgetFavoritesSettings
        )
    }
}
