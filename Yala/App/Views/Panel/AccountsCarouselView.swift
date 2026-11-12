import SwiftData
import SwiftUI

struct AccountsCarouselView: View {
    @Environment(\.yalaTheme) private var theme
    /// Nombre de cada grupo por su zona, para las filas de la tarjeta «Grupos» (`providesGroupNames()` en la sección).
    @Environment(\.groupNameCatalog) private var groupNameCatalog
    let viewModel: PanelViewModel
    /// Una tarjeta por cuenta principal o suelta; las líneas en otra divisa van dentro de la suya.
    let orderedCards: [AccountCard<Account>]
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
        let allCards = orderedCards
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
                // Todas las tarjetas miden lo que la más alta (S12j, Jürgen 2026-10-27): la de varias divisas trae una
                // fila por divisa y el total, y a su lado las demás quedaban más bajas. El `HStack` toma el alto ideal
                // de la más alta (`fixedSize` vertical) y cada tarjeta se estira hasta él (`maxHeight: .infinity` en
                // `AccountCardView` y `AddAccountCardView`). No es `LazyHStack`: el perezoso no conoce el alto de las
                // que aún no ha montado. Son las cuentas del usuario, pocas.
                HStack(alignment: .top, spacing: DS.Spacing.md) {
                    ForEach(0..<totalCards, id: \.self) { index in
                        cardView(at: index, accounts: allCards)
                            .frame(width: cardWidth)
                            .frame(maxHeight: .infinity)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByFew))
            .scrollPosition(id: $leadingColumnIndex)
            .contentMargins(.horizontal, 0, for: .scrollContent)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { carouselWidth = $0 }
            // iPhone Duo cerrado: se funde contra la barra vertical en vez de cortarse en seco.
            .fadesTowardVerticalBar()

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

    // MARK: - Tarjeta «Grupos»

    /// Una fila por grupo con lo que aporta a las cuentas de sistema (card extra del 2026-11-03). Lo que no apunta a un
    /// grupo conocido se nombra con su cuenta («Grupos PEN»). En modo «solo gastos» la tarjeta enseña lo gastado por
    /// moneda, como antes: las filas por grupo son de saldo.
    private func groupRows(for card: AccountCard<Account>) -> [AccountCardView.GroupRow] {
        guard viewModel.isGroupsCard(card), !isExpensesOnlyMode else { return [] }
        let accountNameByCurrency = Dictionary(
            card.members.map { (normalizeCurrencyCode($0.currencyCode), $0.name) }, uniquingKeysWith: { first, _ in first })
        let rows: [AccountCardView.GroupRow] = viewModel.groupAccountLines.map { line in
            let code = normalizeCurrencyCode(line.currencyCode)
            let name = line.zoneID.flatMap { groupNameCatalog[$0] } ?? accountNameByCurrency[code] ?? code
            return .init(name: name, amount: .init(value: line.value, currencyCode: code))
        }
        // Las tarjetas del carrusel miden lo que la más alta: con muchos grupos, todas crecerían. Las tres mayores y
        // «y N más»; el total de abajo sigue sumándolo todo.
        guard rows.count > Self.maxGroupRows else { return rows }
        return Array(rows.prefix(Self.maxGroupRows))
            + [.init(name: L10n.Groups.Card.andMore(rows.count - Self.maxGroupRows), amount: nil)]
    }

    static let maxGroupRows = 3

    /// La tarjeta «Grupos» con varias cuentas (una por moneda) abre la ficha de la que se elija: la ficha es de UNA
    /// cuenta, y abrir la primera escondería las demás. Con una sola, el toque de siempre.
    @ViewBuilder
    private func openControl<Label: View>(
        for card: AccountCard<Account>, @ViewBuilder label: () -> Label
    ) -> some View {
        if viewModel.isGroupsCard(card), card.hasLines {
            Menu {
                ForEach(card.members, id: \.persistentModelID) { member in
                    Button(member.name) { onOpenAccount(member) }
                }
            } label: {
                label()
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
        } else {
            Button {
                onOpenAccount(card.head)
            } label: {
                label()
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Card View

    @ViewBuilder
    private func cardView(at index: Int, accounts cards: [AccountCard<Account>]) -> some View {
        if index < cards.count {
            let card = cards[index]
            let account = card.head
            // `contains` y no `== .first`: con dos cuentas filtradas desde
            // Registros el carrusel marcaba una sola, y el saldo ya suma las dos. Con líneas, manda la principal: filtrar
            // desde la tarjeta pone la principal y el filtro de sesión le añade sus líneas (entrega 3), así que el saldo
            // filtrado es el de la tarjeta entera. Marcarla por una línea elegida sola la enseñaría con un saldo parcial.
            let membership = viewModel.accountMembership(account.persistentModelID)

            openControl(for: card) {
                AccountCardView(
                    account: account,
                    currentBalance: isExpensesOnlyMode
                        ? accountPeriodExpenses[account.persistentModelID] ?? 0
                        : accountBalances[account.persistentModelID] ?? 0,
                    filterMembership: membership,
                    isExpensesOnlyMode: isExpensesOnlyMode,
                    periodName: viewModel.selectedPeriod.displayName,
                    lines: card.hasLines || viewModel.isGroupsCard(card)
                        ? viewModel.lineAmounts(for: card, isExpensesOnlyMode: isExpensesOnlyMode) : [],
                    groupRows: groupRows(for: card),
                    title: viewModel.isGroupsCard(card) ? L10n.Category.System.groups : nil
                )
            }
            .accessibilityIdentifier("panel_account_card_\(index)")
            .pointerHighlight(cornerRadius: DS.Radius.xl)
            // Clic secundario en el iPad, pulsación larga en el iPhone: filtrar y editar sin pasar por la ficha.
            .contextMenu {
                // Solo si la cuenta no está ya en el filtro (incluida u oculta): quitarla se hace desde su cápsula.
                // La tarjeta «Grupos» con varias cuentas no filtra desde aquí: filtraría una sola y el saldo filtrado
                // no sería el de la tarjeta.
                if PanelAccountCardLogic.showsFilterAction(membership: membership),
                   !(viewModel.isGroupsCard(card) && card.hasLines) {
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
