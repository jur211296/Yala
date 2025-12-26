//
//  AmountDisplayView.swift
//  Neto
//
//  Created by Neto - New Transaction Form.
//

import SwiftUI

// MARK: - Amount Display View

/// Vista del monto grande centrado con chip de divisa - tappable para editar
struct AmountDisplayView: View {
    let amount: String
    let currencyCode: String
    let color: Color
    let hasError: Bool
    let isEditing: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Button(action: onTap) {
                HStack(alignment: .center, spacing: 12) {
                    HStack(spacing: 4) {
                        Text(formattedAmount)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(color)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.3), value: amount)

                        // Cursor parpadeante cuando está editando
                        if isEditing {
                            Rectangle()
                                .fill(color)
                                .frame(width: 3, height: 40)
                                .opacity(cursorOpacity)
                                .animation(
                                    .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                                    value: isEditing)
                        }
                    }

                    CurrencyChip(currencyCode: currencyCode)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isEditing ? color.opacity(0.08) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isEditing ? color.opacity(0.3) : Color.clear, lineWidth: 2)
                )
            }
            .buttonStyle(.plain)

            if hasError {
                Text("Ingresa un monto mayor a 0")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: hasError)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isEditing)
    }

    @State private var cursorOpacity: Double = 1.0

    private var formattedAmount: String {
        let value = Double(amount) ?? 0
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: value)) ?? "0.00"
    }
}

// MARK: - Currency Chip

struct CurrencyChip: View {
    let currencyCode: String

    var body: some View {
        Text(currencyCode)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.secondary.opacity(0.12))
            )
            .foregroundStyle(.secondary)
    }
}

#Preview {
    VStack(spacing: 30) {
        AmountDisplayView(
            amount: "125.50",
            currencyCode: "PEN",
            color: Color.hotPink,
            hasError: false,
            isEditing: true,
            onTap: {}
        )

        AmountDisplayView(
            amount: "0",
            currencyCode: "USD",
            color: Color.neonCyan,
            hasError: true,
            isEditing: false,
            onTap: {}
        )
    }
    .padding()
    .background(Color.netoBackground)
}
