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
    /// «Iguales» de serie (UX 2.2 · L2-12): es lo común; antes abría en «Porcentaje».
    var splitType: SplitType = .equal
    var percentageText: String = ""
    var participantsText: String = ""
    var exactAmountText: String = ""
    var mySharesText: String = ""
    var totalSharesText: String = ""

    func reset() {
        totalAmountText = ""
        splitType = .equal
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
    /// La divisa del cálculo, siempre: la de la cuenta o la principal (UX 2.2 · L2-17). Símbolo o código según la
    /// preferencia de formato de moneda.
    let currencyCode: String
    @Bindable var fieldState: SplitCalculatorFieldState
    let onUseSplit: (Double, SplitType, Double, Double, Double?) -> Void
    let onDismiss: () -> Void

    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    private var currencySymbol: String? { appPreferences.currencyIdentifier(for: currencyCode) }

    private func format(_ value: Double) -> String {
        appPreferences.currency(value, currencyCode: currencyCode, forceFullPrecision: true)
    }

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
                    // Etiqueta corta (`shortName`, hecha para un selector segmentado): con el nombre largo, cuatro
                    // segmentos no caben y «Partes iguales» salía cortado («Partes igual…»). El nombre largo sigue en
                    // la ayuda de debajo. Auditoría UX 2.2, lote 2, B4.
                    Picker(L10n.Split.title, selection: $fieldState.splitType) {
                        ForEach(SplitType.allCases) { type in
                            Text(type.shortName).tag(type)
                                .accessibilityLabel(type.displayName)
                        }
                    }
                    .pickerStyle(.segmented)

                    // Dynamic inputs
                    dynamicInputs

                    // Percentage presets (only for percentage type)
                    if fieldState.splitType == .percentage {
                        percentagePresets
                    }

                    // Result: «Te toca pagar», la fórmula y la barra tú / los demás (L2-17).
                    if let result = calculatedResult {
                        resultCard(mine: result)
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
                    .accessibilityHint(calculatedResult == nil ? L10n.Accessibility.completeCalculation : "")
                    .accessibilityIdentifier("split_calc_use_button")
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.lg)
                .dismissKeyboardOnTap()
            }
            .scrollContentBackground(.hidden)
            .yalaScreenBackground(.subtle)
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

                Text(L10n.Split.sharesUnit(Int(fieldState.totalSharesText) ?? 0))
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
                .accessibilityIdentifier("split_calc_preset_\(value)")
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
                            .foregroundStyle(DS.Semantic.disabledForeground.opacity(DS.Opacity.overlay))
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

    // MARK: - Result (UX 2.2 · L2-17)

    /// «Te toca pagar» con el monto grande y con moneda; debajo, la barra de reparto («Tú S/ 40.00 · Los demás S/ 80.00»)
    /// y la fórmula del modo («S/ 120.00 ÷ 3 personas = S/ 40.00 cada una»). Antes, una fila «Tu parte 40.00». Sin
    /// nombres de personas (C no elegida) y sin brillo.
    private func resultCard(mine: Double) -> some View {
        let (myValue, divisor) = currentMyValueAndDivisor()
        let others = SplitSummaryLogic.othersAmount(total: totalAmount, mine: mine)
        let fraction = SplitSummaryLogic.myFraction(total: totalAmount, mine: mine)
        return VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
                Text(L10n.UXL2B.splitYouPay)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.primary)
                Spacer(minLength: DS.Spacing.sm)
                Text(format(mine))
                    .font(DS.Typography.title)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.emphasisPinkText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .contentTransition(.numericText())
                    .accessibilityIdentifier("split_calc_result")
            }

            SplitShareBar(fraction: fraction)
                .accessibilityHidden(true)

            HStack(spacing: DS.Spacing.sm) {
                Text(L10n.UXL2B.splitBarYou(format(mine)))
                    .foregroundStyle(Color.emphasisPinkText)
                Spacer(minLength: DS.Spacing.sm)
                Text(L10n.UXL2B.splitBarOthers(format(others)))
                    .foregroundStyle(.secondary)
            }
            .font(DS.Typography.caption)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("split_calc_bar_labels")

            Text(SplitSummaryLogic.formula(
                type: fieldState.splitType,
                total: totalAmount,
                mine: mine,
                myValue: myValue,
                divisor: divisor,
                format: format
            ))
            .font(DS.Typography.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("split_calc_formula")
        }
        .padding(DS.Spacing.lg)
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

/// La barra de reparto de «Mi parte»: tu tramo en rosa sólido y el de los demás en gris. Sin brillo ni degradado.
private struct SplitShareBar: View {
    let fraction: Double
    @ScaledMetric(relativeTo: .caption) private var height: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            let gap = DS.Spacing.xxs
            let usable = max(proxy.size.width - gap, 0)
            let mine = usable * fraction
            HStack(spacing: gap) {
                Capsule()
                    .fill(Color.hotPink)
                    .frame(width: max(mine, fraction > 0 ? height : 0))
                Capsule()
                    .fill(Color.secondary.opacity(0.3))
            }
        }
        .frame(height: height)
    }
}
