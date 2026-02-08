//
//  ExchangeRateInputView.swift
//  Yala
//
//  Created by Yala - New Transaction Form.
//

import SwiftUI

// MARK: - Exchange Rate Input View

/// Vista para editar tipo de cambio y monto destino en transferencias
struct ExchangeRateInputView: View {
    let sourceCurrency: String
    let destinationCurrency: String
    let sourceAmount: Double

    @Binding var exchangeRate: Double
    @Binding var destinationAmount: Double

    let onExchangeRateChanged: () -> Void
    let onDestinationAmountChanged: () -> Void

    @State private var exchangeRateText: String = ""
    @State private var destinationAmountText: String = ""
    @FocusState private var focusedField: Field?

    enum Field {
        case rate
        case amount
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tipo de cambio
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 28)

                Text(L10n.Settings.exchangeRate)
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer()

                HStack(spacing: DS.Spacing.xs) {
                    Text("1 \(sourceCurrency) =")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("0.00", text: $exchangeRateText)
                        .font(.subheadline.weight(.medium))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .focused($focusedField, equals: .rate)
                        .onChange(of: exchangeRateText) { _, newValue in
                            if let rate = Double(newValue.replacingOccurrences(of: ",", with: "."))
                            {
                                exchangeRate = rate
                                onExchangeRateChanged()
                            }
                        }

                    Text(destinationCurrency)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.FormRow.paddingV)
            .background(Color.yalaCard)

            SubsectionDivider()

            // Monto destino
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "banknote")
                    .font(DS.Typography.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 28)

                Text(L10n.Transaction.willReceive)
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer()

                HStack(spacing: DS.Spacing.xs) {
                    TextField("0.00", text: $destinationAmountText)
                        .font(.subheadline.weight(.medium))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                        .focused($focusedField, equals: .amount)
                        .onChange(of: destinationAmountText) { _, newValue in
                            if let amount = Double(
                                newValue.replacingOccurrences(of: ",", with: "."))
                            {
                                destinationAmount = amount
                                onDestinationAmountChanged()
                            }
                        }

                    Text(destinationCurrency)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.FormRow.paddingV)
            .background(Color.yalaCard)
        }
        .onAppear {
            updateTextFields()
        }
        .onChange(of: exchangeRate) { _, _ in
            if focusedField != .rate {
                updateTextFields()
            }
        }
        .onChange(of: destinationAmount) { _, _ in
            if focusedField != .amount {
                updateTextFields()
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(L10n.Action.done) {
                    focusedField = nil
                }
            }
        }
    }

    private func updateTextFields() {
        exchangeRateText = formatNumber(exchangeRate, decimals: 4)
        destinationAmountText = formatNumber(destinationAmount, decimals: 2)
    }

    private func formatNumber(_ value: Double, decimals: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = decimals
        return formatter.string(from: NSNumber(value: value)) ?? "0.00"
    }
}

#Preview {
    VStack {
        ExchangeRateInputView(
            sourceCurrency: "USD",
            destinationCurrency: "PEN",
            sourceAmount: 100,
            exchangeRate: .constant(3.72),
            destinationAmount: .constant(372),
            onExchangeRateChanged: {},
            onDestinationAmountChanged: {}
        )
    }
    .background(Color.yalaBackground)
    .padding()
}
