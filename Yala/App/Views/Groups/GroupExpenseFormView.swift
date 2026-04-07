//
//  GroupExpenseFormView.swift
//  Yala
//
//  Formulario de creación/edición de gastos compartidos.
//

import SwiftUI
import SwiftData

struct GroupExpenseFormView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme

    // MARK: - Input

    let group: SplitGroup
    let members: [SplitMember]
    let memberNameLookup: [String: String]
    let expenseToEdit: SplitExpense?
    let existingShares: [SplitShare]
    let onSave: () -> Void

    // MARK: - State

    @State private var viewModel: GroupExpenseViewModel
    @FocusState private var focusedField: ExpenseField?

    // Sheets
    @State private var showPaidByPicker = false
    @State private var showMemberSelector = false
    @State private var showCurrencyPicker = false

    // MARK: - Init

    init(
        group: SplitGroup,
        members: [SplitMember],
        memberNameLookup: [String: String],
        expenseToEdit: SplitExpense? = nil,
        existingShares: [SplitShare] = [],
        onSave: @escaping () -> Void
    ) {
        self.group = group
        self.members = members
        self.memberNameLookup = memberNameLookup
        self.expenseToEdit = expenseToEdit
        self.existingShares = existingShares
        self.onSave = onSave

        let vm = GroupExpenseViewModel(group: group, members: members, memberNameLookup: memberNameLookup)
        self._viewModel = State(initialValue: vm)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    // Amount input
                    amountSection

                    // Details
                    detailsSection

                    // Paid by
                    paidBySection

                    // Split
                    splitSection
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.sm)
                .padding(.bottom, DS.Spacing.safeBottom)
            }
            .background(PanelBackgroundView())
            .navigationTitle(viewModel.isEditMode ? L10n.Groups.Expense.editTitle : L10n.Groups.Expense.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    YalaSaveButton(action: handleSave, isDisabled: !viewModel.canSave)
                }
            }
            .onAppear {
                viewModel.setContext(modelContext)
                if let expense = expenseToEdit {
                    viewModel.prefill(from: expense, shares: existingShares)
                } else {
                    focusedField = .amount
                }
            }
            .sheet(isPresented: $showPaidByPicker) {
                MemberPickerView(
                    members: members,
                    memberNameLookup: memberNameLookup,
                    groupColorHex: group.colorHex,
                    mode: .singleSelect,
                    selectedMemberID: $viewModel.paidByMemberID,
                    selectedMemberIDs: .constant([]),
                    onSelectAll: {},
                    onDeselectAll: {}
                )
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showMemberSelector) {
                MemberPickerView(
                    members: members,
                    memberNameLookup: memberNameLookup,
                    groupColorHex: group.colorHex,
                    mode: .multiSelect,
                    selectedMemberID: .constant(""),
                    selectedMemberIDs: $viewModel.selectedMemberIDs,
                    onSelectAll: { viewModel.selectAllMembers() },
                    onDeselectAll: { viewModel.deselectAllMembers() }
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showCurrencyPicker) {
                CurrencySelectorView(selectedCurrency: currencyCodeBinding)
            }
        }
    }

    // MARK: - Amount Section

    private var amountSection: some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                Button {
                    showCurrencyPicker = true
                } label: {
                    Text(viewModel.currencyCode)
                        .font(DS.Typography.headline)
                        .foregroundStyle(.thAccent)
                }
                .buttonStyle(.plain)

                TextField("0.00", text: $viewModel.amountString)
                    .font(.system(size: 40, weight: .bold, design: .rounded)) // A11Y-DT: amount display, large by design
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .amount)
                    .onChange(of: viewModel.amountString) { _, newValue in
                        let filtered = AmountInputHelper.filterAmountInput(newValue)
                        if filtered != newValue {
                            viewModel.amountString = filtered
                        }
                    }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.xl)
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        SectionBox(title: L10n.Groups.Expense.descriptionLabel) {
            // Description
            VStack(spacing: DS.Spacing.none) {
                TextField(L10n.Groups.Expense.descriptionPlaceholder, text: $viewModel.expenseDescription)
                    .font(DS.Typography.body)
                    .padding(.horizontal, DS.FormRow.paddingH)
                    .padding(.vertical, DS.FormRow.paddingV)
                    .focused($focusedField, equals: .description)

                Divider().padding(.leading, DS.FormRow.paddingH)

                // Date
                DatePicker(L10n.Groups.Expense.date, selection: $viewModel.date, displayedComponents: .date)
                    .font(DS.Typography.body)
                    .padding(.horizontal, DS.FormRow.paddingH)
                    .padding(.vertical, DS.FormRow.paddingV)

                Divider().padding(.leading, DS.FormRow.paddingH)

                // Note
                TextField(L10n.Groups.Expense.notePlaceholder, text: $viewModel.note)
                    .font(DS.Typography.body)
                    .padding(.horizontal, DS.FormRow.paddingH)
                    .padding(.vertical, DS.FormRow.paddingV)
                    .focused($focusedField, equals: .note)
            }
        }
    }

    // MARK: - Paid By Section

    private var paidBySection: some View {
        SectionBox(title: L10n.Groups.Expense.paidByTitle) {
            Button {
                showPaidByPicker = true
            } label: {
                HStack(spacing: DS.Spacing.md) {
                    paidByAvatar

                    Text(memberNameLookup[viewModel.paidByMemberID] ?? "—")
                        .font(DS.Typography.body)
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(DS.Typography.captionSmall)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, DS.FormRow.paddingH)
                .padding(.vertical, DS.FormRow.paddingV)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var paidByAvatar: some View {
        ZStack {
            Circle()
                .fill(Color(hex: group.colorHex).opacity(0.2))
                .frame(width: 36, height: 36)

            let name = memberNameLookup[viewModel.paidByMemberID] ?? ""
            Text(String(name.prefix(1)).uppercased())
                .font(DS.Typography.label)
                .foregroundStyle(Color(hex: group.colorHex))
        }
    }

    // MARK: - Split Section

    private var splitSection: some View {
        SectionBox(title: L10n.Groups.Expense.divideBetween) {
            VStack(spacing: DS.Spacing.md) {
                // Member selector row
                Button {
                    showMemberSelector = true
                } label: {
                    HStack {
                        Text(L10n.Groups.Expense.membersSelected(viewModel.selectedMemberIDs.count, members.count))
                            .font(DS.Typography.body)
                            .foregroundStyle(.primary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(DS.Typography.captionSmall)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, DS.FormRow.paddingH)
                    .padding(.vertical, DS.FormRow.paddingV)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Divider().padding(.leading, DS.FormRow.paddingH)

                // Split selector
                GroupSplitSelectorView(viewModel: viewModel)
                    .padding(.bottom, DS.Spacing.sm)
            }
        }
    }

    // MARK: - Actions

    private func handleSave() {
        if viewModel.save() {
            DS.Haptic.success()
            onSave()
            dismiss()
        }
    }

    // MARK: - Helpers

    private var currencyCodeBinding: Binding<CurrencyCode> {
        Binding(
            get: { CurrencyCode(rawValue: viewModel.currencyCode) ?? .usd },
            set: { viewModel.currencyCode = $0.rawValue }
        )
    }
}

// MARK: - Focus Field

private enum ExpenseField: Hashable {
    case amount
    case description
    case note
}
