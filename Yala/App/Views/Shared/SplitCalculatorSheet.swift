//
//  SplitCalculatorSheet.swift
//  Yala
//
//  Split calculator sheet for computing the user's portion of a shared expense.
//

import SwiftUI

// MARK: - Field State (persists across sheet open/close)

@MainActor @Observable
final class SplitCalculatorFieldState {
    var totalAmountText: String = ""
    var splitType: SplitType = .percentage
    var percentageText: String = ""
    var participantsText: String = ""
    var exactAmountText: String = ""
    var mySharesText: String = ""
    var totalSharesText: String = ""

    func reset() {
        totalAmountText = ""
        splitType = .percentage
        percentageText = ""
        participantsText = ""
        exactAmountText = ""
        mySharesText = ""
        totalSharesText = ""
    }

    func prefill(totalAmount: Double, splitType: SplitType, myValue: Double, divisor: Double?) {
        self.totalAmountText = formatForField(totalAmount)
        self.splitType = splitType
        switch splitType {
        case .percentage:
            percentageText = formatForField(myValue)
        case .equal:
            participantsText = String(Int(myValue))
        case .exact:
            exactAmountText = formatForField(myValue)
        case .shares:
            mySharesText = String(Int(myValue))
            if let d = divisor {
                totalSharesText = String(Int(d))
            }
        }
    }

    func prefillTotal(_ amount: Double) {
        guard amount > 0 else { return }
        totalAmountText = formatForField(amount)
    }

    private func formatForField(_ value: Double) -> String {
        if value == value.rounded() && value > 0 {
            return String(Int(value))
        }
        return String(format: "%.2f", value)
    }
}

// MARK: - Split Calculator Sheet

struct SplitCalculatorSheet: View {
    let currencySymbol: String?
    @Bindable var fieldState: SplitCalculatorFieldState
    let onUseSplit: (Double, SplitType, Double, Double, Double?) -> Void
    let onDismiss: () -> Void

    @Environment(\.yalaTheme) private var theme

    @FocusState private var focusedField: CalcField?

    private enum CalcField: Hashable {
        case totalAmount
        case percentage
        case participants
        case exactAmount
        case myShares
        case totalShares
    }

    // MARK: - Computed

    private var totalAmount: Double {
        AmountInputHelper.parseDecimal(fieldState.totalAmountText)
    }

    private func currentMyValueAndDivisor() -> (myValue: Double, divisor: Double?) {
        switch fieldState.splitType {
        case .percentage:
            return (AmountInputHelper.parseDecimal(fieldState.percentageText), 100)
        case .equal:
            let v = AmountInputHelper.parseDecimal(fieldState.participantsText)
            return (v, v)
        case .exact:
            return (AmountInputHelper.parseDecimal(fieldState.exactAmountText), nil)
        case .shares:
            return (AmountInputHelper.parseDecimal(fieldState.mySharesText),
                    AmountInputHelper.parseDecimal(fieldState.totalSharesText))
        }
    }

    private var calculatedResult: Double? {
        let (myValue, divisor) = currentMyValueAndDivisor()
        return SplitCalculator.calculate(
            totalAmount: totalAmount,
            splitType: fieldState.splitType,
            myValue: myValue,
            divisor: divisor
        )
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    // Total amount — large card
                    amountCard(
                        label: L10n.Split.totalAmount,
                        text: $fieldState.totalAmountText,
                        field: .totalAmount,
                        prefix: currencySymbol,
                        suffix: nil,
                        isAmount: true
                    )

                    // Split type picker
                    Picker(L10n.Split.title, selection: $fieldState.splitType) {
                        ForEach(SplitType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    // Dynamic inputs
                    dynamicInputs

                    // Percentage presets (only for percentage type)
                    if fieldState.splitType == .percentage {
                        percentagePresets
                    }

                    // Result
                    if let result = calculatedResult {
                        resultRow(label: L10n.Split.yourPortion, amount: result)
                    }

                    // Tip
                    tipView(text: fieldState.splitType.hintText)

                    // Use amount button
                    YalaPrimaryButton(L10n.Split.useAmount) {
                        guard let result = calculatedResult else { return }
                        let (myValue, divisor) = currentMyValueAndDivisor()
                        onUseSplit(result, fieldState.splitType, totalAmount, myValue, divisor)
                        onDismiss()
                    }
                    .disabled(calculatedResult == nil)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.lg)
            }
            .background(.thBackground)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(L10n.Split.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        onDismiss()
                    }
                }
            }
        }
    }

    // MARK: - Dynamic Inputs

    @ViewBuilder
    private var dynamicInputs: some View {
        switch fieldState.splitType {
        case .percentage:
            amountCard(
                label: L10n.Split.percentage,
                text: $fieldState.percentageText,
                field: .percentage,
                prefix: nil,
                suffix: "%",
                isAmount: true
            )

        case .equal:
            amountCard(
                label: L10n.Split.people,
                text: $fieldState.participantsText,
                field: .participants,
                prefix: nil,
                suffix: nil,
                isAmount: false
            )

        case .exact:
            amountCard(
                label: L10n.Split.yourPart,
                text: $fieldState.exactAmountText,
                field: .exactAmount,
                prefix: currencySymbol,
                suffix: nil,
                isAmount: true
            )

        case .shares:
            sharesInput
        }
    }

    // MARK: - Shares Input (inline: "Pagas [X] de [Y] partes")

    private var sharesInput: some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                Text(L10n.Split.sharesYouPay)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)

                TextField("0", text: $fieldState.mySharesText)
                    .font(DS.Typography.title2)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 56)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.sm)
                            .fill(Color.hotPink.opacity(0.08))
                    )
                    .focused($focusedField, equals: .myShares)
                    .onChange(of: fieldState.mySharesText) { _, newValue in
                        let filtered = AmountInputHelper.filterIntegerInput(newValue)
                        if filtered != newValue {
                            fieldState.mySharesText = filtered
                        }
                    }

                Text(L10n.Split.sharesOf)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)

                TextField("0", text: $fieldState.totalSharesText)
                    .font(DS.Typography.title2)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 56)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.sm)
                            .fill(Color.secondary.opacity(0.08))
                    )
                    .focused($focusedField, equals: .totalShares)
                    .onChange(of: fieldState.totalSharesText) { _, newValue in
                        let filtered = AmountInputHelper.filterIntegerInput(newValue)
                        if filtered != newValue {
                            fieldState.totalSharesText = filtered
                        }
                    }

                Text(L10n.Split.sharesParts)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(DS.Spacing.lg)
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }

    // MARK: - Percentage Presets

    private var percentagePresets: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach([50, 60, 70, 80], id: \.self) { value in
                Button {
                    fieldState.percentageText = "\(value)"
                } label: {
                    Text("\(value)%")
                        .font(DS.Typography.label)
                        .foregroundStyle(
                            fieldState.percentageText == "\(value)"
                                ? Color.white
                                : Color.secondary
                        )
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(
                            Capsule().fill(
                                fieldState.percentageText == "\(value)"
                                    ? Color.hotPink
                                    : Color.secondary.opacity(0.1)
                            )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Amount Card (large input like account balance)

    private func amountCard(
        label: String,
        text: Binding<String>,
        field: CalcField,
        prefix: String?,
        suffix: String?,
        isAmount: Bool
    ) -> some View {
        VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
            // Label
            Text(label)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)

            // Input
            HStack(spacing: DS.Spacing.xs) {
                Spacer()
                if let prefix {
                    Text(prefix)
                        .font(DS.Typography.title2)
                        .foregroundStyle(.secondary)
                }

                ZStack(alignment: .trailing) {
                    if text.wrappedValue.isEmpty {
                        Text("0")
                            .font(DS.Typography.largeTitle)
                            .foregroundStyle(.gray.opacity(0.4))
                    }
                    TextField("", text: text)
                        .font(DS.Typography.largeTitle)
                        .keyboardType(isAmount ? .decimalPad : .numberPad)
                        .multilineTextAlignment(.trailing)
                        .focused($focusedField, equals: field)
                        .onChange(of: text.wrappedValue) { _, newValue in
                            let filtered = isAmount
                                ? AmountInputHelper.filterAmountInput(newValue)
                                : AmountInputHelper.filterIntegerInput(newValue)
                            if filtered != newValue {
                                text.wrappedValue = filtered
                            }
                        }
                }

                if let suffix {
                    Text(suffix)
                        .font(DS.Typography.title2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(DS.Spacing.lg)
        .background(.thCard)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }

    // MARK: - Result Row

    private func resultRow(label: String, amount: Double) -> some View {
        HStack {
            Text(label)
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)
            Spacer()
            Text("\(currencySymbol.map { "\($0) " } ?? "")\(YalaFormatter.number(value: amount, forceFullPrecision: true))")
                .font(DS.Typography.title2)
                .foregroundStyle(Color.hotPink)
        }
        .padding(DS.Spacing.md)
        .background(Color.hotPink.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    // MARK: - Tip View

    private func tipView(text: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: "lightbulb.fill")
                .font(DS.Typography.body)
                .foregroundStyle(Color.hotPink)
                .accessibilityHidden(true)
            Text(text)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.hotPink.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
}
