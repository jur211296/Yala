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

    /// Ancho del carrusel. En una ventana ancha «Tus finanzas» va en la columna derecha de la cabecera del Panel
    /// (`HeaderBandLayout`): con el size class solo saldrían cuatro tarjetas de ~110 pt en media pantalla.
    @State private var carouselWidth: CGFloat = 0

    /// Cuatro tarjetas a la vez solo en ancha y con sitio para cuatro de al menos 140 pt; si no, dos, como en iPhone.
    private static let fourCardsMinWidth: CGFloat = 4 * 140 + 3 * DS.Spacing.md

    var body: some View {
        let allCards = orderedAccounts
        let totalCards = allCards.count + 1  // accounts + add button
        let cardsVisible = DS.Adaptive.isWideScreen(sizeClass) && carouselWidth >= Self.fourCardsMinWidth ? 4 : 2

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
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { carouselWidth = $0 }

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
            // `contains` y no `== .first`: con dos cuentas filtradas desde
            // Registros el carrusel marcaba una sola, y el saldo ya suma las dos.
            let isSelected = viewModel.selectedAccountIDs.contains(account.persistentModelID)

            Button {
                if viewModel.isExcludeMode {
                    // La tarjeta atenuada dice "excluida": tocarla la devuelve al
                    // total, y tocar una normal la excluye. Reemplazar el filtro
                    // aquí convertía la cuenta excluida en la única incluida —el
                    // filtro inverso del que el usuario acababa de pedir.
                    if isSelected {
                        viewModel.selectedAccountIDs.remove(account.persistentModelID)
                    } else {
                        viewModel.selectedAccountIDs.insert(account.persistentModelID)
                    }
                } else if isSelected && viewModel.selectedAccountIDs.count == 1 {
                    viewModel.selectedAccountID = nil
                } else {
                    // Elegir ésta reemplaza el filtro; volver a tocarla lo limpia.
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
            .pointerHighlight(cornerRadius: DS.Radius.xl)
            // Clic secundario en el iPad, pulsación larga en el iPhone: lo mismo que el toque y que el botón de ajustes
            // de la tarjeta, que no existe en las cuentas de sistema.
            .contextMenu {
                // En modo exclusión el toque invierte su sentido; ahí «filtrar» confundiría, así que no se ofrece.
                if !isSelected && !viewModel.isExcludeMode {
                    Button(L10n.Keyboard.filterByAccount, systemImage: "line.3.horizontal.decrease.circle") {
                        viewModel.selectedAccountID = account.persistentModelID
                    }
                }
                if !account.isSystemAccount {
                    Button(L10n.Account.edit, systemImage: "slider.horizontal.3") {
                        onEditAccount(account)
                    }
                }
            }
        } else {
            AddAccountCardView {
                onAddAccount()
            }
        }
    }

}
