//
//  SettlementFormView.swift
//  Yala
//
//  Formulario para registrar un pago de liquidación entre miembros.
//

import SwiftUI

struct SettlementFormView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme

    // MARK: - Input

    let group: SplitGroup
    let debt: Debt
    let memberNameLookup: [String: String]
    let onSave: () -> Void

    // MARK: - State

    @State private var amountString: String
    @State private var note: String = ""
    @State private var date: Date = .now
    @State private var isSaving: Bool = false
    @State private var showSaveError: Bool = false
    @State private var saveErrorMessage: String = ""

    // MARK: - Init

    init(
        group: SplitGroup,
        debt: Debt,
        memberNameLookup: [String: String],
        onSave: @escaping () -> Void
    ) {
        self.group = group
        self.debt = debt
        self.memberNameLookup = memberNameLookup
        self.onSave = onSave
        self._amountString = State(initialValue: AmountInputHelper.formatWithGrouping(debt.amount))
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    // Header: who pays whom
                    paymentHeader

                    // Amount
                    amountSection

                    // Details
                    detailsSection

                    // Submit button
                    YalaPrimaryButton(L10n.Groups.Settlement.registerPayment, icon: "checkmark.circle.fill") {
                        handleSave()
                    }
                    .disabled(parsedAmount <= 0 || isSaving)
                    .padding(.horizontal, DS.Spacing.lg)
                }
                .padding(.top, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.safeBottom)
            }
            .background(PanelBackgroundView())
            .navigationTitle(L10n.Groups.Settlement.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
            .alert(L10n.Common.error, isPresented: $showSaveError) {
                Button(L10n.Common.ok) {}
            } message: {
                Text(saveErrorMessage)
            }
        }
    }

    // MARK: - Payment Header

    private var paymentHeader: some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.md) {
                memberBubble(debt.fromMemberID)

                VStack(spacing: DS.Spacing.xxs) {
                    Image(systemName: "arrow.right")
                        .font(DS.Typography.headline)
                        .foregroundStyle(.secondary)
                    Text(L10n.Groups.Settlement.payTo)
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }

                memberBubble(debt.toMemberID)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.lg)
    }

    private func memberBubble(_ memberID: String) -> some View {
        let name = memberNameLookup[memberID] ?? "?"
        return VStack(spacing: DS.Spacing.xs) {
            ZStack {
                Circle()
                    .fill(Color(hex: group.colorHex).opacity(0.2))
                    .frame(width: 48, height: 48) // A11Y-DT: decorative avatar, fixed size

                Text(String(name.prefix(1)).uppercased())
                    .font(DS.Typography.headline)
                    .foregroundStyle(Color(hex: group.colorHex))
            }

            Text(name)
                .font(DS.Typography.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .accessibilityLabel(name)
    }

    // MARK: - Amount Section

    private var amountSection: some View {
        VStack(spacing: DS.Spacing.xs) {
            HStack(spacing: DS.Spacing.sm) {
                Text(debt.currencyCode)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thAccent)

                TextField("0.00", text: $amountString)
                    .font(.system(size: 36, weight: .bold, design: .rounded)) // A11Y-DT: amount display
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .keyboardType(.decimalPad)
                    .onChange(of: amountString) { _, newValue in
                        let filtered = AmountInputHelper.filterAmountInput(newValue)
                        if filtered != newValue {
                            amountString = filtered
                        }
                    }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        SectionBox(title: L10n.Groups.Expense.noteLabel) {
            VStack(spacing: DS.Spacing.none) {
                TextField(L10n.Groups.Expense.notePlaceholder, text: $note)
                    .font(DS.Typography.body)
                    .padding(.horizontal, DS.FormRow.paddingH)
                    .padding(.vertical, DS.FormRow.paddingV)

                Divider().padding(.leading, DS.FormRow.paddingH)

                DatePicker(L10n.Groups.Expense.date, selection: $date, displayedComponents: .date)
                    .font(DS.Typography.body)
                    .padding(.horizontal, DS.FormRow.paddingH)
                    .padding(.vertical, DS.FormRow.paddingV)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    // MARK: - Actions

    private var parsedAmount: Double {
        AmountInputHelper.parseDecimal(amountString)
    }

    private func handleSave() {
        guard parsedAmount > 0 else { return }
        isSaving = true

        do {
            try GroupExpenseService.shared.createSettlement(
                in: group,
                fromMemberID: debt.fromMemberID,
                toMemberID: debt.toMemberID,
                amount: parsedAmount,
                currencyCode: debt.currencyCode,
                note: note.isEmpty ? nil : note,
                date: date
            )
            DS.Haptic.success()
            TelemetryService.track(.groupSettlementCreated)
            isSaving = false
            onSave()
            dismiss()
        } catch {
            #if DEBUG
            print("SettlementFormView: Error saving: \(error)")
            #endif
            saveErrorMessage = error.localizedDescription
            showSaveError = true
            isSaving = false
        }
    }
}
