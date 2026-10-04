//
//  PanelPanoramaSection.swift
//  Yala
//
//  `panelAccountsCollapsed` is reused as the storage key for the whole group
//  to preserve iCloud KV sync across devices; renaming it would orphan the
//  existing value.
//

import SwiftUI

struct PanelPanoramaSection: View {
    let viewModel: PanelViewModel
    let sessionState: SessionState
    let accountsSortOrderNames: [String]
    let accountsVisible: Bool
    let healthVisible: Bool
    @Binding var accountFormSheet: AccountFormSheet?
    @Binding var accountDetail: AccountDetailPresentation?
    @Binding var showUpgradeForAccounts: Bool

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let isExpanded = !appPreferences.panelAccountsCollapsed
        // Sin la frase de IA ni su botón desde el 2026-10-03 (`panel-accounts-redesign`): la sección enseña las
        // cuentas y la salud, y la cabecera lleva el total.
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            header

            if isExpanded {
                content
                    .padding(.top, DS.Spacing.sm)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Header (collapse toggle)

    private var header: some View {
        let expanded = !appPreferences.panelAccountsCollapsed
        return CollapsibleSectionHeader(
            title: L10n.Panel.panoramaTitle,
            subtitleAttributed: accountsSummaryAttributed,
            isExpanded: expanded,
            // `title3` como en `PanelSection`: «Tu panorama» es un título de
            // section, no de widget, y con el resto ya a 20 pt quedarse en 15
            // lo dejaba como el único rótulo pequeño de la columna.
            titleFont: DS.Typography.title3,
            subtitleFont: DS.Typography.subheadline,
            accessibilityValue: accessibilityValue(expanded: expanded),
            accessibilityHint: expanded ? L10n.Panel.panoramaCollapse : L10n.Panel.panoramaExpand
        ) {
            DS.Haptic.selection()
            dsWithAnimation(reduceMotion) {
                appPreferences.panelAccountsCollapsed.toggle()
            }
        }
        .accessibilityIdentifier("panel_panorama_header")
    }

    /// Conteo de cuentas del saldo total, coherente con `viewModel.panelTotalBalance`:
    /// excluye las cuentas sistema de grupos cuando `includeGroupsInPanelTotal` está OFF.
    private var totalAccountsCount: Int {
        let active = viewModel.accounts.filter { !$0.isArchived }
        return PanelTotalAccountsLogic.accountsForTotal(
            active,
            includeGroups: appPreferences.includeGroupsInPanelTotal,
            hasSelectedAccount: PanelTotalAccountsLogic.hasAccountFilter(
                selectedAccountIDs: viewModel.selectedAccountIDs,
                isExcludeMode: viewModel.isExcludeMode
            )
        ).count
    }

    private var accountsSummary: String? {
        let activeCount = totalAccountsCount
        guard activeCount > 0 else { return nil }
        let formattedBalance = appPreferences.currency(
            viewModel.panelTotalBalance,
            currencyCode: appPreferences.defaultCurrencyCode.rawValue,
            isEstimate: viewModel.panelTotalBalanceIsApproximate
        )
        return L10n.Panel.panoramaCollapsedSummary(formattedBalance, accounts: activeCount)
    }

    /// Versión atribuida de `accountsSummary`: monto con jerarquía (symbol y
    /// decimales en secondary tamaño caption, integer en subheadline) embebido
    /// dentro de "Tienes <amount> en N cuentas". Splittea el string L10n por
    /// el formattedBalance para concatenar el AttributedString del amount
    /// entre los fragmentos textuales — preserva la traducción cross-locale.
    private var accountsSummaryAttributed: AttributedString? {
        let activeCount = totalAccountsCount
        guard activeCount > 0 else { return nil }
        let formattedBalance = appPreferences.currency(
            viewModel.panelTotalBalance,
            currencyCode: appPreferences.defaultCurrencyCode.rawValue,
            isEstimate: viewModel.panelTotalBalanceIsApproximate
        )
        let full = L10n.Panel.panoramaCollapsedSummary(formattedBalance, accounts: activeCount)
        let parts = full.components(separatedBy: formattedBalance)

        var result = AttributedString()
        if let first = parts.first {
            result.append(AttributedString(first))
        }
        result.append(AmountText.attributedAmount(
            value: viewModel.panelTotalBalance,
            currencyCode: appPreferences.defaultCurrencyCode.rawValue,
            prefs: appPreferences,
            isEstimate: viewModel.panelTotalBalanceIsApproximate
        ))
        if parts.count > 1 {
            result.append(AttributedString(parts.dropFirst().joined(separator: formattedBalance)))
        }
        return result
    }

    private func accessibilityValue(expanded: Bool) -> String {
        var parts: [String] = []
        parts.append(expanded ? L10n.Panel.panoramaExpandedValue : L10n.Panel.panoramaCollapsedValue)
        if let accountsSummary {
            parts.append(accountsSummary)
        }
        return parts.joined(separator: ". ")
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            if accountsVisible {
                PanelAccountsSection(
                    viewModel: viewModel,
                    sessionState: sessionState,
                    accountsSortOrderNames: accountsSortOrderNames,
                    accountFormSheet: $accountFormSheet,
                    accountDetail: $accountDetail,
                    showUpgradeForAccounts: $showUpgradeForAccounts
                )
            }
            if healthVisible {
                PanelHealthSection(
                    viewModel: viewModel,
                    sessionState: sessionState
                )
            }
        }
    }
}
