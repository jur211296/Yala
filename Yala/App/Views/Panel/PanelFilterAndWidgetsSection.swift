//
//  PanelFilterAndWidgetsSection.swift
//  Yala
//
//  Multi-widget sections auto-hide when every widget is individually hidden;
//  single-widget sections only hide when the section itself is toggled off.
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
    @Binding var showCustomPeriodPicker: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            let allVisibleSections = PanelSectionKind.allCases.filter { kind in
                viewModel.isSectionVisible(kind) && viewModel.hasAnyVisibleWidget(in: kind)
            }
            let orderedVisibleSections = viewModel.orderedPanelSections(allVisibleSections)
            let accountsVisible = orderedVisibleSections.contains(.accounts)
            let healthVisible = orderedVisibleSections.contains(.health)

            if accountsVisible || healthVisible {
                PanelPanoramaSection(
                    viewModel: viewModel,
                    sessionState: sessionState,
                    accountsSortOrderNames: accountsSortOrderNames,
                    accountsVisible: accountsVisible,
                    healthVisible: healthVisible,
                    accountFormSheet: $accountFormSheet,
                    showUpgradeForAccounts: $showUpgradeForAccounts
                )
            }

            // Filter bar sits between Tu panorama and the thematic sections —
            // period + chips travel with the widgets they affect, not with the hero.
            PanelFilterControlBar(
                viewModel: viewModel,
                sessionState: sessionState,
                showCustomPeriodPicker: $showCustomPeriodPicker
            )

            let thematicSections = orderedVisibleSections.filter {
                $0 != .accounts && $0 != .health
            }
            ForEach(thematicSections, id: \.self) { kind in
                sectionView(for: kind)
            }
        }
    }

    // MARK: - Section Routing

    @ViewBuilder
    private func sectionView(for kind: PanelSectionKind) -> some View {
        switch kind {
        case .accounts, .health:
            let _ = assertionFailure("\(kind) should be rendered inside PanelPanoramaSection")
            EmptyView()
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
