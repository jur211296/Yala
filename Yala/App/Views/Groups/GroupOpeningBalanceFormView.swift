//
//  GroupOpeningBalanceFormView.swift
//  Yala
//
//  Editor de un saldo inicial (deuda de apertura) — owner-only. Define "quién debe a
//  quién" + monto + moneda + fecha (card t3fq). Sin tipo de división, categoría ni descripción:
//  un saldo inicial es una arista de deuda pura entre dos miembros existentes.
//

import SwiftUI

struct GroupOpeningBalanceFormView: View {

    let group: SplitGroup
    let members: [SplitMember]
    let memberNameLookup: [String: String]
    /// Gasto a editar (nil = crear nuevo).
    var expenseToEdit: SplitExpense?
    /// Deudor actual del gasto a editar (la única share).
    var existingDebtorMemberID: String?
    /// Miembro pre-seleccionado como deudor (atajo al aprobar un miembro).
    var prefillDebtorMemberID: String?
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var debtorMemberID: String
    @State private var creditorMemberID: String
    @State private var amountString: String
    @State private var selectedCurrency: CurrencyCode
    /// Card t3fq: la fecha del saldo, que es la del registro en el grupo. Al crear, hoy; al editar, la que tenía.
    @State private var date: Date

    @State private var showDebtorPicker = false
    @State private var showCreditorPicker = false
    @State private var showCurrencyPicker = false
    @State private var errorMessage: String?
    @State private var showError = false
    @FocusState private var amountFocused: Bool
    /// Lote 12.3 (card rhgi, molde de L13-9): «Guardar» siempre activo; tocarlo con algo pendiente marca el campo y lo dice.
    @State private var showsMissingField = false

    init(
        group: SplitGroup,
        members: [SplitMember],
        memberNameLookup: [String: String],
        expenseToEdit: SplitExpense? = nil,
        existingDebtorMemberID: String? = nil,
        prefillDebtorMemberID: String? = nil,
        onSave: @escaping () -> Void
    ) {
        self.group = group
        self.members = members
        self.memberNameLookup = memberNameLookup
        self.expenseToEdit = expenseToEdit
        self.existingDebtorMemberID = existingDebtorMemberID
        self.prefillDebtorMemberID = prefillDebtorMemberID
        self.onSave = onSave

        if let edit = expenseToEdit {
            _debtorMemberID = State(initialValue: existingDebtorMemberID ?? "")
            _creditorMemberID = State(initialValue: edit.paidByMemberID)
            _amountString = State(initialValue: AmountInputHelper.formatWithGrouping(edit.amount))
            // Fallback a la moneda del grupo (no .usd) si el código guardado fuese inválido/legacy.
            _selectedCurrency = State(initialValue: CurrencyCode(rawValue: edit.currencyCode) ?? CurrencyCode(rawValue: group.currencyCode) ?? .usd)
            _date = State(initialValue: edit.date)
        } else {
            _debtorMemberID = State(initialValue: prefillDebtorMemberID ?? "")
            _creditorMemberID = State(initialValue: "")
            _amountString = State(initialValue: "")
            _selectedCurrency = State(initialValue: CurrencyCode(rawValue: group.currencyCode) ?? .usd)
            _date = State(initialValue: Date.now)
        }
    }

    private var amountValue: Double { AmountInputHelper.parseDecimal(amountString) }

    private var firstMissingField: GroupOpeningBalanceMissingField? {
        GroupOpeningBalanceMissingFieldLogic.firstMissing(
            debtorMemberID: debtorMemberID,
            creditorMemberID: creditorMemberID,
            amount: amountValue
        )
    }

    /// Lo que se marca: lo primero que falta, solo después de haber tocado «Guardar».
    private var markedMissingField: GroupOpeningBalanceMissingField? {
        showsMissingField ? firstMissingField : nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    // UX 2.2 · L13-10: qué es un saldo inicial, en una línea, antes de pedir nada.
                    Text(L10n.Groups.OpeningBalance.formHelp)
                        .font(DS.Typography.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, DS.Spacing.xs)
                        .accessibilityIdentifier("opening_balance_help")
                    missingFieldHint
                    memberRow(
                        label: L10n.Groups.OpeningBalance.debtorLabel,
                        selectedID: debtorMemberID,
                        isMarked: markedMissingField == .debtor || markedMissingField == .samePerson,
                        action: { showDebtorPicker = true },
                        identifier: "opening_balance_debtor"
                    )
                    memberRow(
                        label: L10n.Groups.OpeningBalance.creditorLabel,
                        selectedID: creditorMemberID,
                        isMarked: markedMissingField == .creditor || markedMissingField == .samePerson,
                        action: { showCreditorPicker = true },
                        identifier: "opening_balance_creditor"
                    )
                    amountSection
                    dateRow
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.md)
            }
            .dismissKeyboardOnTap()
            .yalaScreenBackground(.subtle)
            .navigationTitle(L10n.Groups.OpeningBalance.editorTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.Action.save) { save() }
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("opening_balance_save")
                }
            }
            .sheet(isPresented: $showDebtorPicker) {
                MemberPickerView(
                    title: L10n.Groups.OpeningBalance.debtorLabel,
                    members: members.filter { $0.id.uuidString != creditorMemberID },
                    groupColorHex: group.colorHex,
                    selectedMemberID: $debtorMemberID
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showCreditorPicker) {
                MemberPickerView(
                    title: L10n.Groups.OpeningBalance.creditorLabel,
                    members: members.filter { $0.id.uuidString != debtorMemberID },
                    groupColorHex: group.colorHex,
                    selectedMemberID: $creditorMemberID
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showCurrencyPicker) {
                NavigationStack {
                    CurrencySelectorView(selectedCurrency: $selectedCurrency)
                }
                .yalaSheetDetents([.large])
            }
            .alert(L10n.Common.error, isPresented: $showError) {
                Button(L10n.Common.ok) {}
            } message: {
                Text(errorMessage ?? L10n.Groups.Errors.actionFailed)
            }
        }
    }

    // MARK: - Rows

    private func memberRow(label: String, selectedID: String, isMarked: Bool, action: @escaping () -> Void, identifier: String) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                Text(label)
                    .font(DS.Typography.body)
                    .foregroundStyle(.primary)
                Spacer()
                Text(selectedID.isEmpty ? L10n.Action.select : (memberNameLookup[selectedID] ?? "?"))
                    .font(DS.Typography.body)
                    .foregroundStyle(selectedID.isEmpty ? .secondary : .primary)
                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, DS.FormRow.paddingH)
            .padding(.vertical, DS.FormRow.paddingV)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .solidCard(padding: DS.Spacing.none, radius: DS.Radius.lg)
        .overlay {
            if isMarked {
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .strokeBorder(DS.Semantic.errorForeground, lineWidth: 2)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityIdentifier(identifier)
    }

    private var amountSection: some View {
        HStack(alignment: .center, spacing: DS.Spacing.md) {
            Button {
                showCurrencyPicker = true
            } label: {
                // Lote 13: respeta la preferencia «S/» / «PEN», como el formulario de gasto.
                Text(appPreferences.currencyDisplayFormat.label(for: selectedCurrency.rawValue))
                    .font(DS.Typography.label)
                    .foregroundStyle(theme.accentText)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(Capsule().fill(theme.accent.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("opening_balance_currency")

            TextField("0.00", text: $amountString)
                .font(.system(size: 34, weight: .bold, design: .rounded)) // A11Y-DT: campo de monto hero, escala con minimumScaleFactor
                .foregroundStyle(theme.accentText)
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .focused($amountFocused)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .accessibilityIdentifier("opening_balance_amount")
                .overlay(alignment: .bottom) {
                    if markedMissingField == .amount {
                        Capsule()
                            .fill(DS.Semantic.errorForeground)
                            .frame(height: 2)
                            .accessibilityHidden(true)
                    }
                }
        }
        .padding(.vertical, DS.Spacing.lg)
    }

    /// La fecha del saldo, en una tarjeta como las de las personas. Nada en el futuro: un saldo inicial es lo que ya
    /// se debía.
    private var dateRow: some View {
        DatePicker(
            L10n.Groups.OpeningBalance.dateLabel,
            selection: $date,
            in: ...Date.now,
            displayedComponents: .date
        )
        .font(DS.Typography.body)
        .padding(.horizontal, DS.FormRow.paddingH)
        .padding(.vertical, DS.FormRow.paddingV)
        .solidCard(padding: DS.Spacing.none, radius: DS.Radius.lg)
        .accessibilityIdentifier("opening_balance_date")
    }

    // MARK: - Qué falta (card rhgi)

    private func missingFieldMessage(_ missing: GroupOpeningBalanceMissingField) -> String {
        switch missing {
        case .debtor: L10n.Groups.OpeningBalance.missingDebtor
        case .creditor: L10n.Groups.OpeningBalance.missingCreditor
        case .samePerson: L10n.Groups.OpeningBalance.missingDistinctPeople
        case .amount: L10n.Groups.Expense.missingAmount
        }
    }

    /// Una línea bajo la ayuda —lo más cerca de «Guardar», que está arriba— con lo que falta; se va al completarlo.
    @ViewBuilder
    private var missingFieldHint: some View {
        if let missing = markedMissingField {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(DS.Typography.caption)
                    .accessibilityHidden(true)
                Text(missingFieldMessage(missing))
                    .font(DS.Typography.subheadline)
                Spacer(minLength: DS.Spacing.none)
            }
            .foregroundStyle(DS.Semantic.errorForeground)
            .padding(.horizontal, DS.Spacing.xs)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("opening_balance_missing_hint")
            .transition(.opacity)
        }
    }

    private func showMissingField(_ missing: GroupOpeningBalanceMissingField) {
        DS.Haptic.warning()
        dsWithAnimation(reduceMotion) {
            showsMissingField = true
            if missing == .amount { amountFocused = true }
        }
        UIAccessibility.post(notification: .announcement, argument: missingFieldMessage(missing))
    }

    // MARK: - Save

    private func save() {
        if let missing = firstMissingField {
            showMissingField(missing)
            return
        }
        showsMissingField = false
        do {
            if let edit = expenseToEdit {
                try GroupExpenseService.shared.updateOpeningBalance(
                    edit,
                    in: group,
                    debtorMemberID: debtorMemberID,
                    creditorMemberID: creditorMemberID,
                    amount: amountValue,
                    currencyCode: selectedCurrency.rawValue,
                    date: date
                )
            } else {
                try GroupExpenseService.shared.setOpeningBalance(
                    in: group,
                    debtorMemberID: debtorMemberID,
                    creditorMemberID: creditorMemberID,
                    amount: amountValue,
                    currencyCode: selectedCurrency.rawValue,
                    date: date
                )
            }
            DS.Haptic.success()
            onSave()
            dismiss()
        } catch {
            errorMessage = GroupsUserFacingErrorLogic.message(for: error)
            showError = true
        }
    }
}
