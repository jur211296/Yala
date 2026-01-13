//
//  TransactionAmountInputView.swift
//  Neto
//
//  Extracted from NewTransactionView - Amount input field for standard transactions
//

import SwiftUI

// MARK: - Transaction Amount Input View

struct TransactionAmountInputView: View {
    @Binding var amountText: String
    let transactionType: TransactionType
    let currencyCode: String
    let onCurrencyTap: () -> Void

    @FocusState private var isAmountFocused: Bool

    var body: some View {
        VStack(spacing: 16) {
            // Currency selector
            Button {
                onCurrencyTap()
            } label: {
                HStack(spacing: 6) {
                    Text(currencyCode)
                        .font(.headline.weight(.semibold))

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.netoCard))
            }
            .buttonStyle(.plain)

            // Amount display
            HStack(spacing: 4) {
                Text(transactionType == .expense ? "-" : "+")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(transactionType.color)

                TextField("0", text: $amountText)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(transactionType.color)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .focused($isAmountFocused)
                    .frame(maxWidth: 200)
            }
        }
        .padding(.top, 24)
        .onAppear {
            isAmountFocused = true
        }
    }
}
