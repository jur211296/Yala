//
//  GroupOpeningBalanceFormView.swift
//  Yala
//
//  Editor de un saldo inicial (deuda de apertura) — owner-only. Define "quién debe a
//  quién" + monto + moneda. Sin tipo de división, categoría ni descripción: un saldo
//  inicial es una arista de deuda pura entre dos miembros existentes.
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

    @State private var debtorMemberID: String
    @State private var creditorMemberID: String
    @State private var amountString: String
    @State private var selectedCurrency: CurrencyCode

    @State private var showDebtorPicker = false
    @State private var showCreditorPicker = false
    @State private var showCurrencyPicker = false
    @State private var errorMessage: String?
    @State private var showError = false
    @FocusState private var amountFocused: Bool

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
        } else {
            _debtorMemberID = State(initialValue: prefillDebtorMemberID ?? "")
            _creditorMemberID = State(initialValue: "")
            _amountString = State(initialValue: "")
            _selectedCurrency = State(initialValue: CurrencyCode(rawValue: group.currencyCode) ?? .usd)
        }
    }

    private var amountValue: Double { AmountInputHelper.parseDecimal(amountString) }

    private var canSave: Bool {
        !debtorMemberID.isEmpty
            && !creditorMemberID.isEmpty
            && debtorMemberID != creditorMemberID
            && amountValue > 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    memberRow(
                        label: L10n.Groups.OpeningBalance.debtorLabel,
                        selectedID: debtorMemberID,
                        action: { showDebtorPicker = true },
                        identifier: "opening_balance_debtor"
                    )
                    memberRow(
                        label: L10n.Groups.OpeningBalance.creditorLabel,
                        selectedID: creditorMemberID,
                        action: { showCreditorPicker = true },
                        identifier: "opening_balance_creditor"
                    )
                    amountSection
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
                        .disabled(!canSave)
                        .accessibilityIdentifier("opening_balance_save")
                }
            }
            .sheet(isPresented: $showDebtorPicker) {
                MemberPickerView(
                    members: members.filter { $0.id.uuidString != creditorMemberID },
                    groupColorHex: group.colorHex,
                    selectedMemberID: $debtorMemberID
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showCreditorPicker) {
                MemberPickerView(
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
                .presentationDetents(DS.Adaptive.sheetDetents([.large]))
            }
            .alert(L10n.Common.error, isPresented: $showError) {
                Button(L10n.Common.ok) {}
            } message: {
                Text(errorMessage ?? L10n.Groups.Errors.actionFailed)
            }
        }
    }

    // MARK: - Rows

    private func memberRow(label: String, selectedID: String, action: @escaping () -> Void, identifier: String) -> some View {
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
        .accessibilityIdentifier(identifier)
    }

    private var amountSection: some View {
        HStack(alignment: .center, spacing: DS.Spacing.md) {
            Button {
                showCurrencyPicker = true
            } label: {
                Text(selectedCurrency.rawValue)
                    .font(DS.Typography.label)
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(Capsule().fill(theme.accent.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("opening_balance_currency")

            TextField("0.00", text: $amountString)
                .font(.system(size: 34, weight: .bold, design: .rounded)) // A11Y-DT: campo de monto hero, escala con minimumScaleFactor
                .foregroundStyle(theme.accent)
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .focused($amountFocused)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .accessibilityIdentifier("opening_balance_amount")
        }
        .padding(.vertical, DS.Spacing.lg)
    }

    // MARK: - Save

    private func save() {
        do {
            if let edit = expenseToEdit {
                try GroupExpenseService.shared.updateOpeningBalance(
                    edit,
                    in: group,
                    debtorMemberID: debtorMemberID,
                    creditorMemberID: creditorMemberID,
                    amount: amountValue,
                    currencyCode: selectedCurrency.rawValue
                )
            } else {
                try GroupExpenseService.shared.setOpeningBalance(
                    in: group,
                    debtorMemberID: debtorMemberID,
                    creditorMemberID: creditorMemberID,
                    amount: amountValue,
                    currencyCode: selectedCurrency.rawValue
                )
            }
            DS.Haptic.success()
            onSave()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}
