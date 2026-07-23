//
//  PanelAccountsSection.swift
//  Yala
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
        let activeCount = viewModel.accounts.billableUserAccounts.count
        return !FeatureGateService.shared.canCreate(.accounts, currentCount: activeCount)
    }

    var body: some View {
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
