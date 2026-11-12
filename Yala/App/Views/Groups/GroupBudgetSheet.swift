//
//  GroupBudgetSheet.swift
//  Yala
//
//  El presupuesto del grupo en su hoja (auditoría UX 2.2 · L19-6, decisión D variante 3 de Jürgen, 18-oct): el monto
//  grande con la divisa del grupo, qué pasa al fijarlo y una vista previa de lo gastado contra la cifra antes de
//  guardar («Ya se pasarían por S/ 1,084»). Sustituye a la alerta con un campo, que no decía que el tope lo ve todo el
//  grupo ni que Yala avisa al llegar a la mitad, a tres cuartos, casi al tope y al tope.
//
//  Lo gastado sale de `GroupBudgetLogic.progress`, la misma función que pinta la barra del detalle y decide los avisos:
//  así la vista previa no puede decir otra cosa que lo que la persona verá al guardar. Lleva `≈` si hubo conversión.
//

import SwiftUI

struct GroupBudgetSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(AppPreferences.self) private var appPreferences

    let group: SplitGroup
    let expenses: [SplitExpense]
    /// Recibe lo tecleado. Valida y guarda quien llama (`GroupSettingsView.saveBudgetLimitFromInput`), que es el
    /// sitio que ya sabe que lo ilegible no es «quitar».
    let onSave: (String) -> Void

    @State private var input: String
    @FocusState private var amountFocused: Bool

    init(group: SplitGroup, expenses: [SplitExpense], initialInput: String, onSave: @escaping (String) -> Void) {
        self.group = group
        self.expenses = expenses
        self.onSave = onSave
        self._input = State(initialValue: initialInput)
    }

    /// Lo tecleado como número, o `nil` si todavía no es un tope (vacío, cero, ilegible).
    private var typedLimit: Double? {
        let value = AmountInputHelper.parseDecimal(input)
        guard value.isFinite, value > 0, value < GroupService.maxBudgetLimitAmount else { return nil }
        return value
    }

    /// Lo gastado contra lo tecleado. Sin tope legible se mide contra un tope simbólico solo para saber lo gastado.
    private var preview: GroupBudgetProgress? {
        GroupBudgetLogic.progress(
            limitAmount: typedLimit ?? 1,
            currencyCode: group.currencyCode,
            expenses: expenses
        )
    }

    private func money(_ value: Double) -> String {
        appPreferences.currency(value, currencyCode: group.currencyCode)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    Text(L10n.UXL19.budgetQuestion)
                        .font(DS.Typography.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    amountField
                    previewBlock
                    whatHappens

                    VStack(spacing: DS.Spacing.sm) {
                        YalaPrimaryButton(L10n.Action.save) {
                            onSave(input)
                            dismiss()
                        }
                        .accessibilityIdentifier("group_budget_sheet_save")

                        Button(L10n.Common.cancel) { dismiss() }
                            .font(DS.Typography.body)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .accessibilityIdentifier("group_budget_sheet_cancel")
                    }
                    .padding(.top, DS.Spacing.xs)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.basedOnSize)
            .yalaScreenBackground(.subtle)
            .navigationTitle(L10n.Groups.Budget.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) { dismiss() }
                }
            }
            .onAppear { amountFocused = true }
        }
    }

    // MARK: - Piezas

    private var amountField: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs) {
            Text(appPreferences.currencyDisplayFormat.label(for: group.currencyCode))
                .font(DS.Typography.title2)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("0", text: $input)
                .font(DS.Typography.heroAmount) // A11Y-DT: la cifra grande del mismo token que «Nuevo registro»
                .minimumScaleFactor(0.5)
                .keyboardType(.decimalPad)
                .focused($amountFocused)
                .accessibilityLabel(L10n.Groups.Budget.title)
                .accessibilityIdentifier("group_budget_sheet_amount")
        }
        .padding(DS.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { amountFocused = true }
    }

    @ViewBuilder
    private var previewBlock: some View {
        if let preview, preview.spentAmount > 0 {
            let spentText = (preview.isEstimate ? "≈ " : "") + money(preview.spentAmount)
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline) {
                        spentLabel(spentText)
                        Spacer(minLength: DS.Spacing.sm)
                        verdictLabel(preview)
                    }
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        spentLabel(spentText)
                        verdictLabel(preview)
                    }
                }
                if typedLimit != nil {
                    progressBar(preview)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("group_budget_sheet_preview")
        } else {
            Text(L10n.UXL19.budgetNoSpendingYet)
                .font(DS.Typography.caption)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("group_budget_sheet_preview")
        }
    }

    private func spentLabel(_ spentText: String) -> some View {
        Text(L10n.UXL19.budgetSpentSoFar(spentText))
            .font(DS.Typography.caption)
            .foregroundStyle(.primary)
    }

    @ViewBuilder
    private func verdictLabel(_ preview: GroupBudgetProgress) -> some View {
        if typedLimit != nil {
            if preview.isExceeded {
                Text(L10n.UXL19.budgetWouldExceed(money(preview.exceededAmount)))
                    .font(DS.Typography.caption.weight(.semibold))
                    .foregroundStyle(DS.Semantic.errorForeground)
            } else {
                Text(L10n.UXL19.budgetWouldRemain(money(preview.remainingAmount)))
                    .font(DS.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func progressBar(_ preview: GroupBudgetProgress) -> some View {
        let fraction = min(max(preview.percentage / 100, 0), 1)
        return GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.2))
                Capsule()
                    .fill(preview.isExceeded ? Color.hotPink : Color.electricIndigo)
                    .frame(width: proxy.size.width * fraction)
            }
        }
        .frame(height: 8) // A11Y-DT: barra de progreso, alto fijo como la del presupuesto del detalle
        .accessibilityHidden(true)
    }

    private var whatHappens: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Label(L10n.UXL19.budgetSeenByAll, systemImage: "person.2")
            Label(L10n.UXL19.budgetAlerts, systemImage: "bell")
        }
        .font(DS.Typography.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
}
