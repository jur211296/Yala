//
//  PanelAccountChipsRow.swift
//  Yala
//
//  Las cuentas de «Tus finanzas» con la sección plegada (UX 2.2 · L3-9, variante 3 elegida por Jürgen el
//  2026-10-14): una fila de chips con nombre y saldo, y «Agregar» al final. Antes, plegada, la sección no enseñaba
//  ninguna cuenta y agregar una estaba al final del carrusel desplegado.
//
//  Tocar un chip abre la ficha, como la tarjeta; la pulsación larga ofrece filtrar y editar con las mismas reglas
//  que el carrusel. La cuenta que filtra va rellena de su color, como su tarjeta (L3-16).
//

import SwiftData
import SwiftUI

struct PanelAccountChipsRow: View {
    let viewModel: PanelViewModel
    /// Una por cuenta principal o suelta: una tarjeta con varias divisas es un chip, con su total en la preferida.
    let orderedCards: [AccountCard<Account>]
    let isExpensesOnlyMode: Bool
    let onAddAccount: () -> Void
    let onEditAccount: (Account) -> Void
    let onOpenAccount: (Account) -> Void

    @Environment(AppPreferences.self) private var appPreferences
    /// «Ocultar montos» del Panel (`AmountPrivacy`).
    @Environment(\.amountsHidden) private var amountsHidden
    @Environment(CurrencyConverter.self) private var currencyConverter
    @Environment(\.yalaTheme) private var theme

    /// El cuadrito del icono crece con el texto, con techo (pase de estrés 2.2, card fb1j). Con 24 pt fijos y el glifo en
    /// `caption`, a AX5 el glifo medía más que su marco y se salía de la cápsula por la izquierda, encima del nombre. A
    /// tamaño normal sigue midiendo `badgeSmall`.
    @ScaledMetric(relativeTo: .caption) private var scaledBadgeSide: CGFloat = DS.Icon.badgeSmall
    private var badgeSide: CGFloat { min(scaledBadgeSide, DS.Icon.badgeLarge) }
    /// El glifo deja de crecer en AX1 (~23 pt), que cabe en el techo del cuadrito (40 pt).
    private static let glyphMaxTypeSize = DynamicTypeSize.accessibility1

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                ForEach(Array(orderedCards.enumerated()), id: \.element.head.persistentModelID) { index, card in
                    chip(for: card, index: index)
                }
                addChip
            }
            .padding(.vertical, DS.Spacing.xxs)
        }
        .scrollClipDisabled()
        // iPhone Duo cerrado: se funde contra la barra vertical en vez de cortarse en seco.
        .fadesTowardVerticalBar()
    }

    // MARK: - Chip de cuenta

    private func chip(for card: AccountCard<Account>, index: Int) -> some View {
        let account = card.head
        // Manda la principal, como en la tarjeta del carrusel (`AccountsCarouselView`).
        let membership = viewModel.accountMembership(account.persistentModelID)
        let style = PanelAccountCardLogic.style(membership: membership)
        let color = account.isSystemAccount ? Color(.systemGray) : Color(hex: account.colorHex)
        let isFilled = style == .tinted
        let foreground = isFilled ? Color.contrastingText(for: color) : theme.primaryText
        let raw = isExpensesOnlyMode
            ? viewModel.accountPeriodExpenses[account.persistentModelID] ?? 0
            : viewModel.accountBalances[account.persistentModelID] ?? 0
        let amount = chipAmount(card: card, singleValue: raw)
        let shown = PanelAccountCardLogic.displayedValue(amount.value, kind: amount.kind)
        let currency = amount.currencyCode

        return openControl(for: card) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: account.iconName)
                    .font(DS.Typography.caption)
                    .dynamicTypeSize(...Self.glyphMaxTypeSize)
                    .foregroundStyle(Color.contrastingText(for: color))
                    .frame(width: badgeSide, height: badgeSide)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                            .fill(isFilled ? Color.black.opacity(0.18) : color)
                    )
                    .accessibilityHidden(true)
                // Card extra (2026-11-03): las cuentas de sistema van en un solo chip «Grupos», con su total.
                Text(viewModel.isGroupsCard(card) ? L10n.Category.System.groups : account.name)
                    .font(DS.Typography.subheadlineEmphasized)
                    .foregroundStyle(foreground)
                    .lineLimit(1)
                AmountText(
                    value: shown,
                    currencyCode: currency,
                    font: DS.Typography.subheadline,
                    secondaryFont: DS.Typography.captionSmall,
                    tint: .color(isFilled ? foreground.opacity(0.85) : theme.secondaryText),
                    isEstimate: amount.isConverted
                )
                if style == .excluded {
                    Image(systemName: "minus.circle.fill")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Semantic.errorForeground)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background {
                if isFilled {
                    Capsule().fill(color)
                }
            }
            .glassEffect(isFilled ? .identity : .regular.interactive(), in: Capsule())
            .contentShape(Capsule())
            .opacity(style == .excluded ? 0.5 : 1.0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(
            account: account, isGroupsCard: viewModel.isGroupsCard(card), kind: amount.kind, shown: shown, currency: currency,
            isApproximate: amount.isConverted, isFiltering: isFilled))
        .accessibilityAddTraits(isFilled ? .isSelected : [])
        .accessibilityIdentifier("panel_account_chip_\(index)")
        .pointerHighlight(cornerRadius: nil)
        .contextMenu {
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
    }

    private func accessibilityLabel(
        account: Account,
        isGroupsCard: Bool,
        kind: PanelAccountCardLogic.AmountKind,
        shown: Double,
        currency: String,
        isApproximate: Bool,
        isFiltering: Bool
    ) -> String {
        let label: String
        switch kind {
        case .balance: label = L10n.PanelAccountCard.balance
        case .toPay: label = L10n.PanelAccountCard.toPay
        case .spent: label = L10n.PanelAccountCard.spentInPeriod(viewModel.selectedPeriod.displayName)
        }
        let amount = AmountPrivacy.spoken(appPreferences.currency(shown, currencyCode: currency), hidden: amountsHidden)
        let name = isGroupsCard ? L10n.Category.System.groups : account.name
        var text = "\(name). \(label): \(isApproximate ? "≈ " : "")\(amount)"
        if isFiltering { text += ". \(L10n.PanelAccountCard.filtering)" }
        return text
    }

    /// Lo que enseña el chip: el importe de la cuenta en su divisa o, en una tarjeta con varias divisas, el total de sus
    /// líneas en la preferida (`AccountCardLogic.total`), con el rótulo de la tarjeta (`cardAmountKind`).
    private func chipAmount(
        card: AccountCard<Account>, singleValue: Double
    ) -> (value: Double, currencyCode: String, kind: PanelAccountCardLogic.AmountKind, isConverted: Bool) {
        let isCreditCard = AccountType(rawValue: card.head.type) == .creditCard
        guard card.hasLines else {
            let kind = PanelAccountCardLogic.amountKind(
                isExpensesOnlyMode: isExpensesOnlyMode, isCreditCard: isCreditCard, value: singleValue)
            return (singleValue, normalizeCurrencyCode(card.head.currencyCode), kind, false)
        }
        let lines = viewModel.lineAmounts(for: card, isExpensesOnlyMode: isExpensesOnlyMode).map {
            AccountCardLogic.LineAmount(value: $0.value, currencyCode: normalizeCurrencyCode($0.currencyCode))
        }
        let kind = PanelAccountCardLogic.cardAmountKind(lineKinds: lines.map {
            PanelAccountCardLogic.lineKind(isExpensesOnlyMode: isExpensesOnlyMode, isCreditCard: isCreditCard, value: $0.value)
        })
        let target = appPreferences.defaultCurrencyCode.rawValue
        let total = AccountCardLogic.total(lines, in: target) { value, code in
            let outcome = currencyConverter.convertCheckedWithLatestRate(Decimal(value), from: code, to: target)
            return (outcome.amount as NSDecimalNumber).doubleValue
        }
        return (total.value, target, kind, total.isConverted)
    }

    /// La tarjeta «Grupos» con varias cuentas abre la ficha de la que se elija (ver `AccountsCarouselView.openControl`).
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

    // MARK: - Agregar

    /// Misma pastilla que una cuenta (S12j, Jürgen 2026-10-27): el «+» ocupa el hueco del icono de cuenta, así que mide lo
    /// mismo, y lleva el mismo cristal. Antes era una cápsula morada rellena, más baja y de otra familia que las demás.
    private var addChip: some View {
        Button(action: onAddAccount) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "plus")
                    .font(DS.Typography.caption)
                    .fontWeight(.bold)
                    .dynamicTypeSize(...Self.glyphMaxTypeSize)
                    .frame(width: badgeSide, height: badgeSide)
                    .accessibilityHidden(true)
                Text(L10n.PanelAccountCard.addChip)
                    .font(DS.Typography.subheadlineEmphasized)
                    .lineLimit(1)
            }
            .foregroundStyle(.thAccentText)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .glassEffect(.regular.interactive(), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.Account.new)
        .accessibilityIdentifier("panel_account_chip_add")
        .pointerHighlight(cornerRadius: nil)
    }
}
