//
//  CashFlowStartingBalanceSheet.swift
//  Yala
//
//  Auditoría UX 2.2 · L18-10 (opción C): cambiar el saldo inicial. Antes era un lápiz que parecía «prohibido» y una hoja
//  sin título, sin fondo y sin divisa, con un «0» suelto. Ahora la hoja lleva la cabecera de la app, la cifra grande con
//  su divisa como en «Nuevo registro» y, si se sabe, «Hoy tienes S/ X en tus cuentas · Usar este monto». La usan la
//  fila «Empezaste con S/ X · Cambiar» del plan y «Cambiar el monto» de crear el plan (L18-5).
//

import SwiftUI

struct CashFlowStartingBalanceSheet: View {
    let title: String
    let initialAmount: Double
    let initialDate: Date?
    /// Lo que la persona tiene hoy en sus cuentas (`CashFlowSetupLogic.todayBalance`); `nil` si no hay cuentas que sumen.
    let todayBalance: CashFlowSetupLogic.TodayBalance?
    let currencyCode: String
    /// La fecha del saldo solo tiene sentido con un plan creado.
    let showsDate: Bool
    let onSave: (Double, Date?) -> Void

    @State private var amountText: String = ""
    @State private var hasDate: Bool = false
    @State private var balanceDate: Date = .now
    @FocusState private var amountFocused: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    amountField
                    if let todayBalance {
                        todayCard(todayBalance)
                    }
                    if showsDate {
                        dateCard
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.xl)
                .yalaSafeBottomPadding()
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
            .safeAreaInset(edge: .bottom) {
                YalaPrimaryButton(L10n.CashFlowPlan.editStartingBalanceSave, icon: "checkmark.circle.fill") {
                    save()
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.sm)
                .accessibilityIdentifier("cashflow_starting_balance_save")
            }
            .yalaScreenBackground(.subtle)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
        .accessibilityIdentifier("cashflow_starting_balance_sheet")
        .onAppear {
            amountText = Self.editableText(initialAmount)
            if let initialDate {
                hasDate = true
                balanceDate = initialDate
            }
        }
    }

    // MARK: - Piezas

    /// La cifra grande y centrada con su divisa, como en «Nuevo registro».
    private var amountField: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm) {
            Text(appPreferences.currencyIdentifier(for: currencyCode))
                .font(DS.Typography.title2)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("0", text: $amountText)
                .keyboardType(.decimalPad)
                .font(DS.Typography.largeTitle.weight(.bold))
                .monospacedDigit()
                .multilineTextAlignment(.leading)
                .fixedSize()
                .focused($amountFocused)
                .accessibilityLabel(title)
                .accessibilityIdentifier("cashflow_starting_balance_field")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.lg)
        .contentShape(Rectangle())
        .onTapGesture { amountFocused = true }
    }

    private func todayCard(_ balance: CashFlowSetupLogic.TodayBalance) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Text(L10n.UXL18.todayBalance(
                appPreferences.currency(balance.amount, currencyCode: currencyCode, isEstimate: balance.isApproximate)
            ))
            .font(DS.Typography.subheadline)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Con ese monto ya puesto, el botón no haría nada.
            if amountText != Self.editableText(balance.amount) {
                Button {
                    amountText = Self.editableText(balance.amount)
                } label: {
                    Text(L10n.UXL18.useThisAmount)
                        .font(DS.Typography.label.weight(.semibold))
                        .foregroundStyle(theme.accentText)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(Capsule().fill(theme.accent.opacity(0.14)))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("cashflow_starting_balance_use_today")
            }
        }
        .padding(DS.Spacing.lg)
        .solidCard()
    }

    private var dateCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Toggle(L10n.CashFlowPlan.startingBalanceDateLabel, isOn: $hasDate)
                .font(DS.Typography.label)
            if hasDate {
                DatePicker("", selection: $balanceDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
            }
            Text(L10n.CashFlowPlan.startingBalanceDateHelper)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
        }
        .padding(DS.Spacing.lg)
        .solidCard()
    }

    // MARK: - Guardar

    private func save() {
        onSave(AmountInputHelper.parseDecimal(amountText), showsDate && hasDate ? balanceDate : nil)
        dismiss()
    }

    /// El monto en el campo: sin decimales si es entero, con hasta dos si no (antes se redondeaba siempre a entero), con
    /// el separador decimal del teléfono y sin separador de miles, que es lo que lee `AmountInputHelper.parseDecimal`.
    static func editableText(_ amount: Double, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.0f", amount)
    }
}
