//
//  PanelThematicSection.swift
//  Yala
//
//  Single thematic Panel section. Omitted entirely when no widget is visible.
//
//  P20-11:
//   - Accepts `.latestRecords` and `.tools` kinds (previously routed via default).
//   - Section-level footer CTA for Tendencias/Distribución/Últimos registros.
//   - Planificación uses per-widget full-width layout with inline footer per
//     widget (semantic "footer pertenece al widget"). Same layout on iPhone
//     and iPad — trade-off is more vertical space in exchange for consistency.
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let widgets = viewModel.activeWidgets(in: kind)
        if !widgets.isEmpty {
            PanelSection(
                title: kind.localizedTitle,
                onPreferences: onPreferences,
                content: { contentView(widgets: widgets) },
                footer: { footerView() }
            )
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func contentView(widgets: [WidgetConfig]) -> some View {
        if kind == .planificacion {
            // Per-widget footer — each widget renders full-width followed by
            // its dedicated CTA. Bypasses the half-width pair layout in iPad
            // to keep the "footer belongs to the widget" semantics.
            VStack(spacing: DS.Spacing.lg) {
                ForEach(widgets) { config in
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        PanelWidgetRouter(
                            config: config,
                            viewModel: viewModel,
                            sessionState: sessionState,
                            currencyCode: defaultCurrencyCodeRaw,
                            showVariations: showVariations,
                            reduceMotion: reduceMotion,
                            showBudgetFavoritesSettings: $showBudgetFavoritesSettings
                        )
                        planificacionFooter(for: config.type)
                    }
                }
            }
        } else {
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

    // MARK: - Planificación per-widget footer

    @ViewBuilder
    private func planificacionFooter(for type: WidgetType) -> some View {
        switch type {
        case .budgets:
            PanelSectionFooterButton(
                title: L10n.Panel.seeBudgets,
                hint: L10n.Panel.seeMoreHintBudgets,
                action: { sessionState.navigateToBudgets() }
            )
        case .scheduledPayments:
            PanelSectionFooterButton(
                title: L10n.Panel.seeScheduledPayments,
                hint: L10n.Panel.seeMoreHintScheduled,
                action: { sessionState.navigateToScheduledPayments() }
            )
        default:
            EmptyView()
        }
    }

    // MARK: - Section-level footer (Tendencias / Distribución / Últimos registros)

    @ViewBuilder
    private func footerView() -> some View {
        switch kind {
        case .tendencias:
            PanelSectionFooterButton(
                title: L10n.Panel.seeMoreInTrends,
                hint: L10n.Panel.seeMoreHintTrends,
                action: { viewModel.navigateToStatistics(.trends) }
            )
        case .distribucion:
            PanelSectionFooterButton(
                title: L10n.Panel.seeMoreInDistribution,
                hint: L10n.Panel.seeMoreHintDistribution,
                action: { viewModel.navigateToStatistics(.categories) }
            )
        case .latestRecords:
            PanelSectionFooterButton(
                title: L10n.Panel.seeAllRecords,
                hint: L10n.Panel.seeMoreHintRecords,
                action: { sessionState.navigateToRecordsStandalone() }
            )
        case .planificacion, .tools, .health, .accounts:
            EmptyView()
        }
    }
}
