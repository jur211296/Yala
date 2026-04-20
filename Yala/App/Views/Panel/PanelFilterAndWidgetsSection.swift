//
//  PanelFilterAndWidgetsSection.swift
//  Yala
//
//  P20-11: Simplificado a un loop de secciones con auto-hide. El period
//  selector + chips se movió a `PanelFilterControlBar` (invocado desde
//  PanelView). Routing por `PanelSectionKind` incluye todas las secciones
//  de Panel 2.0 — Cuentas (P20-11), Últimos registros (toggleable ahora),
//  Salud financiera, y los thematic sections multi-widget.
//
//  Auto-hide (P20-11): `viewModel.hasAnyVisibleWidget(in:)` oculta secciones
//  multi-widget cuando el usuario ocultó todos sus widgets individualmente.
//  Single-widget sections siempre retornan `true` para ese helper.
//

import SwiftData
import SwiftUI

struct PanelFilterAndWidgetsSection: View {
    let viewModel: PanelViewModel
    let sessionState: SessionState
    let defaultCurrencyCodeRaw: String
    let showVariations: Bool
    let accountsSortOrderNames: [String]
    @Binding var sectionPrefsPresentation: PanelSectionKind?
    @Binding var showBudgetFavoritesSettings: Bool
    @Binding var accountFormSheet: AccountFormSheet?
    @Binding var showUpgradeForAccounts: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Thematic sections. Filtering here (not in `PanelThematicSection`)
            // keeps hidden sections from mounting at all — no render, no
            // observer subscriptions. Multi-widget sections expose a per-section
            // gear (P20-03) that presents `PanelSectionPreferencesSheet`;
            // single-widget sections skip it (nothing to reorder or toggle).
            let visibleSections = PanelSectionKind.allCases.filter { kind in
                viewModel.isSectionVisible(kind) && viewModel.hasAnyVisibleWidget(in: kind)
            }
            ForEach(visibleSections, id: \.self) { kind in
                sectionView(for: kind)
            }
        }
    }

    // MARK: - Section Routing

    @ViewBuilder
    private func sectionView(for kind: PanelSectionKind) -> some View {
        switch kind {
        case .health:
            PanelHealthSection(viewModel: viewModel, sessionState: sessionState)
        case .accounts:
            PanelAccountsSection(
                viewModel: viewModel,
                sessionState: sessionState,
                accountsSortOrderNames: accountsSortOrderNames,
                accountFormSheet: $accountFormSheet,
                showUpgradeForAccounts: $showUpgradeForAccounts
            )
        case .tendencias, .distribucion, .planificacion, .latestRecords, .tools:
            PanelThematicSection(
                kind: kind,
                viewModel: viewModel,
                sessionState: sessionState,
                defaultCurrencyCodeRaw: defaultCurrencyCodeRaw,
                showVariations: showVariations,
                showBudgetFavoritesSettings: $showBudgetFavoritesSettings,
                onPreferences: kind.hasMultipleWidgets
                    ? { sectionPrefsPresentation = kind }
                    : nil
            )
        }
    }
}
