//
//  ScheduledPaymentEditorView.swift
//  Neto
//
//  Editor sheet for creating and editing scheduled payments
//

import SwiftData
import SwiftUI

struct ScheduledPaymentEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Account.name) private var allAccounts: [Account]
    @Query(sort: \Tag.name) private var allTags: [Tag]

    @AppStorage("defaultCurrencyCode") private var defaultCurrencyCode: String = CurrencyCode.pen.rawValue

    let payment: ScheduledPayment?
    let defaultCategory: String?

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

    // Recurrence
    @State private var isRecurring: Bool = true
    @State private var recurrenceType: RecurrenceType = .monthly
    @State private var recurrenceInterval: Int = 1
    @State private var paymentDate: Date = Date()  // For one-time or start date
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

    // Sheet states
    @State private var showAccountSheet = false
    @State private var showCategoriesSheet = false
    @State private var showDeleteConfirmation = false

    // Focus state
    @FocusState private var isNameFieldFocused: Bool

    init(payment: ScheduledPayment?, defaultCategory: String? = nil) {
        self.payment = payment
        self.defaultCategory = defaultCategory
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    // Basic Information Section
                    basicInfoSection

                    // Toggles Section (Activa + Suscripción)
                    togglesSection

                    // Classification Section
                    classificationSection

                    // Recurrence Section
                    recurrenceSection

                    // Notifications Section
                    notificationsSection

                    // Delete Button (only for existing payments)
                    if payment != nil {
                        deleteSection
                    }
                }
                .padding(.vertical, DS.Spacing.xxl)
                .padding(.horizontal, DS.Spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(
                PanelBackgroundView()
                    .dismissKeyboardOnTap()
            )
            .alert(
                NSLocalizedString("scheduled.delete.confirm.title", comment: ""),
                isPresented: $showDeleteConfirmation
            ) {
                Button(NSLocalizedString("action.cancel", comment: ""), role: .cancel) {}
                Button(NSLocalizedString("action.delete", comment: ""), role: .destructive) {
                    deletePayment()
                }
            } message: {
                Text(NSLocalizedString("scheduled.delete.confirm.message", comment: ""))
            }
            .navigationTitle(
                payment == nil
                    ? NSLocalizedString("scheduled.new", comment: "")
                    : NSLocalizedString("scheduled.edit", comment: "")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NetoToolbarButton(systemName: "xmark") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    NetoSaveButton(action: savePayment, isDisabled: !canSave)
                }
            }
            .sheet(isPresented: $showCategoriesSheet) {
                SubcategorySelectorSheet(
                    selectedSubcategory: $selectedSubcategory,
                    transactionType: transactionType == "income" ? .income : .expense
                )
            }
            .onChange(of: showCategoriesSheet) { _, isPresenting in
                if isPresenting { dismissKeyboard() }
            }
            .onAppear {
                loadPaymentData()
                // Auto-focus name field for new payments
                if payment == nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isNameFieldFocused = true
                    }
                }
            }
        }
    }

    // MARK: - Basic Information Section

    private var basicInfoSection: some View {
        SectionBox(title: NSLocalizedString("scheduled.editor.basic.info", comment: "")) {
            VStack(spacing: 0) {
                // Transaction Type (Income/Expense)
                Picker("", selection: $transactionType) {
                    Text(NSLocalizedString("transaction.type.expense", comment: "")).tag("expense")
                    Text(NSLocalizedString("transaction.type.income", comment: "")).tag("income")
                }
                .pickerStyle(.segmented)
                .padding()

                SubsectionDivider()

                // Name Field
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "textformat")
                        .foregroundStyle(.secondary)
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
                        Text(defaultCurrencyCode)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("0.00", text: $amount)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(transactionType == "income" ? Color.teal : .primary)
                    }
                }
                .padding()

                SubsectionDivider()

                // Note Field
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "note.text")
                        .foregroundStyle(.secondary)
                    TextField(
                        NSLocalizedString("scheduled.editor.note.placeholder", comment: ""),
                        text: $note
                    )
                }
                .padding()
            }
        }
    }

    // MARK: - Toggles Section

    private var togglesSection: some View {
        SectionBox(title: NSLocalizedString("scheduled.editor.options", comment: "")) {
            VStack(spacing: 0) {
                // Active Toggle
                Toggle(isOn: $isActive) {
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        Text(NSLocalizedString("common.active", comment: ""))
                    }
                }
                .tint(Color.brandPrimary)
                .padding()

                SubsectionDivider()

                // Subscription Toggle
                Toggle(isOn: isSubscriptionBinding) {
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        Text(NSLocalizedString("scheduled.is.subscription", comment: ""))
                    }
                }
                .tint(Color.electricIndigo)
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
            VStack(spacing: 0) {
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
            ForEach(activeAccounts) { account in
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

                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
                            .font(.caption)
                            .foregroundStyle(Color(hex: subcategory.colorHex ?? subcategory.category.colorHex))
                        Text(subcategory.name)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(NSLocalizedString("common.select", comment: ""))
                        .foregroundStyle(Color.hotPink.opacity(0.8))
                }

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
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
            items: activeTags,
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
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .white : Color(hex: tag.colorHex))

                Text(tag.name)
                    .font(.subheadline)
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

    // MARK: - Recurrence Section

    private var recurrenceSection: some View {
        SectionBox(title: NSLocalizedString("scheduled.editor.recurrence", comment: "")) {
            VStack(spacing: 0) {
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
        }
    }

    private var paymentDateRow: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "calendar")
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(NSLocalizedString("scheduled.payment.date", comment: ""))
                .foregroundStyle(.primary)

            Spacer()

            DatePicker(
                "",
                selection: $paymentDate,
                displayedComponents: .date
            )
            .labelsHidden()
        }
        .padding()
    }

    private var recurrenceIntervalRow: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "repeat")
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(NSLocalizedString("scheduled.every", comment: ""))
                .foregroundStyle(.primary)

            Picker("", selection: $recurrenceInterval) {
                ForEach(1...30, id: \.self) { num in
                    Text("\(num)").tag(num)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 60)

            Picker("", selection: $recurrenceType) {
                ForEach(RecurrenceType.allCases) { type in
                    Text(recurrenceInterval == 1 ? type.localizedNameSingular : type.localizedNamePlural)
                        .tag(type)
                }
            }
            .pickerStyle(.menu)

            Spacer()
        }
        .padding()
    }

    private var weekdaySelector: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: "calendar.day.timeline.left")
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

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
                .font(.caption.weight(.medium))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(isSelected ? Color.electricIndigo : Color(.tertiarySystemFill))
                )
        }
        .buttonStyle(.plain)
    }

    private var dayOfMonthPicker: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "number")
                .foregroundStyle(.secondary)
                .frame(width: 24)

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

    private func monthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        return formatter.monthSymbols[month - 1]
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

            Text(NSLocalizedString("scheduled.start.date", comment: ""))
                .foregroundStyle(.primary)

            Spacer()

            DatePicker(
                "",
                selection: $paymentDate,
                displayedComponents: .date
            )
            .labelsHidden()
        }
        .padding()
    }

    private var endDateSection: some View {
        VStack(spacing: 0) {
            // Toggle for end date
            Toggle(isOn: $hasEndDate) {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "calendar.badge.minus")
                        .foregroundStyle(.secondary)
                        .frame(width: 24)

                    Text(NSLocalizedString("scheduled.has.end.date", comment: ""))
                }
            }
            .tint(Color.electricIndigo)
            .padding()

            if hasEndDate {
                SubsectionDivider()

                HStack(spacing: DS.Spacing.md) {
                    Spacer()
                        .frame(width: 24 + DS.Spacing.md)

                    Text(NSLocalizedString("scheduled.end.date", comment: ""))
                        .foregroundStyle(.primary)

                    Spacer()

                    DatePicker(
                        "",
                        selection: Binding(
                            get: { endDate ?? Calendar.current.date(byAdding: .year, value: 1, to: paymentDate) ?? paymentDate },
                            set: { endDate = $0 }
                        ),
                        in: paymentDate...,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                }
                .padding()
            }
        }
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        SectionBox(title: NSLocalizedString("scheduled.editor.notifications", comment: "")) {
            VStack(spacing: 0) {
                // Notify on due date
                Toggle(isOn: $notifyOnDueDate) {
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: "bell")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)

                        Text(NSLocalizedString("scheduled.notify.on.due", comment: ""))
                    }
                }
                .tint(Color.electricIndigo)
                .padding()

                SubsectionDivider()

                // Notify days before
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "bell.badge")
                        .foregroundStyle(.secondary)
                        .frame(width: 24)

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
                    .font(.body.weight(.medium))
                Spacer()
            }
            .padding(.vertical, DS.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .fill(Color.red.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                    .stroke(Color.red.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(.red)
        .padding(.top, 16)
    }

    // MARK: - Computed Properties

    private var activeAccounts: [Account] {
        allAccounts.filter { !$0.isArchived }
    }

    private var activeTags: [Tag] {
        allTags.filter { $0.isActive }
    }

    // MARK: - Validation

    private var canSave: Bool {
        !name.isEmpty &&
        !amount.isEmpty &&
        Double(amount) != nil &&
        selectedAccount != nil &&
        selectedSubcategory != nil
    }

    // MARK: - Data Management

    private func loadPaymentData() {
        // Set default category from tab if creating new
        if payment == nil, let defaultCat = defaultCategory {
            paymentCategory = PaymentCategory(rawValue: defaultCat) ?? .recurring
        }

        guard let payment = payment else { return }

        name = payment.name
        amount = String(format: "%.2f", payment.amount)
        note = payment.note ?? ""
        transactionType = payment.transactionType
        paymentCategory = PaymentCategory(rawValue: payment.paymentCategory) ?? .recurring
        selectedAccount = payment.account
        selectedSubcategory = payment.subcategory
        selectedTags = Set(payment.tags.map { $0.persistentModelID })

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
        guard let amountValue = Double(amount) else { return }

        // Get tags array
        let tagsArray = activeTags.filter { selectedTags.contains($0.persistentModelID) }

        // Convert selectedWeekdays set to comma-separated string
        let weekdaysStr = selectedWeekdays.sorted().map { String($0) }.joined(separator: ",")

        // Determine the effective end date
        let effectiveEndDate = hasEndDate ? endDate : nil

        if let existingPayment = payment {
            // Update existing
            existingPayment.name = name
            existingPayment.amount = amountValue
            existingPayment.note = note.isEmpty ? nil : note
            existingPayment.currencyCode = defaultCurrencyCode
            existingPayment.transactionType = transactionType
            existingPayment.paymentCategory = paymentCategory.rawValue
            existingPayment.account = selectedAccount
            existingPayment.subcategory = selectedSubcategory
            existingPayment.tags = tagsArray

            // Recurrence
            existingPayment.isRecurring = isRecurring
            existingPayment.recurrenceType = recurrenceType.rawValue
            existingPayment.recurrenceInterval = recurrenceInterval
            existingPayment.nextDueDate = paymentDate
            existingPayment.dayOfMonth = recurrenceType == .monthly ? dayOfMonth : nil
            existingPayment.selectedWeekdays = recurrenceType == .weekly ? weekdaysStr : nil
            existingPayment.yearlyMonth = recurrenceType == .yearly ? yearlyMonth : nil
            existingPayment.yearlyDay = recurrenceType == .yearly ? yearlyDay : nil
            existingPayment.endDate = isRecurring ? effectiveEndDate : nil

            existingPayment.notifyOnDueDate = notifyOnDueDate
            existingPayment.notifyDaysBefore = notifyDaysBefore
            existingPayment.isActive = isActive
        } else {
            // Create new
            let newPayment = ScheduledPayment(
                name: name,
                note: note.isEmpty ? nil : note,
                amount: amountValue,
                currencyCode: defaultCurrencyCode,
                transactionType: transactionType,
                account: selectedAccount,
                subcategory: selectedSubcategory,
                tags: tagsArray,
                isRecurring: isRecurring,
                recurrenceType: recurrenceType.rawValue,
                recurrenceInterval: recurrenceInterval,
                nextDueDate: paymentDate,
                dayOfMonth: recurrenceType == .monthly ? dayOfMonth : nil,
                selectedWeekdays: recurrenceType == .weekly ? weekdaysStr : nil,
                yearlyMonth: recurrenceType == .yearly ? yearlyMonth : nil,
                yearlyDay: recurrenceType == .yearly ? yearlyDay : nil,
                endDate: isRecurring ? effectiveEndDate : nil,
                paymentCategory: paymentCategory.rawValue,
                notifyOnDueDate: notifyOnDueDate,
                notifyDaysBefore: notifyDaysBefore,
                isActive: isActive
            )

            modelContext.insert(newPayment)
        }

        try? modelContext.save()
        dismiss()
    }

    private func deletePayment() {
        guard let payment = payment else { return }
        modelContext.delete(payment)
        try? modelContext.save()
        dismiss()
    }
}
