//
//  BalanceCalculatorSheet.swift
//  Yala
//
//  Interactive balance calculator that adapts to account type and financial mindset.
//  Shared between OnboardingView and AccountFormView.
//

import SwiftUI

// MARK: - Field State (persists across sheet open/close)

@Observable
final class BalanceCalculatorFieldState {
    // General calculator fields
    var bankAccountsText: String = ""
    var savingsText: String = ""
    var cashText: String = ""
    var creditCardSpendingText: String = ""
    var othersOweMeText: String = ""
    var iOweText: String = ""

    // Credit card calculator fields
    var creditLineText: String = ""
    var availableCreditText: String = ""
    var directSpendingText: String = "" // Mode B: direct spending input

    // Simple account single field
    var simpleAmountText: String = ""

    func reset() {
        bankAccountsText = ""
        savingsText = ""
        cashText = ""
        creditCardSpendingText = ""
        othersOweMeText = ""
        iOweText = ""
        creditLineText = ""
        availableCreditText = ""
        directSpendingText = ""
        simpleAmountText = ""
    }
}

// MARK: - Calculator Sheet

struct BalanceCalculatorSheet: View {
    let accountType: AccountType
    let mindset: String // "cashFlow" | "patrimonial"
    let currencySymbol: String
    @Bindable var fieldState: BalanceCalculatorFieldState
    let onUseBalance: (Double) -> Void
    let onDismiss: () -> Void

    @Environment(\.yalaTheme) private var theme

    @FocusState private var focusedField: CalcField?

    private enum CalcField: Hashable {
        case bankAccounts, savings, cash, creditCardSpending
        case othersOweMe, iOwe
        case creditLine, availableCredit, directSpending
        case simpleAmount
    }

    /// Toggle for credit card calculator: detailed (line+available) vs direct (just spending)
    @State private var creditCardDirectMode: Bool = false

    private var variant: CalculatorVariant {
        switch accountType {
        case .general:
            return .general
        case .creditCard:
            return .creditCard
        case .cash, .checking, .savings:
            return .simple
        }
    }

    private enum CalculatorVariant {
        case general, creditCard, simple
    }

    // MARK: - Computed Balances

    private func parseAmount(_ text: String) -> Double {
        Double(text.replacing(",", with: ".")) ?? 0
    }

    private var generalTotal: Double {
        let bank = parseAmount(fieldState.bankAccountsText)
        let savings = parseAmount(fieldState.savingsText)
        let cash = parseAmount(fieldState.cashText)
        let creditSpending = parseAmount(fieldState.creditCardSpendingText)
        let othersOweMe = parseAmount(fieldState.othersOweMeText)
        let iOwe = parseAmount(fieldState.iOweText)

        if mindset == "patrimonial" {
            return bank + savings + cash - creditSpending + othersOweMe - iOwe
        } else {
            return bank + savings + cash
        }
    }

    private var creditCardSpending: Double {
        let line = parseAmount(fieldState.creditLineText)
        let available = parseAmount(fieldState.availableCreditText)
        return max(line - available, 0)
    }

    private var creditCardBalance: Double {
        -creditCardSpending
    }

    private var directSpendingAmount: Double {
        parseAmount(fieldState.directSpendingText)
    }

    private var simpleAmount: Double {
        parseAmount(fieldState.simpleAmountText)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    switch variant {
                    case .general:
                        generalCalculator
                    case .creditCard:
                        creditCardCalculator
                    case .simple:
                        simpleExplanation
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.lg)
                .dismissKeyboardOnTap()
            }
            .background(.thBackground)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(sheetTitle)
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

    private var sheetTitle: String {
        switch variant {
        case .general:
            return L10n.Onboarding.calcTitle
        case .creditCard:
            return L10n.Onboarding.calcCreditCardTitle
        case .simple:
            return L10n.Onboarding.accountBalanceLearnMore
        }
    }

    // MARK: - General Calculator

    private var generalCalculator: some View {
        VStack(spacing: DS.Spacing.xl) {
            // Intro
            Text(L10n.Onboarding.calcIntro)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.md)

            // Instruction
            Text(L10n.Onboarding.calcInstruction)
                .font(DS.Typography.bodyBold)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.md)

            // Input fields
            VStack(spacing: DS.Spacing.none) {
                calcRow(label: L10n.Onboarding.calcBankAccounts, hint: L10n.Onboarding.calcBankAccountsHint, text: $fieldState.bankAccountsText, field: .bankAccounts)
                SubsectionDivider()
                calcRow(label: L10n.Onboarding.calcSavings, hint: L10n.Onboarding.calcSavingsHint, text: $fieldState.savingsText, field: .savings)
                SubsectionDivider()
                calcRow(label: L10n.Onboarding.calcCash, hint: L10n.Onboarding.calcCashHint, text: $fieldState.cashText, field: .cash)

                if mindset == "patrimonial" {
                    SubsectionDivider()
                    VStack(spacing: DS.Spacing.none) {
                        calcRow(label: L10n.Onboarding.calcCreditCardSpending, hint: L10n.Onboarding.calcCreditCardSpendingHint, text: $fieldState.creditCardSpendingText, field: .creditCardSpending)
                        Text(L10n.Onboarding.calcOptional)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.bottom, DS.Spacing.sm)
                    }
                }
            }
            .background(.thCard)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))

            // Shared expenses section (patrimonial only)
            if mindset == "patrimonial" {
                VStack(spacing: DS.Spacing.none) {
                    // Section header
                    Text(L10n.Onboarding.calcSharedExpenses)
                        .font(DS.Typography.label)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.top, DS.Spacing.md)
                        .padding(.bottom, DS.Spacing.xs)

                    SubsectionDivider()

                    calcRow(label: L10n.Onboarding.calcOthersOweMe, text: $fieldState.othersOweMeText, field: .othersOweMe)
                    SubsectionDivider()
                    VStack(spacing: DS.Spacing.none) {
                        calcRow(label: L10n.Onboarding.calcIOwe, text: $fieldState.iOweText, field: .iOwe)
                        Text(L10n.Onboarding.calcOptional)
                            .font(DS.Typography.caption)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.horizontal, DS.Spacing.md)
                            .padding(.bottom, DS.Spacing.sm)
                    }
                }
                .background(.thCard)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            }

            // Result
            resultRow(
                label: mindset == "patrimonial" ? L10n.Onboarding.calcBalance : L10n.Onboarding.calcAvailable,
                amount: generalTotal
            )

            // Tips
            if mindset == "patrimonial" {
                tipView(text: L10n.Onboarding.calcTipPatrimonial)
                tipView(text: L10n.Onboarding.calcTipCashFlow)
            } else {
                tipView(text: L10n.Onboarding.calcTipCashFlow)
            }

            // Use balance button
            useBalanceButton(amount: generalTotal, isPositive: generalTotal >= 0)

            // Closing note
            Text(L10n.Onboarding.calcAdjustLater)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Credit Card Calculator

    private var creditCardCalculator: some View {
        VStack(spacing: DS.Spacing.xl) {
            if creditCardDirectMode {
                // Mode B: Direct spending input
                VStack(spacing: DS.Spacing.none) {
                    calcRow(
                        label: L10n.Onboarding.calcDirectSpending,
                        hint: L10n.Onboarding.calcDirectSpendingHint,
                        text: $fieldState.directSpendingText,
                        field: .directSpending
                    )
                }
                .background(.thCard)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))

                resultRow(label: L10n.Onboarding.calcYourBalance, amount: -directSpendingAmount)

                useBalanceButton(amount: directSpendingAmount, isPositive: false)
            } else {
                // Mode A: Detailed (line + available)
                VStack(spacing: DS.Spacing.none) {
                    calcRow(label: L10n.Onboarding.calcCreditLine, hint: L10n.Onboarding.calcCreditLineHint, text: $fieldState.creditLineText, field: .creditLine)
                    SubsectionDivider()
                    calcRow(label: L10n.Onboarding.calcAvailableCredit, hint: L10n.Onboarding.calcAvailableCreditHint, text: $fieldState.availableCreditText, field: .availableCredit)
                }
                .background(.thCard)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))

                VStack(spacing: DS.Spacing.sm) {
                    resultRow(label: L10n.Onboarding.calcCurrentSpending, amount: creditCardSpending)
                    resultRow(label: L10n.Onboarding.calcYourBalance, amount: creditCardBalance)
                }

                tipView(text: L10n.Onboarding.calcCreditCardTip)

                useBalanceButton(amount: creditCardSpending, isPositive: false)
            }

            // Toggle between modes — clear the other mode's fields to avoid stale data
            Button {
                if creditCardDirectMode {
                    fieldState.directSpendingText = ""
                } else {
                    fieldState.creditLineText = ""
                    fieldState.availableCreditText = ""
                }
                creditCardDirectMode.toggle()
            } label: {
                Text(creditCardDirectMode
                     ? L10n.Onboarding.calcSwitchToDetailed
                     : L10n.Onboarding.calcSwitchToDirect)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(Color.electricIndigo)
            }
            .buttonStyle(.plain)

            Text(L10n.Onboarding.calcAdjustLater)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Simple Explanation (Cash / Checking / Savings)

    private var simpleExplanation: some View {
        VStack(spacing: DS.Spacing.xl) {
            // Explanation text
            Text(simpleExplanationText)
                .font(DS.Typography.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Single amount field
            VStack(spacing: DS.Spacing.none) {
                calcRow(label: simpleBalanceLabel, text: $fieldState.simpleAmountText, field: .simpleAmount)
            }
            .background(.thCard)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))

            // Use balance button
            useBalanceButton(amount: simpleAmount, isPositive: true)

            // Closing note
            Text(L10n.Onboarding.calcAdjustLater)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var simpleBalanceLabel: String {
        switch accountType {
        case .checking: return L10n.Onboarding.calcBalanceLabelChecking
        case .savings:  return L10n.Onboarding.calcBalanceLabelSavings
        case .cash:     return L10n.Onboarding.calcBalanceLabelCash
        default:        return L10n.Account.balance
        }
    }

    private var simpleExplanationText: String {
        switch accountType {
        case .cash:
            return L10n.Onboarding.calcCashExplanation
        case .checking:
            return L10n.Onboarding.calcCheckingExplanation
        case .savings:
            return L10n.Onboarding.calcSavingsExplanation
        default:
            return ""
        }
    }

    // MARK: - Reusable Components

    private func calcRow(label: String, hint: String? = nil, text: Binding<String>, field: CalcField) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            HStack {
                Text(label)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Spacer()

                HStack(spacing: DS.Spacing.xs) {
                    Text(currencySymbol)
                        .font(DS.Typography.body)
                        .foregroundStyle(.secondary)
                    TextField("0", text: text)
                        .font(DS.Typography.headline)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(minWidth: 80)
                        .focused($focusedField, equals: field)
                        .onChange(of: text.wrappedValue) { _, newValue in
                            let filtered = filterCalcInput(newValue)
                            if filtered != newValue {
                                text.wrappedValue = filtered
                            }
                        }
                }
            }

            if let hint {
                Text(hint)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
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
                .foregroundStyle(amount >= 0 ? Color.electricIndigo : DS.Semantic.errorForeground)
        }
        .padding(DS.Spacing.md)
        .background(Color.electricIndigo.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private func tipView(text: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: "lightbulb.fill")
                .font(DS.Typography.body)
                .foregroundStyle(Color.electricIndigo)
                .accessibilityHidden(true)
            Text(text)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.electricIndigo.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }

    private func useBalanceButton(amount: Double, isPositive: Bool) -> some View {
        YalaPrimaryButton(L10n.Onboarding.calcUseBalance) {
            onUseBalance(isPositive ? amount : -abs(amount))
            onDismiss()
        }
    }

    // MARK: - Input Filtering

    private func filterCalcInput(_ text: String) -> String {
        var result = ""
        var hasDecimalPoint = false
        var decimalCount = 0

        for char in text {
            if char.isNumber {
                if hasDecimalPoint {
                    guard decimalCount < 2 else { continue }
                    decimalCount += 1
                }
                result.append(char)
            } else if (char == "." || char == ",") && !hasDecimalPoint {
                hasDecimalPoint = true
                result.append(".")
            }
        }
        return result
    }
}
