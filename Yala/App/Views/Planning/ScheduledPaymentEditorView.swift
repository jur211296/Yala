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

    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = CurrencyCode.pen.rawValue

    let payment: ScheduledPayment?
    let defaultCategory: String?
    var onDelete: (() -> Void)?
    let prefill: ScheduledPaymentPrefill?
    let onSaved: ((UUID) -> Void)?

    // Basic Info
    @State private var name: String = ""
    @State private var amount: String = ""
    @State private var note: String = ""

    // Type
    @State private var transactionType: String = "expense"
    @State private var paymentCategory: PaymentCategory = .recurring

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

    // Status
    @State private var isActive: Bool = true

    // Preview
    @State private var previewDates: [Date] = []

    // Sheet states
    @State private var showAccountSheet = false
    @State private var showCategoriesSheet = false
    @State private var showDeleteConfirmation = false

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
                .sheet(isPresented: $showCategoriesSheet) {
                    SubcategorySelectorSheet(
                        selectedSubcategory: $selectedSubcategory,
                        transactionType: transactionType == "income" ? .income : .expense
                    )
                }
                .onAppear { handleOnAppear() }
                .onChange(of: isRecurring) { _, _ in dismissEditorKeyboard(); updatePreviewDates() }
                .onChange(of: recurrenceType) { _, _ in dismissEditorKeyboard(); updatePreviewDates() }
                .onChange(of: recurrenceInterval) { _, _ in updatePreviewDates() }
                .onChange(of: paymentDate) { _, _ in updatePreviewDates() }
                .onChange(of: dayOfMonth) { _, _ in updatePreviewDates() }
                .onChange(of: selectedWeekdays) { _, _ in updatePreviewDates() }
                .onChange(of: yearlyMonth) { _, _ in updatePreviewDates() }
                .onChange(of: yearlyDay) { _, _ in updatePreviewDates() }
                .onChange(of: hasEndDate) { _, _ in updatePreviewDates() }
                .onChange(of: endDate) { _, _ in updatePreviewDates() }
                .onChange(of: showCategoriesSheet) { _, isPresenting in
                    if isPresenting { dismissEditorKeyboard() }
                }
                .alert(deleteAlertTitle, isPresented: $showDeleteConfirmation) {
                    Button(NSLocalizedString("action.cancel", comment: ""), role: .cancel) {}
                    Button(NSLocalizedString("action.delete", comment: ""), role: .destructive) {
                        deletePayment()
                    }
                } message: {
                    Text(NSLocalizedString("scheduled.delete.confirm.message", comment: ""))
                }
                .alert(
                    L10n.Common.error,
                    isPresented: Binding(
                        get: { viewModel.showSaveError },
                        set: { _ in viewModel.dismissSaveError() }
                    ),
                    actions: {
                        Button(L10n.Common.understood, role: .cancel) {}
                    },
                    message: {
                        Text(L10n.Common.saveError)
                    }
                )
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
        .scrollDismissesKeyboard(.interactively)
        .background(PanelBackgroundView())
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
        .padding(.horizontal, DS.Spacing.lg)
    }

    // MARK: - Basic Information Section

    private var basicInfoSection: some View {
        SectionBox(title: NSLocalizedString("scheduled.editor.basic.info", comment: "")) {
            VStack(spacing: DS.Spacing.none) {
                // Transaction Type (Income/Expense)
                if !sessionState.isExpensesOnlyMode {
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
                }
                .padding()

                SubsectionDivider()

                // Amount Field
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                        if let account = selectedAccount {
                            Text(account.currencyCode)
                                .font(DS.Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: scaledAmountSize, weight: .bold))
                            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
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

                // Subscription Toggle
                Toggle(isOn: isSubscriptionBinding) {
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

    private var isSubscriptionBinding: Binding<Bool> {
        Binding(
            get: { paymentCategory == .subscription },
            set: { paymentCategory = $0 ? .subscription : .recurring }
        )
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

                SubsectionDivider()

                // Tags
                tagsContent
            }
        }
    }

    private var accountRow: some View {
        Menu {
            ForEach(viewModel.activeAccounts) { account in
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

                if !viewModel.activeAccounts.isEmpty {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(DS.Typography.indicator)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint(viewModel.activeAccounts.isEmpty ? L10n.Accessibility.createAccountFirst : "")
        .disabled(viewModel.activeAccounts.isEmpty)
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
            .background(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous).fill(.thCard))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous).stroke(Color.primary.opacity(0.05), lineWidth: 1))
            .shadow(color: Color.black.opacity(DS.Opacity.faint), radius: 10, x: 0, y: 5)
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
                        .fill(isSelected ? theme.accent : Color(.tertiarySystemFill))
                )
        }
        .buttonStyle(.plain)
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
                    .font(.title3.weight(.bold))
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

    // MARK: - Validation

    private var canSave: Bool {
        !name.isEmpty &&
        !amount.isEmpty &&
        (Double(amount) ?? 0) > 0 &&
        selectedAccount != nil &&
        selectedSubcategory != nil
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
            name = prefill.subcategory?.name ?? prefill.note
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
        selectedAccount = payment.account
        selectedSubcategory = payment.subcategory
        selectedTags = Set((payment.tags ?? []).map { $0.persistentModelID })

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
    }

    private func savePayment() {
        let amountValue = AmountInputHelper.parseDecimal(amount)
        guard amountValue > 0 else { return }

        let effectiveEndDate = hasEndDate ? endDate : nil

        let savedID = viewModel.savePayment(
            existing: payment,
            name: name,
            amount: amountValue,
            note: note,
            currencyCode: selectedAccount?.currencyCode ?? defaultCurrencyCode,
            transactionType: transactionType,
            paymentCategory: paymentCategory,
            account: selectedAccount,
            subcategory: selectedSubcategory,
            selectedTags: selectedTags,
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
            needOverride: selectedNeed?.rawValue
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
