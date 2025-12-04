import SwiftData
import SwiftUI

struct AccountsCarouselView: View {
    @Bindable var viewModel: PanelViewModel
    let orderedAccounts: [Account]
    let transactions: [TransactionItem]
    let onAddAccount: () -> Void
    let onEditAccount: (Account) -> Void

    var body: some View {
        let accountsForGrid = orderedAccounts

        // Construimos la lista de "cards": primero todas las cuentas activas,
        // luego la tarjeta "Agregar cuenta" al final.
        let totalCards = accountsForGrid.count + 1
        let cardIndices = Array(0..<totalCards)

        // Agrupamos los índices en columnas (máximo 2 tarjetas por columna).
        let columns: [[Int]] = stride(from: 0, to: totalCards, by: 2).map { start in
            let end = min(start + 2, totalCards)
            return Array(cardIndices[start..<end])
        }

        let columnsCount = columns.count

        // Número lógico de "páginas" para el indicador
        let pageCount: Int = {
            switch columnsCount {
            case 0: return 1
            case 1, 2: return 1
            default: return max(columnsCount - 1, 1)
            }
        }()

        let pageIndices: [Int] = Array(0..<pageCount)

        let currentPage: Int = {
            guard pageCount > 1 else { return 0 }
            let rawIndex = viewModel.leadingColumnIndex ?? 0
            return max(0, min(pageCount - 1, rawIndex))
        }()

        VStack(spacing: 16) {
            GeometryReader { geo in
                let totalWidth = geo.size.width
                let spacing: CGFloat = 12
                let contentWidth = totalWidth
                let columnWidth = (contentWidth - spacing) / 2

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: spacing) {
                        ForEach(0..<columnsCount, id: \.self) { colIndex in
                            accountsColumnView(
                                indices: columns[colIndex],
                                accountsForGrid: accountsForGrid
                            )
                            .frame(width: columnWidth)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned)
                .scrollPosition(id: $viewModel.leadingColumnIndex)
                .frame(width: contentWidth, height: 210)
            }
            .frame(height: 210)

            if pageCount > 1 {
                HStack(spacing: 6) {
                    ForEach(pageIndices, id: \.self) { page in
                        Circle()
                            .fill(
                                page == currentPage
                                    ? Color.gray.opacity(0.9)
                                    : Color.gray.opacity(0.3)
                            )
                            .frame(width: 6, height: 6)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    @ViewBuilder
    private func accountsColumnView(
        indices: [Int],
        accountsForGrid: [Account]
    ) -> some View {
        VStack(spacing: 12) {
            if indices.indices.contains(0) {
                accountsCardView(
                    cardIndex: indices[0],
                    accountsForGrid: accountsForGrid
                )
            }
            if indices.indices.contains(1) {
                accountsCardView(
                    cardIndex: indices[1],
                    accountsForGrid: accountsForGrid
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func accountsCardView(
        cardIndex: Int,
        accountsForGrid: [Account]
    ) -> some View {
        if cardIndex < accountsForGrid.count {
            let account = accountsForGrid[cardIndex]
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
