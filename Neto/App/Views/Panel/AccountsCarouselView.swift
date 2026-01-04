import SwiftData
import SwiftUI

struct AccountsCarouselView: View {
    @Bindable var viewModel: PanelViewModel
    let orderedAccounts: [Account]
    let transactions: [TransactionItem]
    let onAddAccount: () -> Void
    let onEditAccount: (Account) -> Void

    var body: some View {
        let allCards = orderedAccounts
        let totalCards = allCards.count + 1  // accounts + add button

        // Calculate page count: we show 2 cards at a time, scroll 1 at a time
        // Pages = totalCards - 1 (since last card would show with the previous one)
        let pageCount = max(1, totalCards - 1)

        let currentPage: Int = {
            guard pageCount > 1 else { return 0 }
            let rawIndex = viewModel.leadingColumnIndex ?? 0
            return max(0, min(pageCount - 1, rawIndex))
        }()

        VStack(spacing: DS.Spacing.sm) {
            GeometryReader { geo in
                let totalWidth = geo.size.width
                let spacing: CGFloat = DS.Spacing.md
                let cardWidth = (totalWidth - spacing) / 2

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: spacing) {
                        ForEach(0..<totalCards, id: \.self) { index in
                            cardView(at: index, accounts: allCards)
                                .frame(width: cardWidth)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $viewModel.leadingColumnIndex)
                .frame(width: totalWidth)
            }
            .frame(height: 96)

            // Page indicator
            if pageCount > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<pageCount, id: \.self) { page in
                        Circle()
                            .fill(
                                page == currentPage
                                    ? Color.netoPrimaryText.opacity(0.3)
                                    : Color.netoSecondaryText.opacity(0.2)
                            )
                            .frame(width: 6, height: 6)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    // MARK: - Card View

    @ViewBuilder
    private func cardView(at index: Int, accounts: [Account]) -> some View {
        if index < accounts.count {
            let account = accounts[index]
            let isSelected = viewModel.selectedAccountID == account.persistentModelID

            AccountCardView(
                account: account,
                currentBalance: currentBalance(for: account),
                isSelected: isSelected,
                onEditTapped: {
                    onEditAccount(account)
                }
            )
            .onTapGesture {
                if viewModel.selectedAccountID == account.persistentModelID {
                    viewModel.selectedAccountID = nil
                } else {
                    viewModel.selectedAccountID = account.persistentModelID
                }
            }
        } else {
            AddAccountCardView {
                onAddAccount()
            }
        }
    }

    private func currentBalance(for account: Account) -> Double {
        let currentDecimal = AccountBalanceCalculator.currentBalance(
            for: account,
            allTransactions: transactions
        )
        return (currentDecimal as NSDecimalNumber).doubleValue
    }
}
