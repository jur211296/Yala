//
//  PanelAccountsSection.swift
//  Yala
//
//  Extracted from PanelView to isolate accounts observation tracking.
//  Uses pre-computed balance dictionaries instead of raw transactions array.
//
//  P20-11: header is now a collapse toggle (chevron on the right, color
//  primary). State persists in `AppPreferences.panelAccountsCollapsed`
//  (synced via iCloud KV). All other sections remain non-collapsible.
//

import SwiftData
import SwiftUI

struct PanelAccountsSection: View {
    let viewModel: PanelViewModel
    let sessionState: SessionState
    let accountsSortOrderNames: [String]
    @Binding var accountFormSheet: AccountFormSheet?
    @Binding var showUpgradeForAccounts: Bool

    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isAccountsLimitReached: Bool {
        let activeCount = viewModel.accounts.count(where: { !$0.isArchived })
        return !FeatureGateService.shared.canCreate(.accounts, currentCount: activeCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            header

            if !appPreferences.panelAccountsCollapsed {
                content
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Header (collapse toggle)

    private var header: some View {
        let expanded = !appPreferences.panelAccountsCollapsed
        return Button {
            dsWithAnimation(reduceMotion) {
                appPreferences.panelAccountsCollapsed.toggle()
            }
        } label: {
            HStack(alignment: .firstTextBaseline) {
                Text(L10n.Panel.accounts)
                    .font(DS.Typography.title)
                    .foregroundStyle(Color.primary)
                Spacer()
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(DS.Typography.body)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
                    .accessibilityHidden(true)
            }
            .padding(.vertical, DS.Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.Panel.accounts)
        .accessibilityValue(
            expanded ? L10n.Panel.accountsExpandedValue : L10n.Panel.accountsCollapsedValue
        )
        .accessibilityHint(
            expanded ? L10n.Panel.accountsCollapse : L10n.Panel.accountsExpand
        )
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Content (carousel / empty state)

    @ViewBuilder
    private var content: some View {
        if viewModel.accounts.isEmpty {
            YalaEmptyState.noAccounts {
                if isAccountsLimitReached {
                    showUpgradeForAccounts = true
                } else {
                    accountFormSheet = AccountFormSheet(account: nil)
                }
            }
        } else {
            AccountsCarouselView(
                viewModel: viewModel,
                orderedAccounts: viewModel.orderedActiveAccounts(
                    from: viewModel.accounts,
                    sortOrderNames: accountsSortOrderNames
                ),
                accountBalances: viewModel.accountBalances,
                accountPeriodExpenses: viewModel.accountPeriodExpenses,
                isExpensesOnlyMode: sessionState.isExpensesOnlyMode,
                onAddAccount: {
                    if isAccountsLimitReached {
                        showUpgradeForAccounts = true
                    } else {
                        accountFormSheet = AccountFormSheet(account: nil)
                    }
                },
                onEditAccount: { account in
                    accountFormSheet = AccountFormSheet(account: account)
                }
            )
        }
    }
}
