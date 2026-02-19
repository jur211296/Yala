//
//  TransactionAmountInputView.swift
//  Yala
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

    @ScaledMetric(relativeTo: .largeTitle) private var heroAmountSize: CGFloat = 48
    @FocusState private var isAmountFocused: Bool

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            // Currency selector
            Button {
                onCurrencyTap()
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Text(currencyCode)
                        .font(DS.Typography.headline)

                    Image(systemName: "chevron.down")
                        .font(DS.Typography.labelSmall)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, DS.FormRow.paddingV)
                .padding(.vertical, DS.Spacing.sm)
                .background(Capsule().fill(.thCard))
            }
            .buttonStyle(.plain)

            // Amount display
            HStack(spacing: DS.Spacing.xs) {
                Text(transactionType == .expense ? "-" : "+")
                    .font(.system(size: heroAmountSize, weight: .bold, design: .rounded))
                    .foregroundStyle(transactionType.color)

                TextField("0", text: $amountText)
                    .font(.system(size: heroAmountSize, weight: .bold, design: .rounded))
                    .foregroundStyle(transactionType.color)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .focused($isAmountFocused)
                    .frame(maxWidth: 200)
            }
        }
        .padding(.top, DS.Spacing.xxl)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .onAppear {
            isAmountFocused = true
        }
    }
}
