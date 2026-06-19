import SwiftData
import SwiftUI

struct AccountsCarouselView: View {
    @Environment(\.yalaTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass
    let viewModel: PanelViewModel
    let orderedAccounts: [Account]
    let accountBalances: [PersistentIdentifier: Double]
    let accountPeriodExpenses: [PersistentIdentifier: Double]
    var isExpensesOnlyMode: Bool = false
    let onAddAccount: () -> Void
    let onEditAccount: (Account) -> Void

    /// Local UI state — previously lived en `PanelViewModel.leadingColumnIndex`, pero mantenerlo
    /// en el VM compartido causaba re-render cross-cutting del Panel en cada snap horizontal.
    /// Al moverlo a @State local, sólo este carrusel re-renderea mientras el usuario scrollea.
    @State private var leadingColumnIndex: Int? = 0

    var body: some View {
        let allCards = orderedAccounts
        let totalCards = allCards.count + 1  // accounts + add button
        let cardsVisible = DS.Adaptive.isWideScreen(sizeClass) ? 4 : 2

        // Calculate page count: we show N cards at a time, scroll 1 at a time
        let pageCount = max(1, totalCards - (cardsVisible - 1))

        let currentPage: Int = {
            guard pageCount > 1 else { return 0 }
            let rawIndex = leadingColumnIndex ?? 0
            return max(0, min(pageCount - 1, rawIndex))
        }()

        VStack(spacing: DS.Spacing.sm) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: DS.Spacing.md) {
                    ForEach(0..<totalCards, id: \.self) { index in
                        cardView(at: index, accounts: allCards)
                            .containerRelativeFrame(
                                .horizontal,
                                count: cardsVisible,
                                spacing: DS.Spacing.md
                            )
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByFew))
            .scrollPosition(id: $leadingColumnIndex)
            .contentMargins(.horizontal, 0, for: .scrollContent)
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
                        ? accountPeriodExpenses[account.persistentModelID] ?? 0
                        : accountBalances[account.persistentModelID] ?? 0,
                    isSelected: isSelected,
                    isExcludeMode: viewModel.isExcludeMode,
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

}
