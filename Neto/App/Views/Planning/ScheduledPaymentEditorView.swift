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

    @Query(sort: \Category.name) private var categories: [Category]
    @Query(sort: \Account.name) private var allAccounts: [Account]
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @Query(sort: \Subcategory.sortOrder) private var allSubcategories: [Subcategory]

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
    @State private var recurrenceType: RecurrenceType = .monthly
    @State private var nextDueDate: Date = Date()
    @State private var dayOfMonth: Int = 1
    @State private var dayOfWeek: Int = 1  // 1 = Sunday

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

                    // Type Section
                    typeSection

                    // Category Section
                    categorySection

                    // Classification Section
                    classificationSection

                    // Recurrence Section
                    recurrenceSection

                    // Notifications Section
                    notificationsSection

                    // Active Toggle
                    activeToggle

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
                subcategorySelectorSheet
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

    // MARK: - Type Section

    private var typeSection: some View {
        SectionBox(title: NSLocalizedString("scheduled.editor.type", comment: "")) {
            VStack(spacing: 0) {
                // Transaction Type (Income/Expense)
                Picker("", selection: $transactionType) {
                    Text(NSLocalizedString("transaction.type.expense", comment: "")).tag("expense")
                    Text(NSLocalizedString("transaction.type.income", comment: "")).tag("income")
                }
                .pickerStyle(.segmented)
                .padding()
            }
        }
    }

    // MARK: - Category Section

    private var categorySection: some View {
        SectionBox(title: NSLocalizedString("scheduled.editor.payment.category", comment: "")) {
            Picker("", selection: $paymentCategory) {
                ForEach(PaymentCategory.allCases) { category in
                    HStack {
                        Image(systemName: category.iconName)
                        Text(category.localizedName)
                    }
                    .tag(category)
                }
            }
            .pickerStyle(.segmented)
            .padding()
        }
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
        Button {
            // Simple picker via menu
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
                        .foregroundStyle(.secondary)
                }

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
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
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
                        .foregroundStyle(.secondary)
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
                // Recurrence type picker
                Picker("", selection: $recurrenceType) {
                    ForEach(RecurrenceType.allCases) { type in
                        Text(type.localizedName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                SubsectionDivider()

                // Next due date
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "calendar")
                        .foregroundStyle(.secondary)
                        .frame(width: 24)

                    Text(NSLocalizedString("scheduled.editor.next.due", comment: ""))
                        .foregroundStyle(.primary)

                    Spacer()

                    DatePicker(
                        "",
                        selection: $nextDueDate,
                        displayedComponents: .date
                    )
                    .labelsHidden()
                }
                .padding()

                // Day selector based on recurrence type
                if recurrenceType == .monthly {
                    SubsectionDivider()
                    dayOfMonthPicker
                } else if recurrenceType == .weekly {
                    SubsectionDivider()
                    dayOfWeekPicker
                }
            }
        }
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

    private var dayOfWeekPicker: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: "calendar.day.timeline.left")
                .foregroundStyle(.secondary)
                .frame(width: 24)

            Text(NSLocalizedString("scheduled.editor.day.of.week", comment: ""))
                .foregroundStyle(.primary)

            Spacer()

            Picker("", selection: $dayOfWeek) {
                Text(NSLocalizedString("weekday.sunday", comment: "")).tag(1)
                Text(NSLocalizedString("weekday.monday", comment: "")).tag(2)
                Text(NSLocalizedString("weekday.tuesday", comment: "")).tag(3)
                Text(NSLocalizedString("weekday.wednesday", comment: "")).tag(4)
                Text(NSLocalizedString("weekday.thursday", comment: "")).tag(5)
                Text(NSLocalizedString("weekday.friday", comment: "")).tag(6)
                Text(NSLocalizedString("weekday.saturday", comment: "")).tag(7)
            }
            .pickerStyle(.menu)
        }
        .padding()
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

    // MARK: - Active Toggle

    private var activeToggle: some View {
        Toggle(isOn: $isActive) {
            Text(NSLocalizedString("common.active", comment: ""))
                .font(.body)
        }
        .tint(Color.brandPrimary)
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

    // MARK: - Subcategory Sheet

    private var subcategorySelectorSheet: some View {
        NavigationStack {
            List {
                ForEach(expenseCategories) { category in
                    Section(header: Text(category.name)) {
                        ForEach(category.subcategories.sorted(by: { $0.sortOrder < $1.sortOrder })) { subcategory in
                            Button {
                                selectedSubcategory = subcategory
                                showCategoriesSheet = false
                            } label: {
                                HStack {
                                    Image(systemName: subcategory.iconName ?? "tag.fill")
                                        .foregroundStyle(Color(hex: subcategory.colorHex ?? category.colorHex))

                                    Text(subcategory.name)
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    if selectedSubcategory?.persistentModelID == subcategory.persistentModelID {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.electricIndigo)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(NSLocalizedString("scheduled.select.subcategory", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(NSLocalizedString("action.cancel", comment: "")) {
                        showCategoriesSheet = false
                    }
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var activeAccounts: [Account] {
        allAccounts.filter { !$0.isArchived }
    }

    private var activeTags: [Tag] {
        allTags.filter { $0.isActive }
    }

    private var expenseCategories: [Category] {
        // Filter based on transaction type
        if transactionType == "income" {
            return categories.filter { $0.isIncome }
        } else {
            return categories.filter { !$0.isIncome }
        }
    }

    // MARK: - Validation

    private var canSave: Bool {
        !name.isEmpty && !amount.isEmpty && Double(amount) != nil
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
        recurrenceType = RecurrenceType(rawValue: payment.recurrenceType) ?? .monthly
        nextDueDate = payment.nextDueDate
        dayOfMonth = payment.dayOfMonth ?? 1
        dayOfWeek = payment.dayOfWeek ?? 1
        notifyOnDueDate = payment.notifyOnDueDate
        notifyDaysBefore = payment.notifyDaysBefore
        isActive = payment.isActive
    }

    private func savePayment() {
        guard let amountValue = Double(amount) else { return }

        // Get tags array
        let tagsArray = activeTags.filter { selectedTags.contains($0.persistentModelID) }

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
            existingPayment.recurrenceType = recurrenceType.rawValue
            existingPayment.nextDueDate = nextDueDate
            existingPayment.dayOfMonth = recurrenceType == .monthly ? dayOfMonth : nil
            existingPayment.dayOfWeek = recurrenceType == .weekly ? dayOfWeek : nil
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
                recurrenceType: recurrenceType.rawValue,
                nextDueDate: nextDueDate,
                dayOfMonth: recurrenceType == .monthly ? dayOfMonth : nil,
                dayOfWeek: recurrenceType == .weekly ? dayOfWeek : nil,
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
