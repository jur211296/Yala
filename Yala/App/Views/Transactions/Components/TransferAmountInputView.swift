//
//  TransferAmountInputView.swift
//  Yala
//
//  Extracted from NewTransactionView - Transfer amount input with exchange rate
//

import SwiftUI

// MARK: - Transfer Amount Input View

struct TransferAmountInputView: View {
    @Bindable var viewModel: NewTransactionViewModel

    // Local state for destination amount text
    @State private var destinationAmountString: String = "0.00"

    // Local state for exchange rate display
    @State private var exchangeRateString: String = "1.0000"
    @State private var isRateInverted: Bool = false

    @ScaledMetric(relativeTo: .largeTitle) private var heroAmountSize: CGFloat = 48 // A11Y-DT: @ScaledMetric
    @ScaledMetric(relativeTo: .title) private var currencyLabelSize: CGFloat = 20

    // Focus states
    @FocusState private var isAmountFieldFocused: Bool
    @FocusState private var isDestFieldFocused: Bool
    @FocusState private var isRateFieldFocused: Bool

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            // Source Amount (Large)
            sourceAmountField

            // Arrow visual
            Image(systemName: "arrow.down")
                .font(DS.Typography.title)
                .foregroundStyle(.secondary.opacity(0.5))

            // Destination Amount (Large)
            destinationAmountField

            // Exchange Rate (Clean, Explicit, No Box)
            exchangeRateField
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    // MARK: - Source Amount Field

    private var sourceAmountField: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
            Text(viewModel.sourceAccount?.currencyCode ?? "")
                .font(.system(size: currencyLabelSize, weight: .medium, design: .rounded))
                .foregroundStyle(Color.hotPink.opacity(0.7))

            TextField("0.00", text: $viewModel.amountString)
                .accessibilityLabel(L10n.Accessibility.sourceAmount)
                .font(.system(size: heroAmountSize, weight: .bold, design: .rounded))
                .foregroundStyle(Color.hotPink)
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .focused($isAmountFieldFocused)
                .frame(minWidth: 100)
                .fixedSize(horizontal: true, vertical: false)
                .onChange(of: isAmountFieldFocused) { _, isFocused in
                    if isFocused
                        && (viewModel.amountString == "0" || viewModel.amountString == "0.00")
                    {
                        viewModel.amountString = ""
                    }
                    if !isFocused {
                        if viewModel.amountString.isEmpty {
                            viewModel.amountString = "0.00"
                        } else if let amount = Double(viewModel.amountString.replacing(",", with: ".")) {
                            viewModel.amountString = String(format: "%.2f", amount)
                        }
                    }
                }
                .onChange(of: viewModel.amountString) { _, newValue in
                    let filtered = filterAmountInput(newValue)
                    if filtered != newValue {
                        viewModel.amountString = filtered
                    }
                }
        }
    }

    // MARK: - Destination Amount Field

    private var destinationAmountField: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
            Text(viewModel.destinationAccount?.currencyCode ?? "")
                .font(.system(size: currencyLabelSize, weight: .medium, design: .rounded))
                .foregroundStyle(Color.electricIndigo.opacity(0.7))

            TextField("0.00", text: $destinationAmountString)
                .accessibilityLabel(L10n.Accessibility.destinationAmount)
                .font(.system(size: heroAmountSize, weight: .bold, design: .rounded))
                .foregroundStyle(Color.electricIndigo)
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .focused($isDestFieldFocused)
                .frame(minWidth: 100)
                .fixedSize(horizontal: true, vertical: false)
                .onAppear {
                    destinationAmountString = String(
                        format: "%.2f", viewModel.destinationAmount)
                }
                .onChange(of: isDestFieldFocused) { _, isFocused in
                    // Same clear-on-focus behavior as Source Amount
                    if isFocused
                        && (destinationAmountString == "0.00" || destinationAmountString == "0")
                    {
                        destinationAmountString = ""
                    }
                    // Format on blur
                    if !isFocused {
                        if destinationAmountString.isEmpty {
                            destinationAmountString = "0.00"
                        } else if let amount = Double(
                            destinationAmountString.replacing(",", with: "."))
                        {
                            destinationAmountString = String(format: "%.2f", amount)
                        }
                    }
                }
                .onChange(of: viewModel.destinationAmount) { _, newValue in
                    // Only update string if USER is NOT editing it
                    if !isDestFieldFocused {
                        destinationAmountString = String(format: "%.2f", newValue)
                    }
                }
                .onChange(of: destinationAmountString) { _, newValue in
                    // Only sync to model if USER IS editing it
                    if isDestFieldFocused {
                        let filtered = filterAmountInput(newValue)
                        if filtered != newValue {
                            destinationAmountString = filtered
                        }

                        if let amount = Double(
                            filtered.replacing(",", with: ".")), amount > 0
                        {
                            viewModel.destinationAmount = amount
                            viewModel.updateExchangeRateFromDestination()

                            isRateInverted =
                                viewModel.exchangeRate < 1.0 && viewModel.exchangeRate > 0
                            let displayRate =
                                isRateInverted
                                ? (1.0 / viewModel.exchangeRate) : viewModel.exchangeRate
                            exchangeRateString = String(format: "%.4f", displayRate)
                        }
                    }
                }
        }
    }

    // MARK: - Exchange Rate Field

    private var exchangeRateField: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
            if let source = viewModel.sourceAccount, let dest = viewModel.destinationAccount {
                // Explicit label format: "1 DEST ="
                Text("1 \(isRateInverted ? dest.currencyCode : source.currencyCode) =")
                    .font(DS.Typography.label)
                    .foregroundStyle(.secondary)

                TextField("Rate", text: $exchangeRateString)
                    .accessibilityLabel(L10n.Accessibility.exchangeRate)
                    .font(DS.Typography.label)
                    .foregroundStyle(.primary)
                    .keyboardType(.decimalPad)
                    .focused($isRateFieldFocused)  // Bind focus
                    .fixedSize(horizontal: true, vertical: false)
                    .multilineTextAlignment(.leading)  // Align with label

                // Trailing currency code for completeness: "X SOURCE"
                Text(isRateInverted ? source.currencyCode : dest.currencyCode)
                    .font(DS.Typography.label)
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: exchangeRateString) { _, newValue in
            // Only sync to model if USER IS editing it
            if isRateFieldFocused {
                if let rateInput = Double(newValue.replacing(",", with: ".")),
                    rateInput > 0
                {
                    let internalRate = isRateInverted ? (1.0 / rateInput) : rateInput
                    viewModel.exchangeRate = internalRate
                    viewModel.updateDestinationAmount()
                }
            }
        }
        .onChange(of: viewModel.exchangeRate) { _, newRate in
            // Sync from model if USER is NOT editing it
            if !isRateFieldFocused {
                isRateInverted = newRate < 1.0 && newRate > 0
                let displayRate = isRateInverted ? (1.0 / newRate) : newRate
                exchangeRateString = String(format: "%.4f", displayRate)
            }
        }
        .onAppear {
            // Sync exchange rate from viewModel when view appears
            let rate = viewModel.exchangeRate
            isRateInverted = rate < 1.0 && rate > 0
            let displayRate = isRateInverted ? (1.0 / rate) : rate
            exchangeRateString = String(format: "%.4f", displayRate)
        }
    }

    // MARK: - Helper Methods

    private func filterAmountInput(_ input: String) -> String {
        AmountInputHelper.filterAmountInput(input)
    }
}
