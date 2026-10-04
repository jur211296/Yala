import SwiftData
import SwiftUI

struct AccountsCarouselView: View {
    @Environment(\.yalaTheme) private var theme
    let viewModel: PanelViewModel
    let orderedAccounts: [Account]
    let accountBalances: [PersistentIdentifier: Double]
    let accountPeriodExpenses: [PersistentIdentifier: Double]
    var isExpensesOnlyMode: Bool = false
    let onAddAccount: () -> Void
    let onEditAccount: (Account) -> Void
    /// El toque abre la ficha de la cuenta. Antes filtraba el Panel; filtrar vive ahora en la ficha, en el botón de
    /// filtros de la toolbar y en el menú contextual de abajo.
    let onOpenAccount: (Account) -> Void

    /// Local UI state — previously lived en `PanelViewModel.leadingColumnIndex`, pero mantenerlo
    /// en el VM compartido causaba re-render cross-cutting del Panel en cada snap horizontal.
    /// Al moverlo a @State local, sólo este carrusel re-renderea mientras el usuario scrollea.
    @State private var leadingColumnIndex: Int? = 0

    /// Ancho del carrusel: de él sale el ancho de cada tarjeta (`PanelAccountCardLogic.cardWidth`). En una ventana
    /// ancha «Tus finanzas» va en la columna derecha de la cabecera del Panel (`HeaderBandLayout`), así que lo que
    /// cuenta es lo que mide aquí, no el size class.
    @State private var carouselWidth: CGFloat = 0

    var body: some View {
        let allCards = orderedAccounts
        let totalCards = allCards.count + 1  // accounts + add button
        let cardWidth = PanelAccountCardLogic.cardWidth(containerWidth: carouselWidth)

        // Se ve una tarjeta y asoma la siguiente, y se avanza de una en una: en la última parada caben las dos
        // últimas, así que hay una página menos que tarjetas.
        let pageCount = max(1, totalCards - 1)

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
                            .frame(width: cardWidth)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByFew))
            .scrollPosition(id: $leadingColumnIndex)
            .contentMargins(.horizontal, 0, for: .scrollContent)
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
                onOpenAccount(account)
            } label: {
                AccountCardView(
                    account: account,
                    currentBalance: isExpensesOnlyMode
                        ? accountPeriodExpenses[account.persistentModelID] ?? 0
                        : accountBalances[account.persistentModelID] ?? 0,
                    isSelected: isSelected,
                    isExcludeMode: viewModel.isExcludeMode,
                    isExpensesOnlyMode: isExpensesOnlyMode,
                    periodName: viewModel.selectedPeriod.displayName
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("panel_account_card_\(index)")
            .pointerHighlight(cornerRadius: DS.Radius.xl)
            // Clic secundario en el iPad, pulsación larga en el iPhone: filtrar y editar sin pasar por la ficha.
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
