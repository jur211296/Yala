//
//  AccountCardView.swift
//  Neto
//
//  Created by Neto Refactoring.
//

import SwiftUI

// MARK: - Tarjeta de cuenta

// FIN-46: Tarjeta de cuenta mostrando el saldo actual.
// FIN-56: Versión compacta para el carrusel 2x2 del Panel.
// No modificar sin aprobación explícita, ya que se reutiliza
// para validar visualmente el comportamiento de FIN-46 y FIN-56.
struct AccountCardView: View {

    let account: Account
    /// Saldo actual de la cuenta en su moneda nativa, ya calculado externamente.
    let currentBalance: Double

    /// Indica si esta tarjeta está seleccionada dentro del carrusel de cuentas (FIN-56).
    var isSelected: Bool

    /// Acción opcional para editar / configurar la cuenta asociada a esta tarjeta.
    /// Si es `nil`, no se muestra el botón de edición en la esquina superior derecha.
    var onEditTapped: (() -> Void)?

    // FIN-56: Inicializador explícito para permitir pasar `isSelected` y la acción
    // de edición desde PanelView u otras vistas.
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
        // FIN-56: Tarjeta compacta para el carrusel 2x2 del Panel.
        let backgroundColor =
            isSelected
            ? Color(hex: account.colorHex)
            : Color.netoCard.opacity(0.95)

        let foregroundColor: Color =
            isSelected ? Color.contrastingText(for: backgroundColor) : Color.netoPrimaryText
        let secondaryForeground: Color =
            isSelected ? foregroundColor.opacity(0.85) : Color.netoSecondaryText
        let iconBackground =
            isSelected
            ? Color.white.opacity(DS.Opacity.subtle + 0.08)
            : Color.black.opacity(DS.Opacity.subtle / 2)

        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: iconForAccount)
                        .font(.body)
                        .padding(DS.Spacing.sm)
                        .background(
                            Circle()
                                .fill(iconBackground)
                        )
                        .foregroundStyle(foregroundColor)

                    Text(account.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(secondaryForeground)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer(minLength: 0)
                }

                Spacer(minLength: 0)

                Text(
                    formattedAmount(currentBalance)
                )
                .font(.headline.weight(.bold))
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
                    .stroke(Color.primary.opacity(0.06), lineWidth: 0.8)
            )

            if let onEditTapped {
                Button {
                    onEditTapped()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isSelected ? Color.white : Color.netoPrimaryText)
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
        NetoFormatter.currency(
            value: value, currencyCode: normalizeCurrencyCode(account.currencyCode))
    }

    // Helpers locally defined to resolve scope issues
    private func normalizeCurrencyCode(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "PEN" }

        let upper = trimmed.uppercased()
        switch upper {
        case "PEN", "SOL", "SOLES", "S/", "S/.", "S/. ": return "PEN"
        case "USD", "US$", "US DOLLAR", "$", "$USD", "USD$": return "USD"
        case "EUR", "€", "EURO": return "EUR"
        default: return "PEN"
        }
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
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Color.netoPrimaryText)

                Text(L10n.Account.addAccount)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Color.netoPrimaryText)
            }
            .frame(maxWidth: .infinity, minHeight: 96)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(Color.netoCard.opacity(0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }
}
