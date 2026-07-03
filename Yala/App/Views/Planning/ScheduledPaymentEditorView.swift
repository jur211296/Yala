//
//  ScheduledPaymentEditorView.swift
//  Yala
//
//  Editor sheet for creating and editing scheduled payments
//

import SwiftData
import SwiftUI

struct ScheduledPaymentPrefill {
    let transactionType: String
    let amount: String
    let note: String
    let account: Account?
    let subcategory: Subcategory?
    let tagIDs: Set<PersistentIdentifier>
    let needOverride: SubcategoryNeed?
    let currencyCode: String
    let transactionDate: Date
}

struct ScheduledPaymentEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.yalaTheme) private var theme
    @ScaledMetric(relativeTo: .largeTitle) private var scaledAmountSize: CGFloat = 28 // A11Y-DT: @ScaledMetric
    @Environment(EntityDeletionService.self) private var deletionService
    @Environment(SessionState.self) private var sessionState

    @State private var viewModel = ScheduledPaymentEditorViewModel()

    @Environment(AppPreferences.self) private var appPreferences

    let payment: ScheduledPayment?
    let defaultCategory: String?
    var onDelete: (() -> Void)?
    let prefill: ScheduledPaymentPrefill?
    let onSaved: ((UUID) -> Void)?

    // Error state
    @State private var showSaveError = false

    // Basic Info
    @State private var name: String = ""
    @State private var amount: String = ""
    @State private var note: String = ""

    // Type
    @State private var transactionType: String = "expense"
    @State private var paymentCategory: PaymentCategory = .recurring
    @State private var isSubscription: Bool = false

    // Classification
    @State private var selectedAccount: Account?
    @State private var selectedSubcategory: Subcategory?
    @State private var selectedTags: Set<PersistentIdentifier> = []

    // Nature override
    @State private var selectedNeed: SubcategoryNeed?

    // Recurrence
    @State private var isRecurring: Bool = true
    @State private var recurrenceType: RecurrenceType = .monthly
    @State private var recurrenceInterval: Int = 1
    @State private var paymentDate: Date = Calendar.current.startOfDay(for: Date.now)  // For one-time or start date
    @State private var dayOfMonth: Int = 1
    @State private var selectedWeekdays: Set<Int> = [2]  // Default Monday (2)
    @State private var yearlyMonth: Int = 1
    @State private var yearlyDay: Int = 1
    @State private var endDate: Date? = nil
    @State private var hasEndDate: Bool = false

    // Notifications
    @State private var notifyOnDueDate: Bool = true
    @State private var notifyDaysBefore: Int = 3

    // Amount type
    @State private var isVariableAmount: Bool = false

    // Status
    @State private var isActive: Bool = true

    // Preview
    @State private var previewDates: [Date] = []

    // Sheet states
    @State private var showAccountSheet = false
    @State private var showCategoriesSheet = false
    @State private var showDeleteConfirmation = false

    // MARK: - Group Shared Expense State (F3)
    /// Toggle "¿Es un gasto compartido?". Al ON, el pago genera un gasto de grupo (no una TX personal).
    @State private var isGroupExpense: Bool = false
    @State private var availableGroups: [SplitGroup] = []
    @State private var selectedGroup: SplitGroup?
    @State private var groupMembers: [SplitMember] = []
    /// VM transitorio del gasto de grupo — SOLO alimenta `GroupSplitSelectorView`.
    /// NUNCA se le llama `save()` aquí (crearía un SplitExpense prematuro).
    @State private var splitExpenseVM: GroupExpenseViewModel?
    @State private var splitCurrency: CurrencyCode = .usd
    /// Config de división extraída del VM al cerrar el sheet — alimenta resumen + guardado.
    @State private var splitConfigType: SplitType = .equal
    @State private var splitParticipantIDs: [UUID] = []
    @State private var splitValues: [UUID: Double] = [:]
    @State private var splitMyShare: Double = 0
    @State private var splitConfigured: Bool = false
    @State private var showGroupPicker = false
    @State private var showSplitCurrencyPicker = false
    @State private var showSplitSheet = false

    // Focus state
    @FocusState private var isNameFieldFocused: Bool
    @FocusState private var isAmountFieldFocused: Bool
    @FocusState private var isNoteFieldFocused: Bool

    private var today: Date {
        Calendar.current.startOfDay(for: Date.now)
    }

    init(
        payment: ScheduledPayment?,
        defaultCategory: String? = nil,
        onDelete: (() -> Void)? = nil,
        prefill: ScheduledPaymentPrefill? = nil,
        onSaved: ((UUID) -> Void)? = nil
    ) {
        self.payment = payment
        self.defaultCategory = defaultCategory
        self.onDelete = onDelete
        self.prefill = prefill
        self.onSaved = onSaved
    }

    var body: some View {
        NavigationStack {
            editorScrollView
                .navigationTitle(editorTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { editorToolbar }
                .modifier(EditorSheets(
                    showCategoriesSheet: $showCategoriesSheet,
                    selectedSubcategory: $selectedSubcategory,
                    transactionType: transactionType,
                    showGroupPicker: $showGroupPicker,
                    availableGroups: availableGroups,
                    selectedGroupID: selectedGroup?.id ?? UUID(),
                    memberCount: { activeMemberCount(for: $0) },
                    onSelectGroup: { selectGroup($0) },
                    showSplitCurrencyPicker: $showSplitCurrencyPicker,
                    splitCurrency: $splitCurrency,
                    showSplitSheet: $showSplitSheet,
                    splitExpenseVM: splitExpenseVM,
                    onSplitSheetDismiss: { extractSplitConfigFromVM() }
                ))
                .onChange(of: splitCurrency) { _, newCode in
                    applySplitCurrency(newCode)
                }
                .onAppear { handleOnAppear() }
                .modifier(RecurrencePreviewObservers(
                    isRecurring: isRecurring,
                    recurrenceType: recurrenceType,
                    recurrenceInterval: recurrenceInterval,
                    paymentDate: paymentDate,
                    dayOfMonth: dayOfMonth,
                    selectedWeekdays: selectedWeekdays,
                    yearlyMonth: yearlyMonth,
                    yearlyDay: yearlyDay,
                    hasEndDate: hasEndDate,
                    endDate: endDate,
                    onDismissKeyboard: { dismissEditorKeyboard() },
                    onUpdatePreview: { updatePreviewDates() }
                ))
                .onChange(of: isSubscription) { _, new in paymentCategory = new ? .subscription : .recurring }
                .onChange(of: showCategoriesSheet) { _, isPresenting in
                    if isPresenting { dismissEditorKeyboard() }
                }
                .modifier(EditorAlerts(
                    deleteAlertTitle: deleteAlertTitle,
                    showDeleteConfirmation: $showDeleteConfirmation,
                    onConfirmDelete: { deletePayment() },
                    saveErrorFlag: viewModel.showSaveError,
                    showSaveError: $showSaveError,
                    onDismissSaveError: { viewModel.dismissSaveError() }
                ))
        }
    }

    private var editorTitle: String {
        payment == nil
            ? NSLocalizedString("scheduled.new", comment: "")
            : NSLocalizedString("scheduled.edit", comment: "")
    }

    private var deleteAlertTitle: String {
        NSLocalizedString("scheduled.delete.confirm.title", comment: "")
    }

    private var editorScrollView: some View {
        ScrollView {
            editorContent
                .dismissKeyboardOnTap()
        }
        .scrollViewGlassEdges()
        .scrollDismissesKeyboard(.interactively)
        .yalaScreenBackground(.subtle)
    }

    @ToolbarContentBuilder
    private var editorToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            YalaToolbarButton(systemName: "xmark", label: L10n.Action.close) {
                dismiss()
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            YalaSaveButton(action: savePayment, isDisabled: !canSave)
                .accessibilityHint(!canSave ? L10n.Accessibility.createAccountFirst : "")
        }
    }

    private func handleOnAppear() {
        viewModel.setContext(modelContext, deletionService: deletionService)
        loadPaymentData()
        if sessionState.isExpensesOnlyMode {
            transactionType = "expense"
        }
        if payment == nil && prefill == nil {
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                isNameFieldFocused = true
            }
        }
        updatePreviewDates()
    }

    // MARK: - Editor Content

    private var editorContent: some View {
        VStack(spacing: DS.Spacing.xxl) {
            // Contextual guide for new users creating first scheduled payment
            if payment == nil {
                ContextualGuideBanner.scheduledEditor()
            }

            basicInfoSection
            togglesSection
            if isGroupExpense {
                groupExpenseConfigSection
            }
            classificationSection
            recurrenceSection
            if isRecurring {
                recurrencePreviewSection
            }
            notificationsSection
            if payment != nil {
                deleteSection
            }
        }
        .padding(.vertical, DS.Spacing.xxl)
    }

    // MARK: - Basic Information Section

    private var basicInfoSection: some View {
        SectionBox(title: NSLocalizedString("scheduled.editor.basic.info", comment: "")) {
            VStack(spacing: DS.Spacing.none) {
                // Transaction Type (Income/Expense) — oculto en gasto compartido (siempre gasto)
                if !sessionState.isExpensesOnlyMode && !isGroupExpense {
                    Picker("", selection: $transactionType) {
                        Text(NSLocalizedString("transaction.type.expense", comment: "")).tag("expense")
                        Text(NSLocalizedString("transaction.type.income", comment: "")).tag("income")
                    }
                    .pickerStyle(.segmented)
                    .padding()
                }

                SubsectionDivider()

                // Name Field
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "textformat")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    TextField(
                        NSLocalizedString("scheduled.editor.name.placeholder", comment: ""),
                        text: $name
                    )
                    .textContentType(.name)
                    .focused($isNameFieldFocused)
                    .accessibilityIdentifier("scheduled_name_field")
                }
                .padding()

                SubsectionDivider()

                // Amount Field
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                        if isGroupExpense {
                            Text("\(L10n.Scheduled.GroupExpense.totalHint) · \(splitCurrency.rawValue)")
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                        } else if let account = selectedAccount {
                            Text(account.currencyCode)
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: scaledAmountSize, weight: .bold))
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                            .accessibilityIdentifier("scheduled_amount_field")
                            .foregroundStyle(transactionType == "income" ? Color.electricIndigo : .primary)
                            .focused($isAmountFieldFocused)
                            .onChange(of: isAmountFieldFocused) { _, isFocused in
                                if isFocused && (amount == "0" || amount == "0.00" || amount == "0,00") {
                                    amount = ""
                                }
                                if !isFocused && !amount.isEmpty {
                                    let value = AmountInputHelper.parseDecimal(amount)
                                    amount = AmountInputHelper.formatWithGrouping(value)
                                }
                            }
                            .onChange(of: amount) { _, newValue in
                                let filtered = AmountInputHelper.filterAmountInput(newValue)
                                if filtered != newValue {
                                    amount = filtered
                                }
                            }
                    }
                }
                .padding()

                SubsectionDivider()

                // Variable Amount Toggle
                Toggle(isOn: $isVariableAmount) {
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: "plusminus")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            Text(L10n.Scheduled.VariableAmount.toggle)
                            if isVariableAmount {
                                Text(L10n.Scheduled.VariableAmount.helper)
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding()

                SubsectionDivider()

                // Note Field
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "note.text")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    TextField(
                        NSLocalizedString("scheduled.editor.note.placeholder", comment: ""),
                        text: $note
                    )
                    .focused($isNoteFieldFocused)
                }
                .padding()
            }
        }
    }

    // MARK: - Toggles Section

    private var togglesSection: some View {
        SectionBox(title: NSLocalizedString("scheduled.editor.options", comment: "")) {
            VStack(spacing: DS.Spacing.none) {
                // Active Toggle
                Toggle(isOn: $isActive) {
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                            .accessibilityHidden(true)
                        Text(NSLocalizedString("common.active", comment: ""))
                    }
                }

                .padding()

                SubsectionDivider()

                // Group Shared Expense Toggle (F3) — entre Activo y Suscripción
                Toggle(isOn: $isGroupExpense) {
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: "person.2")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                            Text(L10n.Scheduled.GroupExpense.toggle)
                            if isGroupExpense {
                                Text(L10n.Scheduled.GroupExpense.toggleHelper)
                                    .font(DS.Typography.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding()
                .accessibilityIdentifier("scheduled_group_expense_toggle")
                .onChange(of: isGroupExpense) { _, on in
                    if on {
                        transactionType = "expense"   // gasto compartido = siempre gasto
                        loadAvailableGroups()
                    }
                }

                SubsectionDivider()

                // Subscription Toggle
                Toggle(isOn: $isSubscription) {
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                            .accessibilityHidden(true)
                        Text(NSLocalizedString("scheduled.is.subscription", comment: ""))
                    }
                }

                .padding()
            }
        }
    }

    // MARK: - Group Shared Expense Config Section (F3)

    /// Filas de configuración del gasto compartido (Grupo → Moneda → División).
    /// Visible solo cuando `isGroupExpense`. Reusa GroupPickerSheet / CurrencyPickerSheet /
    /// GroupSplitSelectorView sin modificarlas.
    private var groupExpenseConfigSection: some View {
        SectionBox(title: L10n.Scheduled.GroupExpense.sectionTitle) {
            VStack(spacing: DS.Spacing.none) {
                groupRow
                SubsectionDivider()
                splitCurrencyRow
                SubsectionDivider()
                splitDivisionRow
            }
        }
    }

    private var groupRow: some View {
        Button {
            loadAvailableGroups()
            showGroupPicker = true
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                Text(L10n.Scheduled.GroupExpense.groupRow)
                    .foregroundStyle(.primary)
                Spacer()
                if let group = selectedGroup {
                    Text(group.name)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(NSLocalizedString("common.select", comment: ""))
                        .foregroundStyle(Color.hotPink.opacity(0.8))
                }
                Image(systemName: "chevron.right")
                    .font(DS.Typography.indicator)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("scheduled_group_row")
    }

    private var splitCurrencyRow: some View {
        Button {
            showSplitCurrencyPicker = true
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "coloncurrencysign.circle")
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                Text(L10n.Scheduled.GroupExpense.currencyRow)
                    .foregroundStyle(.primary)
                Spacer()
                Text(splitCurrency.rawValue)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(DS.Typography.indicator)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(selectedGroup == nil)
        .accessibilityIdentifier("scheduled_split_currency_row")
    }

    private var splitDivisionRow: some View {
        Button {
            openSplitSheet()
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "chart.pie.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                Text(L10n.Scheduled.GroupExpense.divisionRow)
                    .foregroundStyle(.primary)
                Spacer()
                if splitConfigured {
                    Text(splitSummaryText)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .multilineTextAlignment(.trailing)
                } else {
                    Text(NSLocalizedString("common.select", comment: ""))
                        .foregroundStyle(Color.hotPink.opacity(0.8))
                }
                Image(systemName: "chevron.right")
                    .font(DS.Typography.indicator)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(selectedGroup == nil)
        .accessibilityIdentifier("scheduled_split_division_row")
    }

    /// Resumen "Entre N · {modo} · Tu parte S/X" para la fila División.
    private var splitSummaryText: String {
        let count = splitParticipantIDs.count
        let mode = splitConfigType.shortName
        let share = appPreferences.currency(splitMyShare, currencyCode: splitCurrency.rawValue)
        return L10n.Scheduled.GroupExpense.splitSummary(count, mode, share)
    }

    // MARK: - Classification Section

    private var classificationSection: some View {
        SectionBox(title: NSLocalizedString("scheduled.editor.classification", comment: "")) {
            VStack(spacing: DS.Spacing.none) {
                // Account selector
                accountRow

                SubsectionDivider()

                // Subcategory selector
                subcategoryRow

                // Tags — ocultas en gasto compartido (los gastos de grupo no manejan etiquetas)
                if !isGroupExpense {
                    SubsectionDivider()
                    tagsContent
                }
            }
        }
    }

    /// Cuentas disponibles para el picker. En gasto compartido, filtradas a la moneda elegida.
    private var accountOptions: [Account] {
        guard isGroupExpense else { return viewModel.activeAccounts }
        return viewModel.activeAccounts.filter { $0.currencyCode == splitCurrency.rawValue }
    }

    private var accountRow: some View {
        Menu {
            ForEach(accountOptions) { account in
                Button {
                    selectedAccount = account
                } label: {
                    HStack {
                        Text(account.name)
                        if selectedAccount?.persistentModelID == account.persistentModelID {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                .accessibilityIdentifier("scheduled_account_option_\(account.name)")
            }
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "creditcard")
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                Text(NSLocalizedString("scheduled.editor.account", comment: ""))
                    .foregroundStyle(.primary)

                Spacer()

                if let account = selectedAccount {
                    HStack(spacing: DS.Spacing.xs) {
                        Circle()
                            .fill(Color(hex: account.colorHex))
                            .frame(width: 10, height: 10)
                        Text(account.name)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(NSLocalizedString("common.select", comment: ""))
                        .foregroundStyle(Color.hotPink.opacity(0.8))
                }

                if !accountOptions.isEmpty {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(DS.Typography.indicator)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(accountOptions.isEmpty ? L10n.Accessibility.createAccountFirst : "")
        .accessibilityIdentifier("scheduled_account_menu")
        .disabled(accountOptions.isEmpty)
    }

    private var subcategoryRow: some View {
        Button {
            showCategoriesSheet = true
        } label: {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "tag")
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                Text(NSLocalizedString("scheduled.editor.subcategory", comment: ""))
                    .foregroundStyle(.primary)

                Spacer()

                if let subcategory = selectedSubcategory {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: subcategory.iconName ?? "tag.fill")
                            .font(DS.Typography.caption)
                            .foregroundStyle(Color(hex: subcategory.colorHex ?? subcategory.safeCategory.colorHex))
                        Text(subcategory.name)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(NSLocalizedString("common.select", comment: ""))
                        .foregroundStyle(Color.hotPink.opacity(0.8))
                }

                Image(systemName: "chevron.right")
                    .font(DS.Typography.indicator)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("scheduled_subcategory_row")
    }

    private var tagsContent: some View {
        FilterChipsSection(
            icon: "number",
            title: NSLocalizedString("settings.tags", comment: ""),
            status: selectedTagsText,
            items: viewModel.activeTags,
            showEmptyPlaceholder: true
        ) { tag in
            tagChip(tag)
        }
    }

    private func tagChip(_ tag: Tag) -> some View {
        let isSelected = selectedTags.contains(tag.persistentModelID)

        return Button {
            if isSelected {
                selectedTags.remove(tag.persistentModelID)
            } else {
                selectedTags.insert(tag.persistentModelID)
            }
        } label: {
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: tag.iconName)
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(isSelected ? .white : Color(hex: tag.colorHex))

                Text(tag.name)
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(
                Capsule()
                    .fill(isSelected ? Color(hex: tag.colorHex) : Color(.tertiarySystemFill))
            )
        }
        .buttonStyle(.plain)
    }

    private var selectedTagsText: String {
        if selectedTags.isEmpty {
            return NSLocalizedString("filters.none", comment: "")
        }
        return "\(selectedTags.count)"
    }

    private var maxInterval: Int {
        switch recurrenceType {
        case .daily: return 30
        case .weekly: return 12
        case .monthly: return 12
        case .yearly: return 5
        }
    }

    // MARK: - Recurrence Section

    private var recurrenceSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                Text(L10n.Scheduled.Editor.recurrence)
                    .font(DS.Typography.headline)
                    .foregroundStyle(.thSecondaryText)
                InfoHintButton(
                    title: L10n.Scheduled.Help.title,
                    message: L10n.Scheduled.Help.message
                )
            }
            .padding(.leading, DS.Spacing.sm)

            VStack(spacing: DS.Spacing.none) {
                // One-time vs Recurring toggle
                Picker("", selection: $isRecurring) {
                    Text(NSLocalizedString("scheduled.recurrence.onetime", comment: "")).tag(false)
                    Text(NSLocalizedString("scheduled.recurrence.recurring", comment: "")).tag(true)
                }
                .pickerStyle(.segmented)
                .padding()

                SubsectionDivider()

                if !isRecurring {
                    // ONE-TIME: Just payment date
                    paymentDateRow
                } else {
                    // RECURRING: Interval + Type + conditional fields
                    recurrenceIntervalRow

                    SubsectionDivider()

                    // Conditional fields based on recurrence type
                    switch recurrenceType {
                    case .daily:
                        // Nothing extra needed
                        EmptyView()
                    case .weekly:
                        weekdaySelector
                        SubsectionDivider()
                    case .monthly:
                        dayOfMonthPicker
                        SubsectionDivider()
                    case .yearly:
                        yearlyDatePicker
                        SubsectionDivider()
                    }

                    // Start date
                    startDateRow

                    SubsectionDivider()

                    // End date (optional)
                    endDateSection
                }
            }
            .solidCard()
        }
    }

    private var paymentDateRow: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "calendar")
                .foregroundStyle(.secondary)
                .frame(width: 24)
                .accessibilityHidden(true)

            Text(NSLocalizedString("scheduled.payment.date", comment: ""))
                .foregroundStyle(.primary)

            Spacer()

            DateFieldButton(
                date: $paymentDate,
                minDate: (payment == nil && prefill == nil) ? today : .distantPast,
                title: NSLocalizedString("scheduled.payment.date", comment: "")
            )
        }
        .padding()
    }

    private var recurrenceIntervalRow: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "repeat")
                .foregroundStyle(.secondary)
                .frame(width: 24)
                .accessibilityHidden(true)

            Text(NSLocalizedString("scheduled.every", comment: ""))
                .foregroundStyle(.primary)

            Spacer()

            Picker("", selection: $recurrenceInterval) {
                ForEach(1...maxInterval, id: \.self) { num in
                    Text("\(num)").tag(num)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 60)
            .onChange(of: recurrenceType) {
                // Clamp interval when switching to a type with lower max
                if recurrenceInterval > maxInterval {
                    recurrenceInterval = maxInterval
                }
            }

            Picker("", selection: $recurrenceType) {
                ForEach(RecurrenceType.allCases) { type in
                    Text(recurrenceInterval == 1 ? type.localizedNameSingular : type.localizedNamePlural)
                        .tag(type)
                }
            }
            .pickerStyle(.menu)
        }
        .padding()
    }

    private var weekdaySelector: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "calendar.day.timeline.left")
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                    .accessibilityHidden(true)

                Text(NSLocalizedString("scheduled.which.days", comment: ""))
                    .foregroundStyle(.primary)
            }

            // Weekday chips
            HStack(spacing: DS.Spacing.sm) {
                ForEach(weekdayOptions, id: \.value) { weekday in
                    weekdayChip(weekday)
                }
            }
        }
        .padding()
    }

    private var weekdayOptions: [(value: Int, short: String)] {
        [
            (1, NSLocalizedString("weekday.short.sunday", comment: "")),
            (2, NSLocalizedString("weekday.short.monday", comment: "")),
            (3, NSLocalizedString("weekday.short.tuesday", comment: "")),
            (4, NSLocalizedString("weekday.short.wednesday", comment: "")),
            (5, NSLocalizedString("weekday.short.thursday", comment: "")),
            (6, NSLocalizedString("weekday.short.friday", comment: "")),
            (7, NSLocalizedString("weekday.short.saturday", comment: ""))
        ]
    }

    private func weekdayChip(_ weekday: (value: Int, short: String)) -> some View {
        let isSelected = selectedWeekdays.contains(weekday.value)

        return Button {
            if isSelected {
                // Don't allow deselecting if it's the only one
                if selectedWeekdays.count > 1 {
                    selectedWeekdays.remove(weekday.value)
                }
            } else {
                selectedWeekdays.insert(weekday.value)
            }
        } label: {
            Text(weekday.short)
                .font(DS.Typography.labelSmall)
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(isSelected ? theme.accent : Color.clear)
                )
                .glassEffect(isSelected ? .clear : .regular.interactive(), in: .circle)
                .frame(height: DS.Button.actionSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(weekday.short)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var dayOfMonthPicker: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "number")
                .foregroundStyle(.secondary)
                .frame(width: 24)
                .accessibilityHidden(true)

            Text(NSLocalizedString("scheduled.editor.day.of.month", comment: ""))
                .foregroundStyle(.primary)

            Spacer()

            Picker("", selection: $dayOfMonth) {
                ForEach(1...31, id: \.self) { day in
                    Text("\(day)").tag(day)
                }
            }
            .pickerStyle(.menu)
        }
        .padding()
    }

    private var yearlyDatePicker: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "calendar")
                .foregroundStyle(.secondary)
                .frame(width: 24)
                .accessibilityHidden(true)

            Text(NSLocalizedString("scheduled.yearly.date", comment: ""))
                .foregroundStyle(.primary)

            Spacer()

            // Month picker
            Picker("", selection: $yearlyMonth) {
                ForEach(1...12, id: \.self) { month in
                    Text(monthName(month)).tag(month)
                }
            }
            .pickerStyle(.menu)

            // Day picker
            Picker("", selection: $yearlyDay) {
                ForEach(1...daysInMonth(yearlyMonth), id: \.self) { day in
                    Text("\(day)").tag(day)
                }
            }
            .pickerStyle(.menu)
        }
        .padding()
    }

    private static let monthSymbolFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale.current
        return f
    }()

    private func monthName(_ month: Int) -> String {
        return Self.monthSymbolFormatter.monthSymbols[month - 1]
    }

    private func daysInMonth(_ month: Int) -> Int {
        switch month {
        case 2: return 29  // Allow 29 for leap years
        case 4, 6, 9, 11: return 30
        default: return 31
        }
    }

    private var startDateRow: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "calendar.badge.plus")
                .foregroundStyle(.secondary)
                .frame(width: 24)
                .accessibilityHidden(true)

            Text(NSLocalizedString("scheduled.start.date", comment: ""))
                .foregroundStyle(.primary)

            Spacer()

            DateFieldButton(
                date: $paymentDate,
                minDate: (payment == nil && prefill == nil) ? today : .distantPast,
                title: NSLocalizedString("scheduled.start.date", comment: "")
            )
        }
        .padding()
    }

    private var endDateSection: some View {
        VStack(spacing: DS.Spacing.none) {
            // Toggle for end date
            Toggle(isOn: $hasEndDate) {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "calendar.badge.minus")
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                        .accessibilityHidden(true)

                    Text(NSLocalizedString("scheduled.has.end.date", comment: ""))
                }
            }

            .padding()

            if hasEndDate {
                SubsectionDivider()

                HStack(spacing: DS.Spacing.md) {
                    Spacer()
                        .frame(width: 24 + DS.Spacing.md)

                    Text(NSLocalizedString("scheduled.end.date", comment: ""))
                        .foregroundStyle(.primary)

                    Spacer()

                    DateFieldButton(
                        date: Binding(
                            get: { endDate ?? Calendar.current.date(byAdding: .year, value: 1, to: paymentDate) ?? paymentDate },
                            set: { endDate = $0 }
                        ),
                        minDate: paymentDate,
                        title: NSLocalizedString("scheduled.end.date", comment: "")
                    )
                }
                .padding()
            }
        }
    }

    // MARK: - Recurrence Preview

    private func updatePreviewDates() {
        let weekdaysStr = selectedWeekdays.sorted().map { String($0) }.joined(separator: ",")
        let effectiveEndDate = hasEndDate ? endDate : nil
        let params = ScheduledPaymentDateCalculator.PaymentParams(
            isRecurring: isRecurring,
            recurrenceType: recurrenceType.rawValue,
            recurrenceInterval: recurrenceInterval,
            nextDueDate: paymentDate,
            createdAt: payment?.createdAt ?? Date.now,
            endDate: effectiveEndDate,
            dayOfMonth: recurrenceType == .monthly ? dayOfMonth : nil,
            selectedWeekdays: recurrenceType == .weekly ? weekdaysStr : nil,
            yearlyMonth: recurrenceType == .yearly ? yearlyMonth : nil,
            yearlyDay: recurrenceType == .yearly ? yearlyDay : nil
        )

        let calendar = Calendar.current
        let now = Date.now
        var allDates: [Date] = []
        for offset in 0...2 {
            if let month = calendar.date(byAdding: .month, value: offset, to: now) {
                allDates.append(contentsOf: ScheduledPaymentDateCalculator.paymentDatesInMonth(params: params, month: month))
            }
        }
        previewDates = Array(Set(allDates)).sorted().prefix(5).map { $0 }
    }

    @ViewBuilder
    private var recurrencePreviewSection: some View {
        if !previewDates.isEmpty {
            SectionBox(title: L10n.Scheduled.Editor.preview) {
                VStack(spacing: DS.Spacing.none) {
                    ForEach(Array(previewDates.enumerated()), id: \.offset) { index, date in
                        previewDateRow(date, index: index + 1)

                        if index < previewDates.count - 1 {
                            SubsectionDivider()
                        }
                    }
                }
            }
        }
    }

    private func previewDateRow(_ date: Date, index: Int) -> some View {
        HStack(spacing: DS.Spacing.md) {
            VStack(spacing: DS.Spacing.xxs) {
                Text(date, format: .dateTime.day())
                    .font(DS.Typography.title3.weight(.bold))
                    .foregroundStyle(.primary)
                Text(date, format: .dateTime.month(.abbreviated))
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 40)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(date, format: .dateTime.weekday(.wide).day().month(.wide).year())
                    .font(DS.Typography.subheadline)
                    .foregroundStyle(.primary)
                Text("#\(index)")
                    .font(DS.Typography.captionSmall)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, DS.Spacing.sm)
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        SectionBox(title: NSLocalizedString("scheduled.editor.notifications", comment: "")) {
            VStack(spacing: DS.Spacing.none) {
                // Notify on due date
                Toggle(isOn: $notifyOnDueDate) {
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: "bell")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                            .accessibilityHidden(true)

                        Text(NSLocalizedString("scheduled.notify.on.due", comment: ""))
                    }
                }

                .padding()

                SubsectionDivider()

                // Notify days before
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "bell.badge")
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                        .accessibilityHidden(true)

                    Text(NSLocalizedString("scheduled.notify.days.before", comment: ""))
                        .foregroundStyle(.primary)

                    Spacer()

                    Picker("", selection: $notifyDaysBefore) {
                        Text(NSLocalizedString("common.disabled", comment: "")).tag(0)
                        Text("1").tag(1)
                        Text("2").tag(2)
                        Text("3").tag(3)
                        Text("5").tag(5)
                        Text("7").tag(7)
                        Text("14").tag(14)
                        Text("30").tag(30)
                    }
                    .pickerStyle(.menu)
                }
                .padding()
            }
        }
    }

    // MARK: - Delete Section

    private var deleteSection: some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            HStack {
                Spacer()
                Text(NSLocalizedString("scheduled.delete", comment: ""))
                    .font(DS.Typography.bodyBold)
                Spacer()
            }
            .padding(.vertical, DS.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(DS.Semantic.errorBackgroundSubtle)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(DS.Semantic.errorBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(DS.Semantic.errorForeground)
        .padding(.top, DS.Spacing.lg)
    }

    // MARK: - Group Shared Expense Helpers (F3)

    /// Carga los grupos disponibles (no archivados ni ocultos) para el picker.
    private func loadAvailableGroups() {
        let descriptor = FetchDescriptor<SplitGroup>(
            predicate: #Predicate { !$0.isArchived && !$0.isHiddenForAll },
            sortBy: [SortDescriptor(\.name)]
        )
        do {
            availableGroups = try modelContext.fetch(descriptor)
        } catch {
            #if DEBUG
            print("ScheduledPaymentEditor: error fetching groups: \(error)")
            #endif
            availableGroups = []
        }
    }

    /// Conteo de miembros activos de un grupo (subtítulo del picker).
    private func activeMemberCount(for group: SplitGroup) -> Int {
        let zone = group.cloudKitZoneID
        let descriptor = FetchDescriptor<SplitMember>(
            predicate: #Predicate { $0.groupZoneID == zone && $0.status == "active" }
        )
        do {
            return try modelContext.fetchCount(descriptor)
        } catch {
            #if DEBUG
            print("ScheduledPaymentEditor: error counting active members: \(error)")
            #endif
            return 0
        }
    }

    private func selectGroup(_ group: SplitGroup) {
        selectedGroup = group
        loadGroupMembers(for: group)
        resetSplitConfig()
        // Setear splitCurrency puede disparar `.onChange` → applySplitCurrency (idempotente).
        splitCurrency = CurrencyCode(rawValue: group.currencyCode) ?? .usd
        buildTransientVM()
        // Cuenta prefill incompatible con la moneda del grupo → limpiar.
        if let account = selectedAccount, account.currencyCode != splitCurrency.rawValue {
            selectedAccount = nil
        }
    }

    private func loadGroupMembers(for group: SplitGroup) {
        do {
            groupMembers = try GroupService.shared.fetchMembers(for: group, context: modelContext)
        } catch {
            #if DEBUG
            print("ScheduledPaymentEditor: error fetching members: \(error)")
            #endif
            groupMembers = []
        }
    }

    /// Instancia el VM transitorio que alimenta `GroupSplitSelectorView`. SOLO captura config
    /// — nunca se le llama `save()`.
    private func buildTransientVM() {
        guard let group = selectedGroup else { splitExpenseVM = nil; return }
        let lookup = Dictionary(
            groupMembers.map { ($0.id.uuidString, $0.displayName) },
            uniquingKeysWith: { first, _ in first }
        )
        let vm = GroupExpenseViewModel(group: group, members: groupMembers, memberNameLookup: lookup)
        vm.setContext(modelContext)
        vm.currencyCode = splitCurrency.rawValue
        vm.amountString = amount   // el campo del editor = total de la factura
        splitExpenseVM = vm
    }

    private func openSplitSheet() {
        guard selectedGroup != nil else { return }
        if splitExpenseVM == nil { buildTransientVM() }
        splitExpenseVM?.amountString = amount
        splitExpenseVM?.currencyCode = splitCurrency.rawValue
        if splitConfigured { applyStoredConfigToVM() }
        showSplitSheet = true
    }

    private func applySplitCurrency(_ code: CurrencyCode) {
        guard isGroupExpense, selectedGroup != nil else { return }
        // Ya sincronizado (p.ej. onChange disparado por selectGroup) → no-op.
        if splitExpenseVM?.currencyCode == code.rawValue { return }
        resetSplitConfig()
        buildTransientVM()
        if let account = selectedAccount, account.currencyCode != code.rawValue {
            selectedAccount = nil
        }
    }

    /// Lee la config elegida del VM al cerrar el sheet → @State (resumen + guardado).
    /// Guarda el valor CRUDO por modo (%/monto/partes) para reconstruir la división.
    private func extractSplitConfigFromVM() {
        guard let vm = splitExpenseVM else { return }
        vm.purgeEmptyParticipants()   // quien no recibió valor no participa (modos ≠ equal)
        splitConfigType = vm.splitType
        splitParticipantIDs = vm.selectedMemberIDs.compactMap { UUID(uuidString: $0) }

        var values: [UUID: Double] = [:]
        for id in vm.selectedMemberIDs {
            guard let uuid = UUID(uuidString: id) else { continue }
            switch vm.splitType {
            case .equal: break
            case .exact: values[uuid] = AmountInputHelper.parseDecimal(vm.exactAmounts[id] ?? "")
            case .percentage: values[uuid] = AmountInputHelper.parseDecimal(vm.percentages[id] ?? "")
            case .shares: values[uuid] = AmountInputHelper.parseDecimal(vm.sharesCounts[id] ?? "")
            }
        }
        splitValues = values

        // Mi parte = monto efectivo del current user (lo que se guarda en `amount`).
        if let myID = vm.currentUserMemberID {
            splitMyShare = vm.effectiveAmountsByID[myID] ?? 0
        } else {
            splitMyShare = 0
        }
        splitConfigured = !splitParticipantIDs.isEmpty && vm.isSharesBalanced && vm.currentUserMemberID != nil
    }

    /// Aplica la config guardada al VM (al reabrir el sheet en edición).
    private func applyStoredConfigToVM() {
        guard let vm = splitExpenseVM else { return }
        vm.splitType = splitConfigType
        vm.selectedMemberIDs = Set(splitParticipantIDs.map { $0.uuidString })
        vm.exactAmounts = [:]; vm.percentages = [:]; vm.sharesCounts = [:]
        for (uuid, value) in splitValues {
            let id = uuid.uuidString
            switch splitConfigType {
            case .exact: vm.exactAmounts[id] = AmountInputHelper.formatWithGrouping(value)
            case .percentage: vm.percentages[id] = String(format: "%.1f", value)
            case .shares: vm.sharesCounts[id] = String(Int(value.rounded()))
            case .equal: break
            }
        }
    }

    private func resetSplitConfig() {
        splitConfigured = false
        splitParticipantIDs = []
        splitValues = [:]
        splitMyShare = 0
        splitConfigType = .equal
    }

    // MARK: - Validation

    private var canSave: Bool {
        guard !name.isEmpty,
              !amount.isEmpty,
              AmountInputHelper.parseDecimal(amount) > 0 else { return false }
        if isGroupExpense {
            // Gasto compartido: exige grupo + división válida. Cuenta y subcategoría son prefill
            // opcional (el bridge/form las resuelve al aprobar).
            return selectedGroup != nil && splitConfigured && !splitParticipantIDs.isEmpty
        }
        return selectedAccount != nil && selectedSubcategory != nil
    }

    // MARK: - Data Management

    private func loadPaymentData() {
        // Set default category from tab if creating new
        if payment == nil, let defaultCat = defaultCategory {
            paymentCategory = PaymentCategory(rawValue: defaultCat) ?? .recurring
        }

        // Pre-fill from transaction data (when creating from "Save as Recurring")
        if payment == nil, let prefill = prefill {
            let calendar = Calendar.current
            // Don't prefill name — let the user decide the payment name
            amount = prefill.amount
            note = prefill.note
            transactionType = prefill.transactionType
            selectedAccount = prefill.account
            selectedSubcategory = prefill.subcategory
            selectedTags = prefill.tagIDs
            selectedNeed = prefill.needOverride
            paymentDate = calendar.startOfDay(for: prefill.transactionDate)
            dayOfMonth = calendar.component(.day, from: prefill.transactionDate)
            yearlyMonth = calendar.component(.month, from: prefill.transactionDate)
            yearlyDay = calendar.component(.day, from: prefill.transactionDate)
            return
        }

        guard let payment = payment else { return }

        name = payment.name
        amount = AmountInputHelper.formatWithGrouping(payment.amount)
        note = payment.note ?? ""
        transactionType = payment.transactionType
        paymentCategory = PaymentCategory(rawValue: payment.paymentCategory) ?? .recurring
        isSubscription = paymentCategory == .subscription
        selectedAccount = payment.account
        selectedSubcategory = payment.subcategory
        // CSV-mirror SSOT via resolver + TagResolver → set of persistentModelIDs.
        let resolved = TagResolver.fetchOrEmpty(
            ids: payment.resolvedTagIDs(scheduleBackfill: true) ?? [],
            in: modelContext,
            errorContext: "ScheduledPaymentEditorView/load"
        )
        selectedTags = Set(resolved.map(\.persistentModelID))

        // Recurrence
        isRecurring = payment.isRecurring
        recurrenceType = RecurrenceType(rawValue: payment.recurrenceType) ?? .monthly
        recurrenceInterval = payment.recurrenceInterval
        paymentDate = payment.nextDueDate
        dayOfMonth = payment.dayOfMonth ?? 1

        // Parse selectedWeekdays from comma-separated string
        if let weekdaysStr = payment.selectedWeekdays {
            selectedWeekdays = Set(weekdaysStr.split(separator: ",").compactMap { Int($0) })
        }
        if selectedWeekdays.isEmpty {
            selectedWeekdays = [2]  // Default Monday
        }

        yearlyMonth = payment.yearlyMonth ?? 1
        yearlyDay = payment.yearlyDay ?? 1

        if let end = payment.endDate {
            hasEndDate = true
            endDate = end
        }

        notifyOnDueDate = payment.notifyOnDueDate
        notifyDaysBefore = payment.notifyDaysBefore
        isActive = payment.isActive
        isVariableAmount = payment.isVariableAmount
        selectedNeed = payment.needOverride.flatMap { SubcategoryNeed(rawValue: $0) }

        // Group shared expense (F3): reconstruir estado desde el payment.
        if payment.isGroupPayment {
            isGroupExpense = true
            splitCurrency = CurrencyCode(rawValue: payment.currencyCode) ?? .usd
            // El campo Monto muestra el TOTAL de la factura (no mi parte).
            if let total = payment.splitTotalAmount {
                amount = AmountInputHelper.formatWithGrouping(total)
            }
            splitConfigType = SplitType(rawValue: payment.splitType ?? "equal") ?? .equal
            splitParticipantIDs = payment.resolvedParticipantIDs()
            splitValues = payment.resolvedSplitValues()
            splitMyShare = payment.amount   // amount ya es mi parte
            splitConfigured = !splitParticipantIDs.isEmpty
            if let zone = payment.groupZoneID {
                loadAvailableGroups()
                selectedGroup = availableGroups.first(where: { $0.cloudKitZoneID == zone })
                if let group = selectedGroup {
                    loadGroupMembers(for: group)
                    buildTransientVM()
                    applyStoredConfigToVM()
                }
            }
        }
    }

    private func savePayment() {
        let amountValue = AmountInputHelper.parseDecimal(amount)
        guard amountValue > 0 else { return }

        let effectiveEndDate = hasEndDate ? endDate : nil

        // Gasto compartido: `amount` guardado = MI PARTE (splitMyShare); el total va a
        // splitTotalAmount. Moneda = la elegida para el gasto de grupo. Etiquetas no aplican.
        let amountToSave = isGroupExpense ? splitMyShare : amountValue
        let currencyToSave = isGroupExpense
            ? splitCurrency.rawValue
            : (selectedAccount?.currencyCode ?? appPreferences.defaultCurrencyCode.rawValue)

        let savedID = viewModel.savePayment(
            existing: payment,
            name: name,
            amount: amountToSave,
            note: note,
            currencyCode: currencyToSave,
            transactionType: transactionType,
            paymentCategory: paymentCategory,
            account: selectedAccount,
            subcategory: selectedSubcategory,
            selectedTags: isGroupExpense ? [] : selectedTags,
            isRecurring: isRecurring,
            recurrenceType: recurrenceType,
            recurrenceInterval: recurrenceInterval,
            paymentDate: paymentDate,
            dayOfMonth: dayOfMonth,
            selectedWeekdays: selectedWeekdays,
            yearlyMonth: yearlyMonth,
            yearlyDay: yearlyDay,
            endDate: effectiveEndDate,
            notifyOnDueDate: notifyOnDueDate,
            notifyDaysBefore: notifyDaysBefore,
            isActive: isActive,
            needOverride: selectedNeed?.rawValue,
            isVariableAmount: isVariableAmount,
            splitTotalAmount: isGroupExpense ? amountValue : nil,
            groupZoneID: isGroupExpense ? selectedGroup?.cloudKitZoneID : nil,
            splitType: isGroupExpense ? splitConfigType.rawValue : nil,
            splitParticipantIDs: isGroupExpense ? splitParticipantIDs : [],
            splitValues: isGroupExpense ? splitValues : [:]
        )

        if let id = savedID {
            onSaved?(id)
            if payment == nil, SetupChecklistManager.shared.stepCompleted[.scheduledPayment] != true {
                // Find PersistentIdentifier from UUID
                let descriptor = FetchDescriptor<ScheduledPayment>(predicate: #Predicate { $0.id == id })
                do {
                    if let persistentID = try modelContext.fetch(descriptor).first?.persistentModelID {
                        SetupChecklistManager.shared.markCompleted(
                            .scheduledPayment,
                            practiceItem: PracticeCleanupItem(
                                stepID: .scheduledPayment,
                                itemName: name,
                                persistentID: persistentID
                            )
                        )
                    } else {
                        SetupChecklistManager.shared.markCompleted(.scheduledPayment)
                    }
                } catch {
                    #if DEBUG
                    print("ScheduledPaymentEditor: Error fetching saved payment: \(error)")
                    #endif
                    SetupChecklistManager.shared.markCompleted(.scheduledPayment)
                }
            } else {
                SetupChecklistManager.shared.markCompleted(.scheduledPayment)
            }
            dismiss()
        }
    }

    private func dismissEditorKeyboard() {
        isNameFieldFocused = false
        isAmountFieldFocused = false
        isNoteFieldFocused = false
    }

    private func deletePayment() {
        guard let payment = payment else { return }

        if viewModel.deletePayment(payment) {
            dismiss()
            onDelete?()
        }
    }
}

// MARK: - Body Decomposition (ViewModifiers)
//
// El `body` de este editor era una única cadena de ~24 modificadores (4 sheets + 14 onChange +
// 2 alerts) que excedía el límite del solver de Swift ("unable to type-check this expression in
// reasonable time"). Se agrupan en `ViewModifier`s privados para que cada `body(content:)` se
// type-checkee por separado. Sin cambios de comportamiento: mismos efectos, mismo orden.

private extension ScheduledPaymentEditorView {

    /// Los `.onChange` de recurrencia que sólo recalculan el preview de fechas.
    /// `dismissEditorKeyboard()` se dispara únicamente en `isRecurring`/`recurrenceType`
    /// (igual que el original); el resto sólo actualiza el preview.
    struct RecurrencePreviewObservers: ViewModifier {
        let isRecurring: Bool
        let recurrenceType: RecurrenceType
        let recurrenceInterval: Int
        let paymentDate: Date
        let dayOfMonth: Int
        let selectedWeekdays: Set<Int>
        let yearlyMonth: Int
        let yearlyDay: Int
        let hasEndDate: Bool
        let endDate: Date?
        let onDismissKeyboard: () -> Void
        let onUpdatePreview: () -> Void

        func body(content: Content) -> some View {
            content
                .onChange(of: isRecurring) { _, _ in onDismissKeyboard(); onUpdatePreview() }
                .onChange(of: recurrenceType) { _, _ in onDismissKeyboard(); onUpdatePreview() }
                .onChange(of: recurrenceInterval) { _, _ in onUpdatePreview() }
                .onChange(of: paymentDate) { _, _ in onUpdatePreview() }
                .onChange(of: dayOfMonth) { _, _ in onUpdatePreview() }
                .onChange(of: selectedWeekdays) { _, _ in onUpdatePreview() }
                .onChange(of: yearlyMonth) { _, _ in onUpdatePreview() }
                .onChange(of: yearlyDay) { _, _ in onUpdatePreview() }
                .onChange(of: hasEndDate) { _, _ in onUpdatePreview() }
                .onChange(of: endDate) { _, _ in onUpdatePreview() }
        }
    }

    /// Los 4 `.sheet` del editor: categorías, selector de grupo, moneda del split y división.
    struct EditorSheets: ViewModifier {
        @Binding var showCategoriesSheet: Bool
        @Binding var selectedSubcategory: Subcategory?
        let transactionType: String

        @Binding var showGroupPicker: Bool
        let availableGroups: [SplitGroup]
        let selectedGroupID: UUID
        let memberCount: (SplitGroup) -> Int
        let onSelectGroup: (SplitGroup) -> Void

        @Binding var showSplitCurrencyPicker: Bool
        @Binding var splitCurrency: CurrencyCode

        @Binding var showSplitSheet: Bool
        let splitExpenseVM: GroupExpenseViewModel?
        let onSplitSheetDismiss: () -> Void

        func body(content: Content) -> some View {
            content
                .sheet(isPresented: $showCategoriesSheet) {
                    SubcategorySelectorSheet(
                        selectedSubcategory: $selectedSubcategory,
                        transactionType: transactionType == "income" ? .income : .expense
                    )
                }
                .sheet(isPresented: $showGroupPicker) {
                    GroupPickerSheet(
                        groups: availableGroups,
                        selectedGroupID: selectedGroupID,
                        memberCount: { memberCount($0) },
                        onSelect: { group in onSelectGroup(group) }
                    )
                }
                .sheet(isPresented: $showSplitCurrencyPicker) {
                    CurrencyPickerSheet(selectedCurrency: $splitCurrency)
                }
                .sheet(isPresented: $showSplitSheet, onDismiss: { onSplitSheetDismiss() }) {
                    if let vm = splitExpenseVM {
                        GroupSplitSelectorView(viewModel: vm)
                    }
                }
        }
    }

    /// Las 2 `.alert` del editor (confirmación de borrado y error al guardar) junto con el
    /// `.onChange` que dispara el alert de error — contiguos para preservar el orden original.
    struct EditorAlerts: ViewModifier {
        let deleteAlertTitle: String
        @Binding var showDeleteConfirmation: Bool
        let onConfirmDelete: () -> Void

        let saveErrorFlag: Bool
        @Binding var showSaveError: Bool
        let onDismissSaveError: () -> Void

        func body(content: Content) -> some View {
            content
                .alert(deleteAlertTitle, isPresented: $showDeleteConfirmation) {
                    Button(NSLocalizedString("action.cancel", comment: ""), role: .cancel) {}
                    Button(NSLocalizedString("action.delete", comment: ""), role: .destructive) {
                        onConfirmDelete()
                    }
                } message: {
                    Text(NSLocalizedString("scheduled.delete.confirm.message", comment: ""))
                }
                .onChange(of: saveErrorFlag) { _, new in if new { showSaveError = true } }
                .alert(
                    L10n.Common.error,
                    isPresented: $showSaveError,
                    actions: {
                        Button(L10n.Common.understood, role: .cancel) { onDismissSaveError() }
                    },
                    message: {
                        Text(L10n.Common.saveError)
                    }
                )
        }
    }
}
