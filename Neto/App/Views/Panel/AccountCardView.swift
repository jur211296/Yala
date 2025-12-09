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
        // Estado visual:
        // - Gris claro cuando no está seleccionada.
        // - Fondo con el color de la cuenta cuando está seleccionada.
        let backgroundColor =
            isSelected
            ? Color(hex: account.colorHex)
            : Color.white.opacity(0.95)

        let foregroundColor: Color = isSelected ? .white : .primary
        let secondaryForeground: Color = isSelected ? Color.white.opacity(0.85) : .secondary
        let iconBackground =
            isSelected
            ? Color.white.opacity(0.18)
            : Color.black.opacity(0.05)

        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: iconForAccount)
                        .font(.body)
                        .padding(8)
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
                    "\(normalizeCurrencyCode(account.currencyCode)) \(formattedAmount(currentBalance))"
                )
                .font(.title3.weight(.bold))
                .foregroundStyle(foregroundColor)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 0.8)
            )

            if let onEditTapped {
                Button {
                    onEditTapped()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .padding(6)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(8)
            }
        }
    }

    private var iconForAccount: String {
        displayIconName(for: account)
    }

    private func formattedAmount(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "0.00"
    }

}

// MARK: - Tarjeta para agregar cuenta

struct AddAccountCardView: View {

    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            VStack(spacing: 12) {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("Agregar cuenta")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, minHeight: 96)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }
}
