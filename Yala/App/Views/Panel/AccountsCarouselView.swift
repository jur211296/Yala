import SwiftData
import SwiftUI

struct AccountsCarouselView: View {
    @Environment(\.yalaTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Bindable var viewModel: PanelViewModel
    let orderedAccounts: [Account]
    let transactions: [TransactionItem]
    var isExpensesOnlyMode: Bool = false
    let onAddAccount: () -> Void
    let onEditAccount: (Account) -> Void

    var body: some View {
        let allCards = orderedAccounts
        let totalCards = allCards.count + 1  // accounts + add button
        let cardsVisible = DS.Adaptive.isWideScreen(sizeClass) ? 4 : 2

        // Calculate page count: we show N cards at a time, scroll 1 at a time
        let pageCount = max(1, totalCards - (cardsVisible - 1))

        let currentPage: Int = {
            guard pageCount > 1 else { return 0 }
            let rawIndex = viewModel.leadingColumnIndex ?? 0
            return max(0, min(pageCount - 1, rawIndex))
        }()

        VStack(spacing: DS.Spacing.sm) {
            GeometryReader { geo in
                let totalWidth = geo.size.width
                let spacing: CGFloat = DS.Spacing.md
                let cardWidth = (totalWidth - spacing * CGFloat(cardsVisible - 1)) / CGFloat(cardsVisible)

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
                HStack(spacing: DS.Spacing.xs) {
                    ForEach(0..<pageCount, id: \.self) { page in
                        Circle()
                            .fill(
                                page == currentPage
                                    ? theme.primaryText.opacity(0.3)
                                    : theme.secondaryText.opacity(0.2)
                            )
                            .frame(width: 6, height: 6)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityLabel(L10n.Accessibility.pageIndicator(currentPage + 1, pageCount))
            }
        }
    }

    // MARK: - Card View

    @ViewBuilder
    private func cardView(at index: Int, accounts: [Account]) -> some View {
        if index < accounts.count {
            let account = accounts[index]
            let isSelected = viewModel.selectedAccountID == account.persistentModelID

            Button {
                if viewModel.selectedAccountID == account.persistentModelID {
                    viewModel.selectedAccountID = nil
                } else {
                    viewModel.selectedAccountID = account.persistentModelID
                }
            } label: {
                AccountCardView(
                    account: account,
                    currentBalance: isExpensesOnlyMode
                        ? viewModel.expenseForPeriod(for: account, allTransactions: transactions)
                        : currentBalance(for: account),
                    isSelected: isSelected,
                    onEditTapped: {
                        onEditAccount(account)
                    }
                )
            }
            .buttonStyle(.plain)
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
