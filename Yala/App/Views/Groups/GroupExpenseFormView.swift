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

    /// Guard para evitar que `onTypeChange` del segmented dispare `showSplitDetail` al
    /// hidratar prefill / mount inicial (cuando el default del grupo no es `.equal`).
    /// Se setea a `true` al final de `onAppear`.
    @State private var didCompleteInitialPrefill = false

    // Opt-out: alert post-save cuando bridge effective OFF + Caso A.
    @State private var pendingOptInExpenseID: String?
    @State private var showOptInAlert: Bool = false

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
                    // Segmented control TOP-anchored: estabiliza el layout y evita
                    // el efecto "no estable" del sheet (sin nada anclado al top el
                    // contenido rebotaba al cambiar keyboard / contenido).
                    splitTypeSegmentedSelector
                        .padding(.top, DS.Spacing.sm)
                        .padding(.horizontal, DS.Spacing.lg)

                    Group {
                        Spacer()

                        centralContent

                        Spacer()

                        bottomChips
                            .padding(.bottom, DS.Spacing.lg)

                        registerButton
                            .padding(.horizontal, DS.Spacing.xl)
                            .padding(.bottom, DS.Spacing.xxl)
                    }
                }
                .dismissKeyboardOnTap()
            }
            .navigationTitle(viewModel.isEditMode ? L10n.Groups.Expense.editTitle : L10n.Groups.Expense.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                        dismiss()
                    }
                }
            }
            .alert(L10n.Groups.Bridge.optoutAlertTitle, isPresented: $showOptInAlert) {
                Button(L10n.Groups.Bridge.optoutAlertYes) { confirmOptIn() }
                Button(L10n.Groups.Bridge.optoutAlertNo, role: .cancel) { declineOptIn() }
            } message: {
                Text(L10n.Groups.Bridge.optoutAlertBody)
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
                // El guard se setea AL FINAL para que cualquier hidratación
                // programática del splitType desde prefill / init NO dispare el
                // auto-open del sheet via `onTypeChange`.
                didCompleteInitialPrefill = true
            }
            .sheet(isPresented: $showDatePicker) {
                DatePickerSheet(selectedDate: $viewModel.date)
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
                // NavigationStack para que el .toolbar con la "X" de CurrencySelectorView
                // se renderice (sin barra de navegación no hay dónde colocarlo).
                NavigationStack {
                    CurrencySelectorView(selectedCurrency: currencyCodeBinding)
                }
                .presentationDetents(DS.Adaptive.sheetDetents([.large]))
            }
            .sheet(isPresented: $showAccountSelector) {
                // M6: filtrado por moneda para que la cuenta seleccionada siempre sea compatible.
                AccountSelectorSheet(
                    selectedAccount: $viewModel.selectedAccount,
                    title: L10n.Transaction.account,
                    currencyFilter: viewModel.currencyCode
                )
                .presentationDetents(DS.Adaptive.sheetDetents([.medium, .large]))
            }
            .sheet(isPresented: $showSubcategorySelector) {
                SubcategorySelectorSheet(
                    selectedSubcategory: $viewModel.selectedSubcategory,
                    transactionType: .expense
                )
                .presentationDetents(DS.Adaptive.sheetDetents([.large]))
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
            splitChipDetail
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
        HStack(alignment: .center, spacing: DS.Spacing.md) {
            currencyChip

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

    // MARK: - Currency Chip

    /// Respeta `appPreferences.currencyDisplayFormat`: `.symbol` muestra "S/"/"£"/"$",
    /// `.code` muestra "PEN"/"GBP"/"USD".
    private var displayedCurrency: String {
        switch appPreferences.currencyDisplayFormat {
        case .symbol: return CurrencyCode.symbol(for: viewModel.currencyCode)
        case .code: return viewModel.currencyCode
        }
    }

    private var currencyChip: some View {
        Button {
            dismissKeyboard()
            showCurrencyPicker = true
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Text(displayedCurrency)
                    .font(DS.Typography.headline)
                Image(systemName: "chevron.down")
                    .font(DS.Typography.labelSmall)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, DS.FormRow.paddingV)
            .padding(.vertical, DS.Spacing.sm)
            .background(Capsule().fill(.thCard))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.Groups.Expense.currency)
    }

    // MARK: - Split Type Segmented Selector (TOP anchor)

    private var splitTypeSegmentedSelector: some View {
        SplitTypeSegmentedSelector(selectedType: $viewModel.splitType) { newType in
            // Guard: solo abre el sheet cuando el cambio fue por tap del user
            // (post-prefill / mount), requiere input (≠ .equal) y hay más de un
            // participante (con uno solo no hay nada que repartir).
            guard didCompleteInitialPrefill, newType != .equal, viewModel.isSplitConfigurable else { return }
            dismissKeyboard()
            showSplitDetail = true
        }
    }

    // MARK: - Split Chip Detail (debajo del monto)

    /// Reemplaza el antiguo `splitMethodChip`. Muestra el desglose dinámico de la
    /// división actual ("Tu: S/ 50 · Resto: S/ 50", etc.) según el output del
    /// `GroupSplitChipFormatter`. Chevron indica que es tappeable: abre el sheet.
    private var splitChipDetail: some View {
        Button {
            // Con un solo participante no hay nada que configurar: el chip queda informativo.
            guard viewModel.isSplitConfigurable else { return }
            dismissKeyboard()
            showSplitDetail = true
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                splitChipDetailContent
                if viewModel.splitType != .equal && !viewModel.isSharesBalanced {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(DS.Typography.labelTiny)
                        .foregroundStyle(Color.hotPink)
                }
                if viewModel.isSplitConfigurable {
                    Image(systemName: "chevron.right")
                        .font(DS.Typography.labelTiny)
                        .foregroundStyle(DS.Semantic.splitMethodForeground.opacity(0.6))
                }
            }
            .foregroundStyle(DS.Semantic.splitMethodForeground)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
            .background(Capsule().fill(DS.Semantic.splitMethodBackground))
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("group_expense_split_chip")
        .accessibilityLabel(splitChipAccessibilityLabel)
    }

    @ViewBuilder
    private var splitChipDetailContent: some View {
        let output = GroupSplitChipFormatter.format(input: chipFormatterInput)
        switch output.mode {
        case .fallbackTypeName, .warningUnbalanced:
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: viewModel.splitType.iconName)
                    .font(DS.Typography.label)
                Text(viewModel.splitType.displayName)
                    .font(DS.Typography.label)
            }
        case .youOnly(let yourAmount):
            HStack(spacing: DS.Spacing.xxs) {
                Text(L10n.Split.youLabel + ":")
                    .font(DS.Typography.label)
                Text(yourAmount)
                    .font(DS.Typography.label)
            }
        case .youPaidAll(let total):
            HStack(spacing: DS.Spacing.xs) {
                Text(L10n.Split.youPaidAll)
                    .font(DS.Typography.label)
                Text("·")
                    .font(DS.Typography.label)
                    .foregroundStyle(.secondary)
                Text(L10n.Split.totalLabel + ": " + total)
                    .font(DS.Typography.label)
            }
        case .notIncluded(let total):
            HStack(spacing: DS.Spacing.xs) {
                Text(L10n.Groups.Expense.notIncluded)
                    .font(DS.Typography.label)
                Text("·")
                    .font(DS.Typography.label)
                    .foregroundStyle(.secondary)
                Text(L10n.Split.totalLabel + ": " + total)
                    .font(DS.Typography.label)
            }
        case .youAndRest(let you, let rest):
            HStack(spacing: DS.Spacing.xs) {
                segmentText(label: L10n.Split.youLabel, segment: you)
                Text("·")
                    .font(DS.Typography.label)
                    .foregroundStyle(.secondary)
                segmentText(label: L10n.Split.restLabel, segment: rest)
            }
        }
    }

    @ViewBuilder
    private func segmentText(label: String, segment: GroupSplitChipFormatter.Output.Segment) -> some View {
        HStack(spacing: DS.Spacing.xxs) {
            Text(label + ": " + segment.amountString)
                .font(DS.Typography.label)
            if let suffix = segment.suffix {
                Text(suffix)
                    .font(DS.Typography.labelTiny)
                    .foregroundStyle(DS.Semantic.splitMethodForeground.opacity(0.7))
            }
        }
    }

    /// Construye el `Input` del formatter mapeando el state actual del VM.
    private var chipFormatterInput: GroupSplitChipFormatter.Input {
        GroupSplitChipFormatter.Input(
            total: viewModel.amount,
            splitType: viewModel.splitType,
            calculatedShares: viewModel.calculatedShares,
            participantValues: viewModel.participantValuesByID,
            currentUserMemberID: viewModel.currentUserMemberID,
            paidByMemberID: viewModel.paidByMemberID,
            selectedMemberIDs: viewModel.selectedMemberIDs,
            formatAmount: { value in
                appPreferences.currency(value, currencyCode: viewModel.currencyCode)
            },
            localizedSharesWord: L10n.Split.sharesParts
        )
    }

    /// VoiceOver label que describe el contenido del chip en lenguaje natural.
    private var splitChipAccessibilityLabel: String {
        let output = GroupSplitChipFormatter.format(input: chipFormatterInput)
        switch output.mode {
        case .fallbackTypeName, .warningUnbalanced:
            return viewModel.splitType.displayName
        case .youOnly(let amount):
            return "\(L10n.Split.youLabel) \(amount)"
        case .youPaidAll(let total):
            return "\(L10n.Split.youPaidAll). \(L10n.Split.totalLabel) \(total)"
        case .notIncluded(let total):
            return "\(L10n.Groups.Expense.notIncluded). \(L10n.Split.totalLabel) \(total)"
        case .youAndRest(let you, let rest):
            return "\(L10n.Split.youLabel) \(you.amountString). \(L10n.Split.restLabel) \(rest.amountString)"
        }
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
                // M6: chip cuenta personal real PRIMERO cuando aplica (Caso A `.full/.completed`).
                // Si no aplica (Caso B / .groupInvite), los demás chips corren a la izquierda.
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
        guard viewModel.save() else { return }
        DS.Haptic.success()

        // Opt-out: si Caso A + bridge effective OFF + creación (no edit), preguntar al
        // user si quiere crear movimiento personal opt-in. Caso C tiene su propio alert
        // en SettlementFormView. Casos B/D no aplican.
        if !viewModel.effectiveBridgeEnabled,
           viewModel.isCaseA,
           let createdID = viewModel.lastCreatedExpenseID {
            pendingOptInExpenseID = createdID
            showOptInAlert = true
            return  // diferir dismiss hasta resolver alert
        }

        onSave()
        dismiss()
    }

    /// Crea el draft opt-in y dismiss. Llamado desde el alert "Sí".
    private func confirmOptIn() {
        guard let expenseID = pendingOptInExpenseID else { return }
        do {
            try DraftService.shared.createGroupExpenseOptInDraft(
                splitExpenseID: expenseID,
                groupZoneID: group.cloudKitZoneID
            )
        } catch {
            #if DEBUG
            print("GroupExpenseFormView: createGroupExpenseOptInDraft failed: \(error)")
            #endif
        }
        pendingOptInExpenseID = nil
        onSave()
        dismiss()
    }

    /// User dice "No" al alert opt-in: dismiss sin crear draft.
    private func declineOptIn() {
        pendingOptInExpenseID = nil
        onSave()
        dismiss()
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
}
