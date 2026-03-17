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
    let currencySymbol: String
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
                    // Total amount
                    VStack(spacing: DS.Spacing.none) {
                        calcRow(
                            label: L10n.Split.totalAmount,
                            text: $fieldState.totalAmountText,
                            field: .totalAmount,
                            isAmount: true
                        )
                    }
                    .background(.thCard)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))

                    // Split type picker
                    Picker(L10n.Split.title, selection: $fieldState.splitType) {
                        ForEach(SplitType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    // Dynamic inputs
                    VStack(spacing: DS.Spacing.none) {
                        dynamicInputs
                    }
                    .background(.thCard)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))

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
            calcRow(
                label: L10n.Split.percentage,
                text: $fieldState.percentageText,
                field: .percentage,
                isAmount: true
            )

        case .equal:
            calcRow(
                label: L10n.Split.people,
                text: $fieldState.participantsText,
                field: .participants,
                isAmount: false
            )

        case .exact:
            calcRow(
                label: L10n.Split.yourPart,
                text: $fieldState.exactAmountText,
                field: .exactAmount,
                isAmount: true
            )

        case .shares:
            calcRow(
                label: L10n.Split.yourShares,
                text: $fieldState.mySharesText,
                field: .myShares,
                isAmount: false
            )
            SubsectionDivider()
            calcRow(
                label: L10n.Split.totalShares,
                text: $fieldState.totalSharesText,
                field: .totalShares,
                isAmount: false
            )
        }
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

    // MARK: - Reusable Components

    private func calcRow(
        label: String,
        text: Binding<String>,
        field: CalcField,
        isAmount: Bool
    ) -> some View {
        HStack {
            Text(label)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Spacer()

            HStack(spacing: DS.Spacing.xs) {
                if isAmount && field == .totalAmount {
                    Text(currencySymbol)
                        .font(DS.Typography.body)
                        .foregroundStyle(.secondary)
                }
                TextField("0", text: text)
                    .font(DS.Typography.headline)
                    .keyboardType(isAmount ? .decimalPad : .numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(minWidth: 80)
                    .focused($focusedField, equals: field)
                    .onChange(of: text.wrappedValue) { _, newValue in
                        let filtered = isAmount
                            ? AmountInputHelper.filterAmountInput(newValue)
                            : AmountInputHelper.filterIntegerInput(newValue)
                        if filtered != newValue {
                            text.wrappedValue = filtered
                        }
                    }
                if field == .percentage {
                    Text("%")
                        .font(DS.Typography.body)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(DS.Spacing.md)
    }

    private func resultRow(label: String, amount: Double) -> some View {
        HStack {
            Text(label)
                .font(DS.Typography.headline)
                .foregroundStyle(.primary)
            Spacer()
            Text("\(currencySymbol) \(YalaFormatter.number(value: amount, forceFullPrecision: true))")
                .font(DS.Typography.title2)
                .foregroundStyle(Color.hotPink)
        }
        .padding(DS.Spacing.md)
        .background(Color.hotPink.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }

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
