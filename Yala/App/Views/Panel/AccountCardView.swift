//
//  AccountCardView.swift
//  Yala
//
//  Created by Yala Refactoring.
//

import SwiftUI

// MARK: - Tarjeta de cuenta

struct AccountCardView: View {
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    let account: Account
    /// Saldo actual de la cuenta en su moneda nativa, ya calculado externamente.
    let currentBalance: Double

    /// Indica si esta tarjeta está seleccionada dentro del carrusel de cuentas.
    var isSelected: Bool

    /// En modo excluir, la cuenta seleccionada se oculta (visual dimmed + ícono minus).
    var isExcludeMode: Bool = false

    /// Acción opcional para editar / configurar la cuenta asociada a esta tarjeta.
    /// Si es `nil`, no se muestra el botón de edición en la esquina superior derecha.
    var onEditTapped: (() -> Void)?

    init(
        account: Account,
        currentBalance: Double,
        isSelected: Bool = false,
        isExcludeMode: Bool = false,
        onEditTapped: (() -> Void)? = nil
    ) {
        self.account = account
        self.currentBalance = currentBalance
        self.isSelected = isSelected
        self.isExcludeMode = isExcludeMode
        self.onEditTapped = onEditTapped
    }

    var body: some View {
        let isExcluded = isSelected && isExcludeMode
        let isHighlighted = isSelected && !isExcludeMode

        let backgroundColor: Color =
            isHighlighted
            ? Color(hex: account.colorHex)
            : theme.card.opacity(0.95)

        let foregroundColor: Color =
            isHighlighted ? Color.contrastingText(for: backgroundColor) : theme.primaryText
        let secondaryForeground: Color =
            isHighlighted ? foregroundColor.opacity(0.85) : theme.secondaryText
        let iconBackground =
            isHighlighted
            ? Color.white.opacity(DS.Opacity.subtle + 0.08)
            : Color.black.opacity(DS.Opacity.subtle / 2)

        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: iconForAccount)
                        .font(DS.Typography.body)
                        .padding(DS.Spacing.sm)
                        .background(
                            Circle()
                                .fill(iconBackground)
                        )
                        .foregroundStyle(foregroundColor)
                        .accessibilityHidden(true)

                    Text(account.name)
                        .font(DS.Typography.labelSmall)
                        .foregroundStyle(secondaryForeground)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer(minLength: 0)
                }

                Spacer(minLength: 0)

                AmountText(
                    value: currentBalance,
                    currencyCode: normalizeCurrencyCode(account.currencyCode),
                    size: .headline,
                    tint: .color(foregroundColor)
                )
            }
            .padding(DS.Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(DS.Colors.borderDark, lineWidth: 1)
            )

            if let onEditTapped {
                Button {
                    onEditTapped()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(DS.Typography.labelTiny)
                        .foregroundStyle(isHighlighted ? Color.white : theme.primaryText)
                        .padding(DS.Spacing.xs)
                        .glassEffect(.regular.interactive(), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.Accessibility.editAccount)
                .padding(DS.Spacing.sm)
            }

            // Exclude mode indicator
            if isExcluded {
                Image(systemName: "minus.circle.fill")
                    .font(DS.Typography.body)
                    .foregroundStyle(DS.Semantic.errorForeground)
                    .padding(DS.Spacing.sm)
                    .accessibilityHidden(true)
            }

            // A0-Bridge: badge "Sistema" para cuentas virtuales `Grupos [moneda]`.
            if account.isSystemAccount {
                Text(L10n.Account.System.badge)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(theme.secondaryText)
                    .padding(.horizontal, DS.Spacing.xs)
                    .padding(.vertical, 2)
                    .glassEffect(.regular, in: Capsule())
                    .padding(DS.Spacing.sm)
                    .accessibilityLabel(L10n.Account.System.badge)
            }
        }
        .opacity(isExcluded ? 0.5 : 1.0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.Accessibility.accountCard(account.name, formattedAmount(currentBalance)))
    }

    private var iconForAccount: String {
        account.iconName
    }

    private func formattedAmount(_ value: Double) -> String {
        appPreferences.currency(value, currencyCode: normalizeCurrencyCode(account.currencyCode))
    }

}

// MARK: - Tarjeta para agregar cuenta

struct AddAccountCardView: View {

    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "plus")
                    .font(DS.Typography.title)
                    .foregroundStyle(.thPrimaryText)

                Text(L10n.Account.addAccount)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thPrimaryText)
            }
            .frame(maxWidth: .infinity, minHeight: 96)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(.thCard.opacity(0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(DS.Colors.borderDark, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
