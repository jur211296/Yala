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

    let account: Account
    /// Saldo actual de la cuenta en su moneda nativa, ya calculado externamente.
    let currentBalance: Double

    /// Indica si esta tarjeta está seleccionada dentro del carrusel de cuentas.
    var isSelected: Bool

    /// Acción opcional para editar / configurar la cuenta asociada a esta tarjeta.
    /// Si es `nil`, no se muestra el botón de edición en la esquina superior derecha.
    var onEditTapped: (() -> Void)?

    init(
        account: Account,
        currentBalance: Double,
        isSelected: Bool = false,
        onEditTapped: (() -> Void)? = nil
    ) {
        self.account = account
        self.currentBalance = currentBalance
        self.isSelected = isSelected
        self.onEditTapped = onEditTapped
    }

    var body: some View {
        let backgroundColor: Color =
            isSelected
            ? Color(hex: account.colorHex)
            : theme.card.opacity(0.95)

        let foregroundColor: Color =
            isSelected ? Color.contrastingText(for: backgroundColor) : theme.primaryText
        let secondaryForeground: Color =
            isSelected ? foregroundColor.opacity(0.85) : theme.secondaryText
        let iconBackground =
            isSelected
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

                    Text(account.name)
                        .font(DS.Typography.labelSmall)
                        .foregroundStyle(secondaryForeground)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer(minLength: 0)
                }

                Spacer(minLength: 0)

                Text(
                    formattedAmount(currentBalance)
                )
                .font(DS.Typography.headline)
                .foregroundStyle(foregroundColor)
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
                        .foregroundStyle(isSelected ? Color.white : theme.primaryText)
                        .padding(DS.Spacing.xs)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(DS.Spacing.sm)
            }
        }
    }

    private var iconForAccount: String {
        account.iconName
    }

    private func formattedAmount(_ value: Double) -> String {
        YalaFormatter.currency(
            value: value, currencyCode: normalizeCurrencyCode(account.currencyCode))
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
