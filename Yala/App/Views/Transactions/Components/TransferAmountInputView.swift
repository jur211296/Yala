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
    @Environment(AppPreferences.self) private var appPreferences

    // Local state for destination amount text. Vacío = el «0.00» gris de ejemplo (UX 2.2 · L2-16).
    @State private var destinationAmountString: String = ""

    @ScaledMetric(relativeTo: .largeTitle) private var heroAmountSize: CGFloat = 48 // A11Y-DT: @ScaledMetric
    @ScaledMetric(relativeTo: .title) private var currencyLabelSize: CGFloat = 20

    // Focus states
    @FocusState private var isAmountFieldFocused: Bool
    @FocusState private var isDestFieldFocused: Bool

    /// Símbolo o código según la preferencia de formato de moneda (UX 2.2 · L2-18): antes, siempre el código.
    private func currencyLabel(_ account: Account?) -> String {
        guard let account else { return "" }
        return appPreferences.currencyIdentifier(for: account.currencyCode)
    }

    private static func isEmptyAmount(_ text: String) -> Bool {
        text.isEmpty || text == "0" || text == "0.00" || text == "0,00"
    }

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
    }

    // MARK: - Source Amount Field

    private var sourceAmountField: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
            Text(currencyLabel(viewModel.sourceAccount))
                .font(.system(size: currencyLabelSize, weight: .medium, design: .rounded))
                .foregroundStyle(Color.hotPink.opacity(0.7))

            TextField("", text: $viewModel.amountString, prompt: Text(verbatim: "0.00").foregroundStyle(.tertiary))
                .accessibilityLabel(L10n.Accessibility.sourceAmount)
                .font(.system(size: heroAmountSize, weight: .bold, design: .rounded))
                .foregroundStyle(Color.hotPink)
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .focused($isAmountFieldFocused)
                .frame(minWidth: 100)
                .fixedSize(horizontal: true, vertical: false)
                .onChange(of: isAmountFieldFocused) { _, isFocused in
                    if isFocused && Self.isEmptyAmount(viewModel.amountString) {
                        viewModel.amountString = ""
                    }
                    if !isFocused {
                        if Self.isEmptyAmount(viewModel.amountString) {
                            // Vacío se queda vacío: el «0.00» gris es de ejemplo, no un monto escrito (L2-16).
                            viewModel.amountString = ""
                        } else {
                            let amount = AmountInputHelper.parseDecimal(viewModel.amountString)
                            viewModel.amountString = AmountInputHelper.formatWithGrouping(amount)
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
            Text(currencyLabel(viewModel.destinationAccount))
                .font(.system(size: currencyLabelSize, weight: .medium, design: .rounded))
                .foregroundStyle(Color.electricIndigo.opacity(0.7))

            TextField("", text: $destinationAmountString, prompt: Text(verbatim: "0.00").foregroundStyle(.tertiary))
                .accessibilityLabel(L10n.Accessibility.destinationAmount)
                .font(.system(size: heroAmountSize, weight: .bold, design: .rounded))
                .foregroundStyle(Color.electricIndigo)
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .focused($isDestFieldFocused)
                .frame(minWidth: 100)
                .fixedSize(horizontal: true, vertical: false)
                .onAppear {
                    destinationAmountString = Self.destinationText(viewModel.destinationAmount)
                }
                .onChange(of: isDestFieldFocused) { _, isFocused in
                    // Same clear-on-focus behavior as Source Amount
                    if isFocused && Self.isEmptyAmount(destinationAmountString) {
                        destinationAmountString = ""
                    }
                    // Format on blur
                    if !isFocused {
                        if Self.isEmptyAmount(destinationAmountString) {
                            destinationAmountString = ""
                        } else {
                            let amount = AmountInputHelper.parseDecimal(destinationAmountString)
                            destinationAmountString = AmountInputHelper.formatWithGrouping(amount)
                        }
                    }
                }
                .onChange(of: viewModel.destinationAmount) { _, newValue in
                    // Only update string if USER is NOT editing it
                    if !isDestFieldFocused {
                        destinationAmountString = Self.destinationText(newValue)
                    }
                }
                .onChange(of: destinationAmountString) { _, newValue in
                    // Only sync to model if USER IS editing it
                    if isDestFieldFocused {
                        let filtered = filterAmountInput(newValue)
                        if filtered != newValue {
                            destinationAmountString = filtered
                        }

                        let amount = AmountInputHelper.parseDecimal(filtered)
                        if amount > 0
                        {
                            viewModel.destinationAmount = amount
                            viewModel.updateExchangeRateFromDestination()
                        }
                    }
                }
        }
    }

    // MARK: - Exchange Rate Field

    /// La cápsula con lápiz y «Tipo de cambio de hoy · tócalo si tu banco usó otro» (UX 2.2 · L2-18), el mismo
    /// componente que el gasto en otra divisa (L2-11). Editar la tasa recalcula el destino, como antes.
    @ViewBuilder
    private var exchangeRateField: some View {
        if let source = viewModel.sourceAccount, let dest = viewModel.destinationAccount {
            ExchangeRateCapsule(
                caption: L10n.UXL2B.rateWithHint(ExchangeRateCaptionLogic.caption(for: viewModel.transactionDate)),
                fromCurrency: source.currencyCode,
                toCurrency: dest.currencyCode,
                rate: viewModel.exchangeRate
            ) { newRate in
                viewModel.exchangeRate = newRate
                viewModel.isExchangeRateManual = true
                viewModel.updateDestinationAmount()
            }
        }
    }

    /// El destino como texto: vacío si es 0 (el «0.00» gris de ejemplo).
    private static func destinationText(_ amount: Double) -> String {
        amount > 0 ? AmountInputHelper.formatWithGrouping(amount) : ""
    }

    // MARK: - Helper Methods

    private func filterAmountInput(_ input: String) -> String {
        AmountInputHelper.filterAmountInput(input)
    }
}
