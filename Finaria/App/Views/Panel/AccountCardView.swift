//
//  AccountCardView.swift
//  Finaria
//
//  Created by Finaria Refactoring.
//

import SwiftUI

// MARK: - Tarjeta de cuenta

// FIN-46: Tarjeta de cuenta mostrando el saldo actual
// No modificar sin aprobación explícita, ya que se reutiliza
// para validar visualmente el comportamiento de FIN-46.
struct AccountCardView: View {

    let account: Account
    /// Saldo actual de la cuenta en su moneda nativa, ya calculado externamente.
    let currentBalance: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: iconForAccount)
                .font(.title2)
                .padding(10)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.05))
                )
                .foregroundStyle(.primary)

            Text(account.name.uppercased())
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(
                "\(normalizeCurrencyCode(account.currencyCode)) \(formattedAmount(currentBalance))"
            )
            .font(.title3.weight(.bold))
        }
        .padding(16)
        .frame(width: 200, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.6), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 10)
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
            .frame(width: 200, height: 110)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.95))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}
