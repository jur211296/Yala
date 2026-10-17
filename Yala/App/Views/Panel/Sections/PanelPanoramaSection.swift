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
        // Sin la frase de IA ni su botón desde el 2026-10-03 (`panel-accounts-redesign`). Sin la línea «Tienes X en
        // N cuentas» desde el lote 3 de la auditoría UX 2.2 (L3-1): el saldo lo cuenta el hero y cada cuenta el suyo.
        // Plegada enseña las cuentas en chips (L3-9, variante 3); desplegada, el carrusel y la salud.
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            header

            if isExpanded {
                content
                    .padding(.top, DS.Spacing.sm)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else if accountsVisible && !viewModel.accounts.isEmpty {
                PanelAccountChipsRow(
                    viewModel: viewModel,
                    orderedAccounts: viewModel.orderedActiveAccounts(
                        from: viewModel.accounts,
                        sortOrderNames: accountsSortOrderNames
                    ),
                    isExpensesOnlyMode: sessionState.isExpensesOnlyMode,
                    onAddAccount: addAccount,
                    onEditAccount: { accountFormSheet = AccountFormSheet(account: $0) },
                    onOpenAccount: { accountDetail = AccountDetailPresentation(account: $0) }
                )
                .transition(.opacity)
            }
        }
    }

    private var isAccountsLimitReached: Bool {
        let activeCount = viewModel.accounts.billableUserAccounts.count
        return !FeatureGateService.shared.canCreate(.accounts, currentCount: activeCount)
    }

    private func addAccount() {
        if isAccountsLimitReached {
            showUpgradeForAccounts = true
        } else {
            accountFormSheet = AccountFormSheet(account: nil)
        }
    }

    // MARK: - Header (collapse toggle)

    private var header: some View {
        let expanded = !appPreferences.panelAccountsCollapsed
        return CollapsibleSectionHeader(
            title: L10n.Panel.panoramaTitle,
            isExpanded: expanded,
            // `title3` como en `PanelSection`: «Tu panorama» es un título de
            // section, no de widget, y con el resto ya a 20 pt quedarse en 15
            // lo dejaba como el único rótulo pequeño de la columna.
            titleFont: DS.Typography.title3,
            subtitleFont: DS.Typography.subheadline,
            accessibilityValue: expanded ? L10n.Panel.panoramaExpandedValue : L10n.Panel.panoramaCollapsedValue,
            accessibilityHint: expanded ? L10n.Panel.panoramaCollapse : L10n.Panel.panoramaExpand
        ) {
            DS.Haptic.selection()
            dsWithAnimation(reduceMotion) {
                appPreferences.panelAccountsCollapsed.toggle()
            }
        }
        .accessibilityIdentifier("panel_panorama_header")
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
