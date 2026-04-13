//
//  PanelAccountsSection.swift
//  Yala
//
//  Extracted from PanelView to isolate accounts observation tracking.
//  Uses pre-computed balance dictionaries instead of raw transactions array.
//

import SwiftData
import SwiftUI

struct PanelAccountsSection: View {
    let viewModel: PanelViewModel
    let sessionState: SessionState
    let accountsSortOrderNames: [String]
    @Binding var accountFormSheet: AccountFormSheet?
    @Binding var showUpgradeForAccounts: Bool

    private var isAccountsLimitReached: Bool {
        let activeCount = viewModel.accounts.count(where: { !$0.isArchived })
        return !FeatureGateService.shared.canCreate(.accounts, currentCount: activeCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            Text(L10n.Panel.accounts)
                .font(DS.Typography.title)

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
                .coachMarkAnchor("accounts")
                .coachMarkAnchor("filterAccount")
            }
        }
    }
}
