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
    @Environment(CurrencyConverter.self) private var currencyConverter
    @Environment(\.yalaTheme) private var theme

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
    }

    // MARK: - Chip de cuenta

    private func chip(for card: AccountCard<Account>, index: Int) -> some View {
        let account = card.head
        // Manda la principal, como en la tarjeta del carrusel (`AccountsCarouselView`).
        let isSelected = viewModel.selectedAccountIDs.contains(account.persistentModelID)
        let style = PanelAccountCardLogic.style(isSelected: isSelected, isExcludeMode: viewModel.isExcludeMode)
        let color = account.isSystemAccount ? Color(.systemGray) : Color(hex: account.colorHex)
        let isFilled = style == .tinted
        let foreground = isFilled ? Color.contrastingText(for: color) : theme.primaryText
        let raw = isExpensesOnlyMode
            ? viewModel.accountPeriodExpenses[account.persistentModelID] ?? 0
            : viewModel.accountBalances[account.persistentModelID] ?? 0
        let amount = chipAmount(card: card, singleValue: raw)
        let shown = PanelAccountCardLogic.displayedValue(amount.value, kind: amount.kind)
        let currency = amount.currencyCode

        return Button {
            onOpenAccount(account)
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: account.iconName)
                    .font(DS.Typography.caption)
                    .foregroundStyle(Color.contrastingText(for: color))
                    .frame(width: DS.Icon.badgeSmall, height: DS.Icon.badgeSmall)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                            .fill(isFilled ? Color.black.opacity(0.18) : color)
                    )
                    .accessibilityHidden(true)
                Text(account.name)
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
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(
            account: account, kind: amount.kind, shown: shown, currency: currency,
            isApproximate: amount.isConverted, isFiltering: isFilled))
        .accessibilityAddTraits(isFilled ? .isSelected : [])
        .accessibilityIdentifier("panel_account_chip_\(index)")
        .pointerHighlight(cornerRadius: nil)
        .contextMenu {
            if PanelAccountCardLogic.showsFilterAction(isSelected: isSelected, isExcludeMode: viewModel.isExcludeMode) {
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
        let amount = appPreferences.currency(shown, currencyCode: currency)
        var text = "\(account.name). \(label): \(isApproximate ? "≈ " : "")\(amount)"
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

    // MARK: - Agregar

    private var addChip: some View {
        Button(action: onAddAccount) {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "plus")
                    .font(DS.Typography.caption)
                    .fontWeight(.bold)
                    .accessibilityHidden(true)
                Text(L10n.PanelAccountCard.addChip)
                    .font(DS.Typography.subheadlineEmphasized)
                    .lineLimit(1)
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(Capsule().fill(Color.selectedIndigoFill))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.Account.new)
        .accessibilityIdentifier("panel_account_chip_add")
        .pointerHighlight(cornerRadius: nil)
    }
}
