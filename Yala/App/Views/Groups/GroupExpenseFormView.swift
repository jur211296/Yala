//
//  GroupExpenseFormView.swift
//  Yala
//
//  Formulario de creación/edición de gastos compartidos.
//  Layout hero centrado — identidad visual con NewTransactionView.
//

import SwiftUI
import SwiftData

struct GroupExpenseFormView: View {

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme
    @Environment(AppPreferences.self) private var appPreferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
    @State private var showDatePicker = false
    @State private var showSubcategorySelector = false
    @State private var showSplitDetail = false
    @State private var showAccountSelector = false  // M6 Caso A

    // Amount scaling
    @ScaledMetric(relativeTo: .largeTitle) private var baseAmountSize: CGFloat = 64 // A11Y-DT: @ScaledMetric

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
            ZStack {
                PanelBackgroundView()

                VStack(spacing: DS.Spacing.none) {
                    Spacer()

                    centralContent

                    Spacer()

                    bottomChips
                        .padding(.bottom, DS.Spacing.lg)

                    registerButton
                        .padding(.horizontal, DS.Spacing.xl)
                        .padding(.bottom, DS.Spacing.xxl)
                }
                .dismissKeyboardOnTap()
            }
            // #35: GroupDetailView padre tiene `.refreshable { viewModel.loadData() }`
            // que en iOS 26 se propaga al sheet del form, generando "gelatina"
            // visual en bottomChips y permitiendo pull-to-refresh sin sentido.
            // No-op refreshable absorbe el gesto sin acción.
            .refreshable {}
            .navigationTitle(viewModel.isEditMode ? L10n.Groups.Expense.editTitle : L10n.Groups.Expense.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.setContext(modelContext)
                if let expense = expenseToEdit {
                    viewModel.prefill(from: expense, shares: existingShares)
                } else {
                    focusedField = .amount
                }
                // M6: defensa profundidad — si VM no resolvió current user (members no cargados),
                // canSave queda bloqueado pero el form sigue navegable.
                #if DEBUG
                if !viewModel.isReady {
                    print("GroupExpenseFormView: VM not ready (currentUserMemberID nil) — canSave will block save")
                }
                #endif
            }
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(selectedDate: $viewModel.date)
                    .presentationDetents([.medium, .large])
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
            .sheet(isPresented: $showAccountSelector) {
                // M6: filtrado por moneda para que la cuenta seleccionada siempre sea compatible.
                AccountSelectorSheet(
                    selectedAccount: $viewModel.selectedAccount,
                    title: L10n.Transaction.account,
                    currencyFilter: viewModel.currencyCode
                )
            }
            .sheet(isPresented: $showSubcategorySelector) {
                SubcategorySelectorSheet(
                    selectedSubcategory: $viewModel.selectedSubcategory,
                    transactionType: .expense
                )
            }
            .sheet(isPresented: $showSplitDetail) {
                splitDetailSheet
                }
            // M6: si user cambia moneda y la cuenta seleccionada deja de ser compatible,
            // se limpia. El form vuelve a pedir cuenta antes de guardar (canSave bloquea).
            .onChange(of: viewModel.currencyCode) { _, _ in
                viewModel.resetAccountIfIncompatible()
            }
        }
    }

    // MARK: - Central Content

    private var centralContent: some View {
        VStack(spacing: DS.Spacing.xxl) {
            dateChip
            descriptionField
            amountDisplay
            splitMethodChip
            noteField
            categoryChip
        }
    }

    // MARK: - Date Chip

    private var dateChip: some View {
        Button {
            showDatePicker = true
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "calendar")
                    .font(DS.Typography.label)
                Text(dateChipText)
                    .font(DS.Typography.label)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .background(
                Capsule()
                    .fill(Color.primary.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }

    private var dateChipText: String {
        if Calendar.current.isDateInToday(viewModel.date) { return L10n.Date.today }
        if Calendar.current.isDateInYesterday(viewModel.date) { return L10n.Date.yesterday }
        return viewModel.date.formatted(.dateTime.day().month(.abbreviated))
    }

    // MARK: - Description Field

    private var descriptionField: some View {
        TextField(L10n.Groups.Expense.descriptionPlaceholder, text: $viewModel.expenseDescription)
            .font(DS.Typography.title)
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)
            .textContentType(.none)
            .autocorrectionDisabled(false)
            .focused($focusedField, equals: .description)
            .frame(maxWidth: 280)
            .tint(Color.primary)
            .accessibilityLabel(L10n.Groups.Expense.descriptionPlaceholder)
    }

    // MARK: - Amount Display

    private var amountFontSize: CGFloat {
        let length = viewModel.amountString.count
        let ratio: CGFloat
        switch length {
        case 0...7: ratio = 1.0
        case 8...9: ratio = 54.0 / 64.0
        case 10...11: ratio = 46.0 / 64.0
        case 12...13: ratio = 38.0 / 64.0
        default: ratio = 32.0 / 64.0
        }
        return baseAmountSize * ratio
    }

    private var amountDisplay: some View {
        HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xxs) {
            Button {
                dismissKeyboard()
                showCurrencyPicker = true
            } label: {
                Text(appPreferences.currencyIdentifier(for: viewModel.currencyCode))
                    .font(.system(size: amountFontSize * 0.44, weight: .medium, design: .rounded))
                    .foregroundStyle(theme.accent.opacity(0.7))
                    .contentTransition(.numericText())
            }
            .buttonStyle(.plain)

            TextField("0.00", text: $viewModel.amountString)
                .font(.system(size: amountFontSize, weight: .bold, design: .rounded))
                .foregroundStyle(theme.accent)
                .multilineTextAlignment(.center)
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: .amount)
                .accessibilityIdentifier("group_expense_amount")
                .fixedSize(horizontal: true, vertical: false)
                .onChange(of: focusedField) { _, newFocus in
                    if newFocus == .amount
                        && (viewModel.amountString == "0" || viewModel.amountString == "0.00" || viewModel.amountString == "0,00")
                    {
                        viewModel.amountString = ""
                    }
                    if newFocus != .amount {
                        if viewModel.amountString.isEmpty {
                            viewModel.amountString = "0.00"
                        } else {
                            viewModel.amountString = AmountInputHelper.formatWithGrouping(viewModel.amount)
                        }
                    }
                }
                .onChange(of: viewModel.amountString) { _, newValue in
                    let filtered = AmountInputHelper.filterAmountInput(newValue)
                    if filtered != newValue {
                        viewModel.amountString = filtered
                    }
                }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    // MARK: - Split Method Chip

    private var splitMethodChip: some View {
        Menu {
            ForEach(SplitType.allCases) { type in
                Button {
                    viewModel.splitType = type
                    if type != .equal {
                        showSplitDetail = true
                    }
                } label: {
                    Label(type.displayName, systemImage: type.iconName)
                }
            }
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: viewModel.splitType.iconName)
                    .font(DS.Typography.label)
                Text(viewModel.splitType.displayName)
                    .font(DS.Typography.label)
                if viewModel.splitType != .equal && !viewModel.isSharesBalanced {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(DS.Typography.labelTiny)
                        .foregroundStyle(Color.hotPink)
                }
            }
            .foregroundStyle(DS.Semantic.splitMethodForeground)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
            .background(Capsule().fill(DS.Semantic.splitMethodBackground))
        }
    }

    // MARK: - Note Field

    private var noteField: some View {
        // A11Y-DM: tertiaryLabel system-managed dark mode (placeholder más claro que .secondary).
        TextField(L10n.Groups.Expense.notePlaceholder, text: $viewModel.note)
            .font(DS.Typography.caption)
            .foregroundStyle(Color(.tertiaryLabel))
            .multilineTextAlignment(.center)
            .frame(maxWidth: 200)
            .focused($focusedField, equals: .note)
            .accessibilityLabel(L10n.Groups.Expense.notePlaceholder)
    }

    // MARK: - Category Chip

    @ViewBuilder
    private var categoryChip: some View {
        if let subcategory = viewModel.selectedSubcategory {
            let category = subcategory.safeCategory
            let categoryColor = Color(hex: category.colorHex)
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: category.iconName ?? "folder")
                    .font(DS.Typography.labelTiny)
                    .accessibilityHidden(true)
                Text(category.name)
                    .font(DS.Typography.labelTiny)
            }
            .foregroundStyle(categoryColor)
            .padding(.horizontal, DS.Chip.paddingH)
            .padding(.vertical, DS.Chip.paddingV)
            .background(Capsule().fill(categoryColor.opacity(0.12)))
        }
    }

    // MARK: - Bottom Chips

    private var bottomChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm) {
                SelectionChip(
                    icon: "tag",
                    text: viewModel.selectedSubcategory?.name ?? L10n.Transaction.subcategory,
                    isSelected: viewModel.selectedSubcategory != nil,
                    color: subcategoryChipColor
                ) {
                    dismissKeyboard()
                    showSubcategorySelector = true
                }

                SelectionChip(
                    icon: "person.fill",
                    text: paidByChipText,
                    isSelected: !viewModel.paidByMemberID.isEmpty,
                    color: !viewModel.paidByMemberID.isEmpty ? Color(hex: group.colorHex) : nil
                ) {
                    dismissKeyboard()
                    showPaidByPicker = true
                }

                SelectionChip(
                    icon: "person.2",
                    text: L10n.Groups.Expense.membersSelected(viewModel.selectedMemberIDs.count, members.count),
                    isSelected: !viewModel.selectedMemberIDs.isEmpty,
                    color: !viewModel.selectedMemberIDs.isEmpty ? Color(hex: group.colorHex) : nil
                ) {
                    dismissKeyboard()
                    showMemberSelector = true
                }

                // M6: chip cuenta personal real solo si Caso A `.full/.completed`.
                if viewModel.isAccountRequired {
                    SelectionChip(
                        icon: "creditcard",
                        text: viewModel.selectedAccount?.name ?? L10n.Transaction.account,
                        isSelected: viewModel.selectedAccount != nil,
                        color: viewModel.selectedAccount.map { Color(hex: $0.colorHex) }
                    ) {
                        dismissKeyboard()
                        showAccountSelector = true
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.xl)
        }
    }

    private var paidByChipText: String {
        if viewModel.paidByMemberID.isEmpty {
            return L10n.Groups.Expense.paidByTitle
        }
        return memberNameLookup[viewModel.paidByMemberID] ?? "—"
    }

    private var subcategoryChipColor: Color? {
        guard let sub = viewModel.selectedSubcategory else { return nil }
        return Color(hex: sub.safeCategory.colorHex)
    }

    // MARK: - Split Detail Sheet

    private var splitDetailSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    GroupSplitSelectorView(viewModel: viewModel)
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.md)
            }
            .yalaScreenBackground()
            .navigationTitle(L10n.Groups.Expense.divideBetween)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        showSplitDetail = false
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    // MARK: - Register Button

    private var registerButton: some View {
        Button {
            handleSave()
        } label: {
            HStack {
                if viewModel.isSaving {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .font(DS.Typography.headline)
                    Text(L10n.Action.save)
                        .font(DS.Typography.headline)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(viewModel.canSave ? theme.accent : DS.Semantic.disabledForeground.opacity(0.4))
        .controlSize(.large)
        .disabled(!viewModel.canSave || viewModel.isSaving)
        .accessibilityIdentifier("group_expense_save")
        .dsAnimation(.easeInOut(duration: 0.2), value: viewModel.canSave, reduceMotion: reduceMotion)
    }

    // MARK: - Actions

    private func handleSave() {
        if viewModel.save() {
            DS.Haptic.success()
            onSave()
            dismiss()
        }
    }

    private func dismissKeyboard() {
        focusedField = nil
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
