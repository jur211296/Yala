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
    @Environment(AppPreferences.self) private var appPreferences

    @FocusState private var focusedField: CalcField?

    @ScaledMetric(relativeTo: .largeTitle) private var resultFigureSize: CGFloat = 40 // A11Y-DT: @ScaledMetric
    @ScaledMetric(relativeTo: .subheadline) private var signBadgeSize: CGFloat = 24 // A11Y-DT: @ScaledMetric
    @ScaledMetric(relativeTo: .subheadline) private var signGlyphSize: CGFloat = 12 // A11Y-DT: @ScaledMetric

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

    /// Los términos de la cuenta, con su signo (UX 2.2 · L1UI-3). El total y la cuenta que se enseña debajo salen de
    /// esta MISMA lista: si fueran dos cálculos, la cuenta podría decir una cosa y el total otra.
    private var generalTerms: [BalanceCalculatorTerm] {
        BalanceCalculatorTermsLogic.terms(mindset: mindset, amounts: [
            .bankAccounts: parseAmount(fieldState.bankAccountsText),
            .savings: parseAmount(fieldState.savingsText),
            .cash: parseAmount(fieldState.cashText),
            .creditCardSpending: parseAmount(fieldState.creditCardSpendingText),
            .othersOweMe: parseAmount(fieldState.othersOweMeText),
            .iOwe: parseAmount(fieldState.iOweText)
        ])
    }

    private var generalTotal: Double {
        BalanceCalculatorTermsLogic.total(generalTerms)
    }

    private var creditCardSpending: Double {
        let line = parseAmount(fieldState.creditLineText)
        let available = parseAmount(fieldState.availableCreditText)
        return max(line - available, 0)
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
            .safeAreaInset(edge: .bottom) {
                if variant == .general {
                    generalBottomBar
                }
            }
            .scrollContentBackground(.hidden)
            .yalaScreenBackground(.subtle)
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
                calcRow(label: L10n.Onboarding.calcBankAccounts, hint: L10n.Onboarding.calcBankAccountsHint, text: $fieldState.bankAccountsText, field: .bankAccounts, sign: .plus)
                SubsectionDivider()
                calcRow(label: L10n.Onboarding.calcSavings, hint: L10n.Onboarding.calcSavingsHint, text: $fieldState.savingsText, field: .savings, sign: .plus)
                SubsectionDivider()
                calcRow(label: L10n.Onboarding.calcCash, hint: L10n.Onboarding.calcCashHint, text: $fieldState.cashText, field: .cash, sign: .plus)

                if mindset == "patrimonial" {
                    SubsectionDivider()
                    VStack(spacing: DS.Spacing.none) {
                        calcRow(label: L10n.Onboarding.calcCreditCardSpending, hint: L10n.Onboarding.calcCreditCardSpendingHint, text: $fieldState.creditCardSpendingText, field: .creditCardSpending, sign: .minus)
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

                    calcRow(label: L10n.Onboarding.calcOthersOweMe, text: $fieldState.othersOweMeText, field: .othersOweMe, sign: .plus)
                    SubsectionDivider()
                    VStack(spacing: DS.Spacing.none) {
                        calcRow(label: L10n.Onboarding.calcIOwe, text: $fieldState.iOweText, field: .iOwe, sign: .minus)
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

            // Resultado (UX 2.2 · L1UI-3): ficha índigo con el total y, debajo, la cuenta que lo da.
            resultCard(
                label: mindset == "patrimonial" ? L10n.Onboarding.calcResultBalance : L10n.Onboarding.calcResultAvailable,
                amount: generalTotal,
                formula: generalFormula
            )

            // Tips
            if mindset == "patrimonial" {
                tipView(text: L10n.Onboarding.calcTipPatrimonial)
                tipView(text: L10n.Onboarding.calcTipCashFlow)
            } else {
                tipView(text: L10n.Onboarding.calcTipCashFlow)
            }
        }
    }

    /// «Usar este saldo» fijo abajo (UX 2.2 · L1UI-3): con los seis campos quedaba bajo el pliegue. Fondo sólido del
    /// sheet con una línea fina encima, sin fundido.
    private var generalBottomBar: some View {
        VStack(spacing: DS.Spacing.xs) {
            useBalanceButton(amount: generalTotal, isPositive: generalTotal >= 0)
            Text(L10n.Onboarding.calcAdjustLater)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.top, DS.Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(theme.background)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.primary.opacity(0.08))
                .frame(height: 1)
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

                // Una sola cifra, «Debes», también aquí (UX 2.2 · L1UI-4): es la misma tarjeta.
                resultCard(label: L10n.Onboarding.calcCreditCardOwed, amount: directSpendingAmount, formula: nil)

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

                // Una sola cifra, «Debes», y la cuenta debajo (UX 2.2 · L1UI-4). Antes eran dos, y la del saldo salía
                // en rojo: quien no lleva tarjetas en una app creía que algo había salido mal.
                resultCard(label: L10n.Onboarding.calcCreditCardOwed, amount: creditCardSpending, formula: creditCardFormula)

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

    private func calcRow(
        label: String,
        hint: String? = nil,
        text: Binding<String>,
        field: CalcField,
        sign: BalanceCalculatorSign? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
            HStack {
                if let sign {
                    signBadge(sign)
                }
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
                        .monospacedDigit()
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
                    .padding(.leading, sign == nil ? 0 : signBadgeSize + DS.Spacing.sm)
            }
        }
        .padding(DS.Spacing.md)
    }

    /// Signo en un círculo sólido delante de cada campo (UX 2.2 · L1UI-3): índigo suma, rojo resta.
    private func signBadge(_ sign: BalanceCalculatorSign) -> some View {
        Image(systemName: sign == .plus ? "plus" : "minus")
            .font(.system(size: signGlyphSize, weight: .heavy)) // A11Y-DT: @ScaledMetric
            .foregroundStyle(Color.white)
            .frame(width: signBadgeSize, height: signBadgeSize)
            .background(Circle().fill(sign == .plus ? Color.electricIndigo : Color.subtractSign))
            .accessibilityHidden(true)
    }

    /// El resultado en una ficha índigo sólida (UX 2.2 · L1UI-3/4): el rótulo, la cifra grande en blanco y, si la
    /// hay, la cuenta que la da. Sin rojo: un saldo negativo o una deuda de tarjeta no son un error.
    private func resultCard(label: String, amount rawAmount: Double, formula: AttributedString?) -> some View {
        let amount = BalanceCalculatorDisplayLogic.displayed(rawAmount)
        let figure = "\(currencySymbol) \(appPreferences.number(amount, forceFullPrecision: true))"
        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(label)
                .font(DS.Typography.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.white.opacity(0.85))
            Text(figure)
                .font(.system(size: resultFigureSize, weight: .bold)) // A11Y-DT: @ScaledMetric
                .monospacedDigit()
                .foregroundStyle(Color.white)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .contentTransition(.numericText(value: amount))
            if let formula {
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 1)
                Text(formula)
                    .font(DS.Typography.subheadline)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.selectedIndigoFill)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("balance_calculator_result")
    }

    /// La cuenta de «Todo junto» en vivo: «1,200 + 800 + 150 − 450 + 100 − 0». Lo que resta, en rosa claro.
    private var generalFormula: AttributedString {
        var result = AttributedString()
        for (index, term) in generalTerms.enumerated() {
            let color: Color = term.sign == .minus ? .pinkOnIndigo : Color.white.opacity(0.8)
            if index > 0 {
                var op = AttributedString(term.sign == .minus ? "  −  " : "  +  ")
                op.foregroundColor = color
                result += op
            }
            var number = AttributedString(appPreferences.number(term.amount))
            number.foregroundColor = color
            result += number
        }
        return result
    }

    /// «Línea 5,000 − Disponible 3,200», con las cifras resaltadas (UX 2.2 · L1UI-4).
    private var creditCardFormula: AttributedString {
        let line = appPreferences.number(parseAmount(fieldState.creditLineText))
        let available = appPreferences.number(parseAmount(fieldState.availableCreditText))
        let markdown = String(format: L10n.Onboarding.calcCreditCardFormulaFormat, line, available)
        var result: AttributedString
        do {
            result = try AttributedString(markdown: markdown)
        } catch {
            #if DEBUG
            print("BalanceCalculatorSheet: Error: \(error)")
            #endif
            result = AttributedString(markdown.replacing("**", with: ""))
        }
        result.foregroundColor = Color.white.opacity(0.75)
        for run in result.runs where run.inlinePresentationIntent?.contains(.stronglyEmphasized) == true {
            result[run.range].foregroundColor = Color.white
        }
        return result
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

/// Lo que enseña una fila de resultado de la calculadora.
///
/// La tarjeta muestra su saldo como `-consumo`, y con los campos vacíos eso es `-0.0`: el formateador pinta
/// «S/ -0.00», un saldo negativo sin nada que deber (bug B1 de la pasada UI del lote 1 de la auditoría UX 2.2,
/// medido en el simulador el 2026-10-13). Un cero se enseña sin signo.
enum BalanceCalculatorDisplayLogic {
    static func displayed(_ amount: Double) -> Double {
        amount == 0 ? 0 : amount
    }
}

/// Si un campo de la calculadora suma o resta.
nonisolated enum BalanceCalculatorSign: Equatable {
    case plus, minus
}

/// Un término de la cuenta de «Todo junto»: qué campo, su signo y lo escrito (siempre positivo).
nonisolated struct BalanceCalculatorTerm: Equatable {
    let field: BalanceCalculatorTermsLogic.Field
    let sign: BalanceCalculatorSign
    let amount: Double
}

/// Qué suma y qué resta la calculadora «Todo junto» (UX 2.2 · L1UI-3). Antes daba «Tu saldo → S/ 1.800» sin un solo
/// signo; ahora cada campo lleva el suyo y el total se calcula con la misma lista que se enseña debajo.
nonisolated enum BalanceCalculatorTermsLogic {
    enum Field: CaseIterable, Equatable {
        case bankAccounts, savings, cash, creditCardSpending, othersOweMe, iOwe
    }

    /// Lo que debes (consumo en tarjetas, lo que debes a otros) resta; lo demás suma.
    static func sign(of field: Field) -> BalanceCalculatorSign {
        switch field {
        case .creditCardSpending, .iOwe: return .minus
        case .bankAccounts, .savings, .cash, .othersOweMe: return .plus
        }
    }

    /// Los campos que cuentan, en el orden de la pantalla. El disponible (`cashFlow`) solo cuenta lo que tienes.
    static func fields(mindset: String) -> [Field] {
        mindset == "patrimonial" ? Field.allCases : [.bankAccounts, .savings, .cash]
    }

    static func terms(mindset: String, amounts: [Field: Double]) -> [BalanceCalculatorTerm] {
        fields(mindset: mindset).map { field in
            BalanceCalculatorTerm(field: field, sign: sign(of: field), amount: amounts[field] ?? 0)
        }
    }

    static func total(_ terms: [BalanceCalculatorTerm]) -> Double {
        terms.reduce(0) { $0 + ($1.sign == .plus ? $1.amount : -$1.amount) }
    }
}
